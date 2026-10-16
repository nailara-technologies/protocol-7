#!/usr/bin/env perl
use v5.32;
use strict;
use English;
use warnings;

## bin/p7-deps output in the AMOS7::TERM::Frame house style : the exact     ##
## plain text of list \ check \ check-service, the help option list, error  ##
## lines on STDERR with their exit codes, and the frame rules [ a '::' line ##
## under every ':::[ section ]', no ':' line twice, no double blank line ]. ##
## coloured output comes from a real terminal : p7-deps' STDOUT is the      ##
## slave of a /dev/ptmx pty -- once the escapes are taken out it is the     ##
## plain text, titles are TRUE blue and green stands on ok words only.      ##
## NO_COLOR on that terminal gives the plain text. runs a copy of           ##
## bin/p7-deps in a temporary tree [ own .deps/profiles.yaml ], dpkg-query  ##
## \ apt-get \ systemctl are stubs first in PATH, the service targets live  ##
## in a P7_DEPS_SERVICE_ROOT test root -- nothing outside is touched.       ##

use File::Spec;
use Cwd        qw| abs_path |;
use FindBin    qw| $RealBin |;
use File::Temp qw| tempdir |;
use File::Path qw| make_path |;
use File::Copy qw| copy |;
use POSIX      ();

use constant { TRUE => 5, FALSE => 0 };

my $root_path = abs_path(
    File::Spec->rel2abs(
        File::Spec->catdir( $RealBin, File::Spec->updir, File::Spec->updir )
    )
);

my $pass_count = 0;
my $fail_count = 0;

sub check {
    my ( $label, $cond ) = @_;
    if ($cond) {
        $pass_count++;
        printf "ok   : %s\n", $label;
    } else {
        $fail_count++;
        printf "FAIL : %s\n", $label;
    }
    return $cond;
}

sub write_file {
    my ( $path, $content ) = @_;
    open my $fh, '>', $path or die "cannot write $path : $OS_ERROR";
    print {$fh} $content;
    close $fh;
    return TRUE;
}

sub slurp {
    my ($path) = @_;
    open my $fh, '<', $path or return undef;
    local $INPUT_RECORD_SEPARATOR = undef;
    my $content = <$fh>;
    close $fh;
    return $content;
}

## colour literals [ the palette test in test-deps-core-perl.pl pins them ] ##

my $R  = "\e[0m";
my $pu = "\e[38;2;68;39;172m";    ## p7_fg_0000 structure ##
my $bl = "\e[38;2;6;71;195m";     ## p7_fg_0004 TRUE blue ##
my $am = "\e[38;2;197;141;7m";    ## p7_fg_0005 neon amber ##
my $gr = "\e[38;2;71;195;6m";     ## p7_fg_0006 neon green ##

sub strip_ansi { return $_[0] =~ s|\e\[[0-9;]*m||gr }

## the temporary tree ##

my $sandbox = tempdir( CLEANUP => 1 );
my $tree    = File::Spec->catdir( $sandbox, 'tree' );
my $stubs   = File::Spec->catdir( $sandbox, 'stub' );
my $svc     = File::Spec->catdir( $sandbox, 'service-root' );
my $state   = File::Spec->catfile( $sandbox, 'installed' );

make_path( map { File::Spec->catdir( $tree, @$_ ) } [qw| bin |],
    [qw| .deps |], [qw| data lib-path |] );
make_path( $stubs, $svc );
copy( "$root_path/bin/p7-deps", "$tree/bin/p7-deps" ) or die "copy : $!";
for my $name (qw| Protocol-7 nshell |) {
    copy( "$root_path/bin/$name", "$tree/bin/$name" ) or die "copy : $!";
}
for my $dir (qw| pm systemd |) {
    symlink( "$root_path/data/lib-path/$dir", "$tree/data/lib-path/$dir" )
        or die "symlink : $!";
}

write_file( "$tree/.deps/profiles.yaml", <<'EOF' );
profiles:
  out-test:
    description: "p7-deps output test"
    apt:
      - p7-test-package
      - p7-other-package
    cpan:
      - strict
  out-all:
    description: "includes out-test"
    includes:
      - out-test
EOF

## dpkg-query : installed when listed in the state file ##
write_file( "$stubs/dpkg-query", sprintf <<'EOF', $EXECUTABLE_NAME, $state );
#!%s
my $pkg = $ARGV[-1];
open my $fh, '<', '%s' or exit 1;
my %%have = map { chomp; $_ => 1 } <$fh>;
exit 1 if not $have{$pkg};
print 'install ok installed';
EOF
write_file( "$stubs/apt-get",   "#!/bin/sh\nexit 100\n" );
write_file( "$stubs/systemctl", <<'EOF' );
#!/bin/sh
[ "$1" = "is-enabled" ] && echo disabled
[ "$1" = "is-active" ] && echo inactive
exit 0
EOF
chmod( 0755, map {"$stubs/$_"} qw| dpkg-query apt-get systemctl | );
write_file( $state, "p7-test-package\n" );

## a host with libapt-pkg-perl probes in-process and never asks the ##
## dpkg-query stub -- an AptPkg::Cache that refuses to load first   ##
my $no_aptpkg = "$stubs/no-aptpkg";
make_path("$no_aptpkg/AptPkg");
write_file( "$no_aptpkg/AptPkg/Cache.pm",
    "die qq{AptPkg hidden by the test\\n};\n" );

## run p7-deps : STDOUT a pipe, or the slave of a pty [ $tty ] ; STDERR ##
## always into a file. returns ( exit, stdout, stderr )                 ##

my $err_file = File::Spec->catfile( $sandbox, 'stderr' );

## linux pty ioctls : unlock the slave, read its number ##
use constant { TIOCSPTLCK => 0x40045431, TIOCGPTN => 0x80045430 };

sub open_pty {
    open( my $master, '+<', '/dev/ptmx' ) or return;
    my $unlock = pack( 'i', 0 );
    ioctl( $master, TIOCSPTLCK, $unlock ) or return;
    my $number = pack( 'i', 0 );
    ioctl( $master, TIOCGPTN, $number ) or return;
    my $slave_path = '/dev/pts/' . unpack( 'i', $number );
    return -e $slave_path ? ( $master, $slave_path ) : ();
}

sub p7_deps {
    my ( $tty, $env, @args ) = @_;

    my ( $master, $slave_path );
    if ($tty) {
        ( $master, $slave_path ) = open_pty();
        return if not $master;
    }

    my $out_pipe;
    my $pid
        = $tty
        ? fork()
        : open( $out_pipe, '-|' );
    die "fork : $OS_ERROR" if not defined $pid;

    if ( $pid == 0 ) {
        $ENV{'PATH'}                 = "$stubs:$ENV{'PATH'}";
        $ENV{'PERL5LIB'}             = $no_aptpkg;
        $ENV{'P7_DEPS_SERVICE_ROOT'} = $svc;
        delete $ENV{'NO_COLOR'};
        @ENV{ keys %$env } = values %$env;
        open( STDIN,  '<', File::Spec->devnull );
        open( STDERR, '>', $err_file );
        if ($tty) {
            POSIX::setsid();
            open( STDOUT, '+<', $slave_path ) or exit 126;
        }
        exec( $EXECUTABLE_NAME, "$tree/bin/p7-deps", @args ) or exit 127;
    }

    my $out = '';
    if ($tty) {
        ## EIO once the slave is closed is the end of the output ##
        while ( sysread( $master, my $buffer, 4096 ) ) { $out .= $buffer }
        waitpid( $pid, 0 );
        close $master;
        $out =~ s|\r\n|\n|g;    ## the terminal's onlcr ##
    } else {
        local $INPUT_RECORD_SEPARATOR = undef;
        $out = <$out_pipe> // '';
        close $out_pipe;
    }
    return ( $CHILD_ERROR >> 8, $out, slurp($err_file) // '' );
}

## the banner line ends in a space [ ' .: title :. ' ] -- added here, an ##
## editor would strip it from the expected text below                    ##
sub banner_space { return $_[0] =~ s{^( \.: .+ :\.)$}{$1 }mr }

## the frame rules every output keeps ##

sub frame_rules {
    my ( $name, $out ) = @_;
    my @lines   = split m|\n|, $out, -1;
    my @headers = grep { $lines[$_] =~ m|^:::\[ .+ \]$| } 0 .. $#lines;
    check "$name : a '::' line under every section header",
        not grep { ( $lines[ $_ + 1 ] // '' ) ne '::' } @headers;
    check "$name : no ':' line twice in a row", $out !~ m|^:\n:\n|m;
    check "$name : no double blank line",       index( $out, "\n\n\n" ) < 0;
    return TRUE;
}

## --- plain output [ a pipe ] ##
## ------------------          ##

my %plain;

my ( $exit, $out, $err ) = p7_deps( FALSE, {}, qw| list | );
$plain{'list'} = $out;
check 'list : exit 0',           $exit == 0;
check 'list : plain text exact', $out eq banner_space(<<'EOF');
:
 .: dependency profiles :.
:
:::[ available profiles ]
::
::   out-all .... includes out-test [ includes : out-test ]
::   out-test ... p7-deps output test [ 3 packages ]
:
EOF
printf "       : got [%s]\n", $out if $out !~ m|out-test \.\.\. p7-deps|;
frame_rules( 'list', $out );

( $exit, $out, $err ) = p7_deps( FALSE, {}, qw| check out-all | );
$plain{'check'} = $out;
check 'check, one missing : exit 0 [ out-all itself misses nothing ]',
    $exit == 0;
check 'check : plain text exact', $out eq banner_space(<<'EOF');
:
 .: dependency check :.
:
:::[ profile out-test ]
::
::   description ........ p7-deps output test
::   p7-test-package .... installed [ apt ]
::   p7-other-package ... missing [ apt ]
::   strict ............. installed [ cpan ]
::
::   result ............. 1 missing [ bin/p7-deps install out-test ]
:
:::[ profile out-all ]
::
::   description ... includes out-test
::   includes ...... out-test
::
::   result ........ all dependencies installed [ 0 / 0 ]
:
EOF
printf "       : got [%s]\n", $out if $out !~ m|1 missing|;
check 'check : nothing on STDERR', $err eq '';
frame_rules( 'check', $out );

( $exit, $out, $err ) = p7_deps( FALSE, {}, qw| check-service | );
$plain{'check-service'} = $out;
check 'check-service, nothing installed : exit 1', $exit == 1;
check 'check-service : banner, section, result row', $out =~ m{\A:
 \.: check service :\.[ ]
:
:::\[ service parts \]
::
(?:::   \S.* \.{3,} \S.*\n)+::
::   service parts \.+ missing or differing
:
\z};
check 'check-service : unit row missing', $out =~ m|^::   unit \.+ missing$|m;
frame_rules( 'check-service', $out );

( $exit, $out, $err ) = p7_deps( FALSE, {}, qw| help | );
$plain{'help'} = $out;
check 'help : exit 0', $exit == 0;
check 'help : the option list title',
    $out =~ m|\A\n    \.: p7-deps command line options :\.\n\n|;
my @option_lines = grep {m|^    [-a-z]|} split m|\n|, $out;
check 'help : every command with a dot leader',
    ( @option_lines >= 15
        and not grep { not m| \.{3,}  | and not m{^    none} }
        @option_lines );
check 'help : all leaders end in one column',
    1 == keys %{
    {   map  { index( $_, ' .' ) + length( (m|( \.+  )|)[0] ) => 1 }
        grep {m| \.{3,}  |}
        grep { !m{^    (?:profiles|zenki) } } @option_lines
    }
    };
check 'help : no escape in plain help', index( $out, "\e" ) < 0;
frame_rules( 'help', $out );

## --- error lines on STDERR ##
## ------------------        ##

( $exit, $out, $err ) = p7_deps( FALSE, {}, qw| frobnicate | );
check 'unknown command : exit 1', $exit == 1;
check 'unknown command : framed error line on STDERR, nothing on STDOUT',
    (       $out eq ''
        and $err eq ":\n:: < p7-deps > : unknown command [ frobnicate "
        . "] -- bin/p7-deps help lists them\n:\n" );

( $exit, $out, $err ) = p7_deps( FALSE, {}, qw| check | );
check 'check without a profile : exit 0110 [ 110 ]', $exit == 110;
check 'check without a profile : error line',
    $err =~ m|^:: < p7-deps > : check needs a profile |m;

( $exit, $out, $err ) = p7_deps( FALSE, {}, qw| install no-such another | );
check 'unknown profiles : exit 1', $exit == 1;
check 'unknown profiles : named in the error line',
    $err =~ m|^:: < p7-deps > : unknown profiles \[ no-such, another \] |m;

## --- coloured output on a terminal ##
## ------------------                ##

if ( not open_pty() ) {
    print "skip : no /dev/ptmx pty -- coloured output not checked\n";
} else {
    my %green_words = map { $_ => 1 } 'installed', 'ok',
        'all dependencies installed', 'complete', 'installation complete';

    for my $case ( [qw| list |], [qw| check out-all |], [qw| check-service |],
        [qw| help |] ) {
        my $name = $case->[0];
        my ( $c_exit, $colored ) = p7_deps( TRUE, {}, @$case );

        check "$name on a terminal : coloured", index( $colored, "\e[" ) >= 0;
        check "$name on a terminal : = plain text once stripped",
            strip_ansi($colored) eq $plain{$name};
        my @green = $colored =~ m|\Q$gr\E(.*?)\Q$R\E|g;
        check "$name on a terminal : green on ok words only",
            not grep { not $green_words{$_} } @green;

        ( $c_exit, my $no_color )
            = p7_deps( TRUE, { NO_COLOR => '1' }, @$case );
        check "$name on a terminal, NO_COLOR set : no escape at all",
            index( $no_color, "\e" ) < 0;
        check "$name on a terminal, NO_COLOR set : the plain text",
            $no_color eq $plain{$name};
    }

    my ( undef, $colored ) = p7_deps( TRUE, { NO_COLOR => '' }, qw| list | );
    check 'list on a terminal, NO_COLOR empty : coloured',
        index( $colored, "\e[" ) >= 0;

    ( undef, $colored ) = p7_deps( TRUE, {}, qw| check out-all | );
    check 'check : banner title TRUE blue in a purple frame',
        index( $colored, "$pu .: $R${bl}dependency check$R$pu :. $R" ) >= 0;
    check 'check : section title TRUE blue, then the \'::\' line',
        index( $colored,
        "${pu}:::[ $R${bl}profile out-test$R$pu ]$R\n${pu}::$R\n" ) >= 0;
    check 'check : missing in amber, installed in green',
        (       index( $colored, "${am}missing$R" ) >= 0
            and index( $colored, "${gr}installed$R" ) >= 0 );
    check 'check : the 1 missing result amber, not green',
        index( $colored, "${am}1 missing$R" ) >= 0;

    ( undef, $colored ) = p7_deps( TRUE, {}, qw| help | );
    check 'help : no green at all', index( $colored, $gr ) < 0;
    check 'help : title words blue, frame purple',
        index( $colored, "$pu.:$R ${bl}p7$R$pu-$R${bl}deps$R" ) >= 0;
}

printf "\n: %d checks passed, %d failed\n", $pass_count, $fail_count;
exit( $fail_count ? 1 : 0 );

#,,..,.,.,.,,,,.,,.,,,,.,,...,,,.,.,.,,,.,,,,,..,,...,...,..,,..,,,,.,.,,,,..,
#CR4VIZ34K6ZIQV34YZZEGDAUV4KJ6U32IKS4WNHFF5OOVIVDOTP2S6XLM7R2PNQBYJA4YAXDO5A6I
#\\\|N52IRVDEKIPLKOZIG5BJPRGBDQV2F7E3VF5RG7C6LO4X6LVPA4U \ / AMOS7 \ YOURUM ::
#\[7]6VVFVMMVTHSZA7M4RRP3S5HCDZB6WIPZQOB46XW3NGHASKDW64DA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
