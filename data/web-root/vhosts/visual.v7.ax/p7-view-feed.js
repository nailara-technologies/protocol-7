// p7-view-feed.js : parser, state and dump of the p7-view text feed
//
// the contract is data/md/design/VISUALIZATION-3D-RECOMMENDATIONS.md section 4 :
// a head in p7 config style [ `=` and `:` equivalent ], one empty line, then
// rows. a row is one fact : a kind word, then fields separated by single
// spaces. whole numbers only, `-` for an empty field, truth values as words.
//
// runs without a canvas and without a dom [ node or a plain script tag ].
// no json, no checksum port : `body.bmw` is kept and shown, not verified here.
//
// rule of the readout : this file adds, divides and predicts nothing. it holds
// rows and gives them back. dump( parse( text ) ) equals a canonical text
// byte for byte, or the text was refused.

( function ( root ) {
    'use strict';

    var FORMAT_NAME    = 'p7-view';
    var FORMAT_VERSION = '1';
    var HEAD_KEY_WIDTH = 14;    // canonical head : key padded to 14, then `= `
    var MAX_ERRORS     = 64;    // refusal list is bounded, the count is not

    // column types by column name. the order of the columns always comes from
    // the head [ cols.<kind> ], only the meaning of a name is fixed here.
    // a name not listed is a plain word.
    var NUMBER_COLUMNS = {
        cap : 1, fill : 1, held : 1, reserved : 1, given : 1, leftover : 1,
        horizon : 1, price : 1, entered : 1, number : 1, depth : 1,
        deadline : 1, places : 1, holds : 1
    };
    var TRUTH_COLUMNS = { result : 1 };
    var PATH_COLUMNS  = { path : 1 };
    var TRUTH_WORDS   = { 'true' : 1, 'false' : 1, 'unknown' : 1 };

    // columns that name a row. the first one present in cols.<kind> is the
    // key of the kind ; a kind with none of them holds one row [ `sum` ]
    var KEY_COLUMNS = [ 'id', 'number' ];

    var RE_HEAD   = /^([a-z0-9][a-z0-9._-]*)( *)([=:])( *)(.*)$/;
    var RE_NUMBER = /^-?(0|[1-9][0-9]*)$/;
    var RE_FRAME  = /^(0|[1-9][0-9]*)$/;
    var RE_KIND   = /^[a-z][a-z0-9_-]*$/;
    var RE_PATH   = /^[0-9]+\.[0-9]+\.[0-9]+(\/[0-9]+\.[0-9]+\.[0-9]+)*$/;
    var RE_CTRL   = /[\x00-\x1f\x7f]/;

    function pad_key( key ) {
        var out = key;
        while ( out.length < HEAD_KEY_WIDTH ) out += ' ';
        return out;
    }

    // one field of a row, checked against the type of its column.
    // returns the reason of a refusal, or null
    function check_field( col, tok ) {
        if ( tok === '-' ) return null;    // the empty field
        if ( NUMBER_COLUMNS[col] ) {
            if ( !RE_NUMBER.test( tok ) )
                return 'column ' + col + ' wants a whole number, got ' + tok;
            if ( tok === '-0' ) return 'column ' + col + ' : -0 is not a number';
            if ( !Number.isSafeInteger( Number( tok ) ) )
                return 'column ' + col + ' : number too large to hold exactly';
            return null;
        }
        if ( TRUTH_COLUMNS[col] ) {
            if ( !TRUTH_WORDS[tok] )
                return 'column ' + col + ' wants true \\ false \\ unknown, got '
                    + tok;
            return null;
        }
        if ( PATH_COLUMNS[col] ) {
            if ( !RE_PATH.test( tok ) )
                return 'column ' + col + ' wants a path of triples, got ' + tok;
            var parts = tok.split( /[.\/]/ );
            for ( var i = 0 ; i < parts.length ; i++ ) {
                if ( parts[i].length > 1 && parts[i].charAt( 0 ) === '0' )
                    return 'column path : leading zero in ' + tok;
                if ( Number( parts[i] ) > 255 )
                    return 'column path : octet above 255 in ' + tok;
            }
            return null;
        }
        return null;    // a word : any token without a space
    }

    // parse a whole feed text. returns a feed object, `ok` false when any
    // line was refused [ then nothing of it is to be drawn ]
    function parse( text ) {
        var feed = {
            ok      : false,
            errors  : [],         // { line, reason }, at most MAX_ERRORS
            refused : 0,          // count of refused lines, unbounded
            head    : [],         // [ key, value ] in file order
            headMap : {},
            cols    : {},         // kind -> [ column names ]
            keyCol  : {},         // kind -> index of the key column, or -1
            frames  : [],         // { n, whole, rows : [ { kind, fields } ] }
            skipped : 0,          // rows of an unknown kind, skipped
            skippedKinds : {},    // kind -> count
            rowCount : 0
        };

        function refuse( line, reason ) {
            feed.refused++;
            if ( feed.errors.length < MAX_ERRORS )
                feed.errors.push( { line : line, reason : reason } );
        }

        if ( typeof text !== 'string' || !text.length ) {
            refuse( 0, 'empty feed' );
            return feed;
        }
        if ( text.charAt( text.length - 1 ) !== '\n' ) {
            refuse( 0, 'the last line has no line end' );
            return feed;
        }

        var lines = text.split( '\n' );
        lines.pop();    // the piece after the last line end

        // ---- head : up to the first empty line ----
        var ln = 0;
        for ( ; ln < lines.length ; ln++ ) {
            var hl = lines[ln];
            if ( hl === '' ) break;
            if ( RE_CTRL.test( hl ) ) {
                refuse( ln + 1, 'control character [ tab \\ cr ] in the head' );
                continue;
            }
            var m = RE_HEAD.exec( hl );
            if ( !m ) { refuse( ln + 1, 'head line without key = value' ); continue; }
            var key = m[1], value = m[5];
            if ( value !== value.trim() || value === '' ) {
                refuse( ln + 1, 'head value empty or padded : ' + key );
                continue;
            }
            if ( Object.prototype.hasOwnProperty.call( feed.headMap, key ) ) {
                refuse( ln + 1, 'head key twice : ' + key );
                continue;
            }
            feed.head.push( [ key, value ] );
            feed.headMap[key] = value;
            if ( key.indexOf( 'cols.' ) === 0 ) {
                var kind = key.substring( 5 );
                var names = value.split( ' ' );
                var seen = {}, bad = !RE_KIND.test( kind );
                for ( var c = 0 ; c < names.length ; c++ ) {
                    if ( names[c] === '' || seen[ names[c] ] ) bad = true;
                    seen[ names[c] ] = 1;
                }
                if ( bad || kind === 'frame' || kind === 'gone' ) {
                    refuse( ln + 1, 'bad column list : ' + key );
                    continue;
                }
                feed.cols[kind] = names;
                feed.keyCol[kind] = -1;
                for ( var k = 0 ; k < KEY_COLUMNS.length ; k++ ) {
                    var at = names.indexOf( KEY_COLUMNS[k] );
                    if ( at >= 0 ) { feed.keyCol[kind] = at; break; }
                }
            }
        }
        if ( ln >= lines.length ) {
            refuse( ln, 'no empty line between head and rows' );
            return feed;
        }
        if ( feed.headMap.format !== FORMAT_NAME + ' ' + FORMAT_VERSION )
            refuse( 1, 'format is not ' + FORMAT_NAME + ' ' + FORMAT_VERSION );
        if ( !feed.head.length || feed.head[0][0] !== 'format' )
            refuse( 1, 'the first head line is not format' );

        // ---- rows ----
        var frame = null;
        var live  = {};    // kind -> { key -> 1 } : rows that exist now
        var inFrame = {};  // kind + ' ' + key written in this frame

        for ( ln = ln + 1 ; ln < lines.length ; ln++ ) {
            var line = lines[ln], no = ln + 1;
            if ( line === '' ) { refuse( no, 'empty line inside the rows' ); continue; }
            if ( RE_CTRL.test( line ) ) {
                refuse( no, 'control character [ tab \\ cr ] in a row' );
                continue;
            }
            var tok = line.split( ' ' );
            var empty = false;
            for ( var t = 0 ; t < tok.length ; t++ ) if ( tok[t] === '' ) empty = true;
            if ( empty ) {
                refuse( no, 'more than one space, or a space at an end' );
                continue;
            }
            var word = tok[0];

            if ( word === 'frame' ) {
                var whole = false;
                if ( tok.length === 3 && tok[2] === 'whole' ) whole = true;
                else if ( tok.length !== 2 ) {
                    refuse( no, 'frame wants a number [ and the word whole ]' );
                    continue;
                }
                if ( !RE_FRAME.test( tok[1] )
                    || !Number.isSafeInteger( Number( tok[1] ) ) ) {
                    refuse( no, 'frame number is not a whole number : ' + tok[1] );
                    continue;
                }
                var n = Number( tok[1] );
                if ( frame !== null && n <= frame.n ) {
                    refuse( no, 'frame ' + n + ' does not follow frame ' + frame.n );
                    continue;
                }
                frame = { n : n, whole : whole, rows : [] };
                feed.frames.push( frame );
                inFrame = {};
                if ( whole ) live = {};
                continue;
            }

            if ( frame === null ) { refuse( no, 'row before the first frame' ); continue; }
            if ( !RE_KIND.test( word ) ) { refuse( no, 'bad kind word : ' + word ); continue; }

            if ( word === 'gone' ) {
                if ( tok.length !== 3 ) { refuse( no, 'gone wants a kind and an id' ); continue; }
                var gk = tok[1], gid = tok[2];
                if ( !feed.cols[gk] ) {
                    // gone of a kind this head does not name : skipped as its rows are
                    feed.skipped++;
                    feed.skippedKinds[gk] = ( feed.skippedKinds[gk] || 0 ) + 1;
                    continue;
                }
                if ( !live[gk] || !live[gk][gid] ) {
                    refuse( no, 'gone of a row that is not there : ' + gk + ' ' + gid );
                    continue;
                }
                if ( inFrame[ gk + ' ' + gid ] ) {
                    refuse( no, 'row written and gone in one frame : ' + gk + ' ' + gid );
                    continue;
                }
                delete live[gk][gid];
                inFrame[ gk + ' ' + gid ] = 1;
                frame.rows.push( { kind : 'gone', fields : [ gk, gid ] } );
                feed.rowCount++;
                continue;
            }

            var cols = feed.cols[word];
            if ( !cols ) {
                // an unknown kind is skipped and counted, never guessed at
                feed.skipped++;
                feed.skippedKinds[word] = ( feed.skippedKinds[word] || 0 ) + 1;
                continue;
            }
            if ( tok.length - 1 !== cols.length ) {
                refuse( no, word + ' wants ' + cols.length + ' fields, got '
                    + ( tok.length - 1 ) );
                continue;
            }
            var fields = new Array( cols.length ), why = null;
            for ( var f = 0 ; f < cols.length ; f++ ) {
                var raw = tok[ f + 1 ];
                why = check_field( cols[f], raw );
                if ( why ) break;
                fields[f] = raw === '-' ? null
                    : NUMBER_COLUMNS[ cols[f] ] ? Number( raw ) : raw;
            }
            if ( why ) { refuse( no, why ); continue; }

            var kc = feed.keyCol[word];
            var rowKey = kc < 0 ? '' : fields[kc];
            if ( kc >= 0 && rowKey === null ) {
                refuse( no, word + ' : the key field is empty' );
                continue;
            }
            rowKey = String( rowKey );
            if ( inFrame[ word + ' ' + rowKey ] ) {
                refuse( no, 'row twice in one frame : ' + word + ' ' + rowKey );
                continue;
            }
            inFrame[ word + ' ' + rowKey ] = 1;
            if ( !live[word] ) live[word] = {};
            live[word][rowKey] = 1;
            frame.rows.push( { kind : word, fields : fields } );
            feed.rowCount++;
        }

        if ( !feed.frames.length ) refuse( lines.length, 'no frame row' );
        else if ( feed.frames[0].n !== 0 ) refuse( 0, 'the first frame is not frame 0' );

        // a file source states its frame count, and it must hold
        if ( feed.headMap.frames !== undefined
            && feed.headMap.source !== 'live' ) {
            if ( !RE_FRAME.test( feed.headMap.frames ) )
                refuse( 0, 'head frames is not a whole number' );
            else if ( Number( feed.headMap.frames ) !== feed.frames.length )
                refuse( 0, 'head says ' + feed.headMap.frames + ' frames, rows hold '
                    + feed.frames.length );
        }

        feed.ok = feed.refused === 0;
        return feed;
    }

    // write back what is held, as text. head lines in file order in the
    // canonical form, one empty line, then every frame and row
    function dump( feed ) {
        var out = [];
        for ( var h = 0 ; h < feed.head.length ; h++ )
            out.push( pad_key( feed.head[h][0] ) + '= ' + feed.head[h][1] );
        out.push( '' );
        for ( var i = 0 ; i < feed.frames.length ; i++ ) {
            var fr = feed.frames[i];
            out.push( 'frame ' + fr.n + ( fr.whole ? ' whole' : '' ) );
            for ( var r = 0 ; r < fr.rows.length ; r++ ) {
                var row = fr.rows[r], line = row.kind;
                for ( var f = 0 ; f < row.fields.length ; f++ )
                    line += ' ' + ( row.fields[f] === null ? '-' : row.fields[f] );
                out.push( line );
            }
        }
        return out.join( '\n' ) + '\n';
    }

    // first difference of two texts by line : null when equal
    function differs_at( a, b ) {
        if ( a === b ) return null;
        var la = a.split( '\n' ), lb = b.split( '\n' );
        var n = Math.max( la.length, lb.length );
        for ( var i = 0 ; i < n ; i++ )
            if ( la[i] !== lb[i] ) return i + 1;
        return n;
    }

    // index of a column of a kind by its name, -1 when the head has none
    function col_index( feed, kind, name ) {
        var cols = feed.cols[kind];
        return cols ? cols.indexOf( name ) : -1;
    }

    // the rows that hold at frame index `at` [ position in feed.frames ] :
    // kind -> { key -> fields }. frame 0 is whole, a later row replaces the
    // row of the same kind and key, `gone` removes one
    function state_at( feed, at ) {
        var state = {};
        for ( var i = 0 ; i <= at && i < feed.frames.length ; i++ ) {
            var fr = feed.frames[i];
            if ( fr.whole ) state = {};
            for ( var r = 0 ; r < fr.rows.length ; r++ ) {
                var row = fr.rows[r];
                if ( row.kind === 'gone' ) {
                    if ( state[ row.fields[0] ] )
                        delete state[ row.fields[0] ][ row.fields[1] ];
                    continue;
                }
                var kc = feed.keyCol[row.kind];
                var key = kc < 0 ? '' : String( row.fields[kc] );
                if ( !state[row.kind] ) state[row.kind] = {};
                state[row.kind][key] = row.fields;
            }
        }
        return state;
    }

    // the keys of a kind in the order of their first row
    function keys_of( feed, kind ) {
        var seen = {}, keys = [];
        var kc = feed.keyCol[kind];
        if ( kc === undefined ) return keys;
        for ( var i = 0 ; i < feed.frames.length ; i++ ) {
            var rows = feed.frames[i].rows;
            for ( var r = 0 ; r < rows.length ; r++ ) {
                if ( rows[r].kind !== kind ) continue;
                var key = kc < 0 ? '' : String( rows[r].fields[kc] );
                if ( !seen[key] ) { seen[key] = 1; keys.push( key ); }
            }
        }
        return keys;
    }

    // one column of one row over all frames, as a typed column. the value at
    // a frame is the field of the row that holds there [ a row holds until it
    // is replaced or gone ] ; NaN where no row holds or the field is empty.
    // nothing is computed between frames
    function column( feed, kind, key, name ) {
        var ci = col_index( feed, kind, name );
        var out = new Float64Array( feed.frames.length );
        var kc = feed.keyCol[kind];
        var cur = NaN;
        for ( var i = 0 ; i < feed.frames.length ; i++ ) {
            var fr = feed.frames[i];
            if ( fr.whole ) cur = NaN;
            for ( var r = 0 ; r < fr.rows.length && ci >= 0 ; r++ ) {
                var row = fr.rows[r];
                if ( row.kind === 'gone' ) {
                    if ( row.fields[0] === kind && row.fields[1] === key ) cur = NaN;
                    continue;
                }
                if ( row.kind !== kind ) continue;
                if ( ( kc < 0 ? '' : String( row.fields[kc] ) ) !== key ) continue;
                var v = row.fields[ci];
                cur = typeof v === 'number' ? v : NaN;
            }
            out[i] = cur;
        }
        return out;
    }

    // the rows of one kind as they were written, each with its frame :
    // [ { at, frame, fields } ]. a `prop` row is an event of its frame,
    // so the marks of a failed property come from here, not from state_at
    function rows_of( feed, kind ) {
        var out = [];
        for ( var i = 0 ; i < feed.frames.length ; i++ ) {
            var rows = feed.frames[i].rows;
            for ( var r = 0 ; r < rows.length ; r++ )
                if ( rows[r].kind === kind )
                    out.push( { at : i, frame : feed.frames[i].n,
                        fields : rows[r].fields } );
        }
        return out;
    }

    // the `prop` rows with a given result word : [ { at, frame, number } ]
    function prop_marks( feed, result ) {
        var ni = col_index( feed, 'prop', 'number' );
        var ri = col_index( feed, 'prop', 'result' );
        var out = [];
        if ( ni < 0 || ri < 0 ) return out;
        var rows = rows_of( feed, 'prop' );
        for ( var i = 0 ; i < rows.length ; i++ )
            if ( rows[i].fields[ri] === result )
                out.push( { at : rows[i].at, frame : rows[i].frame,
                    number : rows[i].fields[ni] } );
        return out;
    }

    var api = {
        parse      : parse,
        dump       : dump,
        differs_at : differs_at,
        col_index  : col_index,
        state_at   : state_at,
        keys_of    : keys_of,
        column     : column,
        rows_of    : rows_of,
        prop_marks : prop_marks,
        FORMAT     : FORMAT_NAME + ' ' + FORMAT_VERSION
    };

    if ( typeof module !== 'undefined' && module.exports ) module.exports = api;
    else root.P7ViewFeed = api;

} )( typeof globalThis !== 'undefined' ? globalThis : this );
