#!/usr/bin/perl
## test-mcp-cloud-pty-text.pl -- unit tests for the pty text helpers in
## bin/mcp-server-p7 [ _cloud_plain_text \ _cloud_trust_prompt_seen ]
##
## the mcp server is a script, not a library — so the two subs are extracted
## from its source [ balanced-brace scan ] and evaled here. asserts :
##
## - cursor-forward escapes \e[nC render as n spaces BEFORE the generic csi
## strip [ dropping them would glue redrawn text onto stale columns ] ; bare
## \e[C is one space
## - valid utf-8 off the pty survives intact
## [ no mojibake, no mangled multibyte chars ] ; lone invalid bytes fall back
## to the replacement char
## - the result is idempotent [ claude_cloud_status runs the capture through
## _cloud_plain_text twice — the decode guard must make that harmless ]
## - the one-time workspace trust dialog is detected in a pty-ish capture
## [ exact text "Do you trust the files in this folder?" ] and a normal
## capture is NOT flagged
##
## usage : perl bin/test-scripts/test-mcp-cloud-pty-text.pl  env :
## P7_MCP_CLOUD_SRC -- server source to extract from  [ default
## <root>/bin/mcp-server-p7 ; point at an old copy to see the tests bite on
## the unfixed code ]

use v5.32;
use strict;
use warnings;
use English qw| -no_match_vars |;

use Encode  qw| encode decode |;
use FindBin qw| $RealBin |;
use File::Spec;

my $root_path = abs_path(
    File::Spec->rel2abs( File::Spec->catdir( $RealBin, '..', '..' ) ) );
use Cwd qw| abs_path |;

my $server_src = $ENV{'P7_MCP_CLOUD_SRC'}
    // File::Spec->catfile( $root_path, qw| bin mcp-server-p7 | );

my $tests_run    = 0;
my $tests_failed = 0;

sub check {
    my ( $label, $condition ) = @_;
    $tests_run++;
    if ($condition) {
        printf "[ ok ] %s\n", $label;
    } else {
        $tests_failed++;
        printf "[ FAIL ] %s\n", $label;
    }
    return $condition;
}

##[ extract + compile the two subs from the server source ]##

sub extract_sub {
    my ( $src, $name ) = @_;
    my $start = index( $src, "sub $name {" );
    return undef if $start < 0;
    my $pos   = index( $src, '{', $start );
    my $depth = 0;
    while (1) {
        my $open  = index( $src, '{', $pos );
        my $close = index( $src, '}', $pos );
        die "unbalanced braces in sub $name" if $close < 0;
        if ( $open >= 0 and $open < $close ) {
            $depth++;
            $pos = $open + 1;
        } else {
            $depth--;
            $pos = $close + 1;
            last if $depth == 0;
        }
    }
    return substr( $src, $start, $pos - $start );
}

open( my $fh, '<:raw', $server_src )
    or die "cannot read $server_src : $!";
my $src = do { local $/ = undef; <$fh> };
close($fh);

my $plain_text_src = extract_sub( $src, '_cloud_plain_text' );
my $trust_seen_src = extract_sub( $src, '_cloud_trust_prompt_seen' );

die "_cloud_plain_text not " . "found in $server_src"
    if not defined $plain_text_src;

## the trust helper is NEW : on the unfixed source it is absent — the ##
## detection checks below then report FAIL instead of dying           ##
my $has_trust_sub = defined $trust_seen_src;

{
    ## subs compiled in this package, same as the server file scope ##
    my $code = "package main; $plain_text_src\n"
        . ( $trust_seen_src // q{} ) . "\n1;";
    eval $code;    ## no critic
    die "compile error in extracted subs : $EVAL_ERROR" if $EVAL_ERROR;
}

die "_cloud_plain_text did not compile"
    if not defined &main::_cloud_plain_text;

printf ":: testing pty text helpers extracted from %s\n", $server_src;

##[ cursor-forward rendering ]##

check '\e[5C renders as 5 spaces',
    main::_cloud_plain_text("pre\e[5Cpost") eq 'pre     post';

check 'bare \e[C renders as 1 space',
    main::_cloud_plain_text("a\e[Cb") eq 'a b';

check 'cursor-forward kept when other escapes strip',
    main::_cloud_plain_text("ab\e[3C\e[2Kx") eq 'ab   x';

check 'colour codes still stripped',
    main::_cloud_plain_text("\e[1;31mRED\e[0m") eq 'RED';

##[ utf-8 handling ]##

my $wide    = "→ héllo ✓ · プロトコル";
my $wide_fb = encode( 'UTF-8', $wide );

check 'valid utf-8 bytes survive intact',
    main::_cloud_plain_text($wide_fb) eq $wide;

check 'utf-8 intact alongside rendered cursor-forward',
    main::_cloud_plain_text( "\e[2C" . $wide_fb ) eq '  ' . $wide;

check 'lone invalid byte falls back to replacement char',
    main::_cloud_plain_text("a\xffb") eq "a\x{FFFD}b";

check 'pure-ascii passes through unchanged',
    main::_cloud_plain_text("plain text\n") eq "plain text\n";

##[ idempotency — cloud_status runs the capture through twice ]##

my $pty_capture = "\e[1G\e[K" . $wide_fb . "\e[3C\r\nsecond line\r\n";
my $once        = main::_cloud_plain_text($pty_capture);
my $twice       = main::_cloud_plain_text($once);

check '_cloud_plain_text is idempotent', $twice eq $once;

##[ trust dialog detection ]##

my $trust_capture
    = "\e[?25l\e[2JDo you trust the files in this folder?\r\n"
    . "\e[1m/data/projects/protocol-7/data/state/cloud-launch/protocol-7"
    . "\e[0m\r\n> \e[0m";

if ( not $has_trust_sub ) {
    check 'trust dialog detection implemented [_cloud_trust_prompt_seen]', 0;
    check 'normal capture NOT flagged as trust dialog',                    0;
    check 'empty capture NOT flagged as trust dialog',                     0;
} else {
    check 'trust dialog detected in a pty-ish capture',
        main::_cloud_trust_prompt_seen($trust_capture) == 1;

    check 'normal capture NOT flagged as trust dialog',
        main::_cloud_trust_prompt_seen(
              "Created cloud session: test\nView: "
            . "https://claude.ai/code/session_abc123\n" ) == 0;

    check 'empty capture NOT flagged as trust dialog',
        main::_cloud_trust_prompt_seen('') == 0;
}

##[ summary ]##

printf ":: %d run, %d failed\n", $tests_run, $tests_failed;
exit( $tests_failed ? 1 : 0 );

#,,.,,,..,.,,,.,,,,..,...,,..,.,,,,,,,..,,.,.,..,,...,...,..,,,,.,,..,,.,,.,.,
#RBVILQGEUYJZ5VZAVHR2S3YHAAGSOL2MBTLISIFPWNWXJGGGKQPRQ45MKK2SEDGNI3BGLAWRCXINC
#\\\|MPZXZMLKUXLPFRBDN6JDG5TCLLPW5FAD7DF75BPOS53J7XFD5WZ \ / AMOS7 \ YOURUM ::
#\[7]TV77YQ5YUPNJVXHUPOWYWP57VOW7LYJF4POZ3KFIWTEGS6FWWOCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
