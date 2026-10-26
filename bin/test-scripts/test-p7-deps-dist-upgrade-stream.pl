#!/usr/bin/perl
use v5.24;
use strict;
use English;
use warnings;

###                                                                      ###
##  AMOS7::deps::dist_upgr : streaming condense test                      ##
###                                                                      ###

## drives the real dist_upgr::run against stubbed apt-get \ dpkg \        ##
## pam-auth-update binaries on a private PATH :                           ##
## - success : condensed package lines arrive mid-run, one summary per    ##
##   step, { ok => 1, failed_step => undef }                              ##
## - hard failure : the apt error passes through verbatim, the run stops  ##
##   at the failing step, { ok => 0, failed_step => <name> }              ##
## - best-effort failure : pam-auth-update failing keeps the run ok       ##
## no root, no network, no real apt -- the stubs emit fixture output      ##

use File::Spec;
use Cwd        qw| abs_path |;
use FindBin    qw| $RealBin |;
use File::Temp qw| tempdir |;

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
}

use AMOS7::deps::dist_upgr qw| run |;

my $fail_count = 0;
my $test_count = 0;

sub ok ($;$) {
    my ( $cond, $label ) = @ARG;
    $test_count++;
    if ($cond) { say "  ok   : $label"; return 1 }
    $fail_count++;
    say "  FAIL : $label";
    return 0;
}

my $stub_dir = tempdir(qw| CLEANUP 1 |);
chmod 0755, $stub_dir;

sub write_stub {
    my ( $name, $body ) = @ARG;
    my $path = File::Spec->catfile( $stub_dir, $name );
    open( my $fh, '>', $path ) or die "cannot write $path : $OS_ERROR";
    print {$fh} $body;
    close($fh);
    chmod 0755, $path;
    return;
}

my $apt_ok = <<'EOS';
#!/bin/sh
case "$*" in
    *dist-upgrade*)
        echo "Reading package lists..."
        echo "Building dependency tree..."
        echo "Reading state information..."
        echo "Calculating upgrade..."
        echo "The following packages will be upgraded:"
        echo "  zlib1g nvidia-settings"
        echo "Get:1 http://deb.debian.org/debian unstable/main amd64 zlib1g amd64 1:1.3.2-4 [92.4 kB]"
        echo "Get:9 https://developer.download.nvidia.com/compute/cuda/repos/debian12/x86_64  nvidia-settings 615.71.10-1 [786 kB]"
        printf 'Fetching... 42%%\r'
        echo "Unpacking zlib1g (1:1.3.2-4) over (1:1.3.2-3)…"
        echo "Unpacking nvidia-settings (615.71.10-1) over (615.71.9-1)…"
        printf 'Unpacking... 7%%\r'
        echo "Setting up zlib1g (1:1.3.2-4)…"
        echo "Setting up nvidia-settings (615.71.10-1)…"
        exit 0 ;;
    *update*)
        echo "Hit:1 http://deb.debian.org/debian unstable InRelease"
        echo "Get:4 https://nvidia.github.io/libnvidia-container/experimental/deb/amd64  InRelease [1,489 B]"
        echo "Get:5 http://deb.debian.org/debian testing/main amd64 Packages.diff/Index [63.6 kB]"
        exit 0 ;;
    *autoremove*)
        echo "Reading package lists..."
        echo "Building dependency tree..."
        echo "Reading state information..."
        echo "The following packages will be REMOVED:"
        echo "  cpp-15-for-host* libpython3.13* libpython3.13-dev*"
        echo "  linux-image-7.1.8+deb14.1-amd64* libavcodec62:amd64*"
        echo "0 upgraded, 0 newly installed, 5 to remove and 5 not upgraded."
        echo "Removing linux-image-7.1.8+deb14.1-amd64 (7.1.8-2)..."
        echo "Removing libpython3.13 (3.13.2-1)..."
        exit 0 ;;
    *)
        echo "Reading package lists..."
        echo "Building dependency tree..."
        echo "Reading state information..."
        echo "Solving dependencies..."
        exit 0 ;;
esac
EOS

my $apt_fail_pass1 = <<'EOS';
#!/bin/sh
case "$*" in
    *dist-upgrade*)
        echo "E: Broken packages"
        exit 1 ;;
    *)
        exit 0 ;;
esac
EOS

my $dpkg_ok = <<'EOS';
#!/bin/sh
echo "(Reading database... 50000 files and directories currently installed.)"
exit 0
EOS

write_stub( 'apt-get',         $apt_ok );
write_stub( 'dpkg',            $dpkg_ok );
write_stub( 'pam-auth-update', "#!/bin/sh\nexit 0\n" );

sub run_upgrade {
    my @emitted;
    my $result = run(
        'dist-upgrade',
        {   'emit' => sub { push @emitted, $_[0] },
            'sudo' => '',
            'path' => "$stub_dir:/usr/bin:/bin",
        }
    );
    return ( \@emitted, $result );
}

sub first_index {
    my ( $needle, $list ) = @ARG;
    for my $i ( 0 .. $#$list ) {
        return $i if $list->[$i] eq $needle;
    }
    return -1;
}

say ':: success run';

my ( $emitted, $result ) = run_upgrade();

ok( $result->{'ok'} == 1 && !defined $result->{'failed_step'},
    'ok => 1, failed_step undef' );

ok( ( grep { $_ eq 'zlib1g  1:1.3.2-3 -> 1:1.3.2-4  92.4 kB' } @$emitted ),
    'the upgrade condensed to one line per package' );

my $pkg_idx
    = first_index( 'zlib1g  1:1.3.2-3 -> 1:1.3.2-4  92.4 kB', $emitted );
my $upd_idx = first_index( ':. apt update ..,', $emitted );
ok( $pkg_idx >= 0 && $upd_idx > $pkg_idx,
    'condensed lines arrive mid-run, not after the end' );

my @summaries = grep {m|^\.\. \d+ routine lines condensed$|} @$emitted;
ok( @summaries >= 2,
    'one routine-lines summary per step that had any [ dpkg + pass 1 ]' );
ok( ( grep {m|^Get:|} @$emitted ) == 0,
    'mirror + repo index fetch lines [ all formats ] are condensed away' );
ok( ( grep { $_ eq '.. 2 names : packages will be upgraded' } @$emitted ),
    'the wrapped package-name list condenses to one count line'
);
ok(
    (   grep { $_ eq 'nvidia-settings  615.71.9-1 -> 615.71.10-1  786 kB' }
            @$emitted
    ),
    'the cuda-style repo line still feeds the package size'
);
ok( ( grep {m|\r|} @$emitted ) == 0,
    'no carriage returns leak into the emitted rows' );
ok( ( grep {m{\d+%\s*\z}} @$emitted ) == 0,
    'tty progress fragments are dropped'
);
ok( ( grep {m{^Unpacking\s}} @$emitted ) == 0,
    'unicode-ellipsis unpack lines condense, not pass through' );
ok( ( grep { $_ eq '.. 5 names : packages will be REMOVED' } @$emitted ),
    'removal name lists count too [ * and :arch tokens ]'
);
ok(
    (   grep { $_ eq 'linux-image-7.1.8+deb14.1-amd64  removed  7.1.8-2' }
            @$emitted
    ),
    'removals condense to one line per package'
);

say ':: hard failure at pass 1';

write_stub( 'apt-get', $apt_fail_pass1 );
( $emitted, $result ) = run_upgrade();

ok( $result->{'ok'} == 0
        && $result->{'failed_step'} eq 'dist-upgrade (pass 1)',
    'ok => 0, failed_step names the step'
);
ok( ( grep { $_ eq 'E: Broken packages' } @$emitted ),
    'the apt error passes through verbatim'
);
ok( ( grep { $_ eq ':. ERROR during dist-upgrade (pass 1)' } @$emitted ),
    'the failing step is named in the stream' );
ok( first_index( ':. apt update ..,', $emitted ) == -1,
    'the run stops at the failing step' );

say ':: best-effort failure [ pam-auth-update ]';

write_stub( 'apt-get', $apt_ok );
write_stub( 'pam-auth-update',
    "#!/bin/sh\necho 'pam-auth-update: " . "no pam'\nexit 1\n" );
( $emitted, $result ) = run_upgrade();

ok( $result->{'ok'} == 1, 'a best-effort step failing keeps the run ok' );
ok( ( grep { $_ eq 'pam-auth-update: no pam' } @$emitted ),
    'the best-effort error line still passes through'
);
ok( ( grep { $_ eq ':. pam-auth-update failed (non-critical)' } @$emitted ),
    'marked non-critical in the stream' );

say '';
say sprintf ':: %d checks, %d failed', $test_count, $fail_count;
exit( $fail_count ? 1 : 0 );

#,,,,,.,,,,..,...,,,,,...,.,.,,..,,,,,,,.,.,,,.,.,...,...,...,,..,,,.,,,,,,,,,
#OMPB7AWHIJX366IOPZBRICQ4IIIRS4QFCGLOBX7VALTRZXLXFUQDXBERJVQTIX5X4ZRH6W355WJ3G
#\\\|XVOWAGG7V6QWC2QHECJAS55IA5WJN3WHLPTCZIQ7FBXJI2CLGVD \ / AMOS7 \ YOURUM ::
#\[7]5E7JFFXAAKQW4TQ7SS3LPL5R47272G3KHHYDLC3THJM3EANCP6BQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
