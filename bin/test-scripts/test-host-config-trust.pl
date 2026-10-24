#!/usr/bin/env perl
use v5.24;
use strict;
use English;
use warnings;

## host overlays are applied only when the zenka user cannot have written  ##
## them [ base.host.trusted_file ] : compiles the real                     ##
## src/base.host.trusted_file, src/base.host.config_dir and                ##
## src/base.load_host_config, drives them with a base.logs stub and a      ##
## load_config_file recorder. the test directory sits next to the tree's   ##
## parent [ the tree itself is group writable on a dev checkout, so a file ##
## inside it is refused -- as it must be ] and is removed afterwards.  run ##
## as the tree owner, not root : root would re-own the test dirs.          ##

use File::Spec;
use File::stat ();
use File::Path qw| make_path remove_tree |;
use Cwd        qw| abs_path |;
use FindBin    qw| $RealBin |;

BEGIN {
    $main::root_path = abs_path(
        File::Spec->rel2abs(
            File::Spec->catdir(
                $RealBin, File::Spec->updir, File::Spec->updir
            )
        )
    );
}
use constant { TRUE => 5, FALSE => 0, UNKNOWN => 2 };

die "run as the tree owner, not root\n" if $EFFECTIVE_USER_ID == 0;

my $root_path = $main::root_path;
my $parent = abs_path( File::Spec->catdir( $root_path, File::Spec->updir ) );

our %data;
our %code;

my @log_lines;
$code{'base.logs'} = sub {
    my ( $level, $fmt ) = splice @ARG, 0, 2;
    push @log_lines, [ $level, sprintf $fmt, @ARG ];
    return 1;
};
my @loaded;
$code{'base.load_config_file'} = sub { push @loaded, shift; return TRUE };

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
    $src =~ s{\n#[^\n]*\z}{\n} while $src =~ m{\n#[,\[\\|:][^\n]*\z};
    my @seg = split m{('(?:[^'\\]|\\.)*'|"(?:[^"\\]|\\.)*"|\#[^\n]*)}x,
        $src, -1;

    for ( my $i = 0; $i < @seg; $i += 2 ) {
        $seg[$i] = translate_code( $seg[$i] );
    }
    my $sub = eval 'sub { ' . join( '', @seg ) . ' }';
    die "compile error in $name : $EVAL_ERROR" if $EVAL_ERROR;
    $code{$name} = $sub;
    return $sub;
}

load_module($_) for qw|
    base.host.trusted_file
    base.host.config_dir
    base.load_host_config
    |;

my ( $pass, $fail ) = ( 0, 0 );

sub check {
    my ( $label, $ok ) = @ARG;
    if   ($ok) { $pass++; say "ok    : $label" }
    else       { $fail++; say "FAIL  : $label" }
}

sub write_file {
    my ( $path, $mode ) = @ARG;
    open my $fh, '>', $path or die "write $path : $OS_ERROR";
    print {$fh} "test.key = 1\n";
    close $fh;
    chmod $mode, $path;
}

## test tree : <parent>/.p7-host-config-test-<pid>/etc/protocol-7 ##
my $base = File::Spec->catdir( $parent, ".p7-host-config-test-$PID" );
die "$base exists\n" if -e $base;
my $etc     = "$base/etc/protocol-7";
my $cfg_dir = "$etc/host-config";
make_path( $cfg_dir, "$etc/jobsite", { mode => 0755 } );
chmod 0755, $base, "$base/etc", $etc, $cfg_dir;

$data{'system'}{'root_path'}                    = $root_path;
$data{'system'}{'amos-zenka-user'}              = 'protocol-7';
$data{'system'}{'path'}{'zenka-dirs'}{'etc_P7'} = $etc;

my $trusted = $code{'base.host.trusted_file'};

eval {

    ## --- base.host.config_dir : non-root, path only --------------------- ##
    check 'config_dir is <etc>/host-config',
        $code{'base.host.config_dir'}->() eq $cfg_dir;

    ## --- trusted_file                                     ##
    ## ---------------------------------------------------- ##
    my $file = "$cfg_dir/jobsite.cfg";
    write_file( $file, 0644 );
    check 'tree-owner file, 0644, clean chain : trusted', $trusted->($file);

    chmod 0664, $file;
    my ( $ok, $why ) = $trusted->($file);
    check 'group writable file : refused', !$ok && $why =~ m|writable|;
    chmod 0644, $file;

    chmod 0775, $cfg_dir;
    ( $ok, $why ) = $trusted->($file);
    check 'group writable dir : refused', !$ok && $why =~ m|host-config|;
    chmod 0755, $cfg_dir;

    chmod 0777, $base;
    ( $ok, $why ) = $trusted->($file);
    check 'writable dir far up the chain : refused',
        !$ok && $why =~ m|\Q$base\E|;
    chmod 0755, $base;

    symlink $file, "$cfg_dir/link.cfg" or die "symlink : $OS_ERROR";
    ( $ok, $why ) = $trusted->("$cfg_dir/link.cfg");
    check 'symlinked file : refused', !$ok && $why =~ m|symlink|;

    ( $ok, $why ) = $trusted->("$cfg_dir/missing.cfg");
    check 'missing file : refused', !$ok;

    ( $ok, $why ) = $trusted->("$cfg_dir/../host-config/jobsite.cfg");
    check "'..' in the path : refused", !$ok;

    ( $ok, $why ) = $trusted->("relative/jobsite.cfg");
    check 'relative path : refused', !$ok;

    ## the tree owner counts only when it is not the zenka user ##
    {
        local $data{'system'}{'amos-zenka-user'} = getpwuid($EUID);
        ( $ok, $why ) = $trusted->($file);
        check 'tree owner = zenka user : refused', !$ok && $why =~ m|owner|;
    }

    ## --- load_host_config                             ##
    ## ------------------------------------------------ ##
    $data{'system'}{'zenka'}{'name'} = 'jobsite';
    @log_lines                       = ();
    @loaded                          = ();
    $code{'base.load_host_config'}->();
    check 'trusted overlay is applied', "@loaded" eq $file;
    check 'applied flag set', $data{'system'}{'host_config'}{'applied'};

    delete $data{'system'}{'host_config'};
    chmod 0666, $file;
    @log_lines = ();
    @loaded    = ();
    $code{'base.load_host_config'}->();
    check 'untrusted overlay is NOT applied', !@loaded;
    check 'untrusted overlay : level 0 REFUSED line',
        grep { $_->[0] == 0 and $_->[1] =~ m|REFUSED| } @log_lines;
    check 'applied flag not set', !$data{'system'}{'host_config'}{'applied'};
    chmod 0644, $file;

    write_file( "$etc/jobsite/host.cfg", 0644 );
    @log_lines = ();
    @loaded    = ();
    $code{'base.load_host_config'}->();
    check 'old <zenka>/host.cfg : level 0 NOT applied line',
        grep { $_->[0] == 0 and $_->[1] =~ m|jobsite/host\.cfg NOT applied| }
        @log_lines;
    check 'old file never loaded', !grep {m|/jobsite/host\.cfg$|} @loaded;

    $data{'system'}{'zenka'}{'name'} = 'host-config';
    @loaded = ();
    $code{'base.load_host_config'}->();
    check "a zenka named 'host-config' gets no overlay", !@loaded;

    $data{'system'}{'zenka'}{'name'} = 'nameserv';
    @loaded = ();
    $code{'base.load_host_config'}->();
    check 'no overlay file : nothing loaded', !@loaded;

    1;
} or do { warn $EVAL_ERROR; $fail++ };

remove_tree($base) if $base =~ m|/\.p7-host-config-test-\d+$|;

say "\n$pass passed, $fail failed";
exit( $fail ? 1 : 0 );

#,,.,,..,,,,,,,.,,,,,,...,,,.,.,,,,,.,,..,,,,,..,,...,...,,..,..,,.,,,,,,,...,
#RRMEUIMUGILQYYTETL645XCWLSWOKR57L3LR54PFUVCF37H7T2Y637TZCRFQFHQMTOH4ITTHAAH4S
#\\\|3DX5CLAYLMYEYUC6REENNL3T6J7MIGMLZ4A5COALSUVRNCYBQEC \ / AMOS7 \ YOURUM ::
#\[7]3UYW7JDL4BKPW7GNM25UEFOEI642YY6DE7BMF4XD3CBZPKO5C4AA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
