#!/usr/bin/env perl
use v5.32.0;
use utf8;
use strict;
use English;
use warnings;

## bin/p7-host-build against test roots [ env P7_HOST_BUILD_ROOT ].
##
## part 1 [ no root ] : a stub world. lsblk, sgdisk, blkid, lvm, cryptsetup,
## mount, debootstrap, chroot .. are one stateful fake binary, and PATH holds
## ONLY its directory -- no real disk tool can run. the fake keeps its disks,
## tables, file systems, lvm and mounts in plain state files and logs every
## call. the assertions read that state, the call log and the tree on disk ;
## the printed text only for the refusal reasons.
##
## part 2 [ root only ] : the whole chain on loop devices backed by files in a
## temp dir, real sgdisk \ lvm \ mkfs \ mount. debootstrap and chroot stay
## fakes unless P7_HOST_BUILD_SLOW_TEST=1 [ then real, network needed ].
## nothing in the temp dir is removed while anything is still mounted there.

use File::Spec;
use Cwd        qw| abs_path |;
use FindBin    qw| $RealBin |;
use File::Temp qw| tempdir |;
use File::Path qw| make_path remove_tree |;
use File::Find qw| find |;
use POSIX      ();

use constant TRUE  => 5;
use constant FALSE => 0;

$OUTPUT_AUTOFLUSH = 1;

my $repo = abs_path(
    File::Spec->catdir( $RealBin, File::Spec->updir, File::Spec->updir ) );
my $tool     = "$repo/bin/p7-host-build";
my $template = "$repo/cfg/host-build/layout.template";

my ( $pass_count, $fail_count ) = ( 0, 0 );

sub check {
    my ( $label, $cond ) = @ARG;
    if ($cond) {
        $pass_count++;
        say "ok   : $label";
    } else {
        $fail_count++;
        say "FAIL : $label";
    }
    return $cond;
}

sub slurp {
    my ($path) = @ARG;
    open( my $fh, '<:raw', $path ) or return undef;
    local $INPUT_RECORD_SEPARATOR = undef;
    my $c = <$fh>;
    close($fh);
    return $c // '';
}

sub spew {
    my ( $path, $content ) = @ARG;
    my ( undef, $dir )     = File::Spec->splitpath($path);
    make_path($dir) if length $dir and not -d $dir;
    open( my $fh, '>:raw', $path ) or die "cannot write $path : $OS_ERROR";
    print {$fh} $content;
    close($fh);
    return TRUE;
}

## the tool with a given env, stdin from /dev/null ; [ exit, output ] ##
sub run_tool {
    my ( $env, @args ) = @ARG;
    my $pid = open( my $pipe, '-|' ) // die "fork : $OS_ERROR";
    if ( $pid == 0 ) {
        %ENV = ( %ENV, %{$env} );
        open( STDERR, '>&', \*STDOUT );
        open( STDIN,  '<',  File::Spec->devnull );
        CORE::exec {$EXECUTABLE_NAME} $EXECUTABLE_NAME, $tool, @args;
        CORE::exit 127;
    }
    my $out = do { local $INPUT_RECORD_SEPARATOR = undef; <$pipe> }
        // '';
    close($pipe);
    return ( $CHILD_ERROR >> 8, $out );
}

## the tool with the first user's password on fd 3 [ a pipe ] ##
sub run_tool_pw {
    my ( $env, $pw, @args ) = @ARG;
    my $pid = open( my $pipe, '-|' ) // die "fork : $OS_ERROR";
    if ( $pid == 0 ) {
        %ENV = ( %ENV, %{$env} );
        open( STDERR, '>&', \*STDOUT );
        open( STDIN,  '<',  File::Spec->devnull );
        $SYSTEM_FD_MAX = 255;    ## fd 3 stays open across exec ##
        pipe( my $r, my $wr ) or CORE::exit 126;
        print {$wr} "$pw\n";
        close($wr);
        POSIX::dup2( fileno($r), 3 ) // CORE::exit 126;
        CORE::exec {$EXECUTABLE_NAME} $EXECUTABLE_NAME, $tool, @args;
        CORE::exit 127;
    }
    my $out = do { local $INPUT_RECORD_SEPARATOR = undef; <$pipe> }
        // '';
    close($pipe);
    return ( $CHILD_ERROR >> 8, $out );
}

## every file below a dir with its content [ the 'nothing changed' view ] ##
sub tree_snapshot {
    my ($dir) = @ARG;
    my %snap;
    return \%snap if not -d $dir;
    find(
        {   qw| no_chdir | => 1,
            qw| wanted |   => sub {
                if ( -l $File::Find::name ) {
                    $snap{$File::Find::name}
                        = 'link:' . readlink($File::Find::name);
                    return;
                }
                return if not -f $File::Find::name;
                $snap{$File::Find::name} = slurp($File::Find::name);
            }
        },
        $dir
    );
    return \%snap;
}

sub count_of {
    my ( $re, $text ) = @ARG;
    my $n = () = $text =~ m|$re|g;
    return $n;
}

sub same_snapshot {
    my ( $x, $y ) = @ARG;
    return FALSE
        if join( "\0", sort keys %{$x} ) ne join( "\0", sort keys %{$y} );
    foreach my $k ( keys %{$x} ) {
        return FALSE if $x->{$k} ne $y->{$k};
    }
    return TRUE;
}

##[ the fake ]################################################################

my $FAKE = <<'FAKE_EOF';
use v5.32.0;
use strict;
use warnings;
use English;
use File::Basename qw| basename |;
use File::Path     qw| make_path |;

my $S    = $ENV{'FAKE_STATE'} // die "no FAKE_STATE\n";
my $name = basename($0);

sub rd { open( my $f, '<', "$S/$_[0]" ) or return (); my @l = grep {length} map { chomp; $_ } <$f>; close $f; return @l }
sub wr { open( my $f, '>', "$S/$_[0]" ) or die; print {$f} map {"$_\n"} @_[ 1 .. $#_ ]; close $f }
sub ap { open( my $f, '>>', "$S/$_[0]" ) or die; print {$f} "$_[1]\n"; close $f }
sub touch { my $p = shift; my ($d) = $p =~ m|\A(.*)/|; make_path($d) if not -d $d; open( my $f, '>>', $p ) or die "$p : $!"; print {$f} @_; close $f }

ap( 'calls', join ' ', $name, @ARGV );

## FAKE_FAIL=<name>[:tree] : that probe gives no answer ##
if ( my $fail = $ENV{'FAKE_FAIL'} ) {
    my ( $fname, $how ) = split m|:|, $fail;
    exit 1 if $fname eq $name and ( not $how or not grep { $_ eq '-d' } @ARGV );
}

## a mounted device's content lives in store/<device> while unmounted ##
sub store_of { ( my $e = $_[0] ) =~ s|/|_|g; "$S/store/$e" }
sub move_all {
    my ( $from, $to ) = @_;
    return if not -d $from;
    make_path($to);
    opendir( my $dh, $from ) or die;
    foreach my $e ( grep { $_ ne '.' and $_ ne '..' } readdir $dh ) { rename( "$from/$e", "$to/$e" ) or die "move $e : $!" }
    closedir $dh;
}

my %disk = map { my @f = split m/\|/; ( $f[0] => { path => $f[0], serial => $f[1], model => $f[2], size => $f[3], ro => $f[4] } ) } rd('disks');
sub sep  { $_[0] =~ m|\d\z| ? 'p' : '' }
sub dbase { ( my $b = $_[0] ) =~ s|.*/||; $b }
sub table { my $d = shift; map { [ split ' ', $_, 5 ] } rd( 'table.' . dbase($d) ) }
sub parts { my $d = shift; map { { num => $_->[0], start => $_->[1], end => $_->[2], code => $_->[3], name => $_->[4] // '', path => $d . sep($d) . $_->[0] } } table($d) }
sub fs    { my %f = map { my @x = split ' '; ( $x[0] => { type => $x[1], uuid => $x[2] } ) } rd('fs'); %f }
sub set_fs { my ( $dev, $type ) = @_; my %f = fs(); my $n = scalar( rd('uuid') ) + 1; ap( 'uuid', $n ); if ( defined $type ) { $f{$dev} = { type => $type, uuid => sprintf( '0000%04d-fake', $n ) } } else { delete $f{$dev} } wr( 'fs', map {"$_ $f{$_}{type} $f{$_}{uuid}"} sort keys %f ) }
sub pvs   { map { my @x = split ' '; ( $x[0] => $x[1] // '' ) } rd('pv') }
sub lvs   { map { [ split ' ' ] } rd('lv') }    ## vg name size active ##
sub dm    { my ( $vg, $lv ) = @_; s/-/--/g for $vg, $lv; "$vg-$lv" }
sub mounts { map { [ split ' ', $_, 2 ] } rd('mounts') }
sub mp_of { my $dev = shift; foreach my $m ( mounts() ) { return $m->[0] if $m->[1] eq $dev } return '' }
sub opened { map { [ split ' ' ] } rd('open') }    ## mapper dev ##
sub size_of {
    my $dev = shift;
    return $disk{$dev}{size} if $disk{$dev};
    foreach my $d ( keys %disk ) { foreach my $p ( parts($d) ) { return ( $p->{end} - $p->{start} + 1 ) * 512 if $p->{path} eq $dev } }
    foreach my $o ( opened() ) { return size_of( $o->[1] ) - 16 * 1024**2 if "/dev/mapper/$o->[0]" eq $dev }
    return 0;
}
sub row { my %r = @_; print join( ' ', map {qq|$_="$r{$_}"|} @{ $r{_cols} } ), "\n" }

if ( $name eq 'lsblk' ) {
    my @a = @ARGV;
    my ($cols) = map { $a[ $_ + 1 ] } grep { $a[$_] eq '-o' } 0 .. $#a;
    my @cols = split m|,|, $cols;
    my $single = grep { $_ eq '-d' } @a;
    my ($target) = grep {m|\A/dev/|} @a;
    my %fs = fs();
    my $emit = sub { my %r = @_; $r{_cols} = \@cols; $r{$_} //= '' for @cols; row(%r) };
    foreach my $d ( sort keys %disk ) {
        next if defined $target and $target ne $d;
        my $D = $disk{$d};
        $emit->( NAME => dbase($d), PATH => $d, SERIAL => $D->{serial}, MODEL => $D->{model}, SIZE => $D->{size}, RO => $D->{ro}, TYPE => 'loop', FSTYPE => '', MOUNTPOINT => mp_of($d) );
        next if $single;
        my %pv = pvs();
        foreach my $p ( parts($d) ) {
            my $t = $fs{ $p->{path} }{type} // '';
            $emit->( NAME => dbase( $p->{path} ), PATH => $p->{path}, TYPE => 'part', FSTYPE => $t, MOUNTPOINT => mp_of( $p->{path} ), SIZE => size_of( $p->{path} ) );
            my @under = ( $p->{path} );
            foreach my $o ( opened() ) {
                next if $o->[1] ne $p->{path};
                my $mp = "/dev/mapper/$o->[0]";
                $emit->( NAME => $o->[0], PATH => $mp, TYPE => 'crypt', FSTYPE => $fs{$mp}{type} // '', MOUNTPOINT => mp_of($mp) );
                push @under, $mp;
            }
            foreach my $u (@under) {
                my $vg = $pv{$u} // next;
                foreach my $lv ( lvs() ) {
                    next if $lv->[0] ne $vg or not $lv->[3];
                    my $path = '/dev/mapper/' . dm( $lv->[0], $lv->[1] );
                    $emit->( NAME => dm( $lv->[0], $lv->[1] ), PATH => $path, TYPE => 'lvm', FSTYPE => $fs{$path}{type} // '', MOUNTPOINT => mp_of($path), SIZE => $lv->[2] );
                }
            }
        }
    }
    exit 0;
}
if ( $name eq 'blockdev' ) {
    my ( $op, $dev ) = @ARGV;
    if ( $op eq '--getro' ) { print( ( $disk{$dev}{ro} // 0 ), "\n" ); }
    exit 0;
}
if ( $name eq 'sgdisk' ) {
    my $dev = $ARGV[-1];
    exit 2 if not $disk{$dev};
    if ( $ARGV[0] eq '-p' ) {
        my $sectors = $disk{$dev}{size} / 512;
        print "Disk $dev: $sectors sectors\nSector size (logical/physical): 512/512 bytes\n";
        print "Number  Start (sector)    End (sector)  Size       Code  Name\n";
        printf "   %d    %d    %d   1.0 MiB   %s  %s\n", @{$_}{qw| num start end code name |} for parts($dev);
        exit 0;
    }
    if ( $ARGV[0] eq '--zap-all' ) { wr( 'table.' . dbase($dev) ); exit 0 }
    my %p;
    my @a = @ARGV[ 0 .. $#ARGV - 1 ];
    while (@a) {
        my ( $o, $v ) = splice @a, 0, 2;
        my ($n) = $v =~ m|\A(\d+):|;
        ( my $rest = $v ) =~ s|\A\d+:||;
        $p{$n}{ { '-n' => 'n', '-t' => 't', '-c' => 'c' }->{$o} } = $rest;
    }
    my @rows = map { join ' ', @$_ } table($dev);
    my $next = 2048;
    my $last = $disk{$dev}{size} / 512 - 34;
    foreach my $n ( sort { $a <=> $b } keys %p ) {
        my ( undef, $end ) = split m|:|, $p{$n}{n};
        my $e;
        if ( $end eq '0' ) { $e = $last }
        else { my ( $num, $u ) = $end =~ m|\+(\d+)([KMGT])|; $e = $next + $num * { K => 2, M => 2048, G => 2048 * 1024, T => 2048 * 1024**2 }->{$u} - 1 }
        exit 4 if $e > $last;
        push @rows, "$n $next $e $p{$n}{t} $p{$n}{c}";
        $next = ( int( $e / 2048 ) + 1 ) * 2048;
    }
    wr( 'table.' . dbase($dev), @rows );
    exit 0;
}
if ( $name eq 'wipefs' ) {
    my $dev = $ARGV[-1];
    set_fs( $dev, undef );
    my %pv = pvs(); delete $pv{$dev}; wr( 'pv', map {"$_ $pv{$_}"} sort keys %pv );
    wr( 'luks', grep { $_ ne $dev } rd('luks') );
    exit 0;
}
if ( $name eq 'blkid' ) {
    my ($s) = map { $ARGV[ $_ + 1 ] } grep { $ARGV[$_] eq '-s' } 0 .. $#ARGV;
    my $dev = $ARGV[-1];
    my %fs = fs();
    my %pv = pvs();
    my %luks = map { $_ => 1 } rd('luks');
    my $type = $fs{$dev}{type} // ( exists $pv{$dev} ? 'LVM2_member' : $luks{$dev} ? 'crypto_LUKS' : undef );
    exit 2 if not defined $type;
    print $s eq 'TYPE' ? "$type\n" : ( $fs{$dev}{uuid} // "luks-uuid-" . length($dev) ) . "\n";
    exit 0;
}
if ( $name =~ m|\Amkfs\.(\w+)\z| or $name eq 'mkswap' ) {
    my $type = $name eq 'mkswap' ? 'swap' : $1;
    set_fs( $ARGV[-1], $type );
    exit 0;
}
if ( $name eq 'cryptsetup' ) {
    my $op = $ARGV[0];
    my %luks = map { $_ => 1 } rd('luks');
    if ( $op eq 'isLuks' ) { exit( $luks{ $ARGV[1] } ? 0 : 1 ) }
    if ( $op eq 'status' ) { exit( ( grep { $_->[0] eq $ARGV[1] } opened() ) ? 0 : 4 ) }
    if ( $op eq 'luksFormat' ) {
        my $pass = do { local $/; <STDIN> } // '';
        exit 2 if not length $pass;
        ap( 'secrets', length $pass );
        ap( 'luks', $ARGV[-1] );
        exit 0;
    }
    if ( $op eq 'open' ) {
        my $pass = do { local $/; <STDIN> } // '';
        exit 2 if not length $pass;
        ap( 'open', "$ARGV[-1] $ARGV[-2]" );
        exit 0;
    }
    if ( $op eq 'close' ) { wr( 'open', map {"@$_"} grep { $_->[0] ne $ARGV[1] } opened() ); exit 0 }
    exit 1;
}
if ( $name eq 'pvs' ) { my %pv = pvs(); print "  $_:$pv{$_}\n" for sort keys %pv; exit 0 }
if ( $name eq 'pvcreate' ) { my %pv = pvs(); $pv{ $ARGV[-1] } = ''; wr( 'pv', map {"$_ $pv{$_}"} sort keys %pv ); exit 0 }
if ( $name eq 'vgcreate' ) { my %pv = pvs(); $pv{ $ARGV[-1] } = $ARGV[-2]; wr( 'pv', map {"$_ $pv{$_}"} sort keys %pv ); exit 0 }
if ( $name eq 'vgchange' ) {
    my $on = ( grep { $_ eq '-ay' } @ARGV ) ? 1 : 0;
    wr( 'lv', map { $_->[0] eq $ARGV[-1] ? "$_->[0] $_->[1] $_->[2] $on" : "@$_" } lvs() );
    exit 0;
}
if ( $name eq 'lvcreate' ) {
    my %a;
    my @a = @ARGV;
    while (@a) { my $o = shift @a; $a{$o} = shift @a if $o =~ m/\A-[nLlW]\z/ }
    my $vg = $ARGV[-1];
    my %pv = pvs();
    my ($pvdev) = grep { $pv{$_} eq $vg } keys %pv;
    my $used = 0; $used += $_->[2] for grep { $_->[0] eq $vg } lvs();
    my $size = defined $a{'-L'} ? ( $a{'-L'} =~ s/b\z//r ) : size_of($pvdev) - $used - 4 * 1024**2;
    ap( 'lv', "$vg $a{'-n'} $size 1" );
    exit 0;
}
if ( $name eq 'lvs' ) { print "  $_->[1]:$_->[2]\n" for grep { $_->[0] eq $ARGV[-1] } lvs(); exit 0 }
if ( $name eq 'findmnt' ) {
    if ( $ARGV[-1] =~ m|\A/| ) { my ($m) = grep { $_->[0] eq $ARGV[-1] } mounts(); exit 1 if not $m; print "$m->[0]\n"; exit 0 }
    print "$_->[0] $_->[1]\n" for mounts();
    exit 0;
}
if ( $name eq 'mount' ) {
    my $dir = $ARGV[-1];
    exit 32 if not -d $dir;
    my $src = $ARGV[0] eq '--bind' ? $ARGV[1] : $ARGV[0] eq '-t' ? $ARGV[2] : $ARGV[0];
    ap( 'mounts', "$dir $src" );
    move_all( store_of($src), $dir ) if $src =~ m{\A/dev/(loop|mapper)};
    exit 0;
}
if ( $name eq 'umount' ) {
    my $dir = $ARGV[-1];
    my @m = mounts();
    my ($m) = grep { $_->[0] eq $dir } @m;
    exit 32 if not $m;
    wr( 'mounts', map {"@$_"} grep { $_->[0] ne $dir } @m );
    move_all( $dir, store_of( $m->[1] ) ) if $m->[1] =~ m{\A/dev/(loop|mapper)};
    exit 0;
}
if ( $name eq 'debootstrap' ) {
    my ( undef, $suite, $target ) = @ARGV;
    print "I: Retrieving Release\nI: Retrieving Packages\nI: Validating Packages\nI: Retrieving libc6\nI: Extracting libc6\nI: Installing core packages\nI: Unpacking required packages\nI: Configuring required packages\nI: Base system installed successfully.\n";
    touch( "$target/etc/debian_version", "13.0\n" );
    touch( "$target/var/lib/dpkg/status", "" );
    touch( "$target/etc/passwd", "root:x:0:0:root:/root:/bin/bash\n" );
    touch( "$target/etc/group", "root:x:0:\nsudo:x:27:\n" );
    make_path("$target/usr/bin", "$target/root");
    touch( "$target/etc/resolv.conf", $ENV{'P7_HOST_BUILD_TEST_HOST_RESOLV'} ) if defined $ENV{'P7_HOST_BUILD_TEST_HOST_RESOLV'};
    touch( "$target/var/lib/dpkg/info/isc-dhcp-client.list", '' ) if $ENV{'FAKE_ISC'};
    exit 0;
}
if ( $name eq 'chroot' ) {
    my $t = shift @ARGV;
    shift @ARGV while @ARGV and ( $ARGV[0] =~ m|=| or $ARGV[0] eq '/usr/bin/env' or $ARGV[0] eq '-i' );
    my $cmd = shift @ARGV // exit 1;
    my $real = do { open( my $f, '<', '/proc/self/mounts' ); local $/; <$f> } // '';
    exit 3 if not grep { $_->[0] eq "$t/dev" } mounts() and index( $real, " $t/dev " ) < 0;
    if ( $cmd eq 'apt-get' ) { touch( "$t/boot/vmlinuz-6.12-fake", '' ) if grep {m|^linux-image|} @ARGV; my $purge = grep { $_ eq 'purge' } @ARGV; foreach my $p ( grep { !m/^-|^(install|purge|update)$/ } @ARGV ) { $purge ? unlink("$t/var/lib/dpkg/info/$p.list") : touch( "$t/var/lib/dpkg/info/$p.list", '' ) } exit 0 }
    if ( $cmd eq 'grub-install' ) {
        exit 5 if grep {m|nvram|} @ARGV and not grep { $_ eq '--no-nvram' } @ARGV;
        touch( "$t/boot/efi/EFI/BOOT/BOOTX64.EFI", 'efi' ) if grep {m|x86_64-efi|} @ARGV;
        exit 0;
    }
    if ( $cmd eq 'update-grub' ) { touch( "$t/boot/grub/grub.cfg", 'menu' ); exit 0 }
    if ( $cmd eq 'useradd' ) { touch( "$t/etc/passwd", "$ARGV[-1]:x:1000:1000::/home/$ARGV[-1]:/bin/bash\n" ); exit 0 }
    if ( $cmd eq 'chpasswd' ) { my $in = do { local $/; <STDIN> }; ap( 'secrets', length $in ); open( my $f, '>>', "$S/chpasswd.in" ) or die; print {$f} $in; close $f; exit 0 }
    if ( $cmd eq 'locale-gen' ) { exit 0 }
    if ( $cmd eq '/usr/bin/perl' ) {
        exit 6 if not -f "$t$ARGV[0]" or not -f "$t/root/p7-host-build/AMOS7/TERM/Frame.pm";
        make_path("$t/usr/local/protocol-7/.git");
        exit 0;
    }
    exit 9;
}
exit 0 if $name =~ m/\A(partprobe|udevadm|sync|swapon)\z/;
die "fake : $name not handled\n";
FAKE_EOF

my @FAKE_NAMES = qw|
    lsblk blockdev sgdisk wipefs blkid findmnt mount umount partprobe udevadm
    pvs pvcreate vgcreate lvcreate vgchange lvs cryptsetup mkfs.vfat mkfs.ext4
    mkfs.xfs mkswap debootstrap chroot sync swapon
    |;

## the commands that write : none may appear in a dry run or a second run ##
my $WRITE_RE
    = qr{^(?:sgdisk (?!-p)|wipefs|mkfs|mkswap|pvcreate|vgcreate|lvcreate|debootstrap|chroot|cryptsetup luksFormat)};

my $LAYOUT = <<'EOL';
## a test host ##
host.name      = testhost
disk.serial    = TESTSERIAL01
part.efi       = 64M vfat /boot/efi
part.boot      = 128M ext4 /boot
part.main      = rest lvm test-vg
lv.root        = 256M ext4 /
lv.rescue      = 32M ext4     [ second boot system ]
lv.data        = rest xfs /data
system.suite   : trixie
system.profile = minimal
user.name      = builder
EOL

my $GiB = 1024**3;

## a fresh stub world : fake dir, state, test root, layout ##
sub stub_world {
    my (%o) = @ARG;
    my $base = tempdir(
        qw| p7-host-build-test-XXXXXX |,
        qw| TMPDIR |  => 1,
        qw| CLEANUP | => 1
    );
    my %w = (
        qw| base |   => $base,
        qw| fake |   => "$base/fake",
        qw| state |  => "$base/state",
        qw| root |   => "$base/root",
        qw| layout | => "$base/test.layout",
    );
    make_path( @w{qw| fake state root |} );
    spew( "$w{'fake'}/fake", "#!$EXECUTABLE_NAME\n$FAKE" );
    chmod 0755, "$w{'fake'}/fake";
    symlink( "$w{'fake'}/fake", "$w{'fake'}/$ARG" ) foreach @FAKE_NAMES;
    spew(
        "$w{'state'}/disks",
        join '',
        map {"$ARG\n"}
            @{ $o{'disks'} // ["/dev/loop90|TESTSERIAL01|FAKE DISK|$GiB|0"] }
    );
    spew( $w{'layout'}, $o{'layout'} // $LAYOUT );

    foreach my $f ( keys %{ $o{'state'} // {} } ) {
        spew( "$w{'state'}/$f", $o{'state'}{$f} );
    }
    $w{'env'} = {
        qw| PATH |                           => $w{'fake'},
        qw| FAKE_STATE |                     => $w{'state'},
        qw| P7_HOST_BUILD_ROOT |             => $w{'root'},
        qw| P7_HOST_BUILD_TEST_PASSPHRASE |  => 'not-on-argv-passphrase',
        qw| NO_COLOR |                       => '',
        qw| P7_HOST_BUILD_TEST_HOST_RESOLV | => "nameserver 192.0.2.53\n",
    };
    $w{'target'} = "$w{'root'}/mnt/p7-host-build/testhost";
    return \%w;
}

sub calls {
    my ($w) = @ARG;
    return grep {length} split m|\n|, slurp("$w->{'state'}/calls") // '';
}

sub writes {
    my ($w) = @ARG;
    return grep { $ARG =~ $WRITE_RE } calls($w);
}
sub reset_calls { my ($w) = @ARG; spew( "$w->{'state'}/calls", '' ) }

sub state_snap {
    my ($w) = @ARG;
    my $s = tree_snapshot( $w->{'state'} );
    delete $s->{"$w->{'state'}/calls"};
    return $s;
}

##[ part 1 : no root ]########################################################

say ':';
say ':: part 1 : stub world [ no root ]';
say ':';

## the template parses as it is [ its placeholder serial on a stub disk ] ##
{
    my $t = slurp($template) // '';
    check( 'template exists', length $t );
    my ($serial) = $t =~ m|^disk\.serial\s*[=:]\s*(\S+)|m;
    my $w = stub_world(
        qw| layout | => $t,
        qw| disks |  => [ "/dev/loop90|$serial|FAKE|" . ( 64 * $GiB ) . "|0" ]
    );
    my ( $exit, $out )
        = run_tool( $w->{'env'}, '-dry-run', '-layout', $w->{'layout'} );
    check( 'template : dry run exit 0', $exit == 0 ) or print $out;
    check( 'template : no write',       !writes($w) );
}

## parser refusals [ the reason names the line ] ##
{
    my @bad = (
        [ 'unknown key', "foo.bar = 1\n", qr|line 13 : unknown key| ],
        [   'rest not last',
            "lv.extra = 1G ext4 /extra\n",
            qr|'rest' only for the last|
        ],
        [ 'key twice', "system.suite = sid\n", qr|key twice| ],
        [   'crypt on vfat',
            "crypt.efi = luks\n",
            qr|crypt\.efi : not on vfat|
        ],
        [ 'bad size', "lv.x = 12Q ext4\n", qr|size not valid| ],
        [   'bad timezone',
            "system.timezone = ../etc\n",
            qr|timezone not valid|
        ],
        [   'bad net.backend',
            "net.backend = dhcp\n",
            qr|net\.backend is ifupdown|
        ],
        [   'bad mount point',
            "lv.x = 1G ext4 /a/../b\n",
            qr|mount point not valid|
        ],
        [   'system on a mounted lv',
            "system.x.lv = lv.data\n",
            qr|lv\.data is mounted at /data|
        ],
        [   'system on no lv',
            "system.x.lv = lv.nope\n",
            qr|system\.x\.lv : no lv\.nope|
        ],
        [   'system without lv',
            "system.x.suite = sid\n",
            qr|system\.x\.lv missing|
        ],
        [ 'main suite twice', "system.main.suite = sid\n", qr|key twice| ],
    );
    foreach my $b (@bad) {
        my ( $label, $extra, $re ) = @{$b};
        my $w = stub_world( qw| layout | => $LAYOUT . $extra );
        my ( $exit, $out )
            = run_tool( $w->{'env'}, '-dry-run', '-layout', $w->{'layout'} );
        check( "parser refuses : $label", $exit != 0 && $out =~ $re )
            or print $out;
    }
    my $w = stub_world(
        qw| layout | => join '',
        grep { !m|^lv\.root| } split m|^|m, $LAYOUT
    );
    my ( $exit, $out )
        = run_tool( $w->{'env'}, '-dry-run', '-layout', $w->{'layout'} );
    check( "parser refuses : no '/'",
        $exit != 0 && $out =~ m|no '/' mount point| );
}

## safety refusals ##
my @refusals = (
    [   'wrong serial',
        { qw| disks | => [ "/dev/loop90|OTHER" . "SERIAL|FAKE|$GiB|0" ] },
        [], qr|no disk with serial TESTSERIAL01|
    ],
    [   '-wipe mismatch',
        {},
        [ '-wipe', 'OTHERSERIAL' ],
        qr|-wipe OTHERSERIAL does not match|
    ],
    [   'read-only disk',
        { qw| disks | => ["/dev/loop90|TESTSERIAL01|FAKE|$GiB|1"] },
        [], qr|read-only \[ blockdev --getro = 1 \]|
    ],
    [   'mounted disk',
        {   qw| state | => {
                'table.loop90' => "1 2048 4095 8300 old\n",
                qw| mounts |   => "/srv/elsewhere /dev/loop90p1\n"
            }
        },
        [],
        qr|/dev/loop90p1 is mounted on /srv/elsewhere|
    ],
    [   'swap in use',
        {   qw| state | => {
                'table.loop90' => "1 2048 4095 8200 sw\n",
                qw| fs |       => "/dev/loop90p1 swap u1\n",
                qw| mounts |   => "[SWAP] /dev/loop90p1\n"
            }
        },
        [],
        qr|in use as swap|
    ],
    [   'foreign lvm active',
        {   qw| state | => {
                'table.loop90' => "1 2048 2000000 8E00 x\n",
                qw| pv |       => "/dev/loop90p1 other-vg\n",
                qw| lv |       => "other-vg home 1000 1\n"
            }
        },
        [],
        qr|in use by lvm \[ vg other-vg active|
    ],
    [   'not a loop in a test root',
        { qw| disks | => ["/dev/sdz|TESTSERIAL01|FAKE|$GiB|0"] },
        [], qr|not a loop device|
    ],
    [   'layout vg on another disk',
        {   qw| disks | => [
                "/dev/loop90|TESTSERIAL0" . "1|FAKE|$GiB|0",
                "/dev/loop91|OTHER|FAKE|$GiB|0"
            ],
            qw| state | => {
                'table.loop91' => "1 2048 2000000 8E00 x\n",
                qw| pv |       => "/dev/loop91p1 test-vg\n"
            }
        },
        [ '-wipe', 'TESTSERIAL01', '-yes' ],
        qr|vg test-vg exists on /dev/loop91p1|
    ],
    [   'missing -wipe',
        {}, ['-yes'],
        qr|destructive actions planned and no -wipe TESTSERIAL01|
    ],
    [   'no terminal, no -yes',
        {},
        [ '-wipe', 'TESTSERIAL01' ],
        qr|no terminal|
    ],
);
foreach my $r (@refusals) {
    my ( $label, $world, $args, $re ) = @{$r};
    my $w      = stub_world( %{$world} );
    my $before = state_snap($w);
    my ( $exit, $out )
        = run_tool( $w->{'env'}, @{$args}, '-layout', $w->{'layout'} );
    check( "refused : $label", $exit != 0 && $out =~ $re ) or print $out;
    check( "refused : $label -- nothing written",
        not writes($w) && same_snapshot( $before, state_snap($w) ) );
}

## dry run : full plan, reads only ##
{
    my $w      = stub_world();
    my $before = state_snap($w);
    my ( $exit, $out )
        = run_tool( $w->{'env'}, qw| -dry-run -wipe TESTSERIAL01 -layout |,
        $w->{'layout'} );
    check( 'dry run : exit 0', $exit == 0 ) or print $out;
    check( 'dry run : plan lists the table and every mkfs',
        $out =~ m|table \.+ create| && count_of( qr|mkfs|, $out ) == 5 );
    check( 'dry run : no write command', !writes($w) );
    check( 'dry run : no mount',         !grep {m|^mount |} calls($w) );
    check( 'dry run : state unchanged',
        same_snapshot( $before, state_snap($w) ) );
    check( 'dry run : nothing in the test root',
        !%{ tree_snapshot( $w->{'root'} ) } && !-e "$w->{'root'}/mnt" );
}

## the whole chain, then a second run ##
my $chain_world;
{
    my $w = $chain_world = stub_world();
    my ( $exit, $out )
        = run_tool( $w->{'env'}, qw| -wipe TESTSERIAL01 -yes -layout |,
        $w->{'layout'} );
    check( 'chain : exit 0', $exit == 0 ) or print $out;
    my @table = grep {length} split m|\n|,
        slurp("$w->{'state'}/table.loop90") // '';
    check(
        'chain : 3 partitions',
        @table == 3
            && $table[0] =~ m|EF00 efi$|
            && $table[2] =~ m|8E00 main$|
    );
    my $fs = slurp("$w->{'state'}/fs") // '';
    check( 'chain : 5 file systems', count_of( qr|\n|, $fs ) == 5 );
    check(
        'chain : lvs root rescue data',
        ( slurp("$w->{'state'}/lv") // '' ) =~ m|root.*\n.*rescue.*\n.*data|s
    );
    check( 'chain : all unmounted',
        !length( slurp("$w->{'state'}/mounts") // '' ) );
    check( 'chain : vg deactivated',
        ( slurp("$w->{'state'}/lv") // '' ) !~ m| 1$|m );
    my $t   = "$w->{'state'}/store/_dev_mapper_test--vg-root";
    my $efi = "$w->{'state'}/store/_dev_loop90p1";
    check( 'chain : target left empty',
        !%{ tree_snapshot( $w->{'target'} ) } );
    my $fstab = slurp("$t/etc/fstab") // '';
    check(
        'chain : fstab by uuid',
        count_of( qr|^UUID=|m, $fstab ) == 4
            && $fstab =~ m|^UUID=\S+  /  ext4|m
    );
    check( 'chain : rescue lv not in fstab',
        $fstab !~ m|rescue| && count_of( qr|^UUID=\S+  /|m, $fstab ) == 4 );
    check( 'chain : hostname',
        ( slurp("$t/etc/hostname") // '' ) eq "testhost\n" );
    check( 'chain : locale',
        ( slurp("$t/etc/default/locale") // '' ) eq "LANG=C.UTF-8\n" );
    check(
        'chain : timezone Etc/UTC [ file and link ]',
        ( slurp("$t/etc/timezone") // '' ) eq "Etc/UTC\n"
            && ( readlink("$t/etc/localtime") // '' ) eq
            '/usr/share/zoneinfo/Etc/UTC'
    );
    check(
        'chain : ifupdown default, dhcp on en*, lo, no wlan, no networkd',
        ( slurp("$t/etc/network/interfaces") // '' )
            =~ m|^auto lo\niface lo inet loopback\n.*^allow-hotplug /en\*/=p7-wired\niface p7-wired inet dhcp$|ms
            && ( slurp("$t/etc/network/interfaces") // '' ) !~ m|wlan|
            && !-e "$t/etc/systemd/network"
            && !-e "$t/etc/systemd/system/multi-user.target.wants"
    ) or print slurp("$t/etc/network/interfaces") // '';
    check(
        'chain : ifupdown + dhcpcd-base installed, no isc-dhcp-client',
        -e "$t/var/lib/dpkg/info/ifupdown.list"
            && -e "$t/var/lib/dpkg/info/dhcpcd-base.list"
            && ( grep {m|apt-get -q -y install ifupdown dhcpcd-base|}
            calls($w) )
            && !grep {m|isc-dhcp-client|} calls($w)
    );
    check(
        "chain : the host's resolv.conf removed, none written",
        !-e "$t/etc/resolv.conf" && !-l "$t/etc/resolv.conf"
    );
    check(
        'chain : no password -> locked, in the report',
        !length( slurp("$w->{'state'}/secrets") // '' )
            && $out =~ m|report.*user builder \.+ created.*locked|s
    ) or print $out;
    check(
        'chain : user created [ locked in a test root ]',
        ( slurp("$t/etc/passwd") // '' ) =~ m|^builder:|m
    );
    check(
        'chain : grub-efi removable, no nvram',
        -f "$efi/EFI/BOOT/BOOTX64.EFI"
            && grep {m|grub-install .*--removable --no-nvram|} calls($w)
    );
    check(
        'chain : p7-install ran in the chroot',
        -d "$t/usr/local/protocol-7/.git"
            && grep {m|chroot .*p7-install -no-hw -profile minimal|} calls($w)
    );
    check( 'chain : report section',
        $out =~ m|report| && $out =~ m|host build \.+ ok| );

    my $before_state = state_snap($w);
    my $before_tree  = tree_snapshot( $w->{'root'} );
    reset_calls($w);
    ( $exit, $out ) = run_tool( $w->{'env'}, '-layout', $w->{'layout'} );
    check( 'second run : exit 0 without -wipe \ -yes', $exit == 0 )
        or print $out;
    check( 'second run : no write command', !writes($w) )
        or print join "\n", writes($w), '';
    check( 'second run : no confirmation', $out !~ m|destructive|i );
    check( 'second run : state unchanged',
        same_snapshot( $before_state, state_snap($w) ) );
    check( 'second run : tree unchanged',
        same_snapshot( $before_tree, tree_snapshot( $w->{'root'} ) ) );
    check( 'second run : report says none', $out =~ m|changes \.+ none| );
}

## several systems on one disk : one grub menu in the main system ##
my $MULTI_LAYOUT
    = $LAYOUT =~ s{^(lv\.data .*)$}{lv.exp         = 32M xfs\n$1}mr . <<'EOL';
system.rescue.lv       = lv.rescue
system.rescue.suite    = trixie
system.exp.lv          = lv.exp
system.exp.suite       = unstable
system.exp.profile     = base
system.exp.hostname    = testhost-lab
EOL

sub multi_checks {
    my ( $w, $label ) = @ARG;
    my $main = "$w->{'state'}/store/_dev_mapper_test--vg-root";
    my $menu = slurp("$main/etc/grub.d/41_p7-systems") // '';
    my %uuid = map { my @x = split ' '; ( $x[0] => $x[2] ) }
        grep {length} split m|\n|, slurp("$w->{'state'}/fs") // '';
    check(
        "$label : menu lists both systems by uuid",
        count_of( qr|^menuentry |m, $menu ) == 2
            && $menu =~ m|'rescue \[ trixie, testhost-rescue \]'|
            && $menu =~ m|'exp \[ unstable, testhost-lab \]'|
            && index( $menu,
            "--set=root $uuid{'/dev/mapper/test--vg-rescue'}" ) >= 0
            && index( $menu, "--set=root $uuid{'/dev/mapper/test--vg-exp'}" )
            >= 0
            && $menu =~ m|insmod xfs|
            && $menu =~ m|insmod ext2|
    ) or print $menu;
    check(
        "$label : menu file executable",
        -x "$main/etc/grub.d/41_p7-systems"
    );
    check(
        "$label : os-prober off",
        ( slurp("$main/etc/default/grub.d/p7-host-build.cfg") // '' )
            =~ m|^GRUB_DISABLE_OS_PROBER=true$|m
    );
    foreach my $s (
        [qw| rescue testhost-rescue minimal |],
        [qw| exp testhost-lab base |]
    ) {
        my $t     = "$w->{'state'}/store/_dev_mapper_test--vg-$s->[0]";
        my $fstab = slurp("$t/etc/fstab") // '';
        check(
            "$label : $s->[0] has its own tree, host name, root fstab",
            -f "$t/etc/debian_version"
                && ( slurp("$t/etc/hostname") // '' ) eq "$s->[1]\n"
                && count_of( qr|^UUID=|m, $fstab ) == 1
                && $fstab =~ m|^UUID=\S+  /  |m
        ) or print $fstab;
        check(
            "$label : $s->[0] kernel, no grub of its own",
            -f "$t/boot/vmlinuz-6.12-fake" && !-e "$t/boot/efi"
        );
        check( "$label : $s->[0] p7-install, profile $s->[2]",
            -d "$t/usr/local/protocol-7/.git" );
    }
}
{
    my $w = stub_world( qw| layout | => $MULTI_LAYOUT );
    my ( $exit, $out )
        = run_tool( $w->{'env'}, qw| -dry-run -wipe TESTSERIAL01 -layout |,
        $w->{'layout'} );
    check( 'multi dry run : exit 0', $exit == 0 ) or print $out;
    check(
        'multi dry run : plan lists both systems and the menu',
        $out        =~ m|system rescue|
            && $out =~ m|system exp|
            && $out =~ m|menu entries \.+ if differing \[ 2 systems|
    ) or print $out;
    check( 'multi dry run : no write command', !writes($w) );
    check(
        'multi dry run : nothing in the test root',
        !%{ tree_snapshot( $w->{'root'} ) }
    );

    ( $exit, $out )
        = run_tool( $w->{'env'}, qw| -wipe TESTSERIAL01 -yes -layout |,
        $w->{'layout'} );
    check( 'multi chain : exit 0', $exit == 0 ) or print $out;
    my @boot = grep {m|^debootstrap|} calls($w);
    check(
        'multi chain : three debootstraps, suites per system',
        @boot == 3
            && ( grep {m| trixie \S+/testhost\.rescue |} @boot )
            && ( grep {m| unstable \S+/testhost\.exp |} @boot )
    ) or print join "\n", @boot, '';
    check(
        'multi chain : p7-install profiles per system',
        ( grep {m|p7-install -no-hw -profile base|} calls($w) )
            && ( grep {m|p7-install -no-hw -profile minimal|} calls($w) )
    );
    check(
        'multi chain : one grub-install, in the main tree',
        (   grep {m|^chroot \S+/testhost /.*grub-install .*x86_64-efi|}
                calls($w)
        ) == 1
    ) or print join "\n", grep {m|grub-install|} calls($w), '';
    check( 'multi chain : all unmounted',
        !length( slurp("$w->{'state'}/mounts") // '' ) );
    multi_checks( $w, 'multi chain' );

    my $before_state = state_snap($w);
    my $before_tree  = tree_snapshot( $w->{'root'} );
    reset_calls($w);
    ( $exit, $out ) = run_tool( $w->{'env'}, '-layout', $w->{'layout'} );
    check( 'multi second run : exit 0',           $exit == 0 ) or print $out;
    check( 'multi second run : no write command', !writes($w) )
        or print join "\n", writes($w), '';
    check(
        'multi second run : state unchanged',
        same_snapshot( $before_state, state_snap($w) )
    );
    check( 'multi second run : tree unchanged',
        same_snapshot( $before_tree, tree_snapshot( $w->{'root'} ) ) );
    check( 'multi second run : report says none',
        $out =~ m|changes \.+ none| )
        or print $out;
}

## network \ timezone \ locale per system, the password from -password-fd ##
{
    my $layout = $MULTI_LAYOUT . <<'EOL';
system.timezone        = Europe/Berlin
system.locale          = de_DE.UTF-8
net.backend            = networkd
net.wlan               = wl*
system.rescue.timezone = UTC
system.rescue.net.backend = ifupdown
system.exp.net.backend = none
system.exp.locale      = C.UTF-8
EOL
    my $w = stub_world( qw| layout | => $layout );
    $w->{'env'}{'FAKE_ISC'} = 1;
    my $pw = 'fd-pass:word with spaces';
    my ( $exit, $out ) = run_tool_pw(
        $w->{'env'}, $pw,
        qw| -dry-run -password-fd 3 |,
        qw| -wipe TESTSERIAL01 -layout |,
        $w->{'layout'}
    );
    check(
        'config dry run : exit 0, plan names fd, nothing written',
        $exit == 0 && $out =~ m|password from fd 3| && !writes($w)
    ) or print $out;
    ( $exit, $out ) = run_tool_pw(
        $w->{'env'}, $pw,
        qw| -password-fd 3 -yes |,
        qw| -wipe TESTSERIAL01 -layout |,
        $w->{'layout'}
    );
    check( 'config chain : exit 0', $exit == 0 ) or print $out;
    my $st = sub {"$w->{'state'}/store/_dev_mapper_test--vg-$ARG[0]"};
    check(
        'config chain : password on chpasswd stdin, once per system',
        ( slurp("$w->{'state'}/chpasswd.in") // '' ) eq "builder:$pw\n" x 3
    );
    check(
        'config chain : password never on argv',
        !grep { index( $ARG, 'fd-pass' ) >= 0 } calls($w)
    );
    check(
        'config chain : timezone per system, main as default',
        ( slurp( $st->('root') . '/etc/timezone' ) // '' ) eq
            "Europe/Berlin\n"
            && ( slurp( $st->('rescue') . '/etc/timezone' ) // '' ) eq "UTC\n"
            && ( readlink( $st->('exp') . '/etc/localtime' ) // '' ) eq
            '/usr/share/zoneinfo/Europe/Berlin'
    );
    check(
        'config chain : locale per system, generated where needed',
        ( slurp( $st->('rescue') . '/etc/default/locale' ) // '' ) eq
            "LANG=de_DE.UTF-8\n"
            && ( slurp( $st->('exp') . '/etc/default/locale' ) // '' ) eq
            "LANG=C.UTF-8\n"
            && ( slurp( $st->('root') . '/etc/locale.gen' ) // '' )
            =~ m|^de_DE\.UTF-8 UTF-8$|m
    );
    my $wlan = $st->('root') . '/etc/systemd/network/25-p7-wlan.network';
    my $nd   = "etc/systemd/system/multi-user.target.wants/"
        . 'systemd-networkd.service';
    check(
        'config chain : networkd main [ wired, enabled, wlan stub off ]',
        (   slurp(
                $st->('root') . '/etc/systemd/network/20-p7-wired.network'
            ) // ''
            ) =~ m|^Name=en\*\n.*^DHCP=yes$|ms
            && ( readlink( $st->('root') . "/$nd" ) // '' ) =~ m|networkd|
            && !-e $wlan
            && ( slurp("$wlan.disabled") // '' ) =~ m|^Name=wl\*$|m
            && !-e $st->('root') . '/etc/network/interfaces'
            && !grep {m|resolved|} calls($w)
    );
    my $rif = slurp( $st->('rescue') . '/etc/network/interfaces' ) // '';
    check(
        'config chain : ifupdown rescue, wlan stanza commented, isc purged',
        $rif        =~ m|^allow-hotplug /en\*/=p7-wired$|m
            && $rif =~ m|^# allow-hotplug /wl\*/=p7-wlan$|m
            && $rif =~ m|^#     wpa-conf |m
            && $rif !~ m|^[^#\n]*wlan|m
            && !-e $st->('rescue')
            . '/etc/systemd/network'
            && !-e $st->('rescue')
            . '/var/lib/dpkg/info/isc-dhcp-client.list'
            && -e $st->('rescue')
            . '/var/lib/dpkg/info/dhcpcd-base.list'
    ) or print $rif;
    check(
        'config chain : none for exp [ no network files, no packages ]',
        !-e $st->('exp') . '/etc/network/interfaces'
            && !-e $st->('exp') . '/etc/systemd/network'
            && !-e $st->('exp') . "/$nd"
            && !-e $st->('exp') . '/var/lib/dpkg/info/dhcpcd-base.list'
    );
    check(
        "config chain : the host's resolv.conf removed in every system",
        3 == grep { !-e $st->($ARG) . '/etc/resolv.conf' }
            qw| root rescue exp |
    );
    my $before_state = state_snap($w);
    my $before_tree  = tree_snapshot( $w->{'root'} );
    reset_calls($w);
    ( $exit, $out ) = run_tool( $w->{'env'}, '-layout', $w->{'layout'} );
    check(
        'config second run : exit 0, no write, changes none',
        $exit == 0 && !writes($w) && $out =~ m|changes \.+ none|
    ) or print $out;
    check(
        'config second run : state unchanged',
        same_snapshot( $before_state, state_snap($w) )
    );

    ( $exit, $out )
        = run_tool( $w->{'env'}, qw| -password-fd 7 -layout |,
        $w->{'layout'} );
    check( 'password-fd not open : refused',
        $exit != 0 && $out =~ m|-password-fd 7 : not open| )
        or print $out;
}

## -nc and NO_COLOR : no escape anywhere ##
{
    my $w = stub_world();
    my ( undef, $out )
        = run_tool( $w->{'env'}, qw| -nc -dry-run -layout |, $w->{'layout'} );
    check( '-nc : no escapes', length $out && $out !~ m|\e| );
    ( undef, $out ) = run_tool(
        { %{ $w->{'env'} }, qw| NO_COLOR | => 1 },
        qw| -dry-run -layout |,
        $w->{'layout'}
    );
    check( 'NO_COLOR : no escapes', length $out && $out !~ m|\e| );
    ( undef, $out ) = run_tool( $w->{'env'}, qw| -nc -options | );
    check( '-nc -options : no escapes', $out =~ m|-wipe| && $out !~ m|\e| );
}

## a table that differs : replaced with -wipe, listed as destructive ##
{
    my $w = stub_world(
        qw| state | => {
            'table.loop90' => "1 2048 999999 8300 old\n",
            qw| fs |       => "/dev/loop90p1 ext4 u1\n"
        }
    );
    my ( $exit, $out )
        = run_tool( $w->{'env'}, qw| -dry-run -layout |, $w->{'layout'} );
    check(
        'other table : plan says replace, needs -wipe',
        $exit == 0
            && $out =~ m|table \.+ replace \[ 1 \]|
            && $out =~ m|wipe \.+ needed|
    );
    ( $exit, $out )
        = run_tool( $w->{'env'}, qw| -wipe TESTSERIAL01 -yes -layout |,
        $w->{'layout'} );
    check( 'other table : replaced',
        $exit == 0 && grep {m|^sgdisk --zap-all|} calls($w) )
        or print $out;
}

## luks : passphrase on stdin only, a second run opens and changes nothing ##
{
    my $w = stub_world( qw| layout | => $LAYOUT . "crypt.main = luks\n" );
    my ( $exit, $out )
        = run_tool( $w->{'env'}, qw| -wipe TESTSERIAL01 -yes -layout |,
        $w->{'layout'} );
    check( 'luks : chain exit 0', $exit == 0 ) or print $out;
    check(
        'luks : passphrase never on argv',
        !grep {m|not-on-argv|}
            calls($w) && length( slurp("$w->{'state'}/secrets") // '' )
    );
    check(
        'luks : pv on the mapping',
        ( slurp("$w->{'state'}/pv") // '' )
            =~ m|^/dev/mapper/testhost-main_crypt test-vg|m
    );
    check(
        'luks : crypttab by uuid',
        (   slurp(
                      "$w->{'state'}/store/_dev_mapp"
                    . "er_test--vg-root/etc/crypttab"
            ) // ''
        ) =~ m|^testhost-main_crypt  UUID=|m
    );
    check( 'luks : closed at the end',
        !length( slurp("$w->{'state'}/open") // '' ) );
    reset_calls($w);
    my $before = state_snap($w);
    ( $exit, $out ) = run_tool( $w->{'env'}, '-layout', $w->{'layout'} );
    check( 'luks : second run exit 0, no write', $exit == 0 && !writes($w) )
        or print $out;
}

## probes without an answer refuse, nothing written ##
foreach my $p (
    [ 'blockdev',   qr|blockdev --getro gave no answer| ],
    [ 'lsblk:tree', qr|lsblk /dev/loop90 gave no answer| ],
    [ 'sgdisk',     qr|sgdisk -p /dev/loop90 gave no answer| ],
    [ 'pvs',        qr|pvs gave no answer| ],
    [ 'findmnt',    qr|findmnt gave no answer| ],
) {
    my ( $fail, $re ) = @{$p};
    my $w      = stub_world();
    my $before = state_snap($w);
    my ( $exit, $out ) = run_tool(
        { %{ $w->{'env'} }, qw| FAKE_FAIL | => $fail },
        qw| -wipe TESTSERIAL01 -yes -layout |,
        $w->{'layout'}
    );
    check( "no answer refused : $fail", $exit != 0 && $out =~ $re )
        or print $out;
    check(
        "no answer refused : $fail -- nothing written",
        !writes($w) && same_snapshot( $before, state_snap($w) )
    );
}

## a table to replace under our own active vg : refused ##
{
    my $w = stub_world(
        qw| state | => {
            'table.loop90' => "1 2048 999999 8E00 old\n",
            qw| pv |       => "/dev/loop90p1 test-vg\n",
            qw| lv |       => "test-vg root 1000 1\n"
        }
    );
    my ( $exit, $out )
        = run_tool( $w->{'env'}, qw| -wipe TESTSERIAL01 -yes -layout |,
        $w->{'layout'} );
    check(
        'busy table refused',
        $exit != 0
            && $out
            =~ m|table is to be replaced but /dev/mapper/test--vg-root active|
    ) or print $out;
    check( 'busy table refused -- nothing written', !writes($w) );
}

## a target that is a live directory : refused ##
{
    my $w = stub_world();
    spew( "$w->{'root'}/live/file", 'x' );
    my ( $exit, $out )
        = run_tool( $w->{'env'}, qw| -wipe TESTSERIAL01 -yes -target |,
        "$w->{'root'}/live", '-layout', $w->{'layout'} );
    check( 'non-empty target refused',
        $exit != 0 && $out =~ m|is not empty and not a mount| )
        or print $out;
    check( 'non-empty target refused -- nothing written', !writes($w) );
}

## the parsers against the real sgdisk on an image file [ no root ] ##
if ( grep { -x "$ARG/sgdisk" } split( m|:|, $ENV{'PATH'} ),
    qw| /usr/sbin /sbin | ) {
    my ($sgdisk)
        = grep { -x $ARG } map {"$ARG/sgdisk"} split( m|:|, $ENV{'PATH'} ),
        qw| /usr/sbin /sbin |;
    my $dir = tempdir(
        qw| p7-host-build-img-XXXXXX |,
        qw| TMPDIR |  => 1,
        qw| CLEANUP | => 1
    );
    my $img = "$dir/real.img";
    open( my $fh, '>', $img ) or die;
    truncate( $fh, $GiB )     or die;
    close $fh;
    my $blank = qx| $sgdisk -p $img 2>&1 |;
    check( 'real sgdisk : a blank image has the header line',
        $blank =~ m|^Number\s+Start|m );
    {
        open( my $saved, '>&', \*STDOUT )            or die;
        open( STDOUT,    '>',  File::Spec->devnull ) or die;
        my $rc = CORE::system(
            $sgdisk,
            qw| -n 1:0:+64M -t 1:EF00 -c 1:efi |,
            qw| -n 2:0:+128M -t 2:8300 -c 2:boot -n 3:0:0 -t 3:8E00 -c 3:main |,
            $img
        );
        open( STDOUT, '>&', $saved ) or die;
        die "sgdisk exit $rc\n" if $rc != 0;
    }
    my $printed = qx| $sgdisk -p $img 2>&1 |;
    ## the tool's own parser, compiled out of its source ##
    my $src = slurp($tool);
    my ($parser) = $src =~ m|(sub read_table \{.*?\n\}\n)|s;
    $parser
        =~ s|my \( \$exit, \$out \) = run_read\(.*?\);|my ( \$exit, \$out ) = ( 0, \$main::PRINTED );|s;
    our $PRINTED = $printed;
    my $table = eval "package hbparse; use English; sub probe_failed "
        . "{ die \@_ } $parser; read_table('$img')";
    check(
        'real sgdisk : read_table parses 3 partitions',
        ref $table && @{ $table->{'parts'} } == 3
    ) or print $EVAL_ERROR, $printed;
    if ( ref $table ) {
        my @p = @{ $table->{'parts'} };
        check(
            'real sgdisk : sector size 512, names and codes',
            $table->{'sector'} == 512
                && $p[0]{'name'} eq 'efi'
                && $p[0]{'code'} eq 'EF00'
                && $p[2]{'code'} eq '8E00'
        );
        check(
            'real sgdisk : efi 64M, boot 128M exactly',
            ( $p[0]{'end'} - $p[0]{'start'} + 1 ) * 512 == 64 * 1024**2
                && ( $p[1]{'end'} - $p[1]{'start'} + 1 ) * 512
                == 128 * 1024**2
        );
    }
} else {
    say ':: real sgdisk check skipped [ no sgdisk ]';
}

##[ part 2 : root, loop devices ]#############################################

say ':';
if ( $EUID != 0 ) {
    say ':: part 2 : skipped [ not root -- run as root for the loop chain ]';
} elsif ( not grep { -x "$ARG/losetup" } split m|:|, $ENV{'PATH'} ) {
    say ':: part 2 : skipped [ no losetup ]';
} else {
    say ':: part 2 : loop devices [ root ]';
    root_loop_chain();
}
say ':';

say sprintf ':: %d passed, %d failed', $pass_count, $fail_count;
say ':';
exit( $fail_count ? 1 : 0 );

## the real tools on loop devices ; every mount and loop is undone in the ##
## end, and the temp dir is removed only when nothing is mounted in it    ##
sub root_loop_chain {
    my $base = tempdir( qw| p7-host-build-loop-XXXXXX |, qw| TMPDIR | => 1 );
    $base = abs_path($base);
    my $root = "$base/root";
    my $fake = "$base/fake";
    make_path( $root, $fake, "$base/state" );
    my $serial = "P7HBTEST$PID";
    ## the images live INSIDE the test root : only those map to a test ##
    ## serial                                                          ##
    my $img    = "$root/$serial.img";
    my $ro_img = "$root/P7HBRO$PID.img";
    my @loops;

    my $cleanup = sub {
        CORE::system( qw| umount -R -l |,    "$root/mnt" ) if -d "$root/mnt";
        CORE::system( qw| vgchange -q -an |, "p7hb$PID" );
        CORE::system( qw| losetup -d |,      $ARG ) foreach @loops;
        my $mounts = slurp('/proc/self/mounts') // '';
        if ( index( $mounts, " $base" ) >= 0 ) {
            say ":: left in place [ still mounted under $base ]";
            return;
        }
        remove_tree($base);
    };

    my $ok = eval {
        foreach my $f ( [ $img, 1300 ], [ $ro_img, 64 ] ) {
            open( my $fh, '>', $f->[0] )       or die "$f->[0] : $OS_ERROR";
            truncate( $fh, $f->[1] * 1024**2 ) or die "truncate : $OS_ERROR";
            close($fh);
        }
        my $loop = qx| losetup -f -P --show $img |;
        chomp $loop;
        die "losetup failed\n" if $loop !~ m|\A/dev/loop\d+\z|;
        CORE::push @loops, $loop;

        ## the two-system layout [ main, rescue, exp ] ; exp on ext4 : ##
        ## mkfs.xfs refuses a 32M volume                               ##
        my $layout = $MULTI_LAYOUT;
        $layout =~ s|^(lv\.exp\s+=\s+32M) xfs|$1 ext4|m;
        $layout =~ s|TESTSERIAL01|$serial|;
        $layout =~ s|test-vg|p7hb$PID|;
        spew( "$base/test.layout", $layout );

        my %env = (
            qw| P7_HOST_BUILD_ROOT |         => $root,
            qw| P7_HOST_BUILD_TEST_SERIALS | => 1,
            qw| NO_COLOR |                   => 1,
        );
        if ( not $ENV{'P7_HOST_BUILD_SLOW_TEST'} ) {
            spew( "$fake/fake", "#!$EXECUTABLE_NAME\n$FAKE" );
            chmod 0755, "$fake/fake";
            symlink( "$fake/fake", "$fake/$ARG" )
                foreach qw| debootstrap chroot |;
            $env{'PATH'}       = "$fake:$ENV{'PATH'}";
            $env{'FAKE_STATE'} = "$base/state";
            spew( "$base/state/disks", '' );
            ## the fake chroot finds the real /dev bind in ##
            ## /proc/self/mounts                           ##
        }

        my ( $exit, $out )
            = run_tool( \%env, qw| -wipe |, $serial, qw| -yes -layout |,
            "$base/test.layout" );
        check( 'loop : chain exit 0', $exit == 0 ) or print $out;
        ## the tool leaves the vg inactive : activate it for the look only ##
        CORE::system( qw| vgchange -q -ay |, "p7hb$PID" );
        my $tree = qx| lsblk -n -o NAME,FSTYPE $loop |;
        CORE::system( qw| vgchange -q -an |, "p7hb$PID" );
        check( 'loop : partitions and file systems',
            $tree =~ m|vfat| && $tree =~ m|xfs| && $tree =~ m|LVM2_member| )
            or print $tree;
        my $mounts = slurp('/proc/self/mounts') // '';
        check( 'loop : nothing left mounted',
            index( $mounts, " $root" ) < 0 );

        ## the main root, read-only, for the menu and the system trees ##
        my $look = "$base/look";
        make_path($look);
        CORE::system( qw| vgchange -q -ay |, "p7hb$PID" );
        my %menu_of;
        foreach my $lv (qw| root rescue exp |) {
            next
                if
                CORE::system( qw| mount -o ro |, "/dev/p7hb$PID/$lv", $look )
                != 0;
            $menu_of{$lv} = {
                qw| menu | => slurp("$look/etc/grub.d/41_p7-systems")   // '',
                qw| hostname | => slurp("$look/etc/hostname")           // '',
                qw| network |  => slurp("$look/etc/network/interfaces") // '',
                qw| timezone | => slurp("$look/etc/timezone")           // '',
            };
            CORE::system( qw| umount |, $look );
        }
        my $menu = $menu_of{'root'}{'menu'} // '';
        my $uuid = sub {
            my $u = qx| blkid -o value -s UUID /dev/p7hb$PID/$ARG[0] |;
            chomp $u;
            return $u;
        };
        check(
            'loop : menu lists both systems by uuid',
            count_of( qr|^menuentry |m, $menu ) == 2
                && index( $menu, '--set=root ' . $uuid->('rescue') ) >= 0
                && index( $menu, '--set=root ' . $uuid->('exp') ) >= 0
        ) or print $menu;
        CORE::system( qw| vgchange -q -an |, "p7hb$PID" );
        check(
            'loop : each system its own tree and host name',
            ( $menu_of{'rescue'}{'hostname'} // '' ) eq "testhost-rescue\n"
                && ( $menu_of{'exp'}{'hostname'} // '' ) eq "testhost-lab\n"
        );
        check(
            'loop : ifupdown dhcp and timezone in every system',
            3 == grep {
                ( $menu_of{$ARG}{'network'} // '' )
                    =~ m|^iface p7-wired inet dhcp$|m
                    && ( $menu_of{$ARG}{'timezone'} // '' ) eq "Etc/UTC\n"
            } qw| root rescue exp |
        );

        my $sig = qx| sgdisk -p $loop |;
        ( $exit, $out ) = run_tool( \%env, '-layout', "$base/test.layout" );
        check( 'loop : second run exit 0 without -wipe', $exit == 0 )
            or print $out;
        check(
            'loop : second run, table unchanged',
            $sig eq qx| sgdisk -p $loop |
        );
        check( 'loop : second run, no changes', $out =~ m|changes \.+ none| );

        ## read-only and mounted : refused with the reason ##
        CORE::system( qw| losetup -d |, $loop );
        @loops = ();
        my $ro = qx| losetup -f -r -P --show $ro_img |;
        chomp $ro;
        CORE::push @loops, $ro;
        ( my $ro_layout = $layout ) =~ s|$serial|P7HBRO$PID|;
        spew( "$base/ro.layout", $ro_layout );
        ( $exit, $out )
            = run_tool( \%env, qw| -wipe |, "P7HBRO$PID", qw| -yes -layout |,
            "$base/ro.layout" );
        check(
            'loop : read-only refused',
            $exit != 0 && $out =~ m|read-only|
        );
        CORE::system( qw| losetup -d |, $ro );
        @loops = ();

        $loop = qx| losetup -f -P --show $img |;
        chomp $loop;
        CORE::push @loops, $loop;
        make_path("$base/elsewhere");
        CORE::system( qw| mount |, "${loop}p2", "$base/elsewhere" );
        ( $exit, $out ) = run_tool( \%env, '-layout', "$base/test.layout" );
        check( 'loop : mounted disk refused',
            $exit != 0 && $out =~ m|is mounted on $base/elsewhere| );
        CORE::system( qw| umount |, "$base/elsewhere" );
        TRUE;
    };
    check( 'loop : no exception', $ok ) or print $EVAL_ERROR;
    $cleanup->();
    return TRUE;
}

#,,,,,.,.,...,...,...,,,.,.,.,.,.,.,.,,,,,...,..,,...,...,,.,,,,,,,..,,.,,..,,
#2L3ZWDFVGLKZRABAIZB3LTNJVHTV76NDQ6FO36DJ6NP75GYBDTIQXRFMD2XBSNCF2TC27QSLEHIRA
#\\\|MD5SYGOK76NVKI7VJBCO6ABJWETKVR5K2VW52QVVVCEDEWVTRFS \ / AMOS7 \ YOURUM ::
#\[7]ICBTJ4CVPUXISHZU7BVLTK3MGTYU3PY3NMTSRE6FYAIYEY2Z5UDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
