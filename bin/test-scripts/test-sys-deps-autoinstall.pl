#!/usr/bin/perl
use v5.24;
use strict;
use English;
use warnings;

###                                                                ###
##  sys_deps auto-install stage 1 : standalone acceptance harness   ##
###                                                                ###

## exercises the real translated module sources [ v7-zenki.sys_deps.scan,  ##
## .probe, .track, callback.object.sys_deps, resolve.object.sys_deps,      ##
## handler.sys_deps_reply, v7-zenki.set_up_zenka_dependencies + the debian ##
## cpan queue modules debian.cmd.install-cpan, .cpan_enqueue_install,      ##
## .job.cpan_install, .handler.cpan_child_output, with debian.cmd.         ##
## install-packages + .apt_enqueue_install + .apt_pump driving the shared  ##
## serialized queue ] against an in-process %data / %code stub environment ##
## -- no live v7-zenki, no debian zenka, no installs. covers:              ##
## - feature off : callback TRUE, no install, no sys_deps in chains        ##
## - nothing missing : 'ok', TRUE, no install                              ##
## - missing apt + cpan : FALSE, ONE debian.install-packages + ONE         ##
## debian.install-cpan, state 'installing', second resolve sends nothing   ##
## - reply TRUE + re-probe ok -> 'ok', TRUE, jobqueue.check_dependencies   ##
## - reply FALSE or still missing -> 'failed', TRUE [ degraded ], logged   ##
## once, retried only after retry_after                                    ##
## - route-send failure -> 'failed'                                        ##
## - the scan runs once, again after a reinit-style cache drop             ##
## - set_up_zenka_dependencies : feature on -> every zenka's chain holds   ##
## sys_deps.<zenka>, also one without a dependencies line ; off -> none    ##
## - debian cpan queue : bad module name fails the job before any shell ;  ##
## apt and cpan jobs serialized in one queue [ job callbacks stubbed ]     ##

use File::Spec;
use Cwd     qw| abs_path |;
use FindBin qw| $RealBin |;

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
use AMOS7::deps::module;
use AMOS7::deps::os_package;

##[ p7 runtime environment stubs ]############################################

use constant TRUE    => 5;
use constant FALSE   => 0;
use constant UNKNOWN => 2;

our %data;
our %code;
our $call;

## controllable fake clock [ same ntime scale as the resolve-hook harness ] ##
use constant NTIME_PER_SECOND => 4200;
my $FAKE_NOW = 1000;

my $NEXT_ID = 1;

my @LOGS;           ## [ level, message ] ##
my @ROUTES;         ## route-send parameter hashes ##
my $ROUTE_SEND_OK = 1;
my @TIMERS;         ## event.add_timer parameter hashes ##
my @IO_WATCHERS;    ## event.add_io parameter hashes ##
my @TRACKED;        ## [ zenka_name, items_aref ] ##
my $CHECK_DEP_CALLS = 0;
my @REPLIES;        ## base.callback.cmd_reply [ reply_id, reply_hash ] ##
my @MOVED;          ## jobqueue.move_job [ job_id, target ] ##

%code = (
    'base.log'  => sub { push @LOGS, [ shift // 0, shift // '' ]; TRUE },
    'base.logs' => sub {
        my $lvl = shift // 0;
        my $msg = shift // '';
        $msg = sprintf( $msg, @_ ) if @_;
        push @LOGS, [ $lvl, $msg ];
        return TRUE;
    },
    'base.cfg_bool' => sub {
        my $val = shift;
        return FALSE if not defined $val;
        return ( $val =~ m{^(1|yes|true|on)$}i ) ? TRUE : FALSE;
    },
    'base.perlmod.load'   => sub { return TRUE },
    'base.perlmod.loaded' => sub { return TRUE },
    'base.ntime'          => sub { return $FAKE_NOW },
    'base.ntime.b32'      => sub { return qw| FAKETIME32 | },
    'base.str.eval_error' => sub { return "$EVAL_ERROR" },
    'base.format_error'   => sub { my $e = shift // ''; return "$e" },
    'base.gen_id'         => sub {
        my $href = shift;
        my $id;
        do { $id = $NEXT_ID++ } while exists $href->{$id};
        return $id;
    },
    'base.zenki.pause_ondemand_timeout'  => sub { return TRUE },
    'base.zenki.resume_ondemand_timeout' => sub { return TRUE },
    'base.s_read'                        => sub { return 0 },
    'base.callback.cmd_reply'            => sub {
        my ( $reply_id, $reply ) = @ARG;
        push @REPLIES, [ $reply_id, $reply ];
        return TRUE;
    },
    'protocol-7.route-send' => sub {
        my $param = shift;
        push @ROUTES, $param;
        return $ROUTE_SEND_OK;
    },
    'event.add_timer' => sub {
        my $param = shift;
        push @TIMERS, $param;
        return scalar @TIMERS;
    },
    'event.add_io' => sub {
        my $param = shift;
        push @IO_WATCHERS, $param;
        return scalar @IO_WATCHERS;
    },
    'jobqueue.check_dependencies' => sub {
        $CHECK_DEP_CALLS++;
        return TRUE;
    },
    'v7-zenki.sys_deps.track' => sub {
        my ( $zenka_name, $items ) = @ARG;
        push @TRACKED, [ $zenka_name, $items ];
        return TRUE;
    },
);

##[ AMOS7::deps probe \ scan stubbing ]#######################################

my $SCAN_PM_CALLS = 0;
my $SCAN_OS_CALLS = 0;
my $FAKE_PM_SCAN  = {};
my $FAKE_OS_SCAN  = {};

my %FAKE_PROBE_MODULE;    ## module => 0 [ missing ] ; default present ##
my %FAKE_PROBE_PKG;       ## package => 0 ; default present ##
my %FAKE_PROBE_BIN;       ## binary  => 0 ; default present ##
my %FAKE_RESOLVE;         ## module => { method, pkg } ; default cpan ##
my %FAKE_KNOWN_BINARY;    ## binary => providing debian package ##

{
    no warnings 'redefine';

    *AMOS7::deps::module::scan_zenki_pm_deps = sub {
        $SCAN_PM_CALLS++;
        return $FAKE_PM_SCAN;
    };
    *AMOS7::deps::os_package::scan_zenki_os_deps = sub {
        $SCAN_OS_CALLS++;
        return $FAKE_OS_SCAN;
    };
    ## v7-zenki must never 'require' a probed module nor build an apt cache ##
    ## in-process : those calls are counted and must stay 0                 ##
    *AMOS7::deps::module::probe_module = sub {
        $main::INPROCESS_PROBES++;
        return 1;
    };
    *AMOS7::deps::module::probe_module_file = sub {
        my $module = shift;
        return $FAKE_PROBE_MODULE{$module} // 1;
    };
    *AMOS7::deps::os_package::probe_os_pkg = sub {
        my ( $pkg, $type, $fresh ) = @_;
        $main::INPROCESS_PROBES++ if ( $type // '' ) eq 'debian' and !$fresh;
        return $FAKE_PROBE_PKG{$pkg} // 1;
    };
    *AMOS7::deps::os_package::probe_binary = sub {
        my $bin = shift;
        return $FAKE_PROBE_BIN{$bin} // 1;
    };
    *AMOS7::deps::module::load_known_deps = sub {
        my ( $root, $section ) = @ARG;
        return \%FAKE_KNOWN_BINARY
            if defined $section and $section eq qw| binary |;
        return {};
    };
    *AMOS7::deps::module::resolve_install = sub {
        my $module = shift;
        return $FAKE_RESOLVE{$module}
            // { 'method' => qw| cpan |, 'pkg' => $module };
    };
}

##[ module compilation [ same sub-wrapper shape as bin/Protocol-7 ] ]#########

my $fail_count = 0;

sub compile_module {
    my $module_name = shift;
    my $src_path
        = File::Spec->catfile( $main::root_path, 'src', $module_name );
    open( my $fh, '<', $src_path ) or die "cannot read $src_path : $!";
    my $src = join( '', <$fh> );
    close($fh);
    my $translated = p7_syntax__translate($src);
    my $cref       = eval "sub {\n# line 1 \"$module_name\"\n$translated\n}";
    die "compile failed for $module_name : $EVAL_ERROR"
        if not defined $cref;
    $code{$module_name} = $cref;
    return $cref;
}

compile_module($_) foreach qw|
    base.dependency.setup
    base.dependency.add_object
    base.dependency.add
    base.dependency.install_callbacks
    base.dependency.ok_resolve
    base.ntime.delta_seconds
    v7-zenki.condition.recheck_later
    v7-zenki.sys_deps.scan
    v7-zenki.sys_deps.probe
    v7-zenki.callback.object.sys_deps
    v7-zenki.resolve.object.sys_deps
    v7-zenki.handler.sys_deps_reply
    v7-zenki.set_up_zenka_dependencies
    debian.cmd.install-packages
    debian.apt_enqueue_install
    debian.apt_pump
    debian.cmd.install-cpan
    debian.cpan_enqueue_install
    debian.job.cpan_install
    debian.handler.cpan_child_output
    |;

## real runtime aliases base.X -> X via base.swap_subs [ base.pre_init ] :
$code{'dependency.setup'} = $code{'base.dependency.setup'};
$code{'dependency.install_callbacks'}
    = $code{'base.dependency.install_callbacks'};
$code{'dependency.add_object'} = $code{'base.dependency.add_object'};
$code{'dependency.add'}        = $code{'base.dependency.add'};

## count probe invocations [ the scan must NOT re-run on a re-probe ] ##
my $PROBE_CALLS = 0;
{
    my $real_probe = $code{'v7-zenki.sys_deps.probe'};
    $code{'v7-zenki.sys_deps.probe'} = sub {
        $PROBE_CALLS++;
        return $real_probe->(@_);
    };
}

##[ fake zenka \ jobqueue layer ]#############################################

my %FAKE_DEPS;    ## zenka_name => dependencies line ; undef = none ##

$code{'zenka.setup.add'} = sub {
    my $param = shift;
    my $setup = $data{'v7-zenki'}{'zenka'}{'setup'} //= {};
    foreach my $s_id ( keys %$setup ) {
        return $s_id if $setup->{$s_id}{'name'} eq $param->{'name'};
    }
    my $s_id = $NEXT_ID++;
    $setup->{$s_id} = { 'name' => $param->{'name'} };
    return $s_id;
};
$code{'zenka.get_id'} = sub {
    my $name  = shift;
    my $setup = $data{'v7-zenki'}{'zenka'}{'setup'} // {};
    foreach my $s_id ( keys %$setup ) {
        return $s_id if $setup->{$s_id}{'name'} eq $name;
    }
    return undef;
};
$code{'zenka.get_object_id'} = sub {
    my $zenka_id = shift;
    foreach my $o_id ( keys %{ $data{'dependency'}{'object'} // {} } ) {
        my $object = $data{'dependency'}{'object'}{$o_id};
        next         if ( $object->{'type'}     // '' ) ne qw| zenka |;
        return $o_id if ( $object->{'zenka_id'} // -1 ) == $zenka_id;
    }
    return undef;
};
$code{'zenka.get_dependencies'} = sub {
    return $FAKE_DEPS{ shift // '' };
};
$code{'zenka.is_enabled'} = sub { return TRUE };

$code{'jobqueue.queue_template'} = sub {
    return { 'by_timestamp' => [], 'by_id' => {} };
};
$code{'jobqueue.add_job'} = sub {
    my $param   = shift;
    my $job_id  = $NEXT_ID++;
    my $queue   = $param->{'target_queue'} // qw| queued |;
    my $joblist = $data{'jobqueue'}{'joblist'} //= {};
    $joblist->{'by_id'}{$job_id} = {
        'name'            => $param->{'name'}            // '',
        'job_callback'    => $param->{'job_callback'}    // '',
        'callback_params' => $param->{'callback_params'} // {},
    };
    push @{ $joblist->{$queue}{'by_timestamp'} }, $job_id;
    $joblist->{$queue}{'by_id'}{$job_id} = 1;
    return $job_id;
};
$code{'jobqueue.get_next_job'} = sub {
    my $queue   = shift;
    my $joblist = $data{'jobqueue'}{'joblist'} // {};
    my $q       = $joblist->{$queue}           // {};
    while ( @{ $q->{'by_timestamp'} // [] } ) {
        my $job_id = shift @{ $q->{'by_timestamp'} };
        next if not exists $q->{'by_id'}{$job_id};
        return ( $job_id, $joblist->{'by_id'}{$job_id} );
    }
    return ();
};
$code{'jobqueue.move_job'} = sub {
    my ( $job_id, $target ) = @ARG;
    my $joblist = $data{'jobqueue'}{'joblist'} // {};
    foreach my $qname ( keys %$joblist ) {
        next if $qname eq 'by_id';
        delete $joblist->{$qname}{'by_id'}{$job_id}
            if ref $joblist->{$qname} eq qw| HASH |;
    }
    $joblist->{$target}{'by_id'}{$job_id} = 1
        if ref $joblist->{$target} eq qw| HASH |;
    push @MOVED, [ $job_id, $target ];
    return TRUE;
};
$code{'jobqueue.exec_job'} = sub {
    my $job_id = shift;
    my $job    = $data{'jobqueue'}{'joblist'}{'by_id'}{$job_id} // {};
    my $cbname = $job->{'job_callback'}                         // '';
    $code{$cbname}->(
        {   'job_id' => $job_id,
            'params' => $job->{'callback_params'} // {}
        }
    ) if ref $code{$cbname} eq qw| CODE |;
    return TRUE;
};

##[ data initialization ]#####################################################

$data{'regex'}{'base'}{'base_32'}    = 'UNUSED_IN_THIS_TEST';
$data{'system'}{'root_path'}         = $main::root_path;
$data{'system'}{'conf_path'}         = $main::root_path . '/cfg';
$data{'system'}{'amos-zenka-user'}   = 'nobody';
$data{'system'}{'path'}{'perl_bin'}  = $EXECUTABLE_NAME;
$data{'system'}{'bin_path'}{'cpanm'} = '/usr/bin/cpanm';

my $zenka_cfg = $data{'v7-zenki'}{'cfg'} //= {};
$zenka_cfg->{'sys_deps'}{'retry_after'} = 3600;

## dependency type registration [ discovers sys_deps callback + resolve ] ##
my $registered = $code{'base.dependency.install_callbacks'}->('v7-zenki');

##[ tiny assertion framework ]################################################

sub ok {
    my ( $cond, $label ) = @ARG;
    if ($cond) { say "  ok   : $label"; return }
    $fail_count++;
    say "  FAIL : $label";
    return;
}

sub state_of {
    my $zenka_name = shift;
    return ( $data{'v7-zenki'}{'sys_deps'}{'state'} // {} )->{$zenka_name};
}

sub sys_deps_object_id {
    my $zenka_name = shift;
    foreach my $o_id ( keys %{ $data{'dependency'}{'object'} // {} } ) {
        my $object = $data{'dependency'}{'object'}{$o_id};
        next         if ( $object->{'type'} // '' ) ne qw| sys_deps |;
        return $o_id if ( $object->{'name'} // '' ) eq $zenka_name;
    }
    return undef;
}

sub chain_has_sys_deps {
    my $zenka_name = shift;
    my $s_id       = $code{'zenka.get_id'}->($zenka_name);
    return FALSE if not defined $s_id;
    my $source = $code{'zenka.get_object_id'}->($s_id);
    return FALSE if not defined $source;
    my $chain = $data{'dependency'}{'chain'}{$source} // [];
    foreach my $o_id (@$chain) {
        my $object = $data{'dependency'}{'object'}{$o_id} // {};
        return TRUE
            if ( $object->{'type'} // '' ) eq qw| sys_deps |
            and ( $object->{'name'} // '' ) eq $zenka_name;
    }
    return FALSE;
}

sub level0_logs_for {
    my $pattern = shift;
    return scalar grep { $ARG->[0] == 0 and $ARG->[1] =~ $pattern } @LOGS;
}

sub reset_recheck_pending {
    $data{'v7-zenki'}{'condition'}{'recheck_pending'} = FALSE;
    return;
}

##[ 1 : feature off -- TRUE, no install, no sys_deps in chains ]##############

say ': feature off';

$data{'v7-zenki'}{'cfg'}{'auto_install_deps'} = qw| no |;

$code{'v7-zenki.set_up_zenka_dependencies'}->('plain-off');

ok( ( not defined sys_deps_object_id('plain-off') ),
    'feature off : set_up creates no sys_deps object'
);
ok(
    (   not defined $data{'dependency'}{'chain'}->{
            $code{'zenka.get_object_id'}
                ->( $code{'zenka.get_id'}->('plain-off') ) // -1
        }
    ),
    'feature off : no dependency chain added at all'
);

my $off_object_id = $code{'base.dependency.add_object'}
    ->( { 'type' => qw| sys_deps |, 'name' => 'plain-off' } );
my @routes_before = @ROUTES;
my $off_result = $code{'v7-zenki.callback.object.sys_deps'}->($off_object_id);
ok( $off_result, 'feature off : callback is TRUE unconditionally' );
ok( scalar(@ROUTES) == scalar(@routes_before),
    'feature off : no install attempted'
);

##[ 2 : feature on, nothing missing -- 'ok', TRUE, no install ]###############

say ': feature on, nothing missing';

$data{'v7-zenki'}{'cfg'}{'auto_install_deps'} = qw| yes |;

$FAKE_PM_SCAN->{'Present::Mod'} = ['healthy'];

$code{'v7-zenki.set_up_zenka_dependencies'}->('healthy');

my $healthy_sys_id = sys_deps_object_id('healthy');
ok( defined $healthy_sys_id,
    'feature on : set_up creates the sys_deps object per zenka' );
ok( chain_has_sys_deps('healthy'),
    "feature on : healthy's chain holds sys_deps.healthy" );

@routes_before = @ROUTES;
ok( $code{'v7-zenki.callback.object.sys_deps'}->($healthy_sys_id),
    'nothing missing : callback is TRUE' );
ok( scalar(@ROUTES) == scalar(@routes_before),
    'nothing missing : no install attempted'
);
ok( ( state_of('healthy')->{'status'} // '' ) eq qw| ok |,
    "nothing missing : state is 'ok'" );

##[ 3 : missing apt + cpan -- FALSE, ONE route-send each, 'installing' ]######

say ': missing apt + cpan [ via dependency.ok_resolve ]';

$FAKE_PM_SCAN->{'Acme::ViaApt'}         = ['hungry'];
$FAKE_PM_SCAN->{'Foo::Missing'}         = ['hungry'];
$FAKE_OS_SCAN->{'debian'}{'libhungry0'} = ['hungry'];
$FAKE_OS_SCAN->{'binary'}{'hungrybin'}  = ['hungry'];

$FAKE_RESOLVE{'Acme::ViaApt'}
    = { 'method' => qw| debian |, 'pkg' => 'libacme-perl' };
$FAKE_KNOWN_BINARY{'hungrybin'} = 'hungrypkg';

$FAKE_PROBE_MODULE{'Acme::ViaApt'} = 0;
$FAKE_PROBE_MODULE{'Foo::Missing'} = 0;
$FAKE_PROBE_PKG{'libhungry0'}      = 0;
$FAKE_PROBE_BIN{'hungrybin'}       = 0;

$code{'v7-zenki.set_up_zenka_dependencies'}->('hungry');
my $hungry_source
    = $code{'zenka.get_object_id'}->( $code{'zenka.get_id'}->('hungry') );

@ROUTES = ();
@TIMERS = ();
reset_recheck_pending();

my $hungry_result = $code{'base.dependency.ok_resolve'}->($hungry_source);
ok( ( not $hungry_result ),
    'missing deps : ok_resolve returns FALSE [ zenka waits in depending ]' );

my @apt_routes
    = grep { $ARG->{'command'} eq qw| debian.install-packages | } @ROUTES;
my @cpan_routes
    = grep { $ARG->{'command'} eq qw| debian.install-cpan | } @ROUTES;

ok( scalar(@apt_routes) == 1,
    'resolve : exactly ONE debian.install-packages sent' );
ok( scalar(@cpan_routes) == 1,
    'resolve : exactly ONE debian.install-cpan sent' );
ok( ( $apt_routes[0]->{'call_args'}{'args'} // '' ) eq
        'libacme-perl libhungry0 hungrypkg',
    'resolve : apt route carries resolved pm-apt + os + binary packages'
);
ok( ( $cpan_routes[0]->{'call_args'}{'args'} // '' ) eq 'Foo::Missing',
    'resolve : cpan route carries the unresolved pm module'
);
ok( ( $apt_routes[0]->{'reply'}{'handler'} // '' ) eq
        qw| v7-zenki.handler.sys_deps_reply |,
    'resolve : apt reply routes back to handler.sys_deps_reply'
);
ok( ( state_of('hungry')->{'status'} // '' ) eq qw| installing |,
    "resolve : state is 'installing'" );
ok( ( state_of('hungry')->{'pending'} // 0 ) == 2,
    'resolve : two installs in flight [ apt + cpan ]'
);
ok( scalar(@TIMERS) > 0,
    'unmet check : a re-check timer was armed [ recheck_later ]' );

@routes_before = @ROUTES;
$code{'base.dependency.ok_resolve'}->($hungry_source);    ## debounced      ##
$code{'v7-zenki.resolve.object.sys_deps'}->( sys_deps_object_id('hungry') );
ok( scalar(@ROUTES) == scalar(@routes_before),
    "second resolve sends nothing [ still 'installing' ]"
);

reset_recheck_pending();
ok(
    (   not $code{'v7-zenki.callback.object.sys_deps'}
            ->( sys_deps_object_id('hungry') )
    ),
    "'installing' : callback stays FALSE [ zenka keeps waiting ]"
);

##[ 4 : replies TRUE + re-probe ok -> 'ok', TRUE, check_dependencies ]########

say ': install replies [ TRUE, re-probe ok ]';

delete $FAKE_PROBE_MODULE{'Acme::ViaApt'};
delete $FAKE_PROBE_MODULE{'Foo::Missing'};
delete $FAKE_PROBE_PKG{'libhungry0'};
delete $FAKE_PROBE_BIN{'hungrybin'};

my $check_dep_before = $CHECK_DEP_CALLS;
@TRACKED = ();

$code{'v7-zenki.handler.sys_deps_reply'}->(
    {   'mode'   => qw| true |,
        'data'   => 'installed : libacme-perl libhungry0 hungrypkg',
        'params' => {
            'zenka'    => 'hungry',
            'kind'     => qw| apt |,
            'packages' => [qw| libacme-perl libhungry0 hungrypkg |]
        }
    }
);

ok( ( state_of('hungry')->{'status'} // '' ) eq qw| installing |,
    'first reply [ apt ] : cpan still in flight -- state stays installing'
);
ok( $CHECK_DEP_CALLS == $check_dep_before + 1,
    'first reply : jobqueue.check_dependencies run'
);
ok( scalar(@TRACKED) == 1 and $TRACKED[0][1][0]{'type'} eq qw| apt |,
    'first reply : apt packages tracked in tracked.yaml shape'
);

$code{'v7-zenki.handler.sys_deps_reply'}->(
    {   'mode'   => qw| true |,
        'data'   => 'installed : Foo::Missing',
        'params' => {
            'zenka'    => 'hungry',
            'kind'     => qw| cpan |,
            'packages' => [qw| Foo::Missing |]
        }
    }
);

ok( ( state_of('hungry')->{'status'} // '' ) eq qw| ok |,
    "last reply [ cpan ] + re-probe ok : state is 'ok'"
);
ok( $CHECK_DEP_CALLS == $check_dep_before + 2,
    'last reply : jobqueue.check_dependencies run again'
);
ok( scalar(@TRACKED) == 2 and $TRACKED[1][1][0]{'type'} eq qw| cpan |,
    'last reply : cpan module tracked with cpan type' );
ok( $code{ 'v7-zenki.callbac' . 'k.object.sys_deps' }
        ->( sys_deps_object_id('hungry') ),
    "'ok' : callback is TRUE [ waiting start released ]"
);

##[ 5 : reply FALSE -> 'failed', TRUE degraded, logged once, retry gate ]#####

say ': failed install [ degraded start, single log, retry_after gate ]';

$FAKE_PM_SCAN->{'Bad::Broken'} = ['broken'];
$FAKE_PROBE_MODULE{'Bad::Broken'} = 0;

$code{'v7-zenki.set_up_zenka_dependencies'}->('broken');
my $broken_source
    = $code{'zenka.get_object_id'}->( $code{'zenka.get_id'}->('broken') );

@ROUTES = ();
$code{'base.dependency.ok_resolve'}->($broken_source);
ok( scalar( grep { $ARG->{'command'} eq qw| debian.install-cpan | } @ROUTES )
        == 1,
    'broken : one debian.install-cpan sent'
);

my $check_dep_broken = $CHECK_DEP_CALLS;
$code{'v7-zenki.handler.sys_deps_reply'}->(
    {   'mode'   => qw| false |,
        'data'   => 'install failed [ exit 1 ]',
        'params' => {
            'zenka'    => 'broken',
            'kind'     => qw| cpan |,
            'packages' => [qw| Bad::Broken |]
        }
    }
);

ok( ( state_of('broken')->{'status'} // '' ) eq qw| failed |,
    'FALSE reply : state is failed' );
ok( $CHECK_DEP_CALLS == $check_dep_broken + 1,
    'FALSE reply : jobqueue.check_dependencies run [ releases the start ]' );

@LOGS = ();
my $broken_sys_id = sys_deps_object_id('broken');
ok( $code{'v7-zenki.callback.object.sys_deps'}->($broken_sys_id),
    "'failed' : callback is TRUE [ zenka starts degraded ]"
);
ok( level0_logs_for(qr/still missing deps for zenka 'broken'/) == 1,
    "'failed' : still-missing report logged ONCE at level 0"
);
$code{'v7-zenki.callback.object.sys_deps'}->($broken_sys_id) foreach 1 .. 3;
ok( level0_logs_for(qr/still missing deps for zenka 'broken'/) == 1,
    "'failed' : repeated callbacks do not re-log" );

my $probe_calls_before = $PROBE_CALLS;
$FAKE_NOW += 1800 * NTIME_PER_SECOND;    ## half the retry window ##
ok( $code{'v7-zenki.callback.object.sys_deps'}->($broken_sys_id),
    'inside retry window : callback still TRUE [ no re-probe ]'
);
ok( $PROBE_CALLS == $probe_calls_before,
    'inside retry window : no re-probe happened'
);

$FAKE_NOW += 3600 * NTIME_PER_SECOND;    ## well past retry_after ##
reset_recheck_pending();
ok( ( not $code{'v7-zenki.callback.object.sys_deps'}->($broken_sys_id) ),
    'past retry_after : callback FALSE again [ fresh install attempt ]'
);
ok( $PROBE_CALLS > $probe_calls_before,
    'past retry_after : state re-probed' );
ok( ( state_of('broken')->{'status'} // '' ) eq qw| missing |,
    "re-probe with deps still absent : state 'missing' again"
);

my $broken_cpan_routes = scalar grep {
            $ARG->{'command'} eq qw| debian.install-cpan |
        and $ARG->{'reply'}{'params'}{'zenka'} eq 'broken'
} @ROUTES;
$code{'v7-zenki.resolve.object.sys_deps'}->($broken_sys_id);
my $broken_cpan_routes_now = scalar grep {
            $ARG->{'command'} eq qw| debian.install-cpan |
        and $ARG->{'reply'}{'params'}{'zenka'} eq 'broken'
} @ROUTES;
ok( $broken_cpan_routes_now == $broken_cpan_routes + 1,
    'past retry_after : resolve starts a new install'
);

##[ 6 : route-send failure -> 'failed' ]######################################

say ': route-send failure';

$FAKE_PM_SCAN->{'Lonely::Mod'} = ['noroute'];
$FAKE_PROBE_MODULE{'Lonely::Mod'} = 0;

$code{'v7-zenki.set_up_zenka_dependencies'}->('noroute');
my $noroute_source
    = $code{'zenka.get_object_id'}->( $code{'zenka.get_id'}->('noroute') );

$ROUTE_SEND_OK = 0;
@ROUTES        = ();
$code{'base.dependency.ok_resolve'}->($noroute_source);
$ROUTE_SEND_OK = 1;

ok( scalar(@ROUTES) == 1,
    'route-send failure : the install was attempted once' );
ok( ( state_of('noroute')->{'status'} // '' ) eq qw| failed |,
    "route-send failure : state is 'failed' [ no reply will arrive ]"
);
ok( $code{'v7-zenki.callback.object.sys_deps'}
        ->( sys_deps_object_id('noroute') ),
    "route-send failure : callback TRUE [ degraded start ]"
);

##[ 7 : scan cache -- once, again after a reinit-style drop ]#################

say ': scan cache';

ok( $SCAN_PM_CALLS == 1,
    "all probes so far shared ONE pm scan [ got $SCAN_PM_CALLS ]" );
ok( $SCAN_OS_CALLS == 1,
    "all probes so far shared ONE os scan [ got $SCAN_OS_CALLS ]" );

$FAKE_PM_SCAN->{'Fresh::Scan'} = ['rescanned'];
$FAKE_PROBE_MODULE{'Fresh::Scan'} = 0;

## exactly what v7-zenki.init_code does with $reinit [ first arg ] ##
$data{'v7-zenki'}{'sys_deps'}{'scan'} = undef;

$code{'v7-zenki.set_up_zenka_dependencies'}->('rescanned');
$code{'base.dependency.ok_resolve'}->(
    $code{'zenka.get_object_id'}->( $code{'zenka.get_id'}->('rescanned') ) );

ok( $SCAN_PM_CALLS == 2,
    "cache dropped [ reinit ] : the scan ran again [ got $SCAN_PM_CALLS ]" );

##[ 8 : set_up_zenka_dependencies -- every chain holds sys_deps.<zenka> ]#####

say ': set_up_zenka_dependencies [ feature on ]';

$FAKE_DEPS{'beta'} = 'alpha';
$code{'v7-zenki.set_up_zenka_dependencies'}->( 'omega', 'beta' );

ok( chain_has_sys_deps('omega'),
          "zenki WITHOUT a dependencies line "
        . ": omega's chain holds sys_deps.omega" );
ok( chain_has_sys_deps('beta'),
    "zenki with dependencies : beta's chain holds sys_deps.beta" );

my $omega_source
    = $code{'zenka.get_object_id'}->( $code{'zenka.get_id'}->('omega') );
my $omega_chain = $data{'dependency'}{'chain'}{$omega_source} // [];
ok( scalar(@$omega_chain) == 1,
    'omega : the implicit sys_deps condition is its ONLY chain entry' );

## the install path itself is exempt : debian waiting for an install only ##
## debian can do would never start                                        ##
$code{'v7-zenki.set_up_zenka_dependencies'}
    ->( 'cube', 'p7-log', 'debian', 'os-pkg', 'slow' );
ok( !chain_has_sys_deps('cube')
        && !chain_has_sys_deps('p7-log')
        && !chain_has_sys_deps('debian')
        && !chain_has_sys_deps('os-pkg'),
    'exempt by default : cube, p7-log, debian, os-pkg get no sys_deps'
);
ok( chain_has_sys_deps('slow'), '  :.. any other zenka still does' );

$data{'v7-zenki'}{'cfg'}{'sys_deps'}{'exempt'} = 'slow';
$code{'v7-zenki.set_up_zenka_dependencies'}->();
ok( !chain_has_sys_deps('slow') && chain_has_sys_deps('debian'),
    'exempt list from config replaces the default'
);
my $exempt_id            = sys_deps_object_id('slow');
my $probes_before_exempt = $PROBE_CALLS;
ok( $code{'v7-zenki.callback.object.sys_deps'}->($exempt_id)
        && $PROBE_CALLS == $probes_before_exempt,
    '  :.. callback for an exempt zenka : TRUE, nothing probed'
);
delete $data{'v7-zenki'}{'cfg'}{'sys_deps'}{'exempt'};
$code{'v7-zenki.set_up_zenka_dependencies'}->();

## an install that never answers : failed after install_timeout ##
my $slow_id = sys_deps_object_id('slow');
$data{'v7-zenki'}{'sys_deps'}{'state'}{'slow'} = {
    'status'      => 'installing',
    'started_at'  => $FAKE_NOW,
    'pending'     => 1,
    'missing_pm'  => ['Slow::Module'],
    'missing_os'  => [],
    'missing_bin' => [],
};
reset_recheck_pending();
ok( !$code{'v7-zenki.callback.object.sys_deps'}->($slow_id),
    'installing, inside install_timeout : callback FALSE [ waits ]'
);
$FAKE_NOW += 1801 * NTIME_PER_SECOND;
@LOGS = ();
ok( $code{'v7-zenki.callback.object.sys_deps'}->($slow_id)
        && state_of('slow')->{'status'} eq 'failed'
        && level0_logs_for(qr/install for zenka 'slow' timed out/) == 1,
    'installing past install_timeout : failed, TRUE [ degraded ], logged'
);

##[ 9 : debian cpan queue -- serialized with apt in ONE queue ]###############

say ': debian cpan queue [ serialized with apt ]';

my @EXECUTED;
$code{'debian.job.apt_install'}
    = sub { push @EXECUTED, [ qw| apt |, shift ] };
$code{'debian.job.cpan_install'}
    = sub { push @EXECUTED, [ qw| cpan |, shift ] };

$data{'debian'}{'apt_child'}{'w_fh'}        = 1;       ## stubbed child ##
$data{'debian'}{'apt_child'}{'current_job'} = undef;
$data{'jobqueue'}{'joblist'}                = {};

my $no_args = $code{'debian.cmd.install-cpan'}->( { 'args' => '' } );
ok( ( $no_args->{'mode'} // '' ) eq qw| false |,
    'install-cpan without modules : refused immediately'
);

my $apt_reply
    = $code{'debian.cmd.install-packages'}
    ->( { 'args' => 'ffmpeg', 'reply_id' => 11 } );
ok( ( $apt_reply->{'mode'} // '' ) eq qw| deferred |,
    'install-packages : deferred reply [ job queued ]'
);

my $cpan_reply = $code{'debian.cmd.install-cpan'}
    ->( { 'args' => 'Foo::Bar', 'reply_id' => 12 } );
ok( ( $cpan_reply->{'mode'} // '' ) eq qw| deferred |,
    'install-cpan : deferred reply [ job queued ]'
);

ok( scalar(@EXECUTED) == 1 and $EXECUTED[0][0] eq qw| apt |,
    'serialization : the apt job ran, the cpan job waits [ one in flight ]' );

my $joblist     = $data{'jobqueue'}{'joblist'};
my @queue_names = grep {
            $_ ne qw| by_id |
        and ref $joblist->{$_} eq qw| HASH |
        and scalar keys %{ $joblist->{$_}{'by_id'} // {} }
} keys %$joblist;
ok( scalar(@queue_names) == 1 and $queue_names[0] eq qw| apt-install |,
    'one shared queue : the waiting cpan job sits in the apt-install queue'
);

my $cpan_job_id
    = $queue_names[0]
    ? ( keys %{ $joblist->{ $queue_names[0] }{'by_id'} } )[0]
    : undef;
ok( defined $cpan_job_id
        and $joblist->{'by_id'}{$cpan_job_id}{'job_callback'} eq
        qw| debian.job.cpan_install |,
    'the queued job is the cpan install job'
);

$data{'debian'}{'apt_child'}{'current_job'} = undef;    ## apt finished ##
$code{'debian.apt_pump'}->();

ok( scalar(@EXECUTED) == 2
        and $EXECUTED[1][0] eq qw| cpan |
        and $EXECUTED[1][1]{'params'}{'modules'}[0] eq qw| Foo::Bar |,
    'serialization : cpan job ran only after the slot was released'
);

##[ 10 : bad module name fails the job BEFORE any shell ]#####################

say ': debian.job.cpan_install [ name sanitization ]';

compile_module('debian.job.cpan_install');    ## the real one again ##

@IO_WATCHERS = ();
@REPLIES     = ();
@MOVED       = ();

$data{'debian'}{'apt_child'}{'current_job'}
    = { 'job_id' => 777, 'reply_id' => 42 };

$code{'debian.job.cpan_install'}->(
    {   'job_id' => 777,
        'params' => {
            'modules'  => [qw| Bad::Name;rm -rf / |],
            'reply_id' => 42
        }
    }
);

my $bad_move
    = ( grep { $ARG->[0] == 777 and $ARG->[1] eq qw| error | } @MOVED )[0];
ok( defined $bad_move,
    'invalid module name : job failed [ moved to error ]' );
ok( scalar(@REPLIES) == 1
        and ( $REPLIES[0][1]{'mode'} // '' ) eq qw| false |
        and $REPLIES[0][1]{'data'} =~ m|^invalid module name|,
    'invalid module name : FALSE deferred reply with the reason'
);
ok( scalar(@IO_WATCHERS) == 0,
    'invalid module name : NO child spawned, NO watcher armed [ no shell ]' );
ok( ( not defined $data{'debian'}{'apt_child'}{'current_job'} ),
    'invalid module name : pump slot released' );

##[ 11 : a valid module goes to the ROOT apt child, nothing spawned here ]####
## the zenka process runs unprivileged after drop_privs : a cpanm it ##
## spawned itself could not write the system perl library            ##

say ': debian.job.cpan_install [ through the root apt child ]';

require Fcntl;    ## base.perlmod.load is a stub here ##
@IO_WATCHERS = ();
@REPLIES     = ();
@MOVED       = ();
my $child_in = '';
open( my $child_w, '>', \$child_in ) or die;
pipe( my $child_r, my $child_r_w )   or die;
$data{'debian'}{'apt_child'}{'w_fh'} = $child_w;
$data{'debian'}{'apt_child'}{'r_fh'} = $child_r;
$data{'debian'}{'apt_child'}{'current_job'}
    = { 'job_id' => 778, 'reply_id' => 43 };

$code{'debian.job.cpan_install'}->(
    {   'job_id' => 778,
        'params' => {
            'modules'  => [qw| Foo::Bar Baz |],
            'reply_id' => 43
        }
    }
);
close($child_w);
ok( $child_in eq "cpan Foo::Bar Baz\n",
    'valid modules : one cpan command written to the root apt child' );
ok( scalar(@IO_WATCHERS) == 1 and $IO_WATCHERS[0]{'fd'} == $child_r,
    '  :.. output watcher armed on the child\'s output pipe'
);
ok( !@MOVED && !@REPLIES, '  :.. job still running, no reply yet' );

##[ 12 : no in-process 'require' \ apt cache probes in v7-zenki ]#############

say ': probes inside v7-zenki';
ok( ( $main::INPROCESS_PROBES // 0 ) == 0,
    'no probe_module [ require ] and no cached apt probe was used' );

##[ summary ]#################################################################

say '';
if ($fail_count) {
    say "FAILED : $fail_count check[s]";
    exit 1;
}
say 'all checks passed';
exit 0;

#,,..,..,,...,.,,,..,,,..,,,,,,..,,,,,,.,,.,,,..,,...,...,.,.,...,,.,,,,.,..,,
#52LIORJFKUFUZZQQLPKAB3LJFVLQ55SRCB7JQEKK2QZ5DDQSXJR3AO2YRL6EWSZEV4OGVX56WN262
#\\\|GOIAA5DUAU67LQVK5W5VYJ5OK5WVTPICP7LAKNPJU4CQY3GMKR5 \ / AMOS7 \ YOURUM ::
#\[7]MF2II4VHS4SHUJVLHK4EKXZPQJVUWDKRTTLEACOQDVE5TK2IPOAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
