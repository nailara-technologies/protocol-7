#!/usr/bin/env perl
use v5.24;
use strict;
use English;
use warnings;

## v7-zenki host.cfg zenki overrides [ todo DYK ] : the three optional     ##
## host.cfg keys v7-zenki.host.zenki.enable \ disable \ on-demand are      ##
## applied on top of the parsed start profile                              ##
## [ including an automatic '-lowram' choice ], before autostart : disable ##
## wins over enable with one level 0 line, one level 1 summary line, set   ##
## based [ re-init safe ].  it compiles the real                           ##
## src/v7-zenki.load_start_setup and  src/v7-zenki.apply_host_zenki_cfg    ##
## modules and drives them with stubs : base.logs, base.load_section_code  ##
## [ returns the globals section of the real profile files ] and a catfile ##
## shim. no zenka started.                                                 ##

use File::Spec;
use Cwd     qw| abs_path |;
use FindBin qw| $RealBin |;

BEGIN {
    my $root_path = abs_path(
        File::Spec->rel2abs(
            File::Spec->catdir(
                $RealBin, File::Spec->updir, File::Spec->updir
            )
        )
    );
    $main::root_path = $root_path;
}

use constant { TRUE => 5, FALSE => 0, UNKNOWN => 2 };

my $root_path = $main::root_path;

## state ##

our %data;
our %code;

$data{'system'}{'conf_path'} = File::Spec->catdir( $root_path, 'cfg' );
$data{'host'}{'mem_mb'}      = 2048;    ## below the 3072 lowram default ##
$data{'regex'}{'base'}{'usr_str'}
    = qr|(?:unix-)?[a-z0-9][a-z0-9\-_]{0,31}|i;

my @log_lines;    ## rendered base.logs output [ level, line ] ##

$code{'base.logs'} = sub {
    my $level = shift;
    if ( $level !~ m|^\d+$| ) {    ## base.log style : fmt first ##
        unshift @ARG, $level;
        $level = 1;
    }
    my $fmt = shift;
    push @log_lines, [ $level, sprintf $fmt, @ARG ];
    return 1;
};

sub catfile { return File::Spec->catfile(@ARG) }

## globals section of a real profile file, as 'key = value' pairs ##

sub profile_globals {
    my $profile = shift;
    my $path    = File::Spec->catfile(
        $root_path,
        qw| cfg zenki v7-zenki |,
        'start-set-up.' . $profile
    );
    open my $fh, '<', $path or die "cannot read $path : $OS_ERROR";
    my %globals;
    my $in_globals = 0;
    while ( my $line = <$fh> ) {
        if    ( $line =~ m|^\.\: globals \:.| ) { $in_globals = 1 }
        elsif ( $line =~ m|^\.\: \w+ \:.| )     {last}
        next unless $in_globals;
        next unless $line =~ m|^\s+([-\w.]+)\s*=\s*(.*?)\s*$|;
        my ( $key, $value ) = ( $1, $2 );
        $value =~ s|\s+#.+$||;
        $globals{$key} = $value;
    }
    close $fh;
    return \%globals;
}

## canned base.load_section_code : the globals section of the real file ##

my $loaded_pattern = '';
$code{'base.load_section_code'} = sub {
    my $pattern = shift;
    $loaded_pattern = $pattern;
    my ($profile) = $pattern =~ m|start-set-up\.(.+)$|;
    return [ { 'globals' => profile_globals($profile) } ];
};

## module loader : translate p7 syntax, compile as anonymous sub ##

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

    ## drop signature block [ last 4 lines starting with # ] ##
    $src =~ s{\n#[^\n]*\z}{\n} while $src =~ m{\n#[,\[\\|:][^\n]*\z};

    ## split out strings and comments, translate code segments only ##
    my @seg = split m{('(?:[^'\\]|\\.)*'|"(?:[^"\\]|\\.)*"|\#[^\n]*)}x,
        $src, -1;
    for ( my $i = 0; $i < @seg; $i += 2 ) {
        $seg[$i] = translate_code( $seg[$i] );
    }
    my $translated = join '', @seg;
    warn qq|===== $name =====\n$translated\n| if $ENV{'P7_DEBUG'};

    my $sub = eval "sub { $translated }";
    die "compile error in $name : $EVAL_ERROR" if $EVAL_ERROR;
    $code{$name} = $sub;
    return $sub;
}

load_module($_) for qw|
    v7-zenki.load_start_setup
    v7-zenki.apply_host_zenki_cfg
    |;

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

sub level_lines {    ## rendered log lines at one level ##
    my $level = shift;
    return map { $ARG->[1] } grep { $ARG->[0] == $level } @log_lines;
}

sub zenki_cfg { return $data{'v7-zenki'}{'start_setup'}{'globals'}{'zenki'} }

sub name_list {    ## split a zenki.<key> string into a name set ##
    my $key = shift;
    my $str = zenki_cfg()->{$key} // '';
    return { map { $ARG => 1 } split m|\s+|, $str };
}

## profile parse simulation : globals pairs into the start_setup tree ##

sub simulate_profile_parse {
    my $globals = shift;
    foreach my $key ( sort keys $globals->%* ) {
        my @path = split m|\.|, $key;
        my $ref  = $data{'v7-zenki'}{'start_setup'}{'globals'} //= {};
        $ref = ( $ref->{$ARG} //= {} ) foreach @path[ 0 .. $#path - 1 ];
        $ref->{ $path[-1] } = $globals->{$key};
    }
    my %enabled = map { $ARG => 1 }
        split m|\s+|, zenki_cfg()->{'enabled'} // '';
    $data{'v7-zenki'}{'start_setup'}{'zenki'}{'startup'}{'start_order'}
        = [ grep { $enabled{$ARG} }
            qw| cube p7-log httpd web letsencr httpsd nameserv system events |
        ];
}

## a full init : load profile [ with the -lowram choice ] and parse ##

sub run_init {
    $data{'v7-zenki'}{'cfg_data'}{'start_setup'} = [];
    $data{'v7-zenki'}{'start_setup'}             = {};
    @log_lines                                   = ();
    $code{'v7-zenki.load_start_setup'}->('remote-server');
    my $loaded
        = $data{'v7-zenki'}{'cfg_data'}{'start_setup'}[0][0]{'globals'};
    simulate_profile_parse($loaded);
    $data{'v7-zenki'}{'start_setup'}{'zenki'}{'config'}
        = { 'x' => {}, 'backup' => {} };
}

## --- the automatic -lowram choice precedes the overrides ------------- ##

run_init();

check 'low ram selects the -lowram profile',
    ( $data{'v7-zenki'}{'cfg_data'}{'start_profile'} eq 'remote-server-lowram'
        and $loaded_pattern eq
        'zenki/v7-zenki/start-set-up.remote-server-lowram' );

check 'lowram profile globals parsed',
    (       name_list('enabled')->{'nameserv'}
        and name_list('on-demand')->{'letsencr'}
        and name_list('disabled')->{'discover'} );

## --- enable, disable, on-demand, conflict on the lowram profile ------ ##

$data{'v7-zenki'}{'host'}{'zenki'}{'enable'}    = 'x web';
$data{'v7-zenki'}{'host'}{'zenki'}{'disable'}   = 'nameserv web system';
$data{'v7-zenki'}{'host'}{'zenki'}{'on-demand'} = 'backup bad..name';

$code{'v7-zenki.apply_host_zenki_cfg'}->();

my %enabled   = name_list('enabled')->%*;
my %disabled  = name_list('disabled')->%*;
my %on_demand = name_list('on-demand')->%*;

check 'disable removed names from zenki.enabled',
    ( not grep { $enabled{$ARG} } qw| nameserv web system | );
check 'disable added names to zenki.disabled',
    ( $disabled{'nameserv'} and $disabled{'web'} and $disabled{'system'} );
check 'profile disable list kept',       $disabled{'discover'};
check 'enable added x to zenki.enabled', $enabled{'x'};

check 'conflict : disable wins over enable',
    ( not $enabled{'web'} and $disabled{'web'} );
check 'conflict logged once at level 0',
    (
    scalar( grep {m|conflict : 'web' in enable and disable|} level_lines(0) )
        == 1 );

check 'invalid name skipped and logged at level 0',
    ( not $on_demand{'bad..name'}
        and scalar( grep {m|skipping invalid name|} level_lines(0) ) == 1 );

check 'on-demand override appended',
    ( $on_demand{'backup'} and $on_demand{'smtpd'} );

my $start_order
    = $data{'v7-zenki'}{'start_setup'}{'zenki'}{'startup'}{'start_order'};
check 'disabled zenki dropped from start_order',
    ( not grep { $ARG eq 'nameserv' or $ARG eq 'web' or $ARG eq 'system' }
        @$start_order );
check 'newly enabled zenki with config joined start_order',
    ( scalar( grep { $ARG eq 'x' } @$start_order ) == 1 );

my @summary = grep {m|\+ host\.cfg|} level_lines(1);
if ( $ENV{'P7_DEBUG'} ) {
    say sprintf '%d : %s', $ARG->[0], $ARG->[1] for @log_lines;
}
check 'one level 1 summary line naming profile and overrides',
    ( scalar @summary == 1
        and $summary[0] eq ': start profile remote-server-lowram + host.cfg '
        . '[ enable : x ; disable : nameserv web '
        . 'system ; on-demand : backup ]' );

## --- re-init : overrides apply exactly once ---------------------------- ##

run_init();    ## fresh profile parse, host.cfg keys still in place ##

$code{'v7-zenki.apply_host_zenki_cfg'}->();
%enabled = name_list('enabled')->%*;

check 're-init keeps x enabled',       $enabled{'x'};
check 're-init : no duplicated names', do {
    my $ok = 1;
    foreach my $key (qw| enabled disabled on-demand |) {
        my @names = split m|\s+|, zenki_cfg()->{$key} // '';
        my %seen;
        map { $ok = 0 if $seen{$ARG}++ } @names;
    }
    $ok;
};

$start_order
    = $data{'v7-zenki'}{'start_setup'}{'zenki'}{'startup'}{'start_order'};
check 're-init : start_order holds x exactly once',
    ( scalar( grep { $ARG eq 'x' } @$start_order ) == 1 );

## --- enable lifts a profile disable ---------------------------------- ##

run_init();
my $cfg = zenki_cfg();
$cfg->{'disabled'} = 'graphics-matrix x';
delete $cfg->{'enabled'};    ## profile without an enabled list ##

$data{'v7-zenki'}{'host'}{'zenki'}{'enable'}  = 'graphics-matrix x';
$data{'v7-zenki'}{'host'}{'zenki'}{'disable'} = '';

$code{'v7-zenki.apply_host_zenki_cfg'}->();

check 'enable lifts a profile disable',
    ( zenki_cfg()->{'disabled'} eq ''
        and not defined zenki_cfg()->{'enabled'} );
check 'lifted zenki with config joined start_order',
    ( scalar grep { $ARG eq 'x' }
        $data{'v7-zenki'}{'start_setup'}{'zenki'}{'startup'}{'start_order'}
        ->@* );

## --- no host.cfg keys : silent no-op ---------------------------------- ##

run_init();
@log_lines = ();
delete $data{'v7-zenki'}{'host'};
$code{'v7-zenki.apply_host_zenki_cfg'}->();

check 'without host.cfg keys nothing changes',
    (       zenki_cfg()->{'enabled'} =~ m|nameserv|
        and zenki_cfg()->{'disabled'} eq 'discover graphics-matrix'
        and zenki_cfg()->{'on-demand'} eq 'letsencr debian smtpd users' );
check 'without host.cfg keys no override logs', not scalar @log_lines;

say '';
## --- a profile without an on-demand list allows every zenka : host.cfg ##
## on-demand must not turn that into an allow list of one -----------    ##

{
    local $data{'host'}{'mem_mb'} = 16384;    ## no -lowram : remote-server ##
    $data{'v7-zenki'}{'host'}{'zenki'} = { 'on-demand' => 'backup' };
    run_init();
    $code{'v7-zenki.apply_host_zenki_cfg'}->();
    check 'no profile list : on-demand not created',
        not defined zenki_cfg()->{'on-demand'};
    check '  :.. ignored, logged at level 1',
        scalar grep {m|on-demand ignored \[ backup \]|} level_lines(1);
    delete $data{'v7-zenki'}{'host'}{'zenki'};
}

say "passed : $pass_count  failed : $fail_count";
exit( $fail_count ? 1 : 0 );

#,,,,,,.,,,.,,..,,,.,,,,.,.,.,,.,,,..,,..,,,.,..,,...,...,..,,.,,,...,,.,,.,.,
#K33WJWOA25APAKVPATIWCDFBXMTT4QBLIUKAWJNVEJIPE3SE2XHLSG4QZA62OPR3N4BTI4ASSMVOM
#\\\|TKN2RDLBNCFTMCPT5BNSCTVCG3LSVYSFZFK3MERDPGYM2QNV6T6 \ / AMOS7 \ YOURUM ::
#\[7]GEQTNNAPAKGLGBTBBFBHSQCE2JGJHHOYSYG3NBWTEK7AKPHGXICQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
