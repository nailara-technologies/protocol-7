#!/usr/bin/env perl
use v5.24;
use strict;
use English;
use warnings;

## the production runtime [ bin/Protocol-7 : use utf8 + Encode ] loads the ##
## bytes pragma transitively. mirror that here, as the precedent tests do. ##
use bytes;

## trust chain step 2 management tools [ data/md/design/TRUST-CHAIN-        ##
## STEP2.md ] : keys.console.certify-host \ accept-owner \ owner-pin \      ##
## owner-unpin \ owner-pins \ distrust \ undistrust + their helpers. the    ##
## REAL modules are compiled [ runtime pragmas ] ; key files, homedir and   ##
## load_keypair are stubbed onto File::Temp directories. the flow end to    ##
## end : certify -> accept -> owner-pin -> trust.pin_decide [ owner path ]. ##

use File::Spec;
use File::Spec::Functions qw| catfile |;
use Cwd                   qw| abs_path getcwd |;
use FindBin               qw| $RealBin |;
use File::Temp            qw| tempdir |;

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
use Crypt::Misc               qw| encode_b32r decode_b32r |;
use Crypt::Ed25519;
use Digest::BMW;

use constant TRUE    => 5;
use constant FALSE   => 0;
use constant UNKNOWN => 2;

our %code;
our %data;
our %keys;

my $fail_count = 0;
my $test_count = 0;

## prototype : a list-context match cannot shift the label ##
sub ok ($;$) {
    my ( $cond, $label ) = @ARG;
    $test_count++;
    if ($cond) { say "  ok   : $label"; return 1 }
    $fail_count++;
    say "  FAIL : $label";
    return 0;
}

my $runtime_pragmas
    = q{no bytes; use File::stat; use open qw| :encoding(UTF-8) |;};

sub compile_module {
    my ($module_name) = @ARG;
    my $src_path
        = File::Spec->catfile( $main::root_path, 'src', $module_name );
    open( my $fh, '<', $src_path ) or die "cannot read $src_path : $!";
    my $src = join( '', <$fh> );
    close($fh);
    my $translated = p7_syntax__translate($src);
    my $cref       = eval "$runtime_pragmas sub {\n# line 1 "
        . "\"$module_name\"\n$translated\n}";
    die "compile failed for $module_name : $EVAL_ERROR" if not defined $cref;
    $code{$module_name} = $cref;
    return $cref;
}

## run a compiled module with stdout captured, trapping base.exit ##
sub run {
    my ( $module_name, @args ) = @ARG;
    my $out = '';
    open( my $fh, '>', \$out ) or die;
    my $old = select($fh);
    my @ret = eval { $code{$module_name}->(@args) };
    my $err = $EVAL_ERROR;
    select($old);
    close($fh);
    my ($exit) = $err =~ m|\AEXIT:(\d+)|;
    return { ret => \@ret, err => $err, out => $out, exit => $exit };
}

sub slurp {
    open( my $fh, '<', shift ) or return undef;
    local $INPUT_RECORD_SEPARATOR = undef;
    my $all = readline($fh);
    close($fh);
    return $all;
}

sub put {
    my ( $path, $content, $mode ) = @ARG;
    open( my $fh, '>', $path ) or die "cannot write $path : $!";
    print {$fh} $content;
    close($fh);
    chmod( $mode // 0600, $path );
    return $path;
}

## --- temp tree : a client home, a backend key dir ----------------------- ##
my $tmp      = tempdir( CLEANUP => 1 );
my $home     = catfile( $tmp, 'home' );
my $key_dir  = catfile( $tmp, 'user-keys' );
my $work_dir = catfile( $tmp, 'work' );
mkdir $_ or die for $home, $key_dir, $work_dir;
my $keys_dir = "$home/.n/remote-keys";

## throwaway keys : owner 06, host-root 03, S 02, beta host-root 07 ##
my %kp;
foreach my $seed (qw| 02 03 06 07 |) {
    $kp{$seed}
        = [ Crypt::Ed25519::generate_keypair( chr( hex $seed ) x 32 ) ];
}
my $fp = sub { encode_b32r( Digest::BMW::bmw_384( $kp{ shift() }[0] ) ) };

my @logged;
my $owner_form   = 'plain';    ## plain \ encrypted \ passphrase ##
my $owner_holder = 'user';
$code{'base.logs'}        = sub { push @logged, [@ARG]; return };
$code{'base.log'}         = sub { push @logged, [@ARG]; return };
$code{'base.str.os_err'}  = sub { return "$OS_ERROR" };
$code{'base.exit'}        = sub { die sprintf "EXIT:%s\n", join '', @ARG };
$code{'base.get_homedir'} = sub { return $home };
$code{'crypt.C25519.key_exists'} = sub { return $ARG[0] eq 'owner' };
$code{'crypt.C25519.key_path'}   = sub {
    my $base = catfile( $key_dir, $ARG[0] );
    return {
        key_dir      => $key_dir,
        key_basepath => $base,
        key_filename => { map { $ARG => "$base.$ARG" } qw| secret public | },
        holder       => $ARG[0] eq 'owner' ? $owner_holder : 'user',
    };
};
$code{'crypt.C25519.key_vars'} = sub { return { key_name => 'srv.base' } };
$code{'crypt.C25519.delegation_file'} = sub { return "$key_dir/$ARG[0].dlg" };
$code{'crypt.C25519.encrypted_key'}   = sub { $owner_form eq 'encrypted' };
$code{'crypt.C25519.key_is_virtual'}  = sub {FALSE};
my $loaded = 0;
$code{'crypt.C25519.load_keypair'} = sub {
    $keys{'C25519'}{'owner'}
        = { public => $kp{'06'}[0], private => $kp{'06'}[1] };
    $loaded++;
    return TRUE;
};
$code{'crypt.C25519.unload_key'} = sub { delete $keys{'C25519'}{ $ARG[0] } };

compile_module($ARG)
    for qw| trust.statement trust.key_id trust.verify trust.chain
    trust.pin_decide auth.client.owner_pins auth.client.distrust_list
    keys.key_id_arg keys.remote_keys_dir keys.distrust_file
    keys.console.owner-pin keys.console.owner-unpin keys.console.owner-pins
    keys.console.distrust keys.console.undistrust keys.console.certify-host
    keys.store_note
    keys.console.accept-owner |;

my $statement = $code{'trust.statement'};
my $leaf_for  = sub {                       ## host-root seed -> S, name ##
    my ( $root, $name ) = @ARG;
    my $st = $statement->(
        'build',
        {   issuer_pub  => $kp{$root}[0],
            subject_pub => $kp{'02'}[0],
            name        => $name,
            not_before  => time - 100,
            not_after   => time + 30 * 86400,
            scope       => ''
        }
    );
    return $statement->(
        'wire', $st, Crypt::Ed25519::sign( $st, $kp{$root}[0], $kp{$root}[1] )
    );
};

######################################################################
say ': keys.key_id_arg';
{
    my $f = $code{'keys.key_id_arg'};
    ok( $f->( $fp->('06') ) eq $fp->('06'), 'a key id is taken as is' );
    ok( $f->( encode_b32r( $kp{'06'}[0] ) ) eq $fp->('06'),
        'a public key becomes its key id' );
    my ( $r, $why ) = $f->('NOPE');
    ok( !defined $r && $why =~ m|77 char|, 'garbage refused with a reason' );
}

######################################################################
say ': keys.console.owner-pin \ owner-pins \ owner-unpin';
{
    my $r   = run( 'keys.console.owner-pin', 'acme ' . $fp->('06') );
    my $pin = "$keys_dir/owners/acme.public";
    ok( !$r->{'err'} && slurp($pin) eq $fp->('06') . "\n",
        'owner pinned : one key id line' );
    ok( ( ( stat $pin )[2] & 07777 ) == 0600, '  :.. mode 0600' );
    ok( index( $r->{'out'}, "store $keys_dir/owners [ user " ) != -1,
        '  :.. names the store + user it wrote' );
    ok( ( ( stat "$keys_dir/owners" )[2] & 07777 ) == 0700,
        '  :.. owners/ 0700' );
    ok( $code{'auth.client.owner_pins'}->($keys_dir)->[0] eq $fp->('06'),
        '  :.. the client reader sees it' );
    $r = run( 'keys.console.owner-pin', 'acme ' . $fp->('06') );
    ok( $r->{'exit'} eq '0010' && $r->{'out'} =~ m|already pinned|,
        'same pin again : already pinned' );
    $r = run( 'keys.console.owner-pin', 'acme ' . $fp->('07') );
    ok( $r->{'exit'} eq '0010' && $r->{'out'} =~ m|owner-unpin acme|,
        'other key id under the same name : refused, unpin first'
    );
    $r = run( 'keys.console.owner-pin', '../x ' . $fp->('06') );
    ok( $r->{'exit'} eq '0010' && !-e "$keys_dir/x.public",
        'name with a slash : refused' );
    $r = run('keys.console.owner-pins');
    ok( $r->{'out'} =~ m|acme| && $r->{'out'} =~ m|distrust\n :\. none|,
        'owner-pins lists the owner, distrust none' );

    $r = run( 'keys.console.owner-unpin', 'acme' );
    ok( !$r->{'err'} && !-e $pin && glob("$pin.*.removed"),
        'owner-unpin : moved aside, not deleted'
    );
    ok( !@{ $code{'auth.client.owner_pins'}->($keys_dir) },
        '  :.. the client reader no longer sees it'
    );
    $r = run( 'keys.console.owner-unpin', 'acme' );
    ok( $r->{'exit'} eq '0010', 'unpin again : not pinned' );
}

######################################################################
say ': keys.console.distrust \ undistrust';
{
    my $list = sub { $code{'auth.client.distrust_list'}->($keys_dir) };
    my $r    = run( 'keys.console.distrust', $fp->('07') . ' beta lost' );
    ok( !$r->{'err'} && $list->()->[0] eq $fp->('07'),
        'distrusted : the client reader sees it'
    );
    ok( slurp("$keys_dir/distrust") eq $fp->('07') . "  # beta lost\n",
        '  :.. comment kept on the line' );
    ok( ( ( stat "$keys_dir/distrust" )[2] & 07777 ) == 0600,
        '  :.. mode 0600' );
    $r = run( 'keys.console.distrust', encode_b32r( $kp{'07'}[0] ) );
    ok( $r->{'exit'} eq '0010', 'same key as a public key : already' );
    $r = run( 'keys.console.distrust', $fp->('03') );
    ok( @{ $list->() } == 2, 'a second entry appended' );

    $r = run( 'keys.console.undistrust', $fp->('07') );
    ok( !$r->{'err'} && @{ $list->() } == 1 && $list->()->[0] eq $fp->('03'),
        'undistrust : only that entry removed'
    );
    ok( scalar( () = glob("$keys_dir/distrust.*.bak") ) >= 1,
        '  :.. the old list kept as .bak' );
    $r = run( 'keys.console.undistrust', $fp->('07') );
    ok( $r->{'exit'} eq '0010', 'undistrust again : not distrusted' );
    run( 'keys.console.undistrust', $fp->('03') );

    put( "$keys_dir/distrust", "garbage\n" );
    $r = run( 'keys.console.distrust', $fp->('07') );
    ok( $r->{'exit'} eq '0110' && slurp("$keys_dir/distrust") eq "garbage\n",
        'malformed list : refused, NOT rewritten'
    );
    $r = run('keys.console.owner-pins');
    ok( !!( $r->{'out'} =~ m|every connect REFUSED| ),
        '  :.. owner-pins says connects are refused'
    );
    unlink "$keys_dir/distrust";
}

######################################################################
say ': keys.console.certify-host';

my $cwd = getcwd();
chdir $work_dir or die;
my $owner_file = "$work_dir/atom.host-root.dlg";    ## printed absolute ##
{
    my $root_b32 = encode_b32r( $kp{'03'}[0] );
    ## plain : on disk, unencrypted ##
    put( "$key_dir/owner.secret", "stub\n" );
    my $r = run( 'keys.console.certify-host', "owner ATOM $root_b32" );
    ok( !$r->{'err'} && -f $owner_file,
        'certified : ./<host>.host-root.dlg written [ host lowercased ]' );
    ok( !!( $r->{'out'} =~ m|UNENCRYPTED| ),
        '  :.. plain ' . 'owner key : warned'
    );
    ok( index( $r->{'out'}, "written   $owner_file" ) != -1,
        '  :.. the ABSOLUTE output path is printed'
    );
    ok( !exists $keys{'C25519'}{'owner'}, '  :.. owner key unloaded' );
    my $wire = slurp($owner_file);
    chomp $wire;
    my $st = $statement->( 'parse_wire', $wire );
    ok( ref $st eq 'HASH'
            && $st->{'issuer_pub'} eq $kp{'06'}[0]
            && $st->{'subject_pub'} eq $kp{'03'}[0]
            && $st->{'name'} eq 'atom'
            && $st->{'scope'} eq 'atom.*',
        '  :.. owner -> host-root, name atom, scope atom.*'
    );
    ok( ref $st eq 'HASH' && abs(
            $st->{'not_after'} - $st->{'not_before'} - ( 365 * 86400 + 300 )
        ) <= 1,
        '  :.. 365 days [ not_before 5 min back ]'
    );
    my $v = $code{'trust.verify'}->(
        {   chain   => [ $wire, $leaf_for->( '03', 'atom.cube' ) ],
            anchors => [ $fp->('06') ],
            subject => $kp{'02'}[0],
            now     => time
        }
    );
    ok( ref $v eq 'HASH' && $v->{'depth'} == 2,
        '  :.. verifies above an atom.cube leaf under the owner' );

    $r = run( 'keys.console.certify-host', "owner atom $root_b32" );
    ok( $r->{'exit'} eq '0010' && $r->{'out'} =~ m|exists|,
        'output file exists : refused' );

    ## the host-root from a .dlg file [ the leaf's issuer ] ##
    put( "$work_dir/beta.dlg", $leaf_for->( '07', 'beta.cube' ) . "\n" );
    $owner_form = 'encrypted';
    $r          = run( 'keys.console.certify-host',
        "owner beta " . "$work_dir/beta.dlg 30" );
    my $bst = $statement->(
        'parse_wire',
        ( slurp("$work_dir/beta.host-root.dlg") // '' ) =~ s|\n\z||r
    );
    ok( ref $bst eq 'HASH' && $bst->{'subject_pub'} eq $kp{'07'}[0],
        'host-root taken from a .dlg file [ leaf issuer ]'
    );
    ok( $r->{'out'} !~ m|WARNING|, '  :.. encrypted owner key : no warning' );
    ok( ref $bst eq 'HASH'
            && $bst->{'not_after'} - $bst->{'not_before'} == 30 * 86400 + 300,
        '  :.. days argument honoured'
    );

    $owner_form = 'passphrase';
    unlink "$key_dir/owner.secret";
    $r = run( 'keys.console.certify-host', "owner gamma $root_b32" );
    ok( !!( $r->{'out'} =~ m|passphrase-derived| ),
        'passphrase-derived owner key : warned, still certified' );
    ok( -f "$work_dir/gamma.host-root.dlg", '  :.. file written' );

    $r = run( 'keys.console.certify-host', 'owner bad..name ' . $root_b32 );
    ok( $r->{'exit'} eq '0010', 'host name with an empty label : refused' );
    $r = run( 'keys.console.certify-host',
        'owner delta ' . encode_b32r( $kp{'06'}[0] ) );
    ok( $r->{'exit'} eq '0010' && $r->{'out'} =~ m|IS the host-root|,
        'owner == host-root : refused' );
    $owner_holder = 'root';
    $r            = run( 'keys.console.certify-host', "owner eps $root_b32" );
    ok( $r->{'exit'} eq '0020', 'root-held owner as non-root : refused' )
        if $EUID != 0;
    $owner_holder = 'user';
}
chdir $cwd or die;

######################################################################
say ': keys.console.accept-owner';
{
    ## this host : S public + the current .dlg leaf [ atom.cube ] ##
    put( "$key_dir/srv.base.public", encode_b32r( $kp{'02'}[0] ) . "\n" );
    my $leaf = $leaf_for->( '03', 'atom.cube' );
    put( "$key_dir/srv.base.dlg", "$leaf\n", 0644 );
    my $target = "$key_dir/host-root.dlg";

    my $r = run( 'keys.console.accept-owner', $owner_file );
    ok( !$r->{'err'} && slurp($target) eq slurp($owner_file),
        'accepted : host-root.dlg holds the owner statement'
    );
    ok( ( ( stat $target )[2] & 07777 ) == 0644,
        '  :.. mode ' . '0644 [ public ]'
    );
    $r = run( 'keys.console.accept-owner', $owner_file );
    ok( $r->{'exit'} eq '0010' && $r->{'out'} =~ m|already installed|,
        'same statement again : already installed' );

    my $before = slurp($target);
    $r = run( 'keys.console.accept-owner', "$work_dir/beta.host-root.dlg" );
    ok( $r->{'exit'} eq '0010' && slurp($target) eq $before,
        'statement for another host-root : refused, file untouched'
    );
    $r = run( 'keys.console.accept-owner', "$work_dir/gamma.host-root.dlg" );
    ok( $r->{'exit'} eq '0010' && $r->{'out'} =~ m|name outside issuer scope|,
        'scope gamma.* does not cover atom.cube : refused'
    );
    $r = run( 'keys.console.accept-owner', 'AAAA..AAAA' );
    ok( $r->{'exit'} eq '0010', 'malformed chain field : refused' );

    ## end to end : the client pins the owner, then decides via the owner ##
    run( 'keys.console.owner-pin', 'acme ' . $fp->('06') );
    my $owner_wire = slurp($target) =~ s|\n\z||r;
    my $d          = $code{'trust.pin_decide'}->(
        {   chain    => [ $owner_wire, $leaf ],
            subject  => $kp{'02'}[0],
            now      => time,
            host_pin => undef,
            owners   => $code{'auth.client.owner_pins'}->($keys_dir),
            distrust => $code{'auth.client.distrust_list'}->($keys_dir),
            strict   => TRUE,
        }
    );
    ok( ref $d eq 'HASH' && $d->{'verdict'} eq 'PIN_NEW' && $d->{'owner'},
        'end to end : certify -> accept -> owner-pin -> owner path [ strict ]'
    );
    run( 'keys.console.distrust', $fp->('03') );
    my ( $dd, $why ) = $code{'trust.pin_decide'}->(
        {   chain    => [ $owner_wire, $leaf ],
            subject  => $kp{'02'}[0],
            now      => time,
            host_pin => undef,
            owners   => $code{'auth.client.owner_pins'}->($keys_dir),
            distrust => $code{'auth.client.distrust_list'}->($keys_dir),
            strict   => TRUE,
        }
    );
    ok( !defined $dd && $why eq 'distrusted key in chain',
        '  :.. after distrust of that host-root : refused'
    );
}

say '';
say "passed : " . ( $test_count - $fail_count ) . "  failed : $fail_count";
exit( $fail_count ? 1 : 0 );

#,,,.,,..,,..,,,,,..,,,,,,,..,,,,,,,,,.,.,...,..,,...,..,,...,.,,,..,,,..,...,
#XNPHLQ7FBAFLUST7HK2N3ODVKPS2EZ3OGMCUIIQHRJQR5FGXY52Q5WHYT4WAIO5KEZO5U6UYEFDWK
#\\\|BLUYKEUZE4GFOPHNMSUX6IAKZZTNMS2MYRYI2OUKXAQ4XEDUFZF \ / AMOS7 \ YOURUM ::
#\[7]RNVHT445ULWJ3TWIY5O6CBXESPCVWN5VICFQ7NEL35JGD2V7VWBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
