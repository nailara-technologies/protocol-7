#!/usr/bin/env perl
use v5.24;
use strict;
use English;
use warnings;

# test script for the hints.* detection sources known_hosts + server pins
# [ todo Q7O, managed abstraction in
# data/ai-mem/claude/vision-managed-abstraction.md ] : compiles the real
# hints.* modules and drives them with FIXTURE FILES ONLY, inside a temp
# dir -- the real ~/.ssh/known_hosts and ~/.n/remote-keys are NEVER read
# here [ privacy ]. all fixture names and addresses are documentation-space
# : example.org names, 192.0.2.x -- no real host names. the hashed
# known_hosts lines are generated HERE with Digest::SHA, no real data is
# used. no zenka started, no network.

use File::Spec;
use Cwd        qw| abs_path |;
use FindBin    qw| $RealBin |;
use File::Temp qw| tempdir |;
use File::Path qw| make_path |;
use POSIX      ();    ## loaded in every zenka : POSIX::strftime in modules ##

use Digest::SHA  qw| hmac_sha1 |;
use MIME::Base64 qw| encode_base64 |;

use constant TRUE  => 5;
use constant FALSE => 0;

our %code;
our %data;
our %keys;

my $fail_count = 0;
my $pass_count = 0;

sub ok ($;$) {
    my ( $cond, $label ) = @ARG;
    if ($cond) { $pass_count++; say "  ok   : $label"; return }
    $fail_count++;
    say "  FAIL : $label";
    return;
}

##[ module loader ]###########################################################

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

my $runtime_pragmas
    = q{no bytes; use File::stat; use File::Spec::Functions qw| canonpath catfile catdir |;}
    . q{ use open qw| :encoding(UTF-8) |;};

sub compile_module {
    my ( $module_name, $prefix ) = @ARG;
    $prefix //= '';
    my $src_path
        = File::Spec->catfile( $main::root_path, 'src', $module_name );
    open( my $fh, '<', $src_path ) or die "cannot read $src_path : $!";
    my $src = join( '', <$fh> );
    close($fh);
    my $translated = p7_syntax__translate($src);
    my $cref
        = eval "$runtime_pragmas sub {\n$prefix\n# "
        . "line 1 \"$module_name\"\n$translated\n}";
    die "compile failed for $module_name : $EVAL_ERROR"
        if not defined $cref;
    $code{$module_name} = $cref;
    return $cref;
}

##[ fixture files in a temp dir ]#############################################

my $var_dir = tempdir( 'hints-var-XXXXXXXX', TMPDIR => TRUE, CLEANUP => 1 );

## nothing here resolves through the home dir, HOME is pointed at the temp dir
## for the duration of this test anyway so no real file can be reached
my $saved_home = $ENV{'HOME'};
$ENV{'HOME'} = $var_dir;
my $ssh_dir = File::Spec->catdir( $var_dir, qw| .ssh | );
File::Path::make_path($ssh_dir);

my $known_hosts_path = File::Spec->catfile( $ssh_dir, qw| known_hosts | );

## the hashed lines are generated here, with Digest::SHA, from the same
## documentation-space names -- no real known_hosts data is used
my $salt_plain = encode_base64( '0123456789abcdefghij', '' );
my $hash_plain = encode_base64(
    hmac_sha1( 'hashed.example.org', '0123456789abcdefghij' ), '' );
my $salt_ported = encode_base64( 'fedcba9876543210jihge', '' );
my $hash_ported = encode_base64(
    hmac_sha1( '[ported.example.org]:2222', 'fedcba9876543210jihge' ), '' );

## line numbers below are asserted : keep the layout in sync with the
## [ line N ] comments
my $known_hosts_fixture = <<"EO_KNOWN_HOSTS";
# test fixture known_hosts
plain.example.org ssh-ed25519 AAAAKCplainkeymaterial0000000000000000000000000
ported.example.org,port-alias.example.org ssh-ed25519 AAAAKCportedkeymateria
[ported.example.org]:2222 ssh-ed25519 AAAAKCportedbracketkeymaterial000000
*.lab.example.org,!bad.lab.example.org ssh-ed25519 AAAAKClabkeymaterial0000
docs?.example.org ssh-ed25519 AAAAKCdocskeymaterial0000000000000000000000000
\@revoked revoked.example.org ssh-ed25519 AAAAKCrevokedkeymaterial0000000000
\@cert-authority ca.example.org ssh-ed25519 AAAAKCcakeymaterial000000000000
|1|$salt_plain|$hash_plain ssh-ed25519 AAAAKChashedkeymaterial0000000000000
|1|$salt_ported|$hash_ported ssh-ed25519 AAAAKChashedportedkeymaterial0000
EO_KNOWN_HOSTS

{
    open( my $fh, '>', $known_hosts_path ) or die $!;
    print {$fh} $known_hosts_fixture;
    close($fh);
}

##[ server pin fixtures ]#####################################################

my $pins_dir = File::Spec->catdir( $var_dir, qw| .n remote-keys servers | );
File::Path::make_path($pins_dir);

my $pin_fortytwo
    = File::Spec->catfile( $pins_dir, qw| srv-one.example.org_42.public | );
my $pin_fortytwofortytwo
    = File::Spec->catfile( $pins_dir, qw| srv-one.example.org_4242.public | );

## the pin CONTENT is never read by the layer -- placeholder junk stands in,
## the test asserts on the file NAME only
my %pin_fixtures = (
    $pin_fortytwo => "FAKEKEYID000000000000000000000000000000000000"
        . "000000000000000000000000000000000000\n",
    $pin_fortytwofortytwo => "FAKEKEYID11111111111111111111111111111111111"
        . "1111111111111111111111111111111111111" . "\n",
    File::Spec->catfile( $pins_dir,
        qw| other-host.example.org_42.public | ) =>
        "FAKEKEYID22222222222222222222222222222222222222222222222222222\n",
    File::Spec->catfile( $pins_dir,
        qw| srv-one.example.org_70000.public | ) =>
        "FAKEKEYID33333333333333333333333333333333333333333333333333333\n",
    File::Spec->catfile( $pins_dir, qw| notes.txt | ) => "not a pin at all\n",
    File::Spec->catfile( $pins_dir, qw| broken.public | ) =>
        "a .public name without a port\n",
);

foreach my $path ( keys %pin_fixtures ) {
    open( my $fh, '>', $path ) or die $!;
    print {$fh} $pin_fixtures{$path};
    close($fh);
}

##[ compile the layer ]#######################################################

compile_module('hints.sanity');
compile_module('hints.candidate');
compile_module('hints.known_hosts');
compile_module('hints.server_pins');

my $known_hosts = $code{'hints.known_hosts'};
my $server_pins = $code{'hints.server_pins'};

sub candidates_for {
    my ( $field, $candidates ) = @ARG;
    return [ grep { $_->{'field'} eq $field } @$candidates ];
}

sub candidate_on_line {
    my ( $line, $candidates ) = @ARG;
    my ($found)
        = grep { $_->{'source'}{'line'} == $line } @$candidates;
    return $found;
}

##[ known_hosts : plain names + markers ]#####################################

say ': known_hosts plain + markers';

my @plain = $known_hosts->( $known_hosts_path, 'plain.example.org' );
ok(
    (           scalar @plain == 1
            and $plain[0]{'field'} eq 'known_host'
            and $plain[0]{'value'} eq 'plain.example.org'
            and $plain[0]{'source'}{'line'} == 2
            and $plain[0]{'source'}{'file'} eq $known_hosts_path
            and $plain[0]{'note'} =~ m{ssh-ed25519, plain entry}
    ),
    'a plain name entry corroborates the asked name [ no value, source kept ]'
);
ok( ( not defined $plain[0]{'conflicting'} ),
    'a plain entry is not a conflict'
);

my @alias = $known_hosts->( $known_hosts_path, 'port-alias.example.org' );
ok(
    (           scalar @alias == 1
            and $alias[0]{'source'}{'line'} == 3
            and $alias[0]{'source'}{'context'} eq
            'ported.example.org,port-alias.example.org'
    ),
    'the second name of a comma-separated entry matches too'
);

my @revoked = $known_hosts->( $known_hosts_path, 'revoked.example.org' );
ok(
    (           scalar @revoked == 1
            and $revoked[0]{'conflicting'}
            and $revoked[0]{'note'} =~ m{revoked}
    ),
    '\@revoked is a conflict marker, never a positive'
);

my @ca = $known_hosts->( $known_hosts_path, 'ca.example.org' );
ok(
    (           scalar @ca == 1
            and $ca[0]{'note'} =~ m{cert-authority}
            and not defined $ca[0]{'conflicting'}
    ),
    '\@cert-authority still corroborates, noted as such'
);

##[ known_hosts : patterns + negation ]#######################################

say ': known_hosts patterns + negation';

my @good_lab = $known_hosts->( $known_hosts_path, 'good.lab.example.org' );
ok( ( scalar @good_lab == 1 and $good_lab[0]{'source'}{'line'} == 5 ),
    "'*.lab.example.org' matches good.lab.example.org" );

my @bad_lab = $known_hosts->( $known_hosts_path, 'bad.lab.example.org' );
ok( scalar @bad_lab == 0,
    "'!bad.lab.example.org' negates the wildcard on the same entry" );

my @docs1 = $known_hosts->( $known_hosts_path, 'docs1.example.org' );
ok( ( scalar @docs1 == 1 and $docs1[0]{'source'}{'line'} == 6 ),
    "'?' in docs?.example.org matches docs1.example.org"
);

my @docs12 = $known_hosts->( $known_hosts_path, 'docs12.example.org' );
ok( scalar @docs12 == 0, "'?' matches exactly one character" );

##[ known_hosts : hashed entries ]############################################

say ': known_hosts hashed';

my @hashed = $known_hosts->( $known_hosts_path, 'hashed.example.org' );
ok(
    (           scalar @hashed == 1
            and $hashed[0]{'source'}{'line'} == 9
            and $hashed[0]{'note'} =~ m{ssh-ed25519, hashed entry}
    ),
    'a hashed entry matches when the HMAC-SHA1 of the name checks out'
);

my @not_hashed = $known_hosts->( $known_hosts_path, 'nothashed.example.org' );
ok( scalar @not_hashed == 0,
    'a hashed entry for another name does NOT match' );

##[ known_hosts : ports ]#####################################################

say ': known_hosts ports';

my @ported_2222
    = $known_hosts->( $known_hosts_path, 'ported.example.org', '2222' );
ok( scalar @ported_2222 == 3,
    'asked with a port, plain + bracketed + hashed entries all answer' );

my $bracket_pos = candidate_on_line( 4, \@ported_2222 );
ok(
    (           defined $bracket_pos
            and $bracket_pos->{'note'} =~ m{plain entry}
            and $bracket_pos->{'note'} !~ m{asked port}
    ),
    "'[host]:port' on the asked port counts as known"
);

my $hashed_pos = candidate_on_line( 10, \@ported_2222 );
ok(
    (           defined $hashed_pos
            and $hashed_pos->{'note'} =~ m{hashed entry}
            and $hashed_pos->{'note'} !~ m{asked port}
    ),
    'the hashed [host]:port form matches the asked port'
);

my $port_mismatch = candidate_on_line( 3, \@ported_2222 );
ok(
    (   defined $port_mismatch
            and $port_mismatch->{'note'}
            =~ m{entry for port 22, asked port 2222}
    ),
    'a plain [ port-22 ] entry on a different '
        . 'asked port is noted, not counted as known'
);

my @ported_22
    = $known_hosts->( $known_hosts_path, 'ported.example.org', '22' );
my $plain_pos = candidate_on_line( 3, \@ported_22 );
ok(
    (           defined $plain_pos
            and $plain_pos->{'note'} !~ m{asked port}
            and candidate_on_line( 4, \@ported_22 )->{'note'}
            =~ m{entry for port 2222, asked port 22}
    ),
    'the plain entry counts on the asked port 22, the bracket one is noted'
);

my @ported_any = $known_hosts->( $known_hosts_path, 'ported.example.org' );
ok(
    (           scalar @ported_any == 2
            and ( grep { $_->{'source'}{'line'} == 4 } @ported_any ) == 1
            and ( grep { $_->{'note'} =~ m{asked port} } @ported_any ) == 0
    ),
    'without a port every name-matching entry corroborates [ a '
        . 'hashed [host]:port entry cannot be enumerated without a port ]'
);

my @ported_2200
    = $known_hosts->( $known_hosts_path, 'ported.example.org', '2200' );
ok(
    (   scalar @ported_2200 == 2
            and candidate_on_line( 4, \@ported_2200 )->{'note'}
            =~ m{entry for port 2222, asked port 2200}
            and candidate_on_line( 3, \@ported_2200 )->{'note'}
            =~ m{entry for port 22, asked port 2200}
    ),
    'asked for a port nobody knows, each entry is noted with its own port'
);

ok( scalar @{
        [   $known_hosts->(
                File::Spec->catfile( $ssh_dir, qw| not_there | ),
                'plain.example.org'
            )
        ]
    } == 0,
    'a missing known_hosts path yields nothing'
);
ok( scalar @{ [ $known_hosts->( $known_hosts_path, '' ) ] } == 0,
    'an empty host name yields nothing' );

##[ server pins : names, ports, non-pins ignored ]############################

say ': server pins';

my @pins = $server_pins->( $pins_dir, 'srv-one.example.org' );

my $pin_ports = candidates_for( 'cube_port', \@pins );
ok(
    (   scalar @$pin_ports == 2
            and join( q{,}, sort map { $_->{'value'} } @$pin_ports ) eq
            '42,4242'
    ),
    'two pins of one host give one cube_port candidate each'
);
ok(
    (   grep {
                    $_->{'note'} eq 'pinned server key'
                and $_->{'source'}{'file'} eq $pin_fortytwo
                and $_->{'source'}{'line'} == 0
                and $_->{'source'}{'context'} eq
                'srv-one.example.org_42.public'
        } @$pin_ports
    ) == 1,
    'a pin candidate names the pin file as source, line 0, note set'
);

my $pin_addr = candidates_for( 'addresses', \@pins );
ok(
    (   scalar @$pin_addr == 2
            and ( grep { $_->{'value'} eq 'srv-one.example.org' } @$pin_addr )
            == 2
    ),
    'each pin also corroborates the host name as an addresses candidate'
);

my $one_pin = $pin_addr->[0];
ok(
    (   ref $one_pin eq qw| HASH |
            and join( q{,}, sort keys %$one_pin ) eq
            'field,note,source,value'
            and join( q{,}, sort keys %{ $one_pin->{'source'} } ) eq
            'context,file,line'
    ),
    'a pin candidate is exactly field, '
        . 'value, source[ file line context ], note'
);

ok(
    (   scalar @pins == 4
            and (
            grep {
                $_->{'source'}{'file'}
                    =~ m{other-host|70000|notes\.txt|broken\.public}
            } @pins
            ) == 0
    ),
    'a different-host pin, an out-of-range '
        . 'port pin and non-pin files are ignored'
);

ok( scalar @{
        [   $server_pins->(
                File::Spec->catdir( $var_dir, qw| .n remote-keys nowhere | ),
                'srv-one.example.org'
            )
        ]
    } == 0,
    'a missing pins dir yields nothing'
);
ok( scalar $server_pins->( $pins_dir, 'other-host.example.org' ) == 2,
    'asking for the other host yields only its own pin candidates'
);

##[ sanity stamp : both sources route through hints.candidate ]###############

say ': sanity stamp';

my @stamped = (
    $code{'hints.known_hosts'}->( $known_hosts_path, 'plain.example.org' ),
    $code{'hints.server_pins'}->( $pins_dir,         'srv-one.example.org' ),
);
ok( ( @stamped > 0 and not grep { exists $_->{'rejected'} } @stamped ),
    'valid known_host + pin candidates pass sanity [ nothing rejected ]'
);
my $bad = $code{'hints.candidate'}->( qw| cube_port |, '70000',
    { file => 'x', line => 1, context => 'x' } );
ok( ( $bad->{'rejected'} // '' ) =~ m{out of range},
    'sanity knows cube_port : an out-of-range '
        . 'pin port is rejected with reason'
);

##[ summary ]#################################################################

$ENV{'HOME'} = $saved_home;

say '';
if ( $fail_count == 0 ) {
    say sprintf '[ done ] %d checks, all passed', $pass_count;
    exit 0;
}
say sprintf '[ done ] %d passed, %d FAILED', $pass_count, $fail_count;
exit 1;

#,,,.,,,,,,.,,...,.,.,.,.,,,.,.,,,,,.,,.,,,.,,..,,...,...,..,,...,.,,,...,.,.,
#HYBYIOGGC3H5QZQTJF6LUP5F2726KTWHPQUUTWX3YT2QESZGBME4KYGVVYUQAA3KFXEUPQ53YW3EK
#\\\|XDDL2GRDDI4BLFFUM73BEMPJSWL4YTZPW2SMI4E2LUYS2H36BVR \ / AMOS7 \ YOURUM ::
#\[7]F2ME7SKKBO3K6L423TZWQZ7YWNQZEZ3GDDKUB2SL7ST2TIRSW6DY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
