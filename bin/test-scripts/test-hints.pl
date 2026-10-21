#!/usr/bin/env perl
use v5.24;
use strict;
use English;
use warnings;

# test script for the hints.* detection layer [ todo Q7O, first piece of
# the 'managed abstraction' principle in
# data/ai-mem/claude/vision-managed-abstraction.md ] : compiles the real
# hints.* modules and drives them with FIXTURE FILES ONLY, inside a temp
# dir -- the real ~/.ssh/config and /etc/hosts are NEVER read here
# [ privacy ]. all fixture names and addresses are documentation-space :
# example.org names, 192.0.2.x and 2001:db8:: -- no real host names.
# no zenka started, no network.

use File::Spec;
use Cwd        qw| abs_path |;
use FindBin    qw| $RealBin |;
use File::Temp qw| tempdir |;
use File::Path qw| make_path |;
use POSIX      ();    ## loaded in every zenka : POSIX::strftime in modules ##

use constant TRUE    => 5;
use constant FALSE   => 0;
use constant UNKNOWN => 2;

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

sub register_stub {
    my ( $name, $cref ) = @ARG;
    $code{$name} = $cref;
    return;
}

##[ fixture files in a temp dir ]#############################################

my $var_dir = tempdir( 'hints-var-XXXXXXXX', TMPDIR => TRUE, CLEANUP => 1 );

## include resolution is '~/.ssh' relative -- point HOME at the fixture dir
## for the duration of this test so no real file can be reached
my $saved_home = $ENV{'HOME'};
$ENV{'HOME'} = $var_dir;
my $ssh_dir = File::Spec->catdir( $var_dir, qw| .ssh | );
File::Path::make_path($ssh_dir);

my $ssh_config_path = File::Spec->catfile( $ssh_dir, qw| config | );

## line numbers below are asserted : keep the layout in sync with the
## [ line N ] comments
my $ssh_config_fixture = <<'EO_CONFIG';
# test fixture ssh config
Include extra_*.conf

Host atom
    HostName atom.example.org
    Port 2222
    User alice

Host kv
    HostName=kv.example.org
    Port=2200

Host *.lab !bad.lab
    HostName lab.example.org
    Port 2201

Host badport
    HostName badport.example.org
    Port 70000

Host *
    Port 4242
    HostName other.example.org

Match host atom
    Port 9999
EO_CONFIG

{
    open( my $fh, '>', $ssh_config_path ) or die $!;
    print {$fh} $ssh_config_fixture;
    close($fh);
}

my $included_config_path
    = File::Spec->catfile( $ssh_dir, qw| extra_one.conf | );
{
    open( my $fh, '>', $included_config_path ) or die $!;
    print {$fh} <<'EO_INCLUDED';
Host includee
    HostName included.example.org
    Port 2022
EO_INCLUDED
    close($fh);
}

my $etc_hosts_path = File::Spec->catfile( $var_dir, qw| hosts | );
{
    open( my $fh, '>', $etc_hosts_path ) or die $!;
    print {$fh} <<'EO_HOSTS';
# test fixture hosts file
192.0.2.10 docs-one.example.org docs1
2001:db8::10 docs-v6.example.org v6alias
EO_HOSTS
    close($fh);
}

##[ compile the layer ]#######################################################

compile_module('hints.sanity');
compile_module('hints.candidate');
compile_module('hints.conflicts');
compile_module('hints.ssh_config');
compile_module('hints.etc_hosts');
compile_module('base.file.glob');

my $ssh_config = $code{'hints.ssh_config'};
my $etc_hosts  = $code{'hints.etc_hosts'};

sub candidates_for {
    my ( $field, $candidates ) = @ARG;
    return [ grep { $_->{'field'} eq $field } @$candidates ];
}

sub values_of {
    my ($candidates) = @ARG;
    return [ map { $_->{'value'} // '' } @$candidates ];
}

##[ ssh config : alias with HostName + Port + User ]##########################

say ': ssh config alias';

my @atom = $ssh_config->( $ssh_config_path, 'atom' );

my $addresses = candidates_for( 'addresses', \@atom );
ok(
    (   scalar @$addresses == 1
            and $addresses->[0]{'value'} eq 'atom.example.org'
    ),
    'HostName of the matching alias becomes an addresses candidate'
);
ok( $addresses->[0]{'source'}{'line'} == 5,
    'the candidate keeps its source line'
);
ok( $addresses->[0]{'source'}{'context'} eq 'Host atom',
    'the candidate keeps the Host block as context'
);
ok( $addresses->[0]{'source'}{'file'} eq $ssh_config_path,
    'the candidate keeps its source file' );

my $ports = candidates_for( 'ssh_port', \@atom );
ok( ( scalar @$ports == 1 and $ports->[0]{'value'} eq '2222' ),
    'Port of the matching alias becomes an ssh_port candidate'
);
ok( $ports->[0]{'source'}{'line'} == 6, 'port keeps its source line' );
ok(
    (           ( not grep { $_->{'value'} eq '4242' } @$ports )
            and ( not grep { $_->{'value'} eq '9999' } @$ports )
    ),
    'later Host block and Match block ports did not leak in'
);
ok( ( grep { defined $_->{'shadowed_by_match'} } @atom ) == 0,
    'a Match AFTER the statement never shadows [ first value wins ]'
);

my $ssh = candidates_for( 'ssh', \@atom );
ok( ( scalar @$ssh == 1 and $ssh->[0]{'value'} eq 'alice@atom.example.org' ),
    'the ssh target composes User and HostName'
);

my $users = candidates_for( 'ssh_user', \@atom );
ok( ( scalar @$users == 1 and $users->[0]{'value'} eq 'alice' ),
    'User becomes an ssh_user candidate' );

##[ ssh config : wildcard + negation, first value wins ]######################

say ': ssh config wildcard + first-wins';

my @good_lab  = $ssh_config->( $ssh_config_path, 'good.lab' );
my $lab_ports = candidates_for( 'ssh_port', \@good_lab );
ok( ( scalar @$lab_ports == 1 and $lab_ports->[0]{'value'} eq '2201' ),
    "'*.lab' matches good.lab [ and the later 'Host *' cannot override ]"
);

my @bad_lab       = $ssh_config->( $ssh_config_path, 'bad.lab' );
my $bad_lab_ports = candidates_for( 'ssh_port', \@bad_lab );
ok(
    (           ( not grep { $_->{'value'} eq '2201' } @$bad_lab_ports )
            and ( grep { $_->{'value'} eq '4242' } @$bad_lab_ports )
    ),
    "'!bad.lab' negates the wildcard, only 'Host *' applies"
);

my @elsewhere = $ssh_config->( $ssh_config_path, 'elsewhere.example' );
my $fallback  = candidates_for( 'addresses', \@elsewhere );
ok(
    (   scalar @$fallback == 1
            and $fallback->[0]{'value'} eq 'other.example.org'
    ),
    'a name only the catch-all matches still gets Host * values'
);

##[ ssh config : skipped Match shadowing, position aware ]####################

say ': ssh config match shadowing';

my $match_config_path = File::Spec->catfile( $ssh_dir, qw| match.conf | );
{
    open( my $fh, '>', $match_config_path ) or die $!;
    print {$fh} <<'EO_MATCH';
Match host shadowed
    Port 9999
Host shadowed
    HostName shadowed.example.org
    Port 2022
EO_MATCH
    close($fh);
}

my @shadowed = $ssh_config->( $match_config_path, 'shadowed' );
my $sh_ports = candidates_for( 'ssh_port',  \@shadowed );
my $sh_addr  = candidates_for( 'addresses', \@shadowed );
ok( ( scalar @$sh_ports == 1 and $sh_ports->[0]{'value'} eq '2022' ),
    'the skipped Match value itself never becomes a candidate'
);
ok(
    (   ref $sh_ports->[0]{'shadowed_by_match'} eq qw| HASH |
            and $sh_ports->[0]{'shadowed_by_match'}{'file'} eq
            $match_config_path
            and $sh_ports->[0]{'shadowed_by_match'}{'line'} == 1
    ),
    'a Match BEFORE the statement shadowing its Port points at the Match'
);
ok( ( $sh_ports->[0]{'note'} // '' ) =~ m{skipped Match},
    'the shadowed port candidate carries the note'
);
ok(
    (   scalar @$sh_addr == 1
            and not defined $sh_addr->[0]{'shadowed_by_match'}
    ),
    'a keyword the skipped Match does not set is not shadowed'
);

## the ssh target is user@host : an earlier Match setting User shadows it ##
my $user_match_path = File::Spec->catfile( $ssh_dir, qw| user-match.conf | );
{
    open( my $fh, '>', $user_match_path ) or die $!;
    print {$fh} "Match host um\n    User bob\nHost um\n   "
        . " HostName um.example.org\n    User alice\n";
    close($fh);
}
my @um      = $ssh_config->( $user_match_path, 'um' );
my $um_ssh  = candidates_for( 'ssh',       \@um );
my $um_addr = candidates_for( 'addresses', \@um );
ok(
    (           scalar @$um_ssh == 1
            and $um_ssh->[0]{'value'} eq 'alice@um.example.org'
            and ref $um_ssh->[0]{'shadowed_by_match'} eq qw| HASH |
    ),
    'an earlier Match setting User shadows the composed ssh target'
);
ok( not( defined $um_addr->[0]{'shadowed_by_match'} ),
    '... but not the address [ hostname untouched ]'
);

##[ ssh config : key=value, rejected port, Include ]##########################

say ': ssh config key=value + rejections + include';

my @kv      = $ssh_config->( $ssh_config_path, 'kv' );
my $kv_addr = candidates_for( 'addresses', \@kv );
my $kv_port = candidates_for( 'ssh_port',  \@kv );
ok(
    (           scalar @$kv_addr == 1
            and $kv_addr->[0]{'value'} eq 'kv.example.org'
            and $kv_addr->[0]{'source'}{'line'} == 10
    ),
    "'key=value' syntax maps the same as 'key value'"
);
ok( ( scalar @$kv_port == 1 and $kv_port->[0]{'value'} eq '2200' ),
    'key=value port mapped' );

my @badport   = $ssh_config->( $ssh_config_path, 'badport' );
my $bad_ports = candidates_for( 'ssh_port', \@badport );
ok( ( scalar @$bad_ports == 1 and $bad_ports->[0]{'value'} eq '70000' ),
    'an out-of-range port is KEPT as a candidate' );
ok( ( $bad_ports->[0]{'rejected'} // '' ) =~ m{out of range},
    'the rejected candidate says WHY [ port out of range ]'
);

my @includee = $ssh_config->( $ssh_config_path, 'includee' );
my $inc_port = candidates_for( 'ssh_port',  \@includee );
my $inc_addr = candidates_for( 'addresses', \@includee );
ok(
    (           scalar @$inc_port == 1
            and $inc_port->[0]{'value'} eq '2022'
            and $inc_port->[0]{'source'}{'file'} eq $included_config_path
    ),
    'Include resolves the glob and reports the included file as source'
);
ok(
    (   scalar @$inc_addr == 1
            and $inc_addr->[0]{'value'} eq 'included.example.org'
    ),
    'included HostName mapped'
);

ok( scalar( $ssh_config->( $ssh_config_path, 'no.such.host' ) ) > 0,
    'catch-all still answers for unknown names' );

##[ ssh config : conditional Include, '%h', '~/' include ]####################

say ': ssh config conditional include + tokens';

my $second_config_path = File::Spec->catfile( $ssh_dir, qw| second.conf | );
{
    open( my $fh, '>', $second_config_path ) or die $!;
    print {$fh} <<'EO_SECOND';
Include ~/.ssh/tilde.conf
Host gated
    Include gated.conf
Match host gated
    Include matched.conf
Host pct
    HostName %h.example.org
EO_SECOND
    close($fh);
    my %parts = (
        'gated.conf'   => "Port 2300\nHostName gated.example.org\n",
        'matched.conf' => "Port 2399\n",
        'tilde.conf'   => "Host tilde\n    HostName tilde.example.org\n",
    );
    foreach my $part ( keys %parts ) {
        open( my $pfh, '>', File::Spec->catfile( $ssh_dir, $part ) )
            or die $!;
        print {$pfh} $parts{$part};
        close($pfh);
    }
}

my $gated_port
    = candidates_for( 'ssh_port',
    [ $ssh_config->( $second_config_path, 'gated' ) ] );
ok( ( scalar @$gated_port == 1 and $gated_port->[0]{'value'} eq '2300' ),
    'an Include inside a matching Host block is read' );
my $other_port
    = candidates_for( 'ssh_port',
    [ $ssh_config->( $second_config_path, 'other' ) ] );
ok( scalar @$other_port == 0,
    'an Include inside a non-matching Host block is NOT read' );
my $pct_addr
    = candidates_for( 'addresses',
    [ $ssh_config->( $second_config_path, 'pct' ) ] );
ok(
    (   scalar @$pct_addr == 1
            and $pct_addr->[0]{'value'} eq 'pct.example.org'
    ),
    "'%h' in HostName becomes the asked name"
);
my $tilde_addr
    = candidates_for( 'addresses',
    [ $ssh_config->( $second_config_path, 'tilde' ) ] );
ok(
    (   scalar @$tilde_addr == 1
            and $tilde_addr->[0]{'value'} eq 'tilde.example.org'
    ),
    "'Include ~/...' resolves against the home dir"
);

my $v6_names
    = candidates_for( 'name',
    [ $etc_hosts->( $etc_hosts_path, '2001:db8::10' ) ] );
ok(
    (   scalar @$v6_names == 2
            and $v6_names->[0]{'value'} eq 'docs-v6.example.org'
    ),
    'an ipv6 ADDRESS query returns its names [ and/or precedence ]'
);

##[ etc/hosts : both directions, ipv6 ]#######################################

say ': etc/hosts';

my @by_name = $etc_hosts->( $etc_hosts_path, 'docs-v6.example.org' );
ok(
    (           scalar @by_name == 1
            and $by_name[0]{'field'} eq 'addresses'
            and $by_name[0]{'value'} eq '2001:db8::10'
            and $by_name[0]{'source'}{'line'} == 3
    ),
    'an ipv6 hosts line yields the address for a name'
);
ok( ( not defined $by_name[0]{'rejected'} ),
    'the ipv6 address passes the sanity check'
);

my @by_address = $etc_hosts->( $etc_hosts_path, '192.0.2.10' );
ok(
    (   scalar @by_address == 2
            and join( q{,}, sort @{ values_of( \@by_address ) } ) eq
            'docs-one.example.org,docs1'
    ),
    'an address query yields the names on its line'
);
ok( ( grep { $_->{'field'} eq 'name' } @by_address ) == 2,
    'reverse lookups carry field name' );

##[ conflicts : kept, marked, explained ]#####################################

say ': conflicts';

my @atom_again      = $ssh_config->( $ssh_config_path, 'atom' );
my $other_statement = $code{'hints.candidate'}->(
    qw| ssh_port |,
    '2022',
    {   file    => 'an-admin-script',
        line    => 1,
        context => 'stated once, elsewhere'
    },
    'a second source'
);

my @merged = $code{'hints.conflicts'}->( [ @atom_again, $other_statement ] );
my @conflicting_ports = grep {
            $_->{'field'} eq 'ssh_port'
        and not defined $_->{'rejected'}
        and defined $_->{'conflicting'}
} @merged;

ok( scalar @conflicting_ports == 2,
    'two different ports for one host are BOTH kept' );
ok(
    (   grep { $_->{'note'} =~ m{conflicts with another candidate} }
            @conflicting_ports
    ) == 2,
    'each conflicting candidate says so in its note'
);

## fresh candidates : the merged pass above stamped @atom_again in place, a
## single-voice list must come from a new parse
my @atom_fresh = $ssh_config->( $ssh_config_path, 'atom' );
my @unrelated  = $code{'hints.conflicts'}->( [@atom_fresh] );
ok( ( grep { defined $_->{'conflicting'} } @unrelated ) == 0,
    'a single voice for a field is not a conflict'
);

##[ candidate shape ]#########################################################

say ': candidate shape';

my $bare = $code{'hints.candidate'}->(
    qw| addresses |,
    '192.0.2.77', { file => 'f', line => 1, context => 'c' }
);
ok(
    (           ref $bare eq qw| HASH |
            and join( q{,}, sort keys %$bare ) eq 'field,source,value'
            and join( q{,}, sort keys %{ $bare->{'source'} } ) eq
            'context,file,line'
    ),
    'a bare candidate is exactly field, value, source[ file line context ]'
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

#,,.,,,,.,.,,,.,.,,.,,,.,,,..,,,,,,..,.,,,,.,,..,,...,..,,,.,,..,,.,.,,,,,.,.,
#KK3WW5RFG3TLRDITUK3ODD4LXFH6XC24QBF4WD6DMCIFWHZR5PKBHL4VEU72MJAEW6LFW7GJU5OLE
#\\\|3Z56WU5H42VEI2TVJM2RPMO2JINNMVWM3VFYCUNPQZGVCVWNNSH \ / AMOS7 \ YOURUM ::
#\[7]TYT6AS7OZKKVEDK6VESU4FXAJQ4GA4JKFHEWY5RUBBR32P5WE6DI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
