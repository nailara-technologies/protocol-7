#!/usr/bin/env perl
use v5.32;
use strict;
use English;
use warnings;

## p7-deps service commands + shared pm-src builds + the v7-zenki start-up  ##
## unit \ symlink maintenance. everything runs against temporary roots :    ##
## the service targets are prefixed with env P7_DEPS_SERVICE_ROOT and       ##
## systemctl \ cpanm are stubbed by fake binaries first in PATH that record ##
## their args. install_pm_src builds a tiny fake pm-src dist through a      ##
## stubbed cpanm from a temporary copy -- the source dir stays unchanged.   ##
## the two v7-zenki src modules are compiled with the same tiny source      ##
## translator the nameserv tests use. no real /usr, /etc or systemd is ever ##
## touched, no service is started, stopped or restarted anywhere.           ##

use File::Spec;
use Cwd        qw| abs_path |;
use FindBin    qw| $RealBin |;
use File::Temp qw| tempdir |;
use File::Path qw| make_path |;

use constant { TRUE => 5, FALSE => 0 };

BEGIN {
    my $root_path = abs_path(
        File::Spec->rel2abs(
            File::Spec->catdir(
                $RealBin, File::Spec->updir, File::Spec->updir
            )
        )
    );
    $main::root_path = $root_path;
    unshift( @INC, File::Spec->catdir( $root_path, qw| data lib-path pm | ) );
}

use AMOS7::deps::module  qw| load_known_deps resolve_install install_pm_src |;
use AMOS7::deps::service ();

my $root_path = $main::root_path;

## assertion helpers ##

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

## run a command, capture stdout and exit code [ list form exec, no shell ] ##

sub run_capture {
    my (@cmd) = @_;

    my $pid = open( my $pipe, '-|' ) // die "fork failed : $OS_ERROR";
    if ( $pid == 0 ) {
        exec(@cmd) or exit 127;
    }
    local $INPUT_RECORD_SEPARATOR = undef;
    my $output = <$pipe> // '';
    close($pipe);
    return ( $CHILD_ERROR >> 8, $output );
}

sub p7_deps {
    my (@args) = @_;
    return run_capture( $EXECUTABLE_NAME, "$root_path/bin/p7-deps", @args );
}

## small helpers for the stubbed environment ##

sub make_stub {
    my ( $dir, $name, $body ) = @_;
    my $path = File::Spec->catfile( $dir, $name );
    write_file( $path, $body );
    chmod( 0755, $path );
    return $path;
}

my $stub_dir = tempdir( CLEANUP => 1 );
my $repo_unit;    ## repo unit content, shared by parts 1 and 3 ##

## --- part 1 : service commands against a temporary root ##
## ------------------                                     ##

my $svc_sandbox = tempdir( CLEANUP => 1 );
my $svc_root    = File::Spec->catdir( $svc_sandbox, 'root' );
my $calls_log   = File::Spec->catfile( $svc_sandbox, 'calls.log' );

my $systemctl_stub = sprintf <<'EOF', $calls_log, ($svc_sandbox) x 3;
#!/bin/sh
echo "$@" >> "%s"
if [ "$1" = "is-enabled" ]; then
    cat "%s/enabled.out" 2>/dev/null || echo disabled
fi
if [ "$1" = "is-active" ]; then
    cat "%s/active.out" 2>/dev/null || echo inactive
fi
if [ "$1" = "show" ]; then
    cat "%s/show-$4.out" 2>/dev/null
fi
exit 0
EOF

make_stub( $stub_dir, 'systemctl', $systemctl_stub );

{
    local $ENV{'P7_DEPS_SERVICE_ROOT'} = $svc_root;
    local $ENV{'PATH'}                 = $stub_dir . ':' . $ENV{'PATH'};

    ## [ 1 ] install-service on an empty root sets everything ##

    my ( $exit, $out ) = p7_deps(qw| install-service |);

    $repo_unit = slurp(
        File::Spec->catfile(
            $root_path, 'data',
            'lib-path', 'systemd',
            'system',   'Protocol-7.service'
        )
    );

    check 'install-service exit 0 on empty root', $exit == 0;
    check 'unit reported changed', $out =~ m|unit\s[.]+\schanged|;
    check 'daemon-reload reported ok',
        $out =~ m|systemctl\sdaemon-reload\s[.]+\sok|;
    check 'install link reported set', $out =~ m|install\slink\s[.]+\sset|;
    check 'Protocol-7 symlink reported set',
        $out =~ m|Protocol-7\ssymlink\s[.]+\sset|;
    check 'nshell symlink reported set',
        $out =~ m|nshell\ssymlink\s[.]+\sset|;
    check 'unit content installed',
        slurp(
        File::Spec->catfile(
            $svc_root, 'usr',
            'lib',     'systemd',
            'system',  'Protocol-7.service'
        )
        ) eq $repo_unit;
    check 'install link points at the checkout',
        readlink(
        File::Spec->catdir( $svc_root, 'usr', 'local', 'protocol-7' ) ) eq
        $root_path;
    check 'Protocol-7 symlink points at the checkout',
        readlink(
        File::Spec->catfile( $svc_root, 'usr', 'local', 'bin', 'Protocol-7' )
        ) eq File::Spec->catfile( $root_path, 'bin', 'Protocol-7' );
    check 'nshell symlink points at the checkout',
        readlink(
        File::Spec->catfile( $svc_root, 'usr', 'local', 'bin', 'nshell' ) )
        eq File::Spec->catfile( $root_path, 'bin', 'nshell' );
    check 'daemon-reload was called',
        slurp($calls_log) =~ m|^daemon-reload$|m;

    ## [ 2 ] a second run is all ok, no second daemon-reload ##

    my $calls_before = slurp($calls_log);
    ( $exit, $out ) = p7_deps(qw| install-service |);
    check 'second install-service exit 0', $exit == 0;
    my @pairs    = $out =~ m{\s([.]{3,})\s(ok|set|changed|failed)}g;
    my @statuses = map { $pairs[ 2 * $ARG + 1 ] } 0 .. ( @pairs / 2 - 1 );
    check 'second run reports all ok',
        ( scalar(@statuses) > 0 and not grep { $_ ne 'ok' } @statuses );
    ## the state read-back adds is-* \ show calls -- count the reloads only ##
    my $reloads = sub { scalar( () = $_[0] =~ m|^daemon-reload$|mg ) };
    check 'no second daemon-reload',
        $reloads->( slurp($calls_log) ) == $reloads->($calls_before);

    ## [ 3 ] a changed installed unit -> changed + daemon-reload ##

    my $unit_path = File::Spec->catfile( $svc_root, 'usr', 'lib', 'systemd',
        'system', 'Protocol-7.service' );
    write_file( $unit_path, "# locally modified unit\n" );
    $calls_before = slurp($calls_log);
    ( $exit, $out ) = p7_deps(qw| install-service |);
    check 'changed unit reported changed', $out =~ m|unit\s[.]+\schanged|;
    check 'unit content restored',         slurp($unit_path) eq $repo_unit;
    check 'daemon-reload after changed unit',
        (       slurp($calls_log) ne $calls_before
            and slurp($calls_log) =~ m|^daemon-reload$|m );
    check 'unchanged links still ok on third run',
        $out =~ m|Protocol-7\ssymlink\s[.]+\sok|;

    ## [ 4 ] a regular file at a symlink path is left alone and reported ##

    my $nshell_link
        = File::Spec->catfile( $svc_root, 'usr', 'local', 'bin', 'nshell' );
    unlink($nshell_link);
    write_file( $nshell_link, "precious local file\n" );
    ( $exit, $out ) = p7_deps(qw| install-service |);
    check 'regular file reported failed',
        $out =~ m|nshell\ssymlink\s[.]+\sfailed|;
    check 'regular file report says left alone',
        $out =~ m|regular\sfile\sin\splace\s--\sleft\salone|;
    check 'install-service exit 1 with blocked step', $exit == 1;
    check 'regular file untouched',
        slurp($nshell_link) eq "precious local file\n";
    unlink($nshell_link);

    ## [ 5 ] check-service exit codes and part states ##

    p7_deps(qw| install-service |);    ## restore the removed link ##
    ( $exit, $out ) = p7_deps(qw| check-service |);
    check 'check-service exit 0 when all parts ok', $exit == 0;
    check 'check-service reports unit ok',          $out =~ m|unit\s[.]+\sok|;
    check 'check-service reports enabled state',
        $out =~ m|is-enabled\s[.]+\sdisabled|;
    check 'check-service reports inactive state',
        $out =~ m|is-active\s[.]+\sinactive|;

    write_file( File::Spec->catfile( $svc_sandbox, 'enabled.out' ),
        "enabled\n" );
    write_file( File::Spec->catfile( $svc_sandbox, 'active.out' ),
        "active\n" );
    ( $exit, $out ) = p7_deps(qw| check-service |);
    check 'check-service shows enabled when stubbed so',
        $out =~ m|is-enabled\s[.]+\senabled|;
    check 'check-service shows active when stubbed so',
        $out =~ m|is-active\s[.]+\sactive|;
    check 'unit state does not change the exit code', $exit == 0;

    ## [ 5b ] what the running service uses : unit mtime vs its start ##
    my $show_start = File::Spec->catfile( $svc_sandbox,
        'show-ActiveEnterTimestamp.out' );
    my $unit_mtime = ( stat($unit_path) )[9];
    write_file( $show_start, sprintf( "@%d\n", $unit_mtime - 60 ) );
    ( $exit, $out ) = p7_deps(qw| check-service |);
    check 'started before the unit changed : reported',
        $out =~ m|running\sservice\s[.]+\solder\s\[started\sbefore|;
    check '  :.. exit code unchanged', $exit == 0;

    write_file( $show_start, sprintf( "@%d\n", $unit_mtime + 60 ) );
    ( $exit, $out ) = p7_deps(qw| check-service |);
    check 'started after the unit changed : uses it',
        $out =~ m|running\sservice\s[.]+\sok\s\[uses\sthe\sinstalled|;

    write_file( $show_start, "\n" );    ## an older systemctl : no row ##
    ( $exit, $out ) = p7_deps(qw| check-service |);
    check 'unparseable start time : no running-service row',
        $out !~ m|running\sservice|;

    my $show_reload
        = File::Spec->catfile( $svc_sandbox, 'show-NeedDaemonReload.out' );
    write_file( $show_reload, "yes\n" );
    ( $exit, $out ) = p7_deps(qw| check-service |);
    check 'daemon-reload pending : unit loaded stale',
        $out =~ m|unit\sloaded\s[.]+\sstale|;
    write_file( $show_reload, "no\n" );
    ( $exit, $out ) = p7_deps(qw| check-service |);
    check '  :.. no stale row without it', $out !~ m|unit\sloaded|;

    ## install-service shows the state read back after installing ##
    write_file( $show_start, sprintf( "@%d\n", $unit_mtime - 60 ) );
    ( $exit, $out ) = p7_deps(qw| install-service |);
    check 'install-service : state after install shown',
        $out =~ m|state\safter\sinstall.*running\sservice\s[.]+\solder|s;
    unlink( $show_start, $show_reload );

    unlink( File::Spec->catfile( $svc_sandbox, 'active.out' ) );
    ( $exit, $out ) = p7_deps(qw| check-service |);
    check 'inactive service : no running-service row',
        $out !~ m|running\sservice|;
    unlink( File::Spec->catfile( $svc_sandbox, 'enabled.out' ) );

    unlink($nshell_link);
    ( $exit, $out ) = p7_deps(qw| check-service |);
    check 'check-service exit 1 when a link is missing', $exit == 1;
    check 'missing link reported', $out =~ m|nshell\ssymlink\s[.]+\smissing|;

    symlink( '/nonexistent/elsewhere', $nshell_link );
    ( $exit, $out ) = p7_deps(qw| check-service |);
    check 'check-service exit 1 when a link differs', $exit == 1;
    check 'differing link reported',
        $out =~ m|nshell\ssymlink\s[.]+\sdiffers|;
    unlink($nshell_link);

    write_file( $nshell_link, "regular file\n" );
    ( $exit, $out ) = p7_deps(qw| check-service |);
    check 'check-service exit 1 with a regular file', $exit == 1;
    check 'regular file reported as differs',
        $out =~ m|nshell\ssymlink\s[.]+\sdiffers\s\[not\sa\ssymlink\]|;
    unlink($nshell_link);
    p7_deps(qw| install-service |);    ## restore ##

    ## [ 6 ] enable \ disable call systemctl ##

    $calls_before = slurp($calls_log);
    ( $exit, $out ) = p7_deps(qw| enable-service |);
    check 'enable-service exit 0', $exit == 0;
    check 'enable-service reported ok',
        $out =~ m|systemctl\senable\s[.]+\sok|;
    check 'systemctl enable was called',
        (       slurp($calls_log) ne $calls_before
            and slurp($calls_log) =~ m|^enable\sProtocol-7$|m );

    $calls_before = slurp($calls_log);
    ( $exit, $out ) = p7_deps(qw| disable-service |);
    check 'disable-service exit 0', $exit == 0;
    check 'disable-service reported ok',
        $out =~ m|systemctl\sdisable\s[.]+\sok|;
    check 'systemctl disable was called',
        (       slurp($calls_log) ne $calls_before
            and slurp($calls_log) =~ m|^disable\sProtocol-7$|m );

    ## [ 7 ] nothing ever starts, stops or restarts the service ##

    my $calls      = slurp($calls_log);
    my $misbehaved = FALSE;
    foreach my $line ( split m|\n|, $calls ) {
        $misbehaved = TRUE
            if $line =~ m{^(start|stop|restart|try-restart|reload-or-restart)
                          \s}x;
    }
    check 'no start \ stop \ restart was ever recorded', not $misbehaved;

    ## [ 8 ] the mutating commands refuse without root ##

    {
        local $ENV{'P7_DEPS_SERVICE_ROOT'} = '';
        ( $exit, $out ) = p7_deps(qw| install-service |);
        check 'install-service refuses without root', $exit == 1;
        ( $exit, $out ) = p7_deps(qw| enable-service |);
        check 'enable-service refuses without root', $exit == 1;
        ( $exit, undef ) = p7_deps(qw| check-service |);
        check 'check-service still runs without root', $exit == 0;
    }
}

## --- part 1b : a server cloned straight to /usr/local/protocol-7 the      ##
## install path IS the checkout [ a real directory ] : ok, not 'left alone' ##
## -- every server is set up like that                                      ##
{
    my $server_root = tempdir( CLEANUP => 1 );
    my $checkout
        = File::Spec->catdir( $server_root, qw| usr local protocol-7 | );
    my $unit_dir
        = File::Spec->catdir( $checkout, qw| data lib-path systemd system | );
    File::Path::make_path( $unit_dir,
        File::Spec->catdir( $checkout, 'bin' ) );
    for my $file (
        [   File::Spec->catfile( $unit_dir, 'Protocol-7.service' ),
            "[Unit]\n"
        ],
        [ File::Spec->catfile( $checkout, qw| bin Protocol-7 | ), "#!\n" ],
        [ File::Spec->catfile( $checkout, qw| bin nshell | ),     "#!\n" ],
    ) {
        open( my $fh, '>', $file->[0] ) or die;
        print {$fh} $file->[1];
        close $fh;
    }
    local $ENV{'P7_DEPS_SERVICE_ROOT'} = $server_root;
    local $ENV{'PATH'}                 = $stub_dir . ':' . $ENV{'PATH'};

    my $report = AMOS7::deps::service::install($checkout);
    my ($link) = grep { $_->[0] eq 'install link' } @{$report};
    check 'server : install link is the checkout itself -> ok',
        defined $link && $link->[1] eq 'ok';
    check 'server : nothing failed', !grep { $_->[1] eq 'failed' } @{$report};
    my $unit = File::Spec->catfile( $server_root,
        qw| usr lib systemd system Protocol-7.service | );
    check 'server : unit written with mode 0644',
        -f $unit && ( ( stat $unit )[2] & 07777 ) == 0644;
    check 'server : no temporary unit file left',
        !glob( $unit . '.p7-deps.*' );

    my ( $checked, $all_ok ) = AMOS7::deps::service::check($checkout);
    my ($clink) = grep { $_->[0] eq 'install link' } @{ $checked // [] };
    check 'server : check-service reports the checkout itself ok',
        defined $clink && $clink->[1] eq 'ok';

    ## another real directory at the install path : still left alone ##
    my $other   = tempdir( CLEANUP => 1 );
    my $report2 = AMOS7::deps::service::install($other);
    my ($link2) = grep { $_->[0] eq 'install link' } @{$report2};
    check 'server : a different real directory is left alone [ failed ]',
        defined $link2 && $link2->[1] eq 'failed';
}

## --- part 2 : shared pm-src builds        ##
## ---------------------------------------- ##

my $cpanm_log = File::Spec->catfile( $svc_sandbox, 'cpanm.log' );
unlink($cpanm_log);

my $cpanm_stub = sprintf <<'EOF', $cpanm_log;
#!/bin/sh
echo "$@" >> "%s"
dir=""
for arg in "$@"; do dir="$arg"; done
cd "$dir" && perl Makefile.PL
EOF

my $cpan_stub_dir = tempdir( CLEANUP => 1 );
make_stub( $cpan_stub_dir, 'cpanm', $cpanm_stub );

my $fake_root = tempdir( CLEANUP => 1 );
my $dist_dir  = File::Spec->catdir( $fake_root, 'data', 'lib-path', 'pm-src',
    'mini-dist' );
make_path($dist_dir);
write_file( File::Spec->catfile( $dist_dir, 'Makefile.PL' ), <<'EOF' );
use strict;
use warnings;
open my $fh, '>', 'built.marker' or die "marker : $!";
print {$fh} "built from the temp copy\n";
close $fh;
exit 0;
EOF

{
    local $ENV{'PATH'} = $cpan_stub_dir . ':' . $ENV{'PATH'};

    my $src_before = slurp( File::Spec->catfile( $dist_dir, 'Makefile.PL' ) );

    check 'install_pm_src builds the fake dist',
        install_pm_src( $fake_root, qw| mini-dist | );

    my $cpanm_calls = slurp($cpanm_log) // '';
    my ($build_arg) = split m|\n|, $cpanm_calls;
    check 'cpanm was called ' . 'once',
        ( $cpanm_calls =~ m|\n$| and $cpanm_calls !~ m|\n.*\n| );
    check 'cpanm built from a temp copy',
        (       defined $build_arg
            and length $build_arg
            and index( $build_arg, $fake_root ) == -1 );
    check 'cpanm built the right dist name',
        ( defined $build_arg and $build_arg =~ m|mini-dist$| );
    check 'source dir has no build files afterwards',
        !-f File::Spec->catfile( $dist_dir, 'built.marker' );
    check 'source dir content unchanged',
        slurp( File::Spec->catfile( $dist_dir, 'Makefile.PL' ) ) eq
        $src_before;

    check 'install_pm_src fails on a missing dist',
        not install_pm_src( $fake_root, qw| no-such-dist | );
}

## resolve_install reports the pm_src method for the local-source modules ##

my $known_deps = load_known_deps($root_path);

my $resolved = resolve_install( 'Digest::BMW', $known_deps );
check 'Digest::BMW resolves to pm_src',
    ( $resolved->{'method'} eq 'pm_src'
        and join( ',', @{ $resolved->{'dirs'} } ) eq 'digest-bmw' );

$resolved = resolve_install( 'Crypt::Curve25519', $known_deps );
check 'Crypt::Curve25519 resolves to pm_src',
    ( $resolved->{'method'} eq 'pm_src'
        and join( ',', @{ $resolved->{'dirs'} } ) eq 'crypt-curve25519' );

$resolved = resolve_install( 'Crypt::Ed25519', $known_deps );
check 'Crypt::Ed25519 resolves to pm_src in build order',
    ( $resolved->{'method'} eq 'pm_src'
        and join( ',', @{ $resolved->{'dirs'} } ) eq
        'canary-stability,crypt-ed25519' );

$resolved = resolve_install( 'Event', $known_deps );
check 'modules without pm_src still resolve to debian',
    $resolved->{'method'} eq 'debian';

## --- part 3 : v7-zenki start-up maintenance ##
## -------------------------------            ##

our %data;
our %code;

my @log_lines;    ## [ [ level-or-undef, fmt, ..args ], .. ] ##

$code{'base.log'}      = sub { push( @log_lines, [@_] ); return TRUE };
$code{'base.logs'}     = sub { push( @log_lines, [@_] ); return TRUE };
$code{'base.cfg_bool'} = sub {
    my $val = shift;
    return FALSE if not defined $val;
    return TRUE if $val =~ m|^\d+$| and $val == TRUE;
    return $val =~ m{^(1|yes|true|on)$}i ? TRUE : FALSE;
};
$code{'base.sort'}  = sub { return sort @_ };
$code{'base.cnt_s'} = sub { my $cnt = shift; return $cnt == 1 ? '' : 's' };
$code{'base.str.os_err'} = sub { return '' };

sub catdir  { File::Spec->catdir(@_) }
sub catfile { File::Spec->catfile(@_) }

## module loader : translate p7 syntax, compile as anonymous sub ##
## [ the same tiny translator the nameserv tests use ]           ##

sub translate_code {
    my $code = shift;
    $code =~ s{<\[([A-Za-z][-\w.]*)\]>(?=->)}{chr(36).qq|code{'$1'}|}eg;
    $code =~ s{<\[([A-Za-z][-\w.]*)\]>}{chr(36).qq|code{'$1'}->()|}eg;
    $code =~ s{<([a-z][-\w.]*)>}{
        my @keys = split m|\.|, $1;
        chr(36).qq|data{'| . join( "'}{'", @keys ) . qq|'}|
    }ge;
    return $code;
}

sub load_module {
    my $name = shift;
    my $path = File::Spec->catfile( $root_path, 'src', $name );
    open my $fh, '<', $path or die "cannot read $path : $OS_ERROR";
    local $INPUT_RECORD_SEPARATOR = undef;
    my $src = <$fh>;
    close $fh;

    ## drop signature block [ last 4 lines starting with # ] ##
    $src =~ s{\n#[^\n]*\z}{\n} while $src =~ m{\n#[,\[\\|:][^\n]*\z};

    ## split out strings and comments, translate code segments only ##
    my @seg = split m{('(?:[^'\\]|\\.)*'|"(?:[^"\\]|\\.)*"|\#[^\n]*)}x,
        $src, -1;
    for ( my $i = 0; $i < @seg; $i += 2 ) {
        $seg[$i] = translate_code( $seg[$i] );
    }
    my $translated = join '', @seg;
    warn qq|===== $name =====\n$translated\n| if $ENV{'P7_DEBUG'};

    my $sub = eval "sub { $translated }";
    die "compile error in $name : $EVAL_ERROR" if $EVAL_ERROR;
    $code{$name} = $sub;
    return $sub;
}

load_module($_) foreach qw|
    v7-zenki.install_zenka_symlinks
    v7-zenki.check_service_unit
    |;

sub level0_count {
    my $pattern = shift;
    my $count   = 0;
    foreach my $entry (@log_lines) {
        next unless defined $entry->[0] and $entry->[0] =~ m|^\d+$|;
        next unless $entry->[0] == 0;
        $count++ if defined $entry->[1] and $entry->[1] =~ $pattern;
    }
    return $count;
}

## sandbox checkout with a console zenka, the launcher binary and p7c ##

my $zenka_root = tempdir( CLEANUP => 1 );
my $zenka_bin  = catdir( $zenka_root, qw| bin | );
my $conf_path  = catdir( $zenka_root, qw| cfg | );
my $code_path  = catdir( $zenka_root, qw| src-modules | );
my $zenki_dir  = catdir( $conf_path,  qw| zenki | );
my $link_dir_a = catdir( $zenka_root, qw| links-a | );
my $p7c_path   = catfile( $zenka_root, qw| usr local bin p7c | );
my $p7r_path   = catfile( $zenka_root, qw| usr local bin p-7-r | );

make_path(
    $zenka_bin,
    catdir( $zenki_dir, 'foo' ),
    catdir( $zenki_dir, 'nshell' ),
    $code_path, $link_dir_a, catdir( $zenka_root, qw| usr local bin | )
);
write_file( catfile( $zenka_bin, 'Protocol-7' ), "#!/bin/sh\nexit 0\n" );
chmod( 0755, catfile( $zenka_bin, 'Protocol-7' ) );
write_file( catfile( $zenka_bin, 'nshell' ), "#!/bin/sh\nexit 0\n" );
chmod( 0755, catfile( $zenka_bin, 'nshell' ) );
write_file( $p7r_path, "#!bin/sh\nexit 0\n" );
chmod( 0755, $p7r_path );
write_file( catfile( $code_path, 'foo.console.bar' ), '' );
write_file( $p7c_path,                                "#!bin/sh\nexit 0\n" );
chmod( 0755, $p7c_path );

$data{'system'}{'root_path'}                  = $zenka_root;
$data{'system'}{'conf_path'}                  = $conf_path;
$data{'system'}{'code_path'}                  = $code_path;
$data{'v7-zenki'}{'cfg'}{'zenka_symlink_dir'} = $link_dir_a;
$data{'v7-zenki'}{'cfg'}{'p7c_bin_path'}      = $p7c_path;
$data{'v7-zenki'}{'cfg'}{'p7r_bin_path'}      = $p7r_path;

my $protocol7_bin = sprintf qw| %s/bin/Protocol-7 |, $zenka_root;

## [ 1 ] links created : p7-<zenka>, Protocol-7, nshell and :: -> p7c ##

@log_lines = ();
my $result = $code{'v7-zenki.install_zenka_symlinks'}->();
check 'install_zenka_symlinks reports installs', $result > 0;
check 'p7-foo symlink created',
    ( -l catfile( $link_dir_a, 'p7-foo' )
        and readlink( catfile( $link_dir_a, 'p7-foo' ) ) eq $protocol7_bin );
check 'Protocol-7 link created',
    ( -l catfile( $link_dir_a, 'Protocol-7' )
        and readlink( catfile( $link_dir_a, 'Protocol-7' ) ) eq
        $protocol7_bin );
## nshell is its own launcher [ bin/nshell ], NOT Protocol-7 ##
check 'nshell link created pointing at bin/nshell',
    ( -l catfile( $link_dir_a, 'nshell' )
        and readlink( catfile( $link_dir_a, 'nshell' ) ) eq
        catfile( $zenka_bin, 'nshell' ) );
check '::: link created pointing at p-7-r',
    ( -l catfile( $link_dir_a, ':::' )
        and readlink( catfile( $link_dir_a, ':::' ) ) eq $p7r_path );
check ':: link created pointing at p7c',
    ( -l catfile( $link_dir_a, '::' )
        and readlink( catfile( $link_dir_a, '::' ) ) eq $p7c_path );

## [ 2 ] second run changes nothing ##

my $log_count_before = scalar @log_lines;
$result = $code{'v7-zenki.install_zenka_symlinks'}->();
check 'second run reports nothing installed', not $result;
check 'second run only logs the current links',
    scalar @log_lines > $log_count_before;

## [ 3 ] a stale symlink is replaced, a regular file is left alone ##

unlink( catfile( $link_dir_a, '::' ) );
symlink( '/somewhere/else', catfile( $link_dir_a, '::' ) );
unlink( catfile( $link_dir_a, 'nshell' ) );
write_file( catfile( $link_dir_a, 'nshell' ), "local nshell\n" );

@log_lines = ();
$result    = $code{'v7-zenki.install_zenka_symlinks'}->();
check 'stale :: symlink replaced',
    readlink( catfile( $link_dir_a, '::' ) ) eq $p7c_path;
check 'regular file left alone',
    ( -f catfile( $link_dir_a, 'nshell' )
        and slurp( catfile( $link_dir_a, 'nshell' ) ) eq "local nshell\n" );
check 'regular file reported at level 0',
    level0_count(qr|regular file, left alone|) == 1;

unlink( catfile( $link_dir_a, 'nshell' ) );
symlink( $protocol7_bin, catfile( $link_dir_a, 'nshell' ) );

## [ 4 ] no :: link when p7c does not exist ##

unlink($p7c_path);
my $link_dir_b = catdir( $zenka_root, qw| links-b | );
make_path($link_dir_b);
$data{'v7-zenki'}{'cfg'}{'zenka_symlink_dir'} = $link_dir_b;
$result = $code{'v7-zenki.install_zenka_symlinks'}->();
check 'links still installed without p7c', $result > 0;
check 'no :: link without p7c', not -e catfile( $link_dir_b, '::' );
check 'Protocol-7 link exists without p7c',
    -l catfile( $link_dir_b, 'Protocol-7' );

## [ 5 ] check_service_unit : matches, differs, missing ##

my $repo_unit_dir = catdir( $zenka_root, qw| data lib-path systemd system | );
make_path($repo_unit_dir);
my $repo_unit_copy = catfile( $repo_unit_dir, 'Protocol-7.service' );
write_file( $repo_unit_copy, $repo_unit );

my $installed_unit = catfile( $zenka_root, 'installed-unit.service' );
$data{'v7-zenki'}{'cfg'}{'service_unit_path'} = $installed_unit;

write_file( $installed_unit, $repo_unit );
@log_lines = ();
$result    = $code{'v7-zenki.check_service_unit'}->();
check 'matching unit returns TRUE',         $result == TRUE;
check 'matching unit logs no level 0 line', level0_count(qr|^|) == 0;

write_file( $installed_unit, "[Unit]\nDescription=locally modified\n" );
@log_lines = ();
$result    = $code{'v7-zenki.check_service_unit'}->();
check 'differing unit returns FALSE', $result == FALSE;
check 'differing unit logs exactly one level 0 line',
    level0_count(qr|^|) == 1;
check 'level 0 line names bin/p7-deps install-service',
    level0_count(
    qr|systemd\sunit\sdiffers\sfrom\sthe\srepo\s--\sbin/p7-deps\sinstall-service|
    ) == 1;
check 'differing unit was NOT copied',
    slurp($installed_unit) ne slurp($repo_unit_copy);

unlink($installed_unit);
@log_lines = ();
$result    = $code{'v7-zenki.check_service_unit'}->();
check 'missing unit returns FALSE',                 $result == FALSE;
check 'missing unit logs exactly one level 0 line', level0_count(qr|^|) == 1;

## summary ##

printf "\n: %d checks passed, %d failed\n", $pass_count, $fail_count;
exit( $fail_count ? 1 : 0 );

#,,,.,,.,,,,,,,.,,,,.,,..,..,,.,,,,,.,,..,,.,,..,,...,..,,,,,,..,,..,,...,,,,,
#KDWAGAXRUUUVSGQKB2YQ4UXUTCQPMOTHMBD2PEC6ZKFSXVNEUWNSMXE62TMJNYLK7AUYVRD3P6KCM
#\\\|RL6HDWDEESTXAR4T6WZNYNX4Q6KBF2THH4EZSIEFPD4E7OTLQUS \ / AMOS7 \ YOURUM ::
#\[7]QONVEHYWMKKBERKPHLP72TFUVCUUBUCAQH2BZZ7GKFSXWBM6V2DY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
