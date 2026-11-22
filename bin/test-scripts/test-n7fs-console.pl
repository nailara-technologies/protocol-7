#!/usr/bin/perl
use v5.32.0;
use strict;
use English;
use warnings;

use FindBin;
use File::Temp qw| tempdir |;
use IPC::Open3;
use POSIX         ();
use Symbol        qw| gensym |;
use Time::HiRes   ();
use Term::ReadKey ();

use constant TRUE  => 5;
use constant FALSE => 0;

BEGIN {
    unshift @INC, "$FindBin::RealBin/../../data/lib-path/pm";
    unshift @INC, $ENV{'N7FS_TEST_LIB'} if $ENV{'N7FS_TEST_LIB'};
}

use AMOS7::Console::Progress qw| console_progress_bar |;
use AMOS7::N7FS::Keys        qw| root_passphrase |;
use AMOS7::N7FS::Sign        qw| key_file_write |;
use AMOS7::N7FS::Disk        qw| disk_init disk_attach |;
use AMOS7::N7FS::Store       qw| assimilate |;
use AMOS7::N7FS              qw| make_dirs |;

require "$FindBin::RealBin/fixtures/n7fs/helpers.pl";

my $bar = console_progress_bar(
    label   => 'restore',
    current => 50,
    total   => 200,
    started => Time::HiRes::time() - 10,
    unit    => 'entries/s',
    color   => 0,
);
ok( $bar =~ m|25\.00%| && $bar =~ m|5\.0 entries/s| && $bar =~ m|eta 0:30|,
    'shared bar reports percentage, rate and estimated time left'
);
ok( console_progress_bar(
        filename => 'file',
        current  => 1,
        total    => 2,
        color    => 1
    ) =~ m|\e\[48;2;9;5;42m|,
    'shared bar keeps the format-code element background'
);

my $box = sandbox();
my ( $root, $hdir, $src ) = @{$box}{qw| root host src |};
my $host = key_file_write("$hdir/host.key");
my %base = ( root => $root, host_dir => $hdir );
clock_real();
my $disk = disk_init(
    %base,
    parent => test_signer(),
    name   => 'console-test',
    intent => 'terminal and plain output'
);
my %run = ( %base, disk => $disk, host => $host );
disk_attach(%run);
make_dirs("$src/tree");
write_file( "$src/tree/file-$ARG", "content $ARG\n" ) for 0 .. 2;
assimilate( %run, paths => ["$src/tree"], tree => 'console-tree' );
my $n7fs = "$FindBin::RealBin/../n7fs";

sub plain_run {
    my @extra = @ARG;
    my $err   = gensym;
    my $pid   = open3(
        undef, my $out,     $err,  $^X, $n7fs, '-root',
        $root, '-host-dir', $hdir, @extra
    );
    my $stdout = do { local $RS; <$out> // '' };
    my $stderr = do { local $RS; <$err> // '' };
    waitpid $pid, 0;
    return ( $CHILD_ERROR >> 8, $stdout, $stderr );
}

my ( $rc, $out, $err ) = plain_run( qw| restore |, $disk, qw| console-tree |,
    "$box->{'base'}/plain", qw| -dry-run | );
ok( $rc == 0 && $out =~ m|would restore 3 files|,
    'non-tty restore completes in the temporary store'
);
ok( $out !~ m|\e\[| && $err !~ m|\e\[| && $err !~ m|\r|,
    'non-tty output has neither colours nor an animated bar'
);

my $has_pty = eval { require IO::Pty; 1 };

sub pty_run {
    my @extra = @ARG;
    my $pty   = IO::Pty->new;
    my $pid   = fork // die "fork : $OS_ERROR";
    if ( not $pid ) {
        my $slave = $pty->slave;
        $pty->make_slave_controlling_terminal;
        close $pty;
        open( STDIN,  '<&', $slave ) or POSIX::_exit(1);
        open( STDOUT, '>&', $slave ) or POSIX::_exit(1);
        open( STDERR, '>&', $slave ) or POSIX::_exit(1);
        { exec $^X, $n7fs, '-root', $root, '-host-dir', $hdir, @extra }
        POSIX::_exit(1);
    }
    $pty->close_slave;
    my $output = '';
    while (1) {
        my $rin = '';
        vec( $rin, fileno($pty), 1 ) = 1;
        select( my $rout = $rin, undef, undef, 5 );
        my $got = sysread( $pty, my $buf, 4096 );
        last if not $got;
        $output .= $buf;
    }
    waitpid $pid, 0;
    close $pty;
    return ( $CHILD_ERROR >> 8, $output );
}

sub passphrase_case {
    my ( $tty, $expected ) = @ARG;
    my $flushes = 0;
    my $pass;
    {
        local *POSIX::tcflush          = sub { $flushes++; return 1 };
        local *Term::ReadKey::ReadMode = sub {return};
        local *STDERR;
        open( STDERR, '>', \my $prompt ) or die "scalar stderr : $OS_ERROR";
        if ($tty) {
            my $pty   = IO::Pty->new;
            my $slave = $pty->slave;
            local *STDIN;
            open( STDIN, '<&', $slave ) or die "pty stdin : $OS_ERROR";
            syswrite( $pty, "$expected\n" );
            $pass = root_passphrase();
            close $pty;
        } else {
            pipe( my $reader, my $writer ) or die "pipe : $OS_ERROR";
            print {$writer} "$expected\n";
            close $writer;
            local *STDIN;
            open( STDIN, '<&', $reader ) or die "pipe stdin : $OS_ERROR";
            $pass = root_passphrase();
        }
    }
    return ( $pass, $flushes );
}

my ( $pass, $flushes ) = passphrase_case( FALSE, 'plain phrase' );
ok( $pass eq 'plain phrase' && $flushes == 0,
    'passphrase input is not flushed when stdin is not a tty' );

SKIP: {
    if ( not $has_pty ) {
        say '  skipped : IO::Pty not installed [ tty and tty flush tests ]';
        last SKIP;
    }
    my ( $tty_rc, $tty_out )
        = pty_run( qw| restore |, $disk, qw| console-tree |,
        "$box->{'base'}/tty", qw| -dry-run | );
    ok( $tty_rc == 0
            && $tty_out =~ m|100\.00%|
            && $tty_out =~ m|eta|
            && $tty_out =~ m|\e\[|,
        'pty restore shows a coloured bar with percentage and eta'
    );
    my ( $nc_rc, $nc_out ) = pty_run(
        qw| -nc restore |,
        $disk,               qw| console-tree |,
        "$box->{'base'}/nc", qw| -dry-run |
    );
    ok( $nc_rc == 0 && $nc_out =~ m|100\.00%| && $nc_out !~ m|\e\[|,
        '-nc keeps the pty bar but removes every escape sequence'
    );
    my ( $long_rc, $long_out ) = pty_run(
        qw| -no-color restore |,
        $disk,                     qw| console-tree |,
        "$box->{'base'}/no-color", qw| -dry-run |
    );
    ok( $long_rc == 0 && $long_out !~ m|\e\[|,
        '-no-color is the long colour-disabling option'
    );
    my ( $tty_pass, $tty_flushes ) = passphrase_case( TRUE, 'tty phrase' );
    ok( $tty_pass eq 'tty phrase' && $tty_flushes == 1,
        'passphrase input is flushed exactly once on a tty'
    );
}

done();

#,,,,,,,.,,,.,...,.,.,..,,..,,,..,,,.,,..,,,.,..,,...,...,.,,,...,,,.,...,.,,,
#7LZ7IHHIBSHKINBDQZATFIENV2AJAOUX5HGTOWIP76SRQ7BD77HJCF2SFPWAJQ3NKKDKDDBIVYLII
#\\\|QJWGAHWUPYAJOGET2CZ2HYRF7JUJXS2IGO7ME6DDXGTPWQ2M3GG \ / AMOS7 \ YOURUM ::
#\[7]I3KRR35O5WFNM2CKFRYZIM6FIXPEZJHLPKZYJNKF4TJNMOTZWECI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
