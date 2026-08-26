#!/usr/bin/env perl

use v5.24;
use strict;
use warnings;
use English;

use lib '/data/projects/protocol-7/data/lib-path/pm';

use AMOS7::STDIO::Tags;
use Crypt::Misc;

## [ helper to load a module file as a coderef ] ##
sub load_module {
    my $path = shift;
    open my $fh, qw| < |, $path or die "cannot open $path: $OS_ERROR";
    local $RS = undef;
    my $src = <$fh>;
    close $fh;
    my $cref = eval "sub {\n$src\n}";
    die "compile error in $path: $EVAL_ERROR" if $EVAL_ERROR or ref $cref ne qw| CODE |;
    return $cref;
}

my $encoder = load_module('/data/projects/protocol-7/modules/base.stdio.frame.encode');
my $decoder = load_module('/data/projects/protocol-7/modules/base.stdio.frame.decode');

my $tests_passed = 0;
my $tests_failed = 0;

sub ok {
    my ( $cond, $desc ) = @ARG;
    $desc //= '';
    if ($cond) {
        say "ok - $desc";
        $tests_passed++;
    } else {
        say "not ok - $desc";
        $tests_failed++;
    }
}

## [ round-trip for all 8 tags x 3 encodings ] ##############################

my @tags = ( qw| META SIN RIN EOUT TOUT NUM STR ERR | );
my @encs = ( qw| b32 nibble byte-pack | );
my $payload = 'hello protocol-7';

for my $tag (@tags) {
    for my $enc (@encs) {
        my $hdr = {};
        if ( $tag eq 'EOUT' or $tag eq 'ERR' ) {
            $hdr->{'fd'} = 1;
        }

        my $encoded = $encoder->( $tag, $enc, $payload, $hdr );
        ok( defined $encoded, "encode: $tag / $enc produces bytes" );

        my $buf = $encoded;
        my @recs = $decoder->( \$buf );
        ok( scalar @recs == 1,
            "decode: $tag / $enc yields exactly one record" );

        my $rec = $recs[0];
        ok( $rec->{'tag'} eq $tag,
            "round-trip tag matches [ $tag / $enc ]" );
        ok( $rec->{'encoding'} eq $enc,
            "round-trip encoding matches [ $tag / $enc ]" );
        if ( $tag eq 'META' ) {
            ## [ META payload is serialized from header, not passed through ] ##
            ok( $rec->{'header'}->{'subtype'} eq 'end-run',
                "round-trip META payload deserialized [ $tag / $enc ]" );
        } else {
            ok( ${ $rec->{'payload_sref'} } eq $payload,
                "round-trip payload matches [ $tag / $enc ]" );
        }

        if ( $tag eq qw| EOUT | or $tag eq qw| ERR | ) {
            ok( $rec->{'header'}->{'fd'} == 1,
                "round-trip fd header matches [ $tag / $enc ]" );
        }
    }
}

## [ inversion rule conformance ] ###########################################

## [ construct a byte with 000 . pair ] ##
##   nibble = payload(3) + sep(1)  →  0000 = 0x0  ##
my $bad_buf = chr( 0x00 );    ## [ high nibble = 000 . ] ##
my @bad_recs = eval { $decoder->( \$bad_buf ) };
my $bad_err = $@;
ok( !defined $bad_recs[0] && length $bad_err,
    "decoder rejects 000 . pair as framing error" );

## [ verify 000 , is accepted as boundary ] ##
my $good_buf = chr( 0x82 );  ## [ 000, + header frame 0 ] ##
$good_buf .= chr( 0x56 );    ## [ header frames 1,2 ] ##
$good_buf .= chr( 0x38 );    ## [ header frame 3 + closing META ] ##
my @good_recs = eval { $decoder->( \$good_buf ) };
ok( scalar @good_recs == 1 && $good_recs[0]->{'tag'} eq 'EOUT',
    "decoder accepts valid 000 , boundary" );

## [ partial-buffer safety ] ################################################

my $full_enc = $encoder->( 'STR', 'byte-pack', 'partial test', {} );
my $full_enc_copy = $full_enc;
my @full_recs = $decoder->( \$full_enc_copy );

my @byte_at_a_time;
my $partial_buf = '';
for my $i ( 0 .. length($full_enc) - 1 ) {
    $partial_buf .= substr $full_enc, $i, 1;
    push @byte_at_a_time, [ $decoder->( \$partial_buf ) ];
}

my @all_from_partial = map { @$_ } @byte_at_a_time;
ok( scalar @all_from_partial == 1,
    "partial feeding yields same record count as full buffer" );
ok( $all_from_partial[0]->{'tag'} eq 'STR',
    "partial feeding yields correct tag" );
ok( ${ $all_from_partial[0]->{'payload_sref'} } eq 'partial test',
    "partial feeding yields correct payload" );
ok( length $partial_buf <= 1,
    "partial feeding leaves at most padding byte in buffer" );

## [ META scope nesting ] ###################################################

my $scope_enter = $encoder->(
    'META', 'byte-pack', '',
    {   'subtype'  => 'scope-enter',
        'hop_id'   => 42,
        'slot_addr' => 'v7.console',
        'origin'   => 'weather'
    }
);

my $eout_run = $encoder->(
    'EOUT', 'b32', 'loaded config',
    { 'fd' => 1 }
);

my $scope_leave = $encoder->(
    'META', 'byte-pack', '',
    {   'subtype' => 'scope-leave',
        'origin'  => 'weather'
    }
);

my $nested_buf = $scope_enter . $eout_run . $scope_leave;
my @nested_recs = $decoder->( \$nested_buf );

ok( scalar @nested_recs == 3,
    "scope nesting yields three records" );

ok( $nested_recs[0]->{'tag'} eq 'META'
    && $nested_recs[0]->{'header'}->{'subtype'} eq 'scope-enter',
    "first record is scope-enter" );

ok( $nested_recs[0]->{'header'}->{'origin'} eq 'weather'
    && $nested_recs[0]->{'header'}->{'slot_addr'} eq 'v7.console'
    && $nested_recs[0]->{'header'}->{'hop_id'} == 42,
    "scope-enter header carries full origin + slot_addr + hop_id" );

ok( $nested_recs[1]->{'tag'} eq 'EOUT',
    "second record is EOUT run" );

ok( $nested_recs[2]->{'tag'} eq 'META'
    && $nested_recs[2]->{'header'}->{'subtype'} eq 'scope-leave',
    "third record is scope-leave" );

ok( $nested_recs[2]->{'header'}->{'origin'} eq 'weather',
    "scope-leave carries origin" );

## [ summary ] ##############################################################

say '';
say "tests passed: $tests_passed";
say "tests failed: $tests_failed";

exit( $tests_failed > 0 ? 1 : 0 );

#,,.,,..,,,,.,,.,,,..,,.,,..,,.,,,.,,,..,,,..,..,,...,...,,,.,,..,..,,.,.,...,
#HT6NPSGHLUNNRZPEV43ULNUEAFXDVKAU2GFHRZBGC2MBJMDJGQEYGZY24DIWEMWTNH36FPS3LTFOW
#\\\|UFLBCPNQUZKNK6HDLIO4U5Z2WG743TNWA2Q4RLJJ34DYDUAINAS \ / AMOS7 \ YOURUM ::
#\[7]XQP4TSRGM574TQTACNXZCPAVVHMQR6G556MONYIMUAZ3QIO7Q6AI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
