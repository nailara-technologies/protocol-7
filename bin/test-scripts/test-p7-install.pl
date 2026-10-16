#!/usr/bin/env perl
use v5.32;
use strict;
use English;
use warnings;

## bin/p7-install against temporary roots : env P7_INSTALL_ROOT prefixes   ##
## the install path [ and becomes p7-deps' P7_DEPS_SERVICE_ROOT ], and     ##
## dpkg-query, apt-get, git and systemctl are stateful fake binaries first ##
## in PATH -- apt-get adds to the package list dpkg-query reads, git clone ##
## writes a fake checkout whose bin/p7-deps is a stub too. every stub      ##
## records its args in a call log outside the root. the assertions read    ##
## state on disk and those call logs, never the printed text. the root     ##
## refusal runs as 'nobody' when the test runs as root. no real package,   ##
## repository, unit or service is touched anywhere.                        ##

use Config;
use File::Spec;
use Cwd         qw| abs_path |;
use FindBin     qw| $RealBin |;
use File::Temp  qw| tempdir |;
use File::Path  qw| make_path remove_tree |;
use File::Copy  qw| copy |;
use File::Find  qw| find |;
use Digest::SHA qw| sha256_hex |;
use B           qw| perlstring |;
use POSIX       ();

use constant { TRUE => 5, FALSE => 0 };

my $root_path = abs_path(
    File::Spec->rel2abs(
        File::Spec->catdir( $RealBin, File::Spec->updir, File::Spec->updir )
    )
);
my $installer = File::Spec->catfile( $root_path, qw| bin p7-install | );
my $lib_path  = File::Spec->catdir( $root_path, qw| data lib-path pm | );

my $REPO   = 'https://example.invalid/protocol-7.git';
my $HEAD_A = 'a' x 40;
my $HEAD_B = 'b' x 40;
my $HEAD_C = 'c' x 40;

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

sub lines_of {
    return grep {length} split m|\n|, slurp( $_[0] ) // '';
}

## run a command, capture stdout + stderr and exit code [ no shell ] ##

sub run_capture {
    my (@cmd) = @_;

    my $pid = open( my $pipe, '-|' ) // die "fork failed : $OS_ERROR";
    if ( $pid == 0 ) {
        open( STDERR, '>&', \*STDOUT );
        exec(@cmd) or exit 127;
    }
    local $INPUT_RECORD_SEPARATOR = undef;
    my $output = <$pipe> // '';
    close($pipe);
    return ( $CHILD_ERROR >> 8, $output );
}

## --- the sandbox : root, stub binaries, stub state, call logs ##
## ------------------                                           ##

my $sandbox = tempdir( CLEANUP => 1 );
chmod( 0755, $sandbox );    ## 'nobody' reaches the stubs ##

my $test_root = File::Spec->catdir( $sandbox,   'root' );
my $stub_dir  = File::Spec->catdir( $sandbox,   'stub' );
my $state_dir = File::Spec->catdir( $sandbox,   'state' );
my $log_dir   = File::Spec->catdir( $sandbox,   'log' );
my $template  = File::Spec->catdir( $sandbox,   'template' );
my $target    = File::Spec->catdir( $test_root, qw| usr local protocol-7 | );

sub log_file   { File::Spec->catfile( $log_dir,   "$_[0].log" ) }
sub state_path { File::Spec->catfile( $state_dir, $_[0] ) }

## the stubs are perl with this perl's absolute path -- nothing else from ##
## PATH is needed, PATH can be the stub dir alone                         ##

my $stub_head = sprintf <<'EOF', $EXECUTABLE_NAME, perlstring($log_dir),
#!%s
use strict;
use warnings;
my $log_dir   = %s;
my $state_dir = %s;
sub state_file { "$state_dir/$_[0]" }
sub slurp_line {
    open my $fh, '<', $_[0] or return undef;
    my $line = <$fh> // '';
    chomp $line;
    return $line;
}
sub put {
    open my $fh, '>', $_[0] or die "stub : cannot write $_[0] : $!";
    print {$fh} $_[1];
    close $fh;
}
sub call_log {
    my ($name) = @_;
    open my $fh, '>>', "$log_dir/$name.log" or die "stub : no log : $!";
    print {$fh} join( ' ', @ARGV ), "\n";
    close $fh;
}
EOF
    perlstring($state_dir);

sub make_stub {
    my ( $dir, $name, $body ) = @_;
    my $path = File::Spec->catfile( $dir, $name );
    write_file( $path, $stub_head . $body );
    chmod( 0755, $path );
    return $path;
}

## dpkg-query -W -f=${Status} <pkg> : installed when listed in the state ##
my $dpkg_query_stub = <<'EOF';
call_log('dpkg-query');
my $pkg = $ARGV[-1];
open my $fh, '<', state_file('installed') or exit 1;
my %installed = map { chomp; $_ => 1 } <$fh>;
exit 1 if not $installed{$pkg};
print 'install ok installed';
exit 0;
EOF

## apt-get update \ -y install <pkgs> : install adds to the state list, ##
## except names listed in apt-fail                                      ##
my $apt_get_stub = <<'EOF';
call_log('apt-get');
my @args = grep { not m|^-| } @ARGV;
exit 0 if $args[0] eq 'update';
exit 1 if $args[0] ne 'install';
my %fail;
if ( open my $fh, '<', state_file('apt-fail') ) {
    %fail = map { chomp; $_ => 1 } <$fh>;
}
open my $out, '>>', state_file('installed') or exit 1;
my $failed = 0;
for my $pkg ( @args[ 1 .. $#args ] ) {
    if   ( $fail{$pkg} ) { $failed++ }
    else                 { print {$out} "$pkg\n" }
}
close $out;
exit( $failed ? 100 : 0 );
EOF

## git : clone \ rev-parse \ symbolic-ref \ ls-remote \ fetch \ status \ ##
## merge on a fake checkout [ .git/head, .git/branch, .git/fetch-head ]  ##
my $git_stub = sprintf <<'EOF', perlstring($template);
call_log('git');
my $template = %s;
my @a = @ARGV;
if ( $a[0] eq 'clone' ) {
    my ( $branch, $dir ) = ( $a[2], $a[-1] );
    exit 128 if -e state_file('clone-fail');
    system( 'cp', '-a', $template, $dir ) == 0 or exit 128;
    mkdir "$dir/.git";
    put( "$dir/.git/head",   slurp_line( state_file('remote-head') ) );
    put( "$dir/.git/branch", $branch );
    exit 0;
}
exit 129 if $a[0] ne '-C';
my ( $dir, $cmd, @rest ) = @a[ 1 .. $#a ];
exit 128 if not -d "$dir/.git";
if ( $cmd eq 'rev-parse' ) {
    my $file = $rest[0] eq 'FETCH_HEAD' ? 'fetch-head' : 'head';
    my $id   = slurp_line("$dir/.git/$file") // exit 128;
    print "$id\n";
} elsif ( $cmd eq 'symbolic-ref' ) {
    print slurp_line("$dir/.git/branch"), "\n";
} elsif ( $cmd eq 'ls-remote' ) {
    printf "%%s\t%%s\n", slurp_line( state_file('remote-head') ), $rest[-1];
} elsif ( $cmd eq 'fetch' ) {
    put( "$dir/.git/fetch-head", slurp_line( state_file('remote-head') ) );
} elsif ( $cmd eq 'status' ) {
    print " M src/changed\n" if -e "$dir/.git/dirty";
} elsif ( $cmd eq 'merge' ) {
    exit 128 if -e state_file('no-ff');
    put( "$dir/.git/head", slurp_line("$dir/.git/fetch-head") );
} else {
    exit 129;
}
exit 0;
EOF

## systemctl : is-enabled \ is-active read the state, enable \ start write ##
## it, anything else is only logged                                        ##
my $systemctl_stub = <<'EOF';
call_log('systemctl');
my ( $cmd, $unit ) = @ARGV;
if ( $cmd eq 'is-enabled' ) {
    print( ( -e state_file('enabled') ? 'enabled' : 'disabled' ), "\n" );
} elsif ( $cmd eq 'is-active' ) {
    print( ( -e state_file('active') ? 'active' : 'inactive' ), "\n" );
} elsif ( $cmd eq 'enable' ) {
    put( state_file('enabled'), '' );
} elsif ( $cmd eq 'start' ) {
    exit 1 if -e state_file('start-fail');
    put( state_file('active'), '' );
}
exit 0;
EOF

## the checkout's bin/p7-deps : logs its args and P7_DEPS_SERVICE_ROOT, ##
## enable-service goes on to systemctl like the real one                ##
my $p7_deps_stub = <<'EOF';
call_log('p7-deps');
open my $fh, '>>', "$log_dir/p7-deps-env.log" or die;
print {$fh} ( $ENV{'P7_DEPS_SERVICE_ROOT'} // '<unset>' ), "\n";
close $fh;
exit 1 if -e state_file("p7-deps-fail-$ARGV[0]");
if ( $ARGV[0] eq 'enable-service' ) {
    system( 'systemctl', 'enable', 'Protocol-7' ) == 0 or exit 1;
}
exit 0;
EOF

sub reset_sandbox {
    remove_tree( $test_root, $stub_dir, $state_dir, $log_dir, $template );
    make_path( $test_root, $stub_dir, $state_dir, $log_dir,
        File::Spec->catdir( $template, 'bin' ) );
    chmod( 0777, $log_dir );    ## 'nobody' writes the call logs ##
    make_stub( $stub_dir, 'dpkg-query', $dpkg_query_stub );
    make_stub( $stub_dir, 'apt-get',    $apt_get_stub );
    make_stub( $stub_dir, 'git',        $git_stub );
    make_stub( $stub_dir, 'systemctl',  $systemctl_stub );
    make_stub( File::Spec->catdir( $template, 'bin' ),
        'p7-deps', $p7_deps_stub );
    write_file( state_path('installed'),   "perl\n" );
    write_file( state_path('remote-head'), $HEAD_A );
    return TRUE;
}

## the installer : stub dir first in PATH, P7_INSTALL_ROOT the test root [ ##
## $path_tail : what follows the stubs -- a real host has systemctl in     ##
## /usr/bin, the no-systemctl case swaps in a copy without it ]            ##
our $path_tail = q{/usr/bin:/bin};

sub install {
    my (@args) = @_;
    local $ENV{'PATH'}            = "$stub_dir:$path_tail";
    local $ENV{'P7_INSTALL_ROOT'} = $test_root;
    local $ENV{'P7_DEPS_SERVICE_ROOT'};
    return run_capture( $EXECUTABLE_NAME, $installer, '--repo', $REPO,
        @args );
}

## every path below the given dirs with its content hash \ link target ; a ##
## leading qr// leaves matching paths out                                  ##
sub snapshot {
    my (@dirs) = @_;
    my $skip = ref( $dirs[0] ) eq q|Regexp| ? shift(@dirs) : undef;
    my %seen;
    for my $dir ( grep {-e} @dirs ) {
        find(
            {   no_chdir => 1,
                wanted   => sub {
                    my $p = $File::Find::name;
                    return if defined $skip and $p =~ $skip;
                    $seen{$p}
                        = -l $p ? 'link:' . readlink($p)
                        : -d _  ? 'dir'
                        :         'file:' . sha256_hex( slurp($p) // '' );
                },
            },
            $dir
        );
    }
    return join "\n", map {"$_ $seen{$_}"} sort keys %seen;
}

sub calls { return lines_of( log_file( $_[0] ) ) }

sub calls_matching {
    my ( $tool, $re ) = @_;
    return scalar grep {m|$re|} calls($tool);
}

my $head_file = File::Spec->catfile( $target, qw| .git head | );

## git's FETCH_HEAD is rewritten by every fetch -- a real one as well ##
my $fetch_head = qr{/\.git/fetch-head$};

## --- [ 1 ] root refusal : not root, no test root -> exit 0110, nothing ##
## run. PATH holds dpkg-query only : had the refusal not happened, the   ##
## base-packages probe would have logged a call                          ##
## ------------------                                                    ##

reset_sandbox();
{
    my $refusal_stub_dir = File::Spec->catdir( $sandbox, 'stub-refusal' );
    make_path($refusal_stub_dir);
    make_stub( $refusal_stub_dir, 'dpkg-query', $dpkg_query_stub );

    local $ENV{'PATH'} = $refusal_stub_dir;
    local $ENV{'P7_INSTALL_ROOT'};
    local $ENV{'P7_DEPS_SERVICE_ROOT'};
    delete $ENV{'P7_INSTALL_ROOT'};

    my ( $exit, $out );
    if ( $EUID == 0 ) {
        my $uid = getpwnam('nobody')     // die "no user 'nobody'\n";
        my $gid = getgrnam('nogroup')    // getgrnam('nobody') // $uid;
        my $pid = open( my $pipe, '-|' ) // die "fork failed : $OS_ERROR";
        if ( $pid == 0 ) {
            open( STDERR, '>&', \*STDOUT );
            POSIX::setgid($gid);
            POSIX::setuid($uid);
            exit 126 if $EUID != $uid            or $UID != $uid;
            exec( $EXECUTABLE_NAME, $installer ) or exit 127;
        }
        local $INPUT_RECORD_SEPARATOR = undef;
        $out = <$pipe> // '';
        close($pipe);
        $exit = $CHILD_ERROR >> 8;
    } else {
        ( $exit, $out ) = run_capture( $EXECUTABLE_NAME, $installer );
    }
    check 'not root : exit 0110 [ 110 ]', $exit == 110;
    check 'not root : no probe ran [ dpkg-query log empty ]',
        not -e log_file('dpkg-query');
    check 'not root : nothing else ran', not( -e log_file('apt-get')
        or -e log_file('git')
        or -e log_file('systemctl')
        or -e log_file('p7-deps') );
    printf "       : exit %d, output [%s]\n", $exit, $out if $exit != 110;
}

## --- [ 2 ] fresh install on an empty root ##
## ------------------                       ##

reset_sandbox();
{
    my ( $exit, $out ) = install();
    check 'fresh : exit 0', $exit == 0;
    print $out if $exit != 0;

    ## the printed frame [ the stub p7-deps prints nothing -- a real one ##
    ## nested in a step is not covered here ]                            ##
    my @lines   = split m|\n|, $out;
    my @headers = grep { $lines[$_] =~ m|^:::\[ .+ \]$| } 0 .. $#lines;
    check 'fresh output : five step headers, each with a \'::\' line below',
        ( @headers == 5
            and not grep { ( $lines[ $_ + 1 ] // '' ) ne '::' } @headers );
    check 'fresh output : the first step reads as decided',
        $out =~ m|^:\n:::\[ base packages \]\n::\n::   ca-certificates |m;
    check 'fresh output : no \':\' line twice in a row', $out !~ m|^:\n:\n|m;

    my @apt = calls('apt-get');
    check 'fresh : apt-get update ran once',
        ( grep {m|\bupdate$|} @apt ) == 1;
    my @installs = grep {m|\binstall\b|} @apt;
    check 'fresh : one apt-get install of the missing packages only',
        (       @installs == 1
            and $installs[0]
            =~ m|-y install ca-certificates git build-essential$| );
    my %installed = map { $_ => 1 } lines_of( state_path('installed') );
    check 'fresh : all base packages installed now',
        4 == grep { $installed{$_} }
        qw| ca-certificates git perl build-essential |;

    check 'fresh : git clone of the base branch into the target',
        calls_matching( 'git',
        qr|^clone --branch base -- \Q$REPO\E \Q$target\E$| ) == 1;
    check 'fresh : checkout is at the remote head',
        slurp($head_file) eq $HEAD_A;

    check 'fresh : p7-deps install minimal, then install-service',
        join( '|', calls('p7-deps') ) eq 'install minimal|install-service';
    check 'fresh : p7-deps got the test root as P7_DEPS_SERVICE_ROOT',
        2 == grep { $_ eq $test_root } lines_of( log_file('p7-deps-env') );
    check 'fresh : no enable, start or restart without --enable \ --start',
        ( 0 == calls_matching( 'systemctl', qr{^(enable|start|restart)\b} )
            and not -e state_path('enabled')
            and not -e state_path('active') );
}

## --- [ 3 ] a second run changes nothing ##
## ------------------                     ##

{
    my $before     = snapshot( $fetch_head, $test_root, $state_dir );
    my $apt_before = scalar calls('apt-get');

    my ( $exit, $out ) = install();
    check 'second run : exit 0', $exit == 0;
    check 'second run : ' . 'no apt-get call',
        scalar calls('apt-get') == $apt_before;
    check 'second run : one clone in all, no merge',
        (       calls_matching( 'git', qr|^clone| ) == 1
            and calls_matching( 'git', qr|\bmerge\b| ) == 0 );
    check 'second run : root and stub state unchanged',
        snapshot( $fetch_head, $test_root, $state_dir ) eq $before;
    check 'second run : still no enable, start or restart',
        0 == calls_matching( 'systemctl', qr{^(enable|start|restart)\b} );
}

## --- [ 4 ] updates : fast-forward, local changes, other branch ##
## ------------------                                            ##

{
    write_file( state_path('remote-head'), $HEAD_B );
    my ( $exit, $out ) = install();
    check 'update : exit 0', $exit == 0;
    check 'update : fetched then merged ff-only',
        (       calls_matching( 'git', qr|fetch -q origin base$| ) >= 1
            and calls_matching( 'git', qr|merge -q --ff-only FETCH_HEAD$| )
            == 1 );
    check 'update : checkout at the new head', slurp($head_file) eq $HEAD_B;

    write_file( state_path('remote-head'),                        $HEAD_C );
    write_file( File::Spec->catfile( $target, qw| .git dirty | ), '' );
    ( $exit, $out ) = install();
    check 'local changes : exit 0 [ checkout still installable ]', $exit == 0;
    check 'local changes : no second merge',
        calls_matching( 'git', qr|\bmerge\b| ) == 1;
    check 'local changes : head left as it was', slurp($head_file) eq $HEAD_B;
    unlink File::Spec->catfile( $target, qw| .git dirty | );

    write_file( File::Spec->catfile( $target, qw| .git branch | ), 'dev' );
    my $fetches = calls_matching( 'git', qr|\bfetch\b| );
    ( $exit, $out ) = install();
    check 'other branch : exit 0, no fetch, head left as it was',
        (       $exit == 0
            and calls_matching( 'git', qr|\bfetch\b| ) == $fetches
            and slurp($head_file) eq $HEAD_B );
    write_file( File::Spec->catfile( $target, qw| .git branch | ), 'base' );
}

## --- [ 5 ] --enable --start : once, then only read back ##
## ------------------                                     ##

{
    my ( $exit, $out ) = install(qw| --enable --start |);
    check 'enable + start : exit 0', $exit == 0;
    check 'enable + start : p7-deps enable-service ran once',
        calls_matching( 'p7-deps', qr|^enable-service$| ) == 1;
    check 'enable + start : unit enabled and active',
        -e state_path('enabled') && -e state_path('active');
    check 'enable + start : systemctl start ran once',
        calls_matching( 'systemctl', qr|^start Protocol-7$| ) == 1;

    ( $exit, $out ) = install(qw| --enable --start |);
    check 'enable + start again : exit 0', $exit == 0;
    check 'enable + start again : no second enable-service or start',
        (       calls_matching( 'p7-deps', qr|^enable-service$| ) == 1
            and calls_matching( 'systemctl', qr|^start\b| ) == 1 );
    check 'never a restart [ any run ]',
        calls_matching( 'systemctl',
        qr{^(restart|reload|try-restart|stop)\b} ) == 0;
}

## --- [ 6 ] --dry-run writes nothing and runs no installer ##
## ------------------                                       ##

## fresh root : everything missing ##
reset_sandbox();
{
    my $before = snapshot( $sandbox . '/root', $state_dir, $template );
    my ( $exit, $out ) = install(qw| --dry-run --enable --start |);
    check 'dry run fresh : exit 0', $exit == 0;
    check 'dry run fresh : root, stub state and template unchanged',
        snapshot( $sandbox . '/root', $state_dir, $template ) eq $before;
    check 'dry run fresh : no apt-get, git, p7-deps call',
        not( -e log_file('apt-get')
        or -e log_file('git')
        or -e log_file('p7-deps') );
    check 'dry run fresh : only is-enabled \ is-active asked',
        not grep { not m{^is-(enabled|active) Protocol-7$} }
        calls('systemctl');
}

## installed, outdated checkout : ls-remote only, no fetch ##
{
    install();
    write_file( state_path('remote-head'), $HEAD_B );
    my $before = snapshot( $test_root, $state_dir );
    my %count  = map { $_ => scalar calls($_) } qw| apt-get p7-deps git |;

    my ( $exit, $out ) = install(qw| --dry-run --enable --start |);
    my @new_git
        = ( calls(q|git|) )[ $count{q|git|} .. scalar( calls(q|git|) ) - 1 ];
    check 'dry run outdated : exit 0', $exit == 0;
    check 'dry run outdated : root and stub state unchanged',
        snapshot( $test_root, $state_dir ) eq $before;
    check 'dry run outdated : no apt-get or p7-deps call',
        (       scalar calls('apt-get') == $count{'apt-get'}
            and scalar calls('p7-deps') == $count{'p7-deps'} );
    check 'dry run outdated : git ls-remote asked, no fetch or merge',
        ( ( grep {m|ls-remote origin refs/heads/base$|} @new_git )
            and not grep {m{\b(fetch|merge)\b}} @new_git );
}

## --- [ 7 ] failures stop the chain with exit 0110 ##
## ------------------                               ##

reset_sandbox();
{
    write_file( state_path('apt-fail'), "git\n" );
    my ( $exit, $out ) = install();
    check 'apt failure : exit 0110', $exit == 110;
    check 'apt failure : no clone, no p7-deps',
        (       not( -e log_file('git') or -e log_file('p7-deps') )
            and not -e $target );
}

reset_sandbox();
{
    write_file( state_path('p7-deps-fail-install'), '' );
    my ( $exit, $out ) = install();
    check 'p7-deps install failure : exit 0110', $exit == 110;
    check 'p7-deps install failure : install-service not run',
        join( '|', calls('p7-deps') ) eq 'install minimal';
}

reset_sandbox();
{
    make_path($target);
    write_file( File::Spec->catfile( $target, 'keep-me' ), "data\n" );
    my $before = snapshot($test_root);
    my ( $exit, $out ) = install();
    check 'non-git target : exit 0110', $exit == 110;
    check 'non-git target : left alone, no clone',
        (       snapshot($test_root) eq $before
            and calls_matching( 'git', qr|^clone| ) == 0 );
}

reset_sandbox();
{
    unlink File::Spec->catfile( $stub_dir, 'systemctl' );

    ## /usr/bin minus systemctl, as symlinks : the real host keeps every ##
    ## other tool, the installer finds no systemctl at all               ##
    my $no_systemctl = File::Spec->catdir( $sandbox, 'bin-no-systemctl' );
    make_path($no_systemctl);
    opendir my $usr_bin, q{/usr/bin} or die "/usr/bin : $OS_ERROR";
    foreach my $tool ( readdir $usr_bin ) {
        next if $tool =~ m{^\.} or $tool eq q{systemctl};
        symlink "/usr/bin/$tool", File::Spec->catfile( $no_systemctl, $tool );
    }
    closedir $usr_bin;
    local $path_tail = $no_systemctl;

    my ( $exit, $out ) = install(qw| --start |);
    check 'no systemctl + --start : exit 0110', $exit == 110;
    ( $exit, $out ) = install();
    check 'no systemctl, nothing asked : exit 0', $exit == 0;
}

## --- [ 8 ] standalone : a copy [ script + AMOS7/ ] on core perl only ##
## ------------------                                                  ##

reset_sandbox();
{
    my $copy = File::Spec->catdir( $sandbox, 'copy' );
    make_path( map { File::Spec->catdir( $copy, @$_ ) } [qw| AMOS7 TERM |],
        [qw| AMOS7 deps |] );
    copy( $installer, File::Spec->catfile( $copy, 'p7-install' ) );
    copy(
        File::Spec->catfile( $lib_path, @$_ ),
        File::Spec->catfile( $copy,     @$_ )
        )
        for [qw| AMOS7.pm |], [qw| AMOS7 TERM Frame.pm |],
        [qw| AMOS7 deps debp.pm |];

    my $inc_log = File::Spec->catfile( $sandbox, 'inc.log' );
    my $script  = File::Spec->catfile( $copy,    'p7-install' );
    my $child   = sprintf <<'EOF', perlstring($script), perlstring($inc_log);
BEGIN {
    use Config;
    @INC = ( $Config::Config{privlibexp}, $Config::Config{archlibexp} );
    $0 = %s;
    ## loaded before the strip [ Config and what it pulls in ] ##
    $main::pre_strip{$_} = 1 for keys %%INC;
}
END {
    open my $fh, '>', %s or die;
    print {$fh} "$_\t$INC{$_}\n" for sort grep { not $main::pre_strip{$_} }
        keys %%INC;
    close $fh;
}
do $0;
die $@ if $@;
EOF
    local $ENV{'PATH'}            = "$stub_dir:/usr/bin:/bin";
    local $ENV{'P7_INSTALL_ROOT'} = $test_root;
    local $ENV{'PERL5LIB'};
    delete $ENV{'PERL5LIB'};
    my ( $exit, $out )
        = run_capture( $EXECUTABLE_NAME, '-e', $child, '--', '--dry-run' );
    check 'copy on core perl : dry run exit 0', $exit == 0;
    print $out if $exit != 0;

    my @loaded  = map { [ split m|\t| ] } lines_of($inc_log);
    my @foreign = grep {
                index( $_->[1], $copy ) != 0
            and index( $_->[1], $Config{privlibexp} ) != 0
            and index( $_->[1], $Config{archlibexp} )
            != 0
    } @loaded;
    check 'copy on core perl : every module from the copy or core perl',
        @loaded > 0 && !@foreign;
    printf "       : %s from %s\n", @$_ for @foreign;
    check 'copy on core perl : the AMOS7 modules came from the copy', (
        3 == grep {
            $_->[0] =~ m{^AMOS7(?:\.pm|/TERM/Frame\.pm|/deps/debp\.pm)$}
                and index( $_->[1], $copy ) == 0
        } @loaded
    );
}

## summary ##

printf "\n: %d checks passed, %d failed\n", $pass_count, $fail_count;
exit( $fail_count ? 1 : 0 );

#,,..,.,.,.,,,,,.,,.,,.,.,.,.,,,,,,..,.,,,.,.,..,,...,...,,,.,,,,,..,,,,,,,,,,
#BKUIMUXRBFDJMGRZ6UDGSWDWXJYYRBNVGXB3TDJCD5IK2NVBDRIQZUA4RNOKYQAVY4SZHPHJQ4NZI
#\\\|2O2KYMVC6DVFQUDSAX5DXP4FY2WL7X6JQ4FRYUSXXABKHGHSGPF \ / AMOS7 \ YOURUM ::
#\[7]D3KUZ7CEMNWCR2I3H7QCLMCOYVRAYXP763QVADIKIYZ3C3DIPQBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
