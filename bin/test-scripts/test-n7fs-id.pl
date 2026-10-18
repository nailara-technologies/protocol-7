#!/usr/bin/perl
use v5.32.0;
use strict;
use English;
use warnings;

## N7FS version 1 : disk identity, attach \ detach, mount records, use window
## [ data/md/design/N7FS-SPEC.md sections 3 + 4 ]. every refusal is checked
## against a full snapshot of root + host dir : NO change on disk.  temp roots
## only [ fixtures/n7fs/helpers.pl ].
##
## perl bin/test-scripts/test-n7fs-id.pl  N7FS_TEST_LIB=<dir> puts a
## [ mutated ] copy of the modules first

use FindBin;

BEGIN {
    unshift @INC, "$FindBin::Bin/../../data/lib-path/pm";
    unshift @INC, $ENV{'N7FS_TEST_LIB'} if $ENV{'N7FS_TEST_LIB'};
}

use AMOS7::N7FS qw| b32 read_file signed_record_pack signed_record_parse |;
use AMOS7::N7FS::Sum  qw| amos_of_bytes l13_standin |;
use AMOS7::N7FS::Sign qw| seed_signer new_seed command_signer verify
    key_file_write |;
use AMOS7::N7FS::Disk qw| disk_init disk_read_id disk_attach disk_detach
    disk_status mount_history witness_read host_mounts state_read |;

require "$FindBin::Bin/fixtures/n7fs/helpers.pl";

##[ global constants ]##
use constant TRUE  => 5;    ##  TRUE.  ##
use constant FALSE => 0;    ##  false  ##

my $box    = sandbox();
my $root   = $box->{'root'};
my $hdir   = $box->{'host'};
my $parent = test_signer();
my $host   = test_signer();
my %base   = ( qw| root | => $root, qw| host_dir | => $hdir );
clock_real();

say ':: init';

my $disk = disk_init(
    %base,
    qw| parent | => $parent,
    qw| name |   => 'test-disk',
    qw| intent | => 'n7fs id test [ test data ]',
);
ok( $disk =~ m|\A[A-Z2-7]{7}\z|, 'disk id is a 7-char amos' );

my $record = read_file("$root/$disk/.n7fs/id.record");
ok( substr( $record, 0, 5 ) eq "P7FS\x01",
    "id.record : magic " . "'P7FS' + format 1"
);
ok( read_file("$root/$disk/.n7fs/id.amos") eq "$disk\n",
    'id.amos = the directory name' );
ok( amos_of_bytes($record) eq $disk, 'id.amos recomputes from id.record' );
ok( read_file("$root/$disk/.n7fs/id.l13") eq l13_standin($record) . "\n",
    'id.l13 holds the tagged stand-in' );
ok( index( read_file("$root/$disk/.n7fs/id.l13"), 'stand-in:' ) == 0,
    'id.l13 is marked as a stand-in' );

my $parsed = signed_record_parse( qw| id |, $record );
ok( $parsed->{'signer_pub'} eq $parent->public,
    'record carries ' . 'the parent key'
);
ok( verify( $parsed->{'signer_pub'}, $parsed->{'signed'}, $parsed->{'sig'} ),
    'parent signature verifies'
);
ok( $parsed->{'payload'}{'intent'} eq 'n7fs id test [ test data ]'
        && $parsed->{'payload'}{'init_ntime'} =~ m|\A\d{14}\z|
        && length $parsed->{'payload'}{'store_pub'} == 52,
    'record : intent, 14-digit init ntime, delegated store key'
);

my $keyfile = "$hdir/stores/$disk.store.key";
ok( -f $keyfile && ( ( stat $keyfile )[2] & 0777 ) == 0600,
    'store key on the host side, 0600' );
ok( !-e "$root/$disk/.n7fs/store.key", 'no secret key inside the store' );
ok( state_read("$root/$disk")->{'store_format'} == 1,
    'state : store ' . 'format 1' );
ok( ref disk_read_id( %base, qw| disk | => $disk ) eq 'HASH',
    'the new disk verifies' );

say ':: collision at init -> the next ntime';
{
    my $seed = new_seed();
    my $T    = clock_now() + 1000;
    my $sb1  = "$box->{'base'}/coll1";
    mkdir $sb1;
    mkdir "$sb1/$_" for qw| root host |;
    my $first = disk_init(
        qw| root |       => "$sb1/root",
        qw| host_dir |   => "$sb1/host",
        qw| parent |     => $parent,
        qw| name |       => 'c',
        qw| intent |     => 'c',
        qw| store_seed | => $seed,
        qw| ntime |      => $T
    );
    my $sb2 = "$box->{'base'}/coll2";
    mkdir $sb2;
    mkdir "$sb2/$_" for qw| root host |;
    mkdir "$sb2/root/$first";    ## the id is taken ##
    my $second = disk_init(
        qw| root |       => "$sb2/root",
        qw| host_dir |   => "$sb2/host",
        qw| parent |     => $parent,
        qw| name |       => 'c',
        qw| intent |     => 'c',
        qw| store_seed | => $seed,
        qw| ntime |      => $T
    );
    my $p2 = signed_record_parse( qw| id |,
        read_file("$sb2/root/$second/.n7fs/id.record") );
    ok( $second ne $first, 'a taken id gives another id' );
    ok( $p2->{'payload'}{'init_ntime'} == $T + 1, 'taken at the next ntime' );
    opendir( my $dh, "$sb2/root/$first" );
    ok( 2 == grep( {1} readdir $dh ),
        'the occupying ' . 'directory is untouched' );
}

say ':: refusals change nothing';

sub refused_unchanged {
    my ( $code, $re, $name ) = @ARG;
    my $before = snapshot( $root, $hdir );
    refused( $code, $re, $name );
    ok( snap_equal( $before, snapshot( $root, $hdir ) ),
        "$name : no change on disk" );
}

## a valid store under a wrong name : only the name rule refuses ##
copy_tree( "$root/$disk", "$root/AAAAAAA" );
refused_unchanged(
    sub { disk_attach( %base, qw| disk | => 'AAAAAAA', qw| host | => $host ) }
    ,
    qr|directory name AAAAAAA does not match the id $disk|,
    'wrong name refused'
);

## forges a store : $mutate gets the record bytes, returns new ones. the name,
## id.amos and id.l13 are recomputed, so ONLY the signature rule can refuse
sub forge {
    my $mutate = shift;
    my $bytes  = $mutate->($record);
    my $amos   = amos_of_bytes($bytes);
    copy_tree( "$root/$disk", "$root/$amos" );
    chmod 0600, "$root/$amos/.n7fs/$_" for qw| id.record id.amos id.l13 |;
    write_file( "$root/$amos/.n7fs/id.record", $bytes );
    write_file( "$root/$amos/.n7fs/id.amos",   "$amos\n" );
    write_file( "$root/$amos/.n7fs/id.l13",    l13_standin($bytes) . "\n" );
    return $amos;
}

my $forged = forge(
    sub {
        my $r    = signed_record_parse( qw| id |, shift );
        my %p    = ( $r->{'payload'}->%*, qw| intent | => 'forged intent' );
        my $json = $AMOS7::N7FS::JSON->encode( \%p );
        return "P7FS\x01"
            . pack( 'n/a* N/a* a32',
            $AMOS7::N7FS::LABEL{'id'},
            $json, $r->{'signer_pub'} )
            . $r->{'sig'};
    }
);
refused_unchanged(
    sub { disk_attach( %base, qw| disk | => $forged, qw| host | => $host ) },
    qr|parent signature does not verify|,
    'forged record [ consistent name ] refused'
);

my $badsig = forge(
    sub {
        my $b = shift;
        substr( $b, -1, 1 ) = chr( ord( substr( $b, -1, 1 ) ) ^ 0x01 );
        return $b;
    }
);
refused_unchanged(
    sub { disk_attach( %base, qw| disk | => $badsig, qw| host | => $host ) },
    qr|parent signature does not verify|,
    'bad signature [ consistent name ] refused'
);

chmod 0600, "$root/$disk/.n7fs/id.amos";
my $id_amos_orig = read_file("$root/$disk/.n7fs/id.amos");
write_file( "$root/$disk/.n7fs/id.amos", "AAAAAAA\n" );
refused_unchanged(
    sub { disk_attach( %base, qw| disk | => $disk, qw| host | => $host ) },
    qr|id\.amos does not match|,
    'tampered id.amos refused'
);
write_file( "$root/$disk/.n7fs/id.amos", $id_amos_orig );

my $id_l13_orig = read_file("$root/$disk/.n7fs/id.l13");
write_file( "$root/$disk/.n7fs/id.l13",
    $AMOS7::N7FS::Sum::L13_TAG . "AAAAAAAAAAAAA\n" );
refused_unchanged(
    sub { disk_attach( %base, qw| disk | => $disk, qw| host | => $host ) },
    qr|id\.l13 does not match|,
    'tampered id.l13 refused'
);
write_file( "$root/$disk/.n7fs/id.l13", $id_l13_orig );

## a self-signed store [ the attacker's own parent key ] : only anchors ##
## catch it                                                             ##
my $attacker = test_signer();
my $evil     = disk_init(
    %base,
    qw| parent | => $attacker,
    qw| name |   => 'evil',
    qw| intent | => 'self-signed [ test data ]',
);
refused_unchanged(
    sub {
        disk_attach(
            %base,
            qw| disk |    => $evil,
            qw| host |    => $host,
            qw| anchors | => [ $parent->public ]
        );
    },
    qr|parent key \S+ is not trusted|,
    'untrusted parent refused when anchors are set'
);
write_file( "$hdir/trusted-parents", b32( $parent->public ) . "\n" );
refused_unchanged(
    sub { disk_attach( %base, qw| disk | => $evil, qw| host | => $host ) },
    qr|is not trusted|,
    'trusted-parents file enforced'
);
unlink "$hdir/trusted-parents";

say ':: mount records + use window';

my $a1 = disk_attach( %base, qw| disk | => $disk, qw| host | => $host );
ok( $a1->{'window'} eq 'first-contact', 'first attach : first contact' );
my @hist = mount_history( "$root/$disk", $disk );
ok( @hist == 1 && $hist[0]{'name'} =~ m|\A\d{14}\.[A-Z2-7]{7}\z|,
    'mount record <ntime14>.<mount>' );
ok( $hist[0]{'event'} eq 'attach' && $hist[0]{'host_pub'} eq $host->public,
    'signed by the host, event attach' );
ok( read_file("$hdir/mounts/$disk/$hist[0]{'name'}") eq
        read_file("$root/$disk/.n7fs/mounts/$hist[0]{'name'}"),
    'the host keeps an identical copy'
);
my $w = witness_read( %base, qw| disk | => $disk, qw| host | => $host );
ok( $w->{'first'} eq $a1->{'ntime'} && $w->{'last'} eq $a1->{'ntime'},
    'witness : first = last = attach' );

refused_unchanged(
    sub { disk_attach( %base, qw| disk | => $disk, qw| host | => $host ) },
    qr|attached already|,
    'second attach refused'
);

my $d1 = disk_detach( %base, qw| disk | => $disk, qw| host | => $host );
ok( $d1->{'mount'} eq $a1->{'mount'}, 'detach keeps the mount handle' );
@hist = mount_history( "$root/$disk", $disk );
ok( @hist == 2 && $hist[1]{'event'} eq 'detach', 'detach record appended' );
$w = witness_read( %base, qw| disk | => $disk, qw| host | => $host );
ok( $w->{'first'} eq $a1->{'ntime'} && $w->{'last'} eq $d1->{'ntime'},
    'witness : first kept, last = detach' );
refused_unchanged(
    sub { disk_detach( %base, qw| disk | => $disk, qw| host | => $host ) },
    qr|not attached here|,
    'detach when detached refused'
);

## a tampered mount record fails closed ##
{
    my $f    = "$root/$disk/.n7fs/mounts/$hist[0]{'name'}";
    my $orig = read_file($f);
    chmod 0600, $f;
    my $bad = $orig;
    substr( $bad, -70, 1 ) = chr( ord( substr( $bad, -70, 1 ) ) ^ 0x01 );
    write_file( $f, $bad );
    refused_unchanged(
        sub { disk_attach( %base, qw| disk | => $disk, qw| host | => $host ) }
        ,
        qr|signature does not verify|,
        'tampered mount record refused'
    );
    write_file( $f, $orig );
    chmod 0600, $f;
}

my $a2 = disk_attach( %base, qw| disk | => $disk, qw| host | => $host );
ok( $a2->{'window'} eq 'current',     'attach after detach : current' );
ok( $a2->{'mount'} ne $a1->{'mount'}, 'a new mount handle per attach' );
## snapshot ##
my $older = copy_tree( "$root/$disk", "$box->{'base'}/older" );
disk_detach( %base, qw| disk | => $disk, qw| host | => $host );

## another host attaches + detaches : the disk travelled ##
my $host2 = test_signer();
my %base2 = ( qw| root | => $root, qw| host_dir | => "$box->{'base'}/host2" );
mkdir $base2{'host_dir'};
disk_attach( %base2, qw| disk | => $disk, qw| host | => $host2 );
disk_detach( %base2, qw| disk | => $disk, qw| host | => $host2 );
my $a3 = disk_attach( %base, qw| disk | => $disk, qw| host | => $host );
ok( $a3->{'window'} eq 'travelled',
    'newer foreign-host ' . 'records : travelled' );
disk_detach( %base, qw| disk | => $disk, qw| host | => $host );

## rollback : the older copy presents a state inside [ first, last ) ##
my $current = "$box->{'base'}/current";
rename "$root/$disk", $current;
copy_tree( $older, "$root/$disk" );
refused_unchanged(
    sub { disk_attach( %base, qw| disk | => $disk, qw| host | => $host ) },
    qr|earlier state .* rollback|,
    'rollback refused by default'
);
## on a copy of the host dir : the real witness stays as it was ##
my $hdir_rb = copy_tree( $hdir, "$box->{'base'}/host-rb" );
my $ar      = disk_attach(
    qw| root |           => $root,
    qw| host_dir |       => $hdir_rb,
    qw| disk |           => $disk,
    qw| host |           => $host,
    qw| allow_rollback | => TRUE
);
ok( $ar->{'window'} eq 'rollback-allowed',
    'rollback accepted ' . 'only when allowed'
);

## clone : a copy of an older state extended by another host ##
remove_tree_all("$root/$disk");
copy_tree( $older, "$root/$disk" );
{
    my $hd3 = "$box->{'base'}/host3";
    mkdir $hd3;
    my $h3 = test_signer();
    ## the clone was attached elsewhere -- host3 has never seen it       ##
    ## [ the older copy ends 'attached' for host 1, host3 just appends ] ##
    disk_attach(
        qw| root |     => $root,
        qw| host_dir | => $hd3,
        qw| disk |     => $disk,
        qw| host |     => $h3
    );
}
refused_unchanged(
    sub { disk_attach( %base, qw| disk | => $disk, qw| host | => $host ) },
    qr|history diverges|,
    'diverging history [ clone ] refused'
);

## wiped history : before the first use = foreign ##
remove_tree_all("$root/$disk");
copy_tree( $current, "$root/$disk" );
remove_tree_all("$root/$disk/.n7fs/mounts");
mkdir "$root/$disk/.n7fs/mounts", 0700;
refused_unchanged(
    sub { disk_attach( %base, qw| disk | => $disk, qw| host | => $host ) },
    qr|before the first use .* foreign|,
    'state before the first use refused'
);
remove_tree_all("$root/$disk");
copy_tree( $current, "$root/$disk" );

## witness records : unsigned \ missing timestamp fail closed ##
{
    my @ws  = sort glob "$hdir/witness/$disk/*.use";
    my $new = clock_now() + 100000;
    my $nt  = sprintf '%014d', $new;
    my $rec = signed_record_pack(
        qw| use |,
        {   qw| disk |        => $disk,
            qw| last |        => $nt,
            qw| last_record | => "$nt.AAAAAAA",
            qw| last_event |  => 'attach'
        },
        $host
    );
    write_file( "$hdir/witness/$disk/$nt.use", $rec );
    refused_unchanged(
        sub { disk_attach( %base, qw| disk | => $disk, qw| host | => $host ) }
        ,
        qr|first-use timestamp missing|,
        'witness without a first-use timestamp refused'
    );
    unlink "$hdir/witness/$disk/$nt.use";

    my $good = read_file( $ws[-1] );
    my $bad  = $good;
    substr( $bad, -1, 1 ) = chr( ord( substr( $bad, -1, 1 ) ) ^ 0x01 );
    my $name = $ws[-1] =~ s|.*/||r;
    chmod 0600, $ws[-1];
    write_file( $ws[-1], $bad );
    refused_unchanged(
        sub { disk_attach( %base, qw| disk | => $disk, qw| host | => $host ) }
        ,
        qr|witness \S+ : signature does not verify|,
        'unsigned \ damaged witness refused'
    );
    write_file( $ws[-1], $good );
}
ok( disk_attach( %base, qw| disk | => $disk, qw| host | => $host )->{'window'}
        eq 'current',
    'restored disk + witness : current again'
);
my $st = disk_status( %base, qw| disk | => $disk, qw| host | => $host );
ok( $st->{'attached'} && $st->{'name'} eq 'test-disk', 'status reads it' );

say ':: the parent signer plug [ external command, list-form exec ]';
{
    my $dir = "$box->{'base'}/signer";
    mkdir $dir;
    my $key    = "$dir/parent.key";
    my $plug   = key_file_write($key);
    my $script = write_file( "$dir/sign.pl", <<"EOS" );
use strict; use warnings;
use lib '$FindBin::Bin/../../data/lib-path/pm';
use AMOS7::N7FS qw| b32 unb32 |;
use AMOS7::N7FS::Sign qw| key_file_signer |;
my \$s = key_file_signer('$key');
if ( \$ARGV[0] eq 'public' ) { print b32( \$s->public ), "\\n"; exit 0 }
exit 3 if \$ARGV[0] ne 'sign' or ( \$ARGV[1] // '' ) !~ m|\\Ap7 n7fs |;
my \$in = <STDIN>; chomp \$in;
print b32( \$s->sign( unb32(\$in) ) ), "\\n";
EOS
    my $cmd = command_signer( $EXECUTABLE_NAME, $script );
    ok( $cmd->public eq $plug->public, 'command signer : public key' );
    my $d = disk_init(
        %base,
        qw| parent | => $cmd,
        qw| name |   => 'plug',
        qw| intent | => 'command signer [ test data ]'
    );
    my $id = disk_read_id( %base, qw| disk | => $d );
    ok( $id->{'parent_pub'} eq $plug->public,
        'disk signed ' . 'through the plug'
    );
    my $foreign = "P7FS\x01" . pack( 'n/a*', 'p7 delegation v1' ) . 'x';
    ok( !defined eval { $cmd->sign($foreign) },
        'the plug refuses a foreign label'
    );
}

say ':: cli : a missing root is refused, never created';
{
    my $key = "$box->{'base'}/cli.key";
    key_file_write($key);
    my $missing = "$box->{'base'}/no-such-root";
    my $before  = -e '/N7FS' ? 1 : 0;
    my $rc
        = system( $EXECUTABLE_NAME, "$FindBin::Bin/../n7fs", '-root',
        $missing, '-parent-key', $key, 'init', '-name', 'x', '-intent', 'y' );
    ok( $rc != 0 && !-e $missing,          'cli refuses a missing root' );
    ok( ( -e '/N7FS' ? 1 : 0 ) == $before, '/N7FS untouched' );
}

sub remove_tree_all { AMOS7::N7FS::remove_tree(shift) }

done();

#,,..,,..,,,.,,..,.,,,,,,,.,,,,,.,..,,.,,,.,,,..,,...,...,,.,,,.,,,,.,.,,,.,,,
#WM42VWOPMG3CAIDE2AKT2GU3W3PAD2CYZIK7R27WACON5SEWGFFRDXCMB362DUO2JFM3OXAJW5GTQ
#\\\|NG2UGVQZHQ7ABB3MBVMH44RV63ZJZXVMK7MVKI7V6TELXLL3D4C \ / AMOS7 \ YOURUM ::
#\[7]RIPKW6WIB6WLCUU4LPC3C6RYT44UPABPZO4R7JV532KLS36IYSCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
