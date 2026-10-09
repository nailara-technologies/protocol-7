#!/usr/bin/env perl
use v5.24;
use strict;
use English;
use warnings;

## the production runtime loads the bytes pragma transitively ##
use bytes;

## host-edit lane B2c : the add-host FLOW [ host-edit.flow.* ] driven with  ##
## a pumped timer queue -- pin-only live [ fake ssh, compiled p-7-r, temp   ##
## HOME ], the owner path with the actions stubbed [ tested on their own ]. ##
## was : host-edit lane B2b : ssh forward + probe [                         ##
## data/md/design/HOST-SETUP.md 'add-host flow' ]. a FAKE ssh [ a local     ##
## port forwarder ] replaces the real one, p-7-r is compiled from bin/c_src ##
## into a temp dir [ the installed one may predate -host ] and the probe    ##
## runs against the LIVE cube on 127.0.0.1:42 -- strict only : the client   ##
## pin store must be byte-identical afterwards. skips cleanly without gcc   ##
## or a cube.                                                               ##

use File::Spec;
use Cwd        qw| abs_path |;
use FindBin    qw| $RealBin |;
use File::Temp qw| tempdir |;
use File::Path;
use IO::Socket::INET;
use Crypt::Misc;
use Digest::BMW;

BEGIN {
    my $up = File::Spec->updir;
    my $root
        = abs_path(
        File::Spec->rel2abs( File::Spec->catdir( $RealBin, $up, $up ) ) );
    unshift( @INC, File::Spec->catdir( $root, qw| data lib-path pm | ) );
    $main::root_path = $root;
}

use AMOS7::Protocol::P7Syntax qw| p7_syntax__translate |;

use constant TRUE    => 5;
use constant FALSE   => 0;
use constant UNKNOWN => 2;

our %code;
our %data;
our %keys;

my ( $test_count, $fail_count ) = ( 0, 0 );

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
    my $cref = eval "$runtime_pragmas sub {\n# line 1 \"$module_name\"\n"
        . p7_syntax__translate($src) . "\n}";
    die "compile failed for $module_name : $EVAL_ERROR" if not defined $cref;
    $code{$module_name} = $cref;
    return $cref;
}

compile_module($ARG)
    for
    qw| host-edit.transport.free_port host-edit.transport.ssh_forward_start
    host-edit.transport.forward_ready host-edit.transport.ssh_forward_stop
    host-edit.action.probe host-edit.action.run_p7r host-edit.action.pin
    host-edit.action.fetch_chain host-edit.action.install
    host-edit.flow.start host-edit.flow.step host-edit.flow.schedule
    host-edit.flow.status host-edit.flow.passphrase host-edit.flow.cancel
    host-edit.flow.needs_passphrase host-edit.record.name_valid
    host-edit.record.name_is_host host-edit.flow.form_values
    keystore.remote_keys_dir
    trust.statement trust.key_id trust.chain |;

my $tmp = tempdir( CLEANUP => 1 );

## never leave a forward [ fake ssh ] running, whatever happens ##
END {
    $code{'host-edit.transport.ssh_forward_stop'}->()
        if ref $code{'host-edit.transport.ssh_forward_stop'} eq 'CODE';
}

## every pin file : name + content [ the store must not change ] ##
sub snapshot_pins {
    my ($dir) = @ARG;
    my @all;
    foreach my $file ( sort glob("$dir/*") ) {
        open( my $fh, '<', $file ) or next;
        local $INPUT_RECORD_SEPARATOR = undef;
        push @all, "$file:" . ( readline($fh) // '' );
        close($fh);
    }
    return join "\n", @all;
}

## --- a fake ssh : forwards -L 127.0.0.1:<L>:127.0.0.1:<R> locally --- ##
my $fake_ssh = File::Spec->catfile( $tmp, 'fake-ssh' );
open( my $sfh, '>', $fake_ssh ) or die;
print {$sfh} <<'FAKE';
#!/usr/bin/env perl
use strict; use warnings; use IO::Socket::INET; use IO::Select;
my ($spec) = map { $ARGV[$_+1] } grep { $ARGV[$_] eq '-L' } 0 .. $#ARGV;
exit 3 if grep { $_ eq 'fail@nowhere' } @ARGV;
my ( undef, $lport, undef, $rport ) = split /:/, $spec;
my $srv = IO::Socket::INET->new( LocalAddr => '127.0.0.1', LocalPort => $lport,
    Listen => 5, ReuseAddr => 1 ) or exit 2;
$SIG{CHLD} = 'IGNORE';
while ( my $c = $srv->accept ) {
    next if fork;
    my $r = IO::Socket::INET->new( PeerAddr => '127.0.0.1', PeerPort => $rport ) or exit 4;
    my $sel = IO::Select->new( $c, $r );
    while ( my @ready = $sel->can_read ) {
        for my $fh (@ready) {
            my $n = sysread( $fh, my $buf, 65536 );
            exit 0 if not $n;
            syswrite( $fh == $c ? $r : $c, $buf );
        }
    }
    exit 0;
}
FAKE
close($sfh);
chmod 0755, $fake_ssh;
$data{'host-edit'}{'cfg'}{'ssh_bin'} = $fake_ssh;

## --- the event loop, pumped by the test : add_timer queues the cb ------ ##
my @queue;
$code{'event.add_timer'} = sub {
    my $p = shift;
    push @queue, [ time + ( $p->{'after'} // 0 ), $p->{'cb'} ];
    return 1;
};

sub pump {    ## run queued steps until none is left [ max 30 s ] ##
    my $deadline = time + 30;
    while ( @queue and time < $deadline ) {
        my $job  = shift @queue;
        my $wait = $job->[0] - time;
        select( undef, undef, undef, $wait ) if $wait > 0;
        $job->[1]->();
    }
    return;
}
my @status;
$code{'form.chrome.set_status'} = sub { push @status, shift; return 1 };

my %record;
$code{'host-edit.record.read'} = sub {
    return { name => $ARG[0], fields => {%record} };
};
my $flow = sub { $data{'host-edit'}{'flow'}{ shift() } };

######################################################################
say ': flow [ pin only, live : fake ssh -> p-7-r -> the live cube ]';

my $cube_up = IO::Socket::INET->new(
    PeerAddr => '127.0.0.1',
    PeerPort => 42,
    Timeout  => 1
);
my $gcc = grep { -x "$ARG/gcc" } split m|:|, $ENV{'PATH'} // '';
if ( not $cube_up or not $gcc ) {
    say '  skip : no cube on 127.0.0.1:42 or no gcc';
} else {
    close($cube_up);
    my $p7r = File::Spec->catfile( $tmp, 'p-7-r' );
    system( 'gcc', '-O2', '-o', $p7r,
        File::Spec->catfile( $main::root_path, qw| bin c_src p-7-r.c | ) )
        == 0
        or die 'p-7-r did not compile';
    $data{'host-edit'}{'cfg'}{'p7r_bin'} = $p7r;
    $ENV{'PROTOCOL_7_BIN_P7R_USER'} //= getpwuid($UID);

    my $home = File::Spec->catdir( $tmp, 'home' );
    mkdir $home;
    local $ENV{'HOME'}                   = $home;
    local $code{'crypt.C25519.key_vars'} = sub {
        return { known_hosts_dir => "$home/.n/remote-keys/servers" };
    };
    %record = (
        addresses => ['127.0.0.1:42'],
        ssh       => 'tester@localhost',
        ssh_port  => 22,
        owner_key => '',
    );
    my ( $ok_, $why ) = $code{'host-edit.flow.start'}->('zz-test');
    ok( $ok_, 'flow started' ) or say "    got : $why";
    pump();
    my $s = $flow->('zz-test');
    ok( $s->{'step'} eq 'done' && $s->{'status'} eq 'pinned',
        'connect -> forward -> probe -> pin -> done'
    ) or say "    got : $s->{'step'} : " . ( $s->{'status'} // '?' );
    ok( -f "$home/.n/remote-keys/servers/zz-test_42.public",
        '  :.. the pin is named after the record'
    );
    ok( !exists $data{'host-edit'}{'forwards'}{'zz-test'},
        '  :.. the ssh forward is stopped at the end'
    );
    ok( scalar( grep {m|probing the host-root|} @status )
            && scalar( grep {m|pinning |} @status ),
        '  :.. every step reported on the status line'
    );

    ( $ok_, $why ) = $code{'host-edit.flow.start'}->('zz-test');
    pump();
    ok( $flow->('zz-test')->{'step'} eq 'done'
            && grep( {m|already pinned|} @status ),
        'a second run : already pinned -> done'
    );
}

######################################################################
say ': flow [ no address : the record name as the address ]';
{
    %record = ( addresses => [], ssh => '', owner_key => '' );

    my ( $ok_, $why ) = $code{'host-edit.flow.start'}->('zz-test');
    ok( !$ok_ && ( $why // '' ) eq 'the record has no address',
        'undotted record name without address : refused as before'
    );

    @status = ();
    ( $ok_, $why ) = $code{'host-edit.flow.start'}->('zz-host.example');
    my $s = $flow->('zz-host.example') // {};
    ok( $ok_
            && ( $s->{'host'}      // '' ) eq 'zz-host.example'
            && ( $s->{'cube_port'} // '' ) eq '42',
        'host-named record without address : dials its name, port 42'
    ) or say "    got : " . ( $why // $s->{'host'} // '?' );
    ok( scalar( grep {m|no address : dialling zz-host\.example|} @status ),
        '  :.. the status says the name is dialled' );

    ## not run here : drop the flow, its queued step then finds nothing ##
    delete $data{'host-edit'}{'flow'}{'zz-host.example'};
}

######################################################################
say ': flow [ unsaved form values ]';
{
    ## form_values : the flow fields as the form shows them [ editor stubbed :
    ## collapse returns the state, get_value reads the field defaults ]
    local $code{'editor.control.list.collapse'} = sub { return $ARG[0] };
    local $code{'editor.control.get_value'}     = sub {
        my ( $state, $name ) = @ARG;
        my ($def)
            = grep { $ARG->{'name'} eq $name }
            @{ $state->{'schema'}{'fields'} };
        return $def->{'default'};
    };
    my $form_state = {
        'schema' => {
            'fields' => [
                { 'name' => 'ssh',      'default' => 'typed@zz-host' },
                { 'name' => 'ssh_port', 'default' => '2242' },
                { 'name' => 'roles',    'default' => 'ignored' },
                {   'name'    => 'addresses',
                    'list'    => TRUE,
                    'entries' => [ 'zz-host.example:42', '' ]
                },
            ]
        }
    };
    my $fv = $code{'host-edit.flow.form_values'}->($form_state);
    ok( ( $fv->{'ssh'} // '' ) eq 'typed@zz-host'
            && ( $fv->{'ssh_port'} // '' ) eq '2242'
            && join( ',', @{ $fv->{'addresses'} // [] } ) eq
            'zz-host.example:42'
            && !exists $fv->{'roles'},
        'form_values : flow fields only, list entries without empty rows'
    );

    ## the saved record has no ssh : the form value wins and is noted ##
    %record
        = ( addresses => ['zz-host.example:42'], ssh => '', owner_key => '' );
    @status = ();
    my ( $ok_, $why ) = $code{'host-edit.flow.start'}->(
        'zz-host.example', { 'ssh' => 'typed@zz-host', 'ssh_port' => 2242 }
    );
    my $s = $flow->('zz-host.example') // {};
    ok( $ok_
            && ( $s->{'ssh'}      // '' ) eq 'typed@zz-host'
            && ( $s->{'ssh_port'} // '' ) eq '2242',
        'flow.start : unsaved form values win over the saved record'
    ) or say "    got : " . ( $why // '?' );
    ok( scalar( grep {m|unsaved form values used|} @status ),
        '  :.. the status says unsaved values are used'
    );
    delete $data{'host-edit'}{'flow'}{'zz-host.example'};

    ## the same values as saved : no note ##
    @status = ();
    $code{'host-edit.flow.start'}->(
        'zz-host.example',
        { 'addresses' => ['zz-host.example:42'], 'ssh' => '' }
    );
    ok( !grep( {m|unsaved|} @status ),
        '  :.. form values equal to the record : no unsaved note' );
    delete $data{'host-edit'}{'flow'}{'zz-host.example'};
}

######################################################################
say ': flow [ owner path, actions stubbed ]';
{
    %record = (
        addresses => ['zz-host.example:42'],
        ssh       => '',
        owner_key => 'test-owner',
    );
    my %called;
    local $code{'host-edit.action.probe'} = sub {
        return { state => 'unpinned', key_id => 'K' x 77, name => 'zz.cube' };
    };
    local $code{'host-edit.action.pin'} = sub {
        $called{'pin'} = [@ARG];
        return { state => 'pinned' };
    };
    local $code{'host-edit.action.fetch_chain'} = sub {
        $called{'fetch'} = [@ARG];
        return { field => 'F' x 120, root_pub => 'R' x 32 };
    };
    local $code{'host-edit.flow.needs_passphrase'} = sub { return 5 };
    local $code{'keys.certify_host'}               = sub {
        $called{'certify'} = { %{ $ARG[0] } };
        return { wire => 'W' x 300, owner_pub => 'O' x 32 };
    };
    local $code{'host-edit.action.install'} = sub {
        $called{'install'} = [@ARG];
        return { state => 'installed' };
    };

    ## the owner pin [ record 'owner' ] names the key id certify expects ##
    my $own_home = File::Spec->catdir( $tmp, 'own-home' );
    File::Path::make_path("$own_home/.n/remote-keys/owners");
    open( my $pfh, '>', "$own_home/.n/remote-k" . "eys/owners/acme.public" )
        or die;
    print {$pfh} 'P' x 77, "\n";
    close($pfh);
    local $code{'base.get_homedir'} = sub { return $own_home };
    $record{'owner'} = 'acme';

    $code{'host-edit.flow.start'}->('zz-own');
    pump();
    my $s = $flow->('zz-own');
    ok( $s->{'step'} eq 'need_passphrase' && !exists $called{'certify'},
        'stops at need_passphrase, nothing certified yet'
    );
    ok( $called{'pin'}[4] eq 'K' x 77 && $called{'fetch'}[4] eq 'K' x 77,
        '  :.. pin + fetch got the PROBED key id' );
    ok( $called{'pin'}[2] eq 'zz-host.example' && $called{'pin'}[3] == 42,
        '  :.. no ssh : dialled the address directly' );
    ok( !$code{'host-edit.flow.passphrase'}->( 'zz-own', '' ),
        'an empty passphrase does not resume' );
    ok( $code{'host-edit.flow.passphrase'}->( 'zz-own', 'pass-phrase' ),
        'the passphrase resumes the flow' );
    pump();
    $s = $flow->('zz-own');
    ok( $called{'certify'}{'passphrase'} eq 'pass-phrase'
            && $called{'certify'}{'owner'} eq 'test-owner'
            && $called{'certify'}{'host'} eq 'zz-own'
            && $called{'certify'}{'root_pub'} eq 'R' x 32,
        'certify : owner key + passphrase + the FETCHED host-root key'
    );
    ok( !exists $s->{'passphrase'}, '  :.. the passphrase is not kept' );
    ok( $called{'certify'}{'expect_id'} eq 'P' x 77,
        '  :.. expect_id = the owner pin\'s key id [ a wrong phrase fails ]'
    );
    ok( $called{'install'}[4] eq 'W' x 300,
        'install : the certified statement'
    );
    ok( $s->{'step'} eq 'done' && $s->{'status'} =~ m|owner-certified|,
        'done : owner-certified' )
        or say "    got : $s->{'step'} : " . ( $s->{'status'} // '?' );

    ## owner set but no such pin : an error before anything is certified ##
    $record{'owner'} = 'no-such-owner';
    %called = ();
    $code{'host-edit.flow.start'}->('zz-own');
    pump();
    $code{'host-edit.flow.passphrase'}->( 'zz-own', 'pass-phrase' );
    pump();
    $s = $flow->('zz-own');
    ok( $s->{'step'} eq 'error'
            && $s->{'status'} =~ m|owner pin 'no-such-owner' not found|
            && !exists $called{'certify'},
        'owner pin missing : error, nothing certified'
    );
    $record{'owner'} = 'acme';

    ## the host-root differs from the pin : an error, never re-pinned ##
    local $code{'host-edit.action.probe'}
        = sub { return { state => 'mismatch', key_id => 'X' x 77 } };
    %called = ();
    $code{'host-edit.flow.start'}->('zz-own');
    pump();
    $s = $flow->('zz-own');
    ok( $s->{'step'} eq 'error'
            && $s->{'status'} =~ m|DIFFERS from the pin|
            && !exists $called{'pin'},
        'a host-root mismatch : error, nothing pinned'
    );
}

######################################################################
say ': needs_passphrase [ which owner keys make the form ask ]';
{
    my $tdir = File::Spec->catdir( $tmp, 'keys' );
    mkdir $tdir;
    my ( $holder, $encrypted, $virtual ) = ( 'user', 0, 0 );
    local $code{'crypt.C25519.key_path'} = sub {
        my $b = "$tdir/$ARG[0]";
        return {
            holder       => $holder,
            key_filename => { secret => "$b.secret", private => "$b.private" }
        };
    };
    local $code{'crypt.C25519.encrypted_key'}  = sub {$encrypted};
    local $code{'crypt.C25519.key_is_virtual'} = sub {$virtual};
    my $needs = $code{'host-edit.flow.needs_passphrase'};
    open( my $fh, '>', "$tdir/plain.secret" ) or die;
    close($fh);
    ok( !$needs->('plain'), 'a plain key on disk : no passphrase' );
    $encrypted = 5;
    ok( $needs->('plain'), 'an encrypted key on disk : passphrase' );
    $encrypted = 0;
    ok( $needs->('derived'),
        'a passphrase-derived key [ ' . 'nothing on disk ] : passphrase' );
    $virtual = 5;
    ok( $needs->('seed'),
              'a VIRTUAL seed-phrase key : passphrase '
            . '[ the network authority form ]' );
    $holder = 'root';
    ok( !$needs->('rooted'), 'a root-held key : no passphrase' );
}

######################################################################
say ': flow [ a dead ssh ]';
{
    %record = (
        addresses => ['127.0.0.1:42'],
        ssh       => 'fail@nowhere',
        ssh_port  => 22,
        owner_key => '',
    );
    $code{'host-edit.flow.start'}->('zz-dead');
    pump();
    my $s = $flow->('zz-dead');
    ok( $s->{'step'} eq 'error' && $s->{'status'} =~ m|known_hosts|,
        'ssh exits : error with the known_hosts hint' );
    ok( !exists $data{'host-edit'}{'forwards'}{'zz-dead'},
        '  :.. no forward left behind' );
}

say '';
say "passed : " . ( $test_count - $fail_count ) . "  failed : $fail_count";
exit( $fail_count ? 1 : 0 );

#,,.,,,.,,.,.,,.,,,,,,.,.,,..,,..,.,.,.,,,,..,..,,...,...,..,,,.,,.,.,...,...,
#7POSHPNR3IXNAOAHLUJBZH6PKSC32X7DR6CIWSRBCNB2BB2D6LPVVC6H4EWF7UFG67Y6SQERBKKZA
#\\\|2EEIPARM5RPAFZMVRCOAFMV2CLOO32BT7EO2LITJQJOYWVVTJI7 \ / AMOS7 \ YOURUM ::
#\[7]QZMAFMLYQPYFSAYZ6IZ37DFHKFHERQ2NGSQZCQAEL257BI7UQSAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
