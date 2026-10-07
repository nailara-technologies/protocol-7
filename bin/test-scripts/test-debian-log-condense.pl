#!/usr/bin/perl
use v5.24;
use strict;
use English;
use warnings;

###                                                                 ###
##  debian.log.condense : standalone harness                         ##
###                                                                 ###

## exercises the real translated module source against captured-style ##
## apt-get \ dpkg output fixtures - no live zenka required :          ##
## - fresh install : one condensed line per package, 'new' as old     ##
## - upgrade : old -> new with remembered sizes                       ##
## - failure : error lines survive verbatim and in order              ##
## - conffile prompt : every prompt block line survives verbatim      ##
## - dropped routine lines counted in one summary line                ##
## - incremental mode [ 3 chunks + state ] == single call             ##

use File::Spec;
use Cwd     qw| abs_path |;
use FindBin qw| $RealBin |;

BEGIN {
    my $up_dir    = File::Spec->updir;
    my $root_path = abs_path(
        File::Spec->rel2abs(
            File::Spec->catdir( $RealBin, $up_dir, $up_dir )
        )
    );
    my $local_lib_path
        = File::Spec->catdir( $root_path, qw| data lib-path pm | );
    die "not found : $local_lib_path" if !-d $local_lib_path;
    unshift( @INC, $local_lib_path );
    $main::root_path = $root_path;
}

use AMOS7::Protocol::P7Syntax qw| p7_syntax__translate |;

##[ p7 runtime environment stubs ]############################################

use constant TRUE  => 5;
use constant FALSE => 0;

our %data;
our %code;
our $call;

##[ module compilation [ same sub-wrapper shape as bin/Protocol-7 ] ]#########

my $fail_count = 0;

sub compile_module {
    my $module_name = shift;
    my $src_path
        = File::Spec->catfile( $main::root_path, 'src', $module_name );
    open( my $fh, '<', $src_path ) or die "cannot read $src_path : $!";
    my $src = join( '', <$fh> );
    close($fh);
    my $translated = p7_syntax__translate($src);
    my $cref       = eval "sub {\n# line 1 \"$module_name\"\n$translated\n}";
    die "compile failed for $module_name : $EVAL_ERROR"
        if not defined $cref;
    $code{$module_name} = $cref;
    return $cref;
}

compile_module('debian.log.condense');

sub call_module {
    my ( $module_name, $params ) = @ARG;
    return $code{$module_name}->($params);
}

sub condense {
    my $lines = shift;
    return call_module( 'debian.log.condense', { 'lines' => $lines } );
}

##[ fixture loading ]#########################################################

sub load_fixture {
    my $name = shift;
    my $path
        = File::Spec->catfile( $RealBin, 'fixtures', 'apt-condense', $name );
    open( my $fh, '<', $path ) or die "cannot read $path : $OS_ERROR";
    my @lines;
    while ( my $line = <$fh> ) {
        last if $line =~ m|^#[,\.]{10,}|;    ## AMOS7 signature footer ##
        push @lines, $line;
    }
    close($fh);
    pop @lines while @lines and $lines[-1] =~ m|^\s*$|;    ## pre-footer ##
    chomp @lines;
    return \@lines;
}

##[ tiny assertion framework ]################################################

sub ok {
    my ( $cond, $label ) = @ARG;
    if ($cond) { say "  ok   : $label"; return }
    $fail_count++;
    say "  FAIL : $label";
    return;
}

sub lines_eq {
    my ( $got, $expected, $label ) = @ARG;
    my $got_str      = join( "\n", @$got );
    my $expected_str = join( "\n", @$expected );
    if ( $got_str eq $expected_str ) { ok( 1, $label ); return }
    $fail_count++;
    say "  FAIL : $label";
    say "  --- expected ---";
    say "  $_" foreach @$expected;
    say "  --- got ---";
    say "  $_" foreach @$got;
    return;
}

##[ 1 : fresh install - one line per package, 'new' as old ]##################

say ': fresh install';

my $a = condense( load_fixture('fresh-install-2-pkgs.log') );

ok( ref $a eq qw| HASH | && $a->{'mode'} eq qw| true |, 'mode true' );

ok( ( $a->{'data'}{'header'} // '' ) eq
        'mirror deb.debian.org  suite testing/main  arch amd64',
    'header line carries mirror, suite and arch'
);

lines_eq(
    $a->{'data'}{'lines'},
    [   'The following NEW packages will be installed:',
        '  hello',
        '0 upgraded, 1 newly installed, 0 to remove and 840 not upgraded.',
        'Need to get 200 kB of archives.',
        'After this operation, 500 kB of additional disk space will be used.',
        'hello  new -> 2.12.3-1  77.4 kB',
        'goodbye  new -> 1.2-3  123 kB',
        '.. 13 routine lines condensed',
    ],
    'fresh install : exact condensed output'
);

my %a_pkg = map { $_->{'pkg'} => $_ } $a->{'data'}{'packages'}->@*;

ok( scalar $a->{'data'}{'packages'}->@* == 2, 'two packages tracked' );
ok( ( $a_pkg{'hello'}{'old'} // '' ) eq qw| new |
        && ( $a_pkg{'hello'}{'new'}    // '' ) eq '2.12.3-1'
        && ( $a_pkg{'hello'}{'size'}   // '' ) eq '77.4 kB'
        && ( $a_pkg{'hello'}{'status'} // '' ) eq qw| installed |,
    'hello : new -> 2.12.3-1, size 77.4 kB, installed'
);
ok( ( $a_pkg{'goodbye'}{'old'} // '' ) eq qw| new |
        && ( $a_pkg{'goodbye'}{'new'}  // '' ) eq '1.2-3'
        && ( $a_pkg{'goodbye'}{'size'} // '' ) eq '123 kB',
    'goodbye : new -> 1.2-3, size 123 kB'
);
ok( $a->{'data'}{'passthrough'} == 5, 'passthrough count is 5' );

##[ 2 : upgrade - old -> new with remembered sizes ]##########################

say ': upgrade';

my $b = condense( load_fixture('upgrade-3-pkgs.log') );

lines_eq(
    $b->{'data'}{'lines'},
    [   'The following packages will be upgraded:',
        '  coreutils libssl3t64 zlib1g',
        '3 upgraded, 0 newly installed, 0 to remove and 837 not upgraded.',
        'Need to get 3577 kB of archives.',
        'After this operation, 1234 kB of '
            . 'additional disk space will be used.',
        'coreutils  9.4-3 -> 9.5-1  1442 kB',
        'libssl3t64  3.3.2-1 -> 3.3.2-2  2023 kB',
        'zlib1g  1.3-8 -> 1.3.1-1  112 kB',
        '.. 14 routine lines condensed',
    ],
    'upgrade : exact condensed output'
);

my @b_pkg = $b->{'data'}{'packages'}->@*;

ok( ( scalar @b_pkg ) == 3, 'three packages tracked' );
my $b_status_ok = 1;
foreach my $rec (@b_pkg) {
    $b_status_ok = 0 unless $rec->{'status'} eq qw| upgraded |;
}
ok( $b_status_ok, 'all three packages marked upgraded' );

##[ 3 : failure - error lines survive verbatim and in order ]#################

say ': failure';

my $c = condense( load_fixture('failure-dpkg-error.log') );

my @c_lines = $c->{'data'}{'lines'}->@*;

my @c_error_expected = (
    'dpkg: error processing package broken-pkg (--configure):',
    ' installed broken-pkg package post-installation '
        . 'script subprocess returned error exit status 1',
    'Errors were encountered while processing:',
    ' broken-pkg',
    'E: Sub-process /usr/bin/dpkg returned an error code (1)',
);

my @c_error_got
    = grep {m{^(?:E:|W:|dpkg: error|Errors were encountered| \S)}} @c_lines;

lines_eq( \@c_error_got, \@c_error_expected,
    'failure : all error lines verbatim and in order' );

my @c_dropped_expected = (
    'The following NEW packages will be installed:',
    '  broken-pkg',
    '0 upgraded, 1 newly installed, 0 to remove and 840 not upgraded.',
    'Need to get 10.2 kB of archives.',
    'After this operation, 45.0 kB of additional disk space will be used.',
    @c_error_expected,
    '.. 8 routine lines condensed',
);

lines_eq( \@c_lines, \@c_dropped_expected,
    'failure : exact condensed output, no condensed line for broken-pkg' );

##[ 4 : conffile prompt - block survives verbatim, then condensed line ]######

say ': conffile prompt';

my $d = condense( load_fixture('conffile-prompt.log') );

my @d_lines = $d->{'data'}{'lines'}->@*;

my @d_prompt_expected = (
    'dpkg: warning: old cfgtool package post-removal '
        . 'script subprocess returned error exit status 1',
    '',
    "Configuration file '/etc/cfgtool/cfgtool.conf'",
    ' ==> Modified (by you or by a script) since installation.',
    '   What would you like to do about it ?  Your options are:',
    q{    Y or I  : install the package maintainer's version},
    '    N or O  : keep your currently-installed version',
    '      D     : show the differences between the versions',
    '      Z     : start a shell to examine the situation',
    ' The default action is to keep your current version.',
    '*** cfgtool.conf (Y/I/N/O/D/Z) [default=N] ? ',
);

my ($d_warn_idx)
    = grep { $d_lines[$ARG] =~ m{^dpkg: warning} } 0 .. $#d_lines;

ok( defined $d_warn_idx, 'conffile : dpkg warning line present' );

my @d_block
    = defined $d_warn_idx
    ? @d_lines[ $d_warn_idx .. $d_warn_idx + $#d_prompt_expected ]
    : [];

lines_eq( \@d_block, \@d_prompt_expected,
    'conffile : prompt block verbatim, contiguous and in order' );

my $d_condensed = 'cfgtool  1.9-4 -> 2.0-1  45.6 kB';

my ($d_cond_idx) = grep { $d_lines[$ARG] eq $d_condensed } 0 .. $#d_lines;

ok( defined $d_warn_idx
        && defined $d_cond_idx
        && $d_cond_idx > $d_warn_idx + $#d_prompt_expected,
    'conffile : condensed line emitted after the prompt block'
);

##[ 5 : incremental mode - 3 chunks with state == single call ]###############

say ': incremental mode';

my $all_lines = load_fixture('upgrade-3-pkgs.log');
my $one_shot  = condense($all_lines);

my @chunk_sizes = ( 8, 8, scalar(@$all_lines) - 16 );
my $state       = {};
my @chunk_out;
my $inc_header;
my $inc_result;

my $offset = 0;
foreach my $chunk_i ( 0 .. 2 ) {
    my @chunk
        = @$all_lines[ $offset .. $offset + $chunk_sizes[$chunk_i] - 1 ];
    $offset += $chunk_sizes[$chunk_i];
    $inc_result = call_module(
        'debian.log.condense',
        {   'lines' => \@chunk,
            'state' => $state,
            'final' => $chunk_i == 2 ? 1 : 0,
        }
    );
    $inc_header //= $inc_result->{'data'}{'header'};
    push @chunk_out, $inc_result->{'data'}{'lines'}->@*;
}

lines_eq(
    \@chunk_out,
    $one_shot->{'data'}{'lines'},
    'incremental : concatenated lines identical to single call'
);

ok( ( $inc_header // '' ) eq ( $one_shot->{'data'}{'header'} // '' ),
    'incremental : header identical to single call' );

my $inc_pkg_str = join '|', map {
    join ',', $_->{'pkg'}, $_->{'old'} // '', $_->{'new'} // '',
        $_->{'size'} // '', $_->{'status'} // ''
} $inc_result->{'data'}{'packages'}->@*;
my $one_pkg_str = join '|', map {
    join ',', $_->{'pkg'}, $_->{'old'} // '', $_->{'new'} // '',
        $_->{'size'} // '', $_->{'status'} // ''
} $one_shot->{'data'}{'packages'}->@*;

ok( $inc_pkg_str eq $one_pkg_str,
    'incremental : final package list identical to single call' );

##[ summary ]#################################################################

say '';
if ($fail_count) {
    say "FAILED : $fail_count check[s]";
    exit 1;
}
say 'all checks passed';
exit 0;

#,,.,,.,,,.,.,,..,.,.,,..,,..,,.,,,,,,,.,,,,,,..,,...,...,.,.,...,..,,,.,,,..,
#4BBTZBPDVA3J4YMG2LHIWBJP4JMNVG752J63P67DGYRNK5DLKJZWO7KNHBO5EKKJE5EIP6IHYTNBA
#\\\|MHB27ZDPJRXH5FKJ5WYJGZ27AWSZVOS5ITGETLJ7MBFI3RUDWEL \ / AMOS7 \ YOURUM ::
#\[7]BWPKFVKMGLCOKGF5LDESYOUKEF6GUDGVBU2YH6FISGQHN52KIYBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
