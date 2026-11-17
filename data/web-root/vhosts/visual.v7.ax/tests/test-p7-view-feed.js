#!/usr/bin/env node
// test-p7-view-feed.js : headless check of the p7-view feed parser
//
// run : node bin/test-scripts/test-p7-view-feed.js
//
// checks [ design VISUALIZATION-3D-RECOMMENDATIONS.md, stage 1 ] :
//   - the parser runs without a canvas
//   - the dump of the loaded fixture equals the file, byte for byte
//   - the `prop false` marker is found at its frame, and nowhere else
//   - a column moved in cols.pool gives the same values
//   - an unknown kind is skipped and counted
//   - malformed lines are refused, with their line number

'use strict';

const fs   = require( 'fs' );
const path = require( 'path' );

const web_dir = path.join( __dirname, '..' );
const feed_js = path.join( web_dir, 'p7-view-feed.js' );
const fixture = path.join( web_dir, 'p7-view-fixture-ramp.txt' );

const P7 = require( feed_js );

let passed = 0, failed = 0;

function ok( cond, name, detail ) {
    if ( cond ) { passed++; console.log( 'ok   : ' + name ); }
    else {
        failed++;
        console.log( 'FAIL : ' + name + ( detail ? ' [ ' + detail + ' ]' : '' ) );
    }
}

// ---- 1. no canvas, no dom ----
ok( typeof document === 'undefined' && typeof window === 'undefined',
    'the parser is loaded without a dom' );

// ---- 2. the fixture loads, the dump equals the file ----
const bytes = fs.readFileSync( fixture );
const text  = bytes.toString( 'utf8' );
const feed  = P7.parse( text );

ok( feed.ok, 'the fixture is accepted',
    feed.errors.map( e => 'line ' + e.line + ' : ' + e.reason ).join( ' ; ' ) );
ok( feed.frames.length === 20, 'the fixture holds 20 frames',
    'got ' + feed.frames.length );
ok( P7.keys_of( feed, 'pool' ).join( ' ' ) === 'root a b',
    'the fixture holds the three pools root a b' );
ok( feed.skipped === 0, 'no row of the fixture was skipped' );

const dumped = Buffer.from( P7.dump( feed ), 'utf8' );
const at     = P7.differs_at( text, dumped.toString( 'utf8' ) );
ok( Buffer.compare( bytes, dumped ) === 0,
    'the dump equals the file byte for byte [ ' + bytes.length + ' bytes ]',
    at === null ? 'bytes differ' : 'differs at line ' + at );

// ---- 3. the failed property is at its frame, and nowhere else ----
const fails = P7.prop_marks( feed, 'false' );
ok( fails.length === 1 && fails[0].frame === 13 && fails[0].number === 4,
    'one `prop false` marker : property 4 at frame 13',
    fails.map( f => f.number + '@' + f.frame ).join( ' ' ) );
ok( P7.prop_marks( feed, 'true' ).length === 10,
    'ten `prop true` rows [ nine at frame 0, one at frame 14 ]' );

// ---- 4. the state : rows hold until replaced, nothing is computed ----
const fill_b = P7.column( feed, 'pool', 'b', 'fill' );
ok( fill_b[13] === 158 && fill_b[14] === 150 && fill_b[19] === 150,
    'pool b fill reads 158 at frame 13, 150 at 14 and at 19 [ row held ]' );
const state13 = P7.state_at( feed, 13 );
ok( state13.pool.b[ P7.col_index( feed, 'pool', 'cap' ) ] === 150
    && state13.prop['4'][1] === 'false' && state13.prop['3'][1] === 'true',
    'state at frame 13 : pool b cap 150, prop 4 false, prop 3 still true' );

// ---- 5. a column moved in cols.pool gives the same values ----
{
    const moved = text.split( '\n' ).map( line => {
        if ( line.indexOf( 'cols.pool' ) === 0 )
            return 'cols.pool     = id parent fill cap held reserved given'
                + ' leftover horizon price';
        const t = line.split( ' ' );
        if ( t[0] !== 'pool' ) return line;
        const cap = t[3]; t[3] = t[4]; t[4] = cap;
        return t.join( ' ' );
    } ).join( '\n' );
    const f2 = P7.parse( moved );
    let same = f2.ok;
    for ( const key of [ 'root', 'a', 'b' ] )
        for ( const col of [ 'cap', 'fill', 'held', 'reserved', 'leftover' ] ) {
            const x = P7.column( feed, 'pool', key, col );
            const y = P7.column( f2, 'pool', key, col );
            for ( let i = 0 ; i < x.length ; i++ ) if ( x[i] !== y[i] ) same = false;
        }
    ok( same, 'cap and fill swapped in cols.pool : the same columns come out' );
}

// ---- 6. `:` equals `=` in the head, the dump is the canonical form ----
{
    const colon = text.replace( /^source        = sim$/m, 'source: sim' );
    const f3 = P7.parse( colon );
    ok( colon !== text && f3.ok && P7.dump( f3 ) === text,
        'a head line with `:` loads, and dumps in the canonical `=` form' );
}

// ---- 7. an unknown kind is skipped and counted ----
{
    const f4 = P7.parse( text + 'frame 20\nwidget w1 5 5\nwidget w2 1 1\n'
        .replace( /^/, '' ).replace( 'frame 20\n', 'frame 20\n' )
        .replace( /^/, '' ) );
    // the head says 20 frames, so the added frame is refused ; use a live head
    const livetext = text.replace( 'source        = sim', 'source        = live' )
        + 'frame 20\nwidget w1 5 5\nwidget w2 1 1\n';
    const f5 = P7.parse( livetext );
    ok( !f4.ok, 'a file source with more frames than its head states is refused' );
    ok( f5.ok && f5.skipped === 2 && f5.skippedKinds.widget === 2,
        'two rows of the unknown kind widget : skipped and counted',
        'ok ' + f5.ok + ' skipped ' + f5.skipped );
}

// ---- 8. frame deltas : gone, and a whole frame ----
{
    const livetext = text.replace( 'source        = sim', 'source        = live' )
        + 'frame 20\ngone pool b\nframe 25 whole\npool root - 600 1 1 0 0 0 0 0\n';
    const f6 = P7.parse( livetext );
    const s20 = f6.ok ? P7.state_at( f6, 20 ) : null;
    const s21 = f6.ok ? P7.state_at( f6, 21 ) : null;
    ok( f6.ok && !s20.pool.b && !!s20.pool.a
        && !s21.pool.a && s21.pool.root[3] === 1 && !s21.prop,
        '`gone pool b` removes one row, `frame 25 whole` starts again' );
    ok( f6.ok && P7.dump( f6 ) === livetext,
        'the dump keeps `gone` and `whole` as written' );
}

// ---- 9. malformed lines are refused ----
const head_end = text.indexOf( '\n\n' ) + 2;
const head = text.substring( 0, head_end );
const body = text.substring( head_end );

function refused( name, bad_text, want_line, want_word ) {
    const f = P7.parse( bad_text );
    const hit = f.errors.find( e =>
        ( want_line === null || e.line === want_line )
        && e.reason.indexOf( want_word ) >= 0 );
    ok( !f.ok && !!hit, 'refused : ' + name,
        'ok ' + f.ok + ' ; ' + f.errors.map( e => e.line + ' ' + e.reason )
            .join( ' ; ' ) );
}

// a row replaced inside the fixture. line 13 is `pool root - 600 0 ...`
function with_line( no, line ) {
    const l = text.split( '\n' );
    l[ no - 1 ] = line;
    return l.join( '\n' );
}
ok( text.split( '\n' )[12] === 'pool root - 600 0 0 0 0 0 0 0',
    'line 13 of the fixture is the first pool row [ anchor of the checks below ]' );

refused( 'a float',               with_line( 13, 'pool root - 600 0.5 0 0 0 0 0 0' ), 13, 'whole number' );
refused( 'a percent',             with_line( 13, 'pool root - 600 5% 0 0 0 0 0 0' ), 13, 'whole number' );
refused( 'a leading zero',        with_line( 13, 'pool root - 600 007 0 0 0 0 0 0' ), 13, 'whole number' );
refused( 'a word for a number',   with_line( 13, 'pool root - 600 many 0 0 0 0 0 0' ), 13, 'whole number' );
refused( 'a number too large',    with_line( 13, 'pool root - 600 90071992547409930 0 0 0 0 0 0' ), 13, 'too large' );
refused( 'a field missing',       with_line( 13, 'pool root - 600 0 0 0 0 0 0' ), 13, 'wants 10 fields' );
refused( 'a field too many',      with_line( 13, 'pool root - 600 0 0 0 0 0 0 0 0' ), 13, 'wants 10 fields' );
refused( 'two spaces',            with_line( 13, 'pool root -  600 0 0 0 0 0 0 0' ), 13, 'space' );
refused( 'a space at the end',    with_line( 13, 'pool root - 600 0 0 0 0 0 0 0 ' ), 13, 'space' );
refused( 'a tab',                 with_line( 13, 'pool root\t- 600 0 0 0 0 0 0 0' ), 13, 'control' );
refused( 'a carriage return',     with_line( 13, 'pool root - 600 0 0 0 0 0 0 0\r' ), 13, 'control' );
refused( 'an empty key field',    with_line( 13, 'pool - - 600 0 0 0 0 0 0 0' ), 13, 'key field' );
refused( 'a bad truth word',      with_line( 17, 'prop 1 yes' ), 17, 'true' );
refused( 'a row twice in a frame', with_line( 14, 'pool root - 600 0 0 0 0 0 0 0' ), 14, 'twice' );
refused( 'an empty line in the rows', with_line( 13, '' ), 13, 'empty line' );
refused( 'a frame number that goes back', with_line( 26, 'frame 0' ), 26, 'does not follow' );
refused( 'a frame number that is no number', with_line( 26, 'frame two' ), 26, 'not a whole number' );
refused( 'gone of a row that is not there',
    head.replace( '= sim', '= live' ) + body + 'frame 20\ngone pool z\n', null, 'not there' );
refused( 'a row before the first frame', head + 'sum 0 0 0 0\n' + body, 12, 'before the first frame' );
refused( 'a body that starts at frame 1', head + body.replace( 'frame 0\n', 'frame 1\n' ), null, 'frame' );
refused( 'no line end at the end', text.substring( 0, text.length - 1 ), null, 'line end' );
refused( 'no empty line after the head', text.replace( '\n\n', '\n' ), null, 'head' );
refused( 'another format', text.replace( 'p7-view 1', 'p7-view 2' ), 1, 'format' );
refused( 'a head line without a value', text.replace( 'seed          = 13', 'seed' ), 4, 'key = value' );
refused( 'a head key twice', text.replace( 'seed          = 13', 'source        = sim' ), 4, 'twice' );
refused( 'a json text', '{ "format" : "p7-view 1" }\n', null, '' );
refused( 'an empty text', '', null, 'empty' );

// a path column : triples of octets
{
    const ptext = 'format        = p7-view 1\ncols.place    = id depth path kind label\n\n'
        + 'frame 0\nplace a7 1 12.200.31/0.255.7 zenka cube\n';
    const fp = P7.parse( ptext );
    ok( fp.ok && P7.dump( fp ) === ptext, 'a place row with a two scale path loads and dumps' );
    refused( 'a path octet above 255', ptext.replace( '12.200.31', '12.256.31' ), 5, '255' );
    refused( 'a path that is no triple', ptext.replace( '12.200.31/', '12.200/' ), 5, 'triples' );
}

console.log( '' );
console.log( 'passed ' + passed + ' failed ' + failed );
process.exit( failed ? 1 : 0 );

