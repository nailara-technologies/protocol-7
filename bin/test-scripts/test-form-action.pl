#!/usr/bin/perl
## test : form.action.send + form.chrome [ lane B2a, stubs only ]
##
## covers the task contract in data/tasks/form-action-chrome.md : send -> busy
## set, second send refused, reply -> busy cleared + on_reply called, timeout
## path, keys ignored while busy except quit, set_status -> footer line
## present, no status -> chrome prints nothing [ the byte-identical render
## guarantee itself is proven by the p7-user-edit show-form cmp in the lane,
## not here ]

use v5.28;
use strict;
use warnings;
use English qw| -no_match_vars |;
use FindBin qw| $RealBin |;
use IO::Handle;

BEGIN { unshift( @INC, "$RealBin/../../data/lib-path/pm" ) }

use AMOS7::Protocol::P7Syntax qw| p7_syntax__translate |;

use constant TRUE    => 5;
use constant FALSE   => 0;
use constant UNKNOWN => 2;

our ( %data, %code, %colors, %keys );
%colors = (
    qw| p7_fg_0000 | => '',
    qw| p7_fg_0001 | => '',
    qw| reset |      => ''
);

{

    package test_timer;
    sub cancel { }
}

my $module_dir = "$RealBin/../../src";

my @module_files = qw|
    form.action.send
    form.handler.action_reply
    form.handler.action_timeout
    form.chrome
    form.chrome.set_status
    form.handler.stdin_key
    |;

for my $file (@module_files) {
    open( my $fh, '<', "$module_dir/$file" ) or die "open $file : $!";
    my $src = do { local $/; <$fh> };
    close($fh);
    $src =~ s{\n#,[^\n]*\n#[A-Z2-7]{40,}[^\n]*\n#\\\\\\\|.*\z}{}s;
    my $translated = p7_syntax__translate($src);
    my $cref = eval( "sub {\n# line 1 \"$file\"\n" . $translated . "\n}" );
    die "compile $file : $@" if ref $cref ne 'CODE';
    $code{$file} = $cref;
}

##[ stubs ]###################################################################

my %stub_log;

$code{'protocol-7.command.send.local'} = sub {
    my ($call) = @_;
    push @{ $stub_log{'send.local'} }, $call;
    return $stub_log{'send.local_result'} // 1;
};

$code{'event.add_timer'} = sub {
    my ($spec) = @_;
    push @{ $stub_log{'add_timer'} }, $spec;
    return $stub_log{'timer_object'} // bless {}, 'test_timer';
};

$code{'test.on_reply'} = sub {
    my ($reply) = @_;
    push @{ $stub_log{'on_reply'} }, $reply;
    return TRUE;
};

$code{'base.logs'} = sub { return TRUE };

$code{'form.quit'} = sub {
    my (@args) = @ARG;
    $stub_log{'quit'} = \@args;
    return TRUE;
};

$code{'editor.input.next_key'} = sub {
    my ($buf_ref) = @_;
    my $queue = $stub_log{'key_queue'} // [];
    return shift @{$queue} if scalar @{$queue};
    return undef;
};

$code{'form.removable_field'} = sub { return undef };

$code{'editor.control.get_value'} = sub { return '' };

$code{'editor.control.process_key'} = sub {
    my ( $state, $key ) = @ARG;
    push @{ $stub_log{'process_key'} }, $key;

    ## ctrl-c arrives as the 'signal' action [ editor.control.process_key
    ## contract -- form.handler.stdin_key's own signal branch quits ]
    return $stub_log{'process_key_result'}
        // { qw| action | => $key eq "\x03" ? qw| signal | : qw| none | };
};

sub reset_state {
    %stub_log = ();
    delete $data{'form'};
    $data{'form'}{'cube_sid'} = 42;
    return;
}

##[ assertions ]##############################################################

my ( $pass, $fail ) = ( 0, 0 );

sub ok {
    my ( $cond, $label ) = @ARG;    ## local ok(), prototype-free ($;$)
    if ($cond) { $pass++; return }
    $fail++;
    print "FAIL : $label\n";
    return;
}

sub stdout_of {
    my ($cref) = @_;
    my $capture = '';
    open( my $out_fh, '>', \$capture ) or die "capture : $!";
    my $old_fh = select $out_fh;
    $cref->();
    select $old_fh;
    close($out_fh);
    return $capture;
}

##[ form.action.send ]########################################################

reset_state();
ok( $code{'form.action.send'}->( 'users.value-get', 'rec-x', 'test.on_reply' )
        == TRUE,
    'send returns TRUE'
);
ok( ref $data{'form'}{'busy'} eq 'HASH', 'busy set [ HASHREF ]' );
ok( $data{'form'}{'busy'}{'label'} eq 'users.value-get',
    'busy carries the command as its label' );
ok( $stub_log{'send.local'}[-1]{'command'} eq '42.users.value-get',
    'route carries the <form.cube_sid> prefix' );
ok( $stub_log{'send.local'}[-1]{'call_args'}{'args'} eq 'rec-x',
    'args passed through call_args' );
ok( $stub_log{'send.local'}[-1]{'reply'}{'handler'} eq
        'form.handler.action_reply',
    'reply wired to form.handler.action_reply'
);
ok( $stub_log{'add_timer'}[-1]{'after'} == 30, 'default timeout is 30 s' );

## second send while busy is refused ##
ok( $code{'form.action.send'}->( 'users.value-get', 'rec-y', 'test.on_reply' )
        == FALSE,
    'second send while busy refused'
);
ok( scalar @{ $stub_log{'send.local'} } == 1,
    'refused send never reached send.local'
);

## explicit timeout parameter ##
reset_state();
$code{'form.action.send'}->( 'users.value-get', '', 'test.on_reply', 7 );
ok( $stub_log{'add_timer'}[-1]{'after'} == 7, 'timeout parameter honoured' );

## reply : busy cleared + on_reply called with the reply ##
ok( $code{'form.handler.action_reply'}->( { qw| data | => qw| reply-ok | } )
        == TRUE,
    'reply handler returns TRUE'
);
ok( !defined $data{'form'}{'busy'} || !$data{'form'}{'busy'},
    'busy cleared on reply' );
ok( ref $stub_log{'on_reply'}[-1] eq 'HASH'
        && $stub_log{'on_reply'}[-1]{'data'} eq 'reply-ok',
    'on_reply called with the reply'
);

## timeout path : busy cleared + on_reply gets the timeout marker ##
reset_state();
$code{'form.action.send'}->( 'users.value-get', '', 'test.on_reply', 7 );
ok( $code{'form.handler.action_timeout'}->() == TRUE,
    'timeout handler returns TRUE' );
ok( !defined $data{'form'}{'busy'} || !$data{'form'}{'busy'},
    'busy cleared on timeout' );
ok( ref $stub_log{'on_reply'}[-1] eq 'HASH'
        && $stub_log{'on_reply'}[-1]{'timeout'},
    'on_reply called with timeout marker'
);

## a LATE reply to the timed-out call must not reach the next action ##
$code{'form.action.send'}->( 'users.value-set', '', 'test.on_reply', 7 );
my $calls_before = scalar @{ $stub_log{'on_reply'} };
ok( $code{'form.handler.action_reply'}->( { qw| data | => qw| late | } )
        == FALSE,
    'late reply of the timed-out call : dropped'
);
ok( scalar @{ $stub_log{'on_reply'} } == $calls_before
        && ref $data{'form'}{'busy'} eq 'HASH',
    '  :.. the new action is still waiting for ITS reply'
);
ok( $code{'form.handler.action_reply'}->( { qw| data | => qw| mine | } )
        == TRUE && $stub_log{'on_reply'}[-1]{'data'} eq 'mine',
    '  :.. and gets its own reply next'
);

## send.local failure : no reply will ever arrive -> busy cleared at once ##
reset_state();
$stub_log{'send.local_result'} = 0;
ok( $code{'form.action.send'}->( 'users.value-get', '', 'test.on_reply' )
        == FALSE,
    'send.local failure returns FALSE'
);
ok( !defined $data{'form'}{'busy'} || !$data{'form'}{'busy'},
    'busy cleared on send.local failure' );

## reply handler with no outstanding call is a clean no-op ##
reset_state();
ok( $code{'form.handler.action_reply'}->( { qw| data | => qw| stray | } )
        == FALSE,
    'stray reply is a no-op'
);

##[ keys while busy ]#########################################################

sub run_stdin_key {
    my (@keys) = @_;
    $stub_log{'key_queue'} = [@keys];
    return $code{'form.handler.stdin_key'}->();
}

## minimal editor state the handler's pre-process_key sampling reads
my $minimal_state = {
    qw| mode |         => qw| insert |,
    qw| active_field | => 0,
    qw| schema |       => { qw| fields | => [ { qw| name | => qw| f0 | } ] },
};

reset_state();
$data{'form'}{'state'}     = $minimal_state;
$data{'form'}{'hint_seen'} = TRUE;
$data{'form'}{'mode'}      = { qw| no_tty_debug | => TRUE };
$data{'form'}{'busy'}      = { qw| label |        => qw| users.value-get | };

run_stdin_key( 'a', "\e[A", "\e[B" );
ok( !defined $stub_log{'process_key'},
    'keys ignored while busy [ none reached process_key ]' );
ok( !defined $stub_log{'quit'}, 'no quit from ignored keys' );

run_stdin_key("\x03");
ok( defined $stub_log{'quit'}, 'ctrl-c quit still works while busy' );

delete $data{'form'}{'busy'};
run_stdin_key('a');
ok( defined $stub_log{'process_key'} && $stub_log{'process_key'}[-1] eq 'a',
    'keys decoded again once busy clears' );

##[ form.chrome ]#############################################################

reset_state();
my $out = stdout_of( sub { $code{'form.chrome'}->() } );
ok( length($out) == 0, 'no status, no busy -> chrome prints nothing' );

$data{'form'}{'status'} = 'probing atom ..';
$out = stdout_of( sub { $code{'form.chrome'}->() } );
ok( index( $out, 'probing atom ..' ) >= 0, 'footer shows <form.status>' );

$data{'form'}{'status'} = '';
$data{'form'}{'busy'}   = { qw| label | => qw| users.value-get | };
$out                    = stdout_of( sub { $code{'form.chrome'}->() } );
ok( index( $out, '[ users.value-get ]' ) >= 0,
    'footer shows busy label with bracket marker'
);

$data{'form'}{'status'} = 'pinned';
$out = stdout_of( sub { $code{'form.chrome'}->() } );
ok( index( $out, 'pinned [ users.value-get ]' ) >= 0,
    'status and busy label combine on one footer line'
);

## form.chrome.set_status updates <form.status> and repaints ##
reset_state();
my $dirty_before = $data{'form'}{'dirty'} // 0;
ok( $code{'form.chrome.set_status'}->('certified') == TRUE,
    'set_status returns TRUE' );
ok( ( $data{'form'}{'status'} // '' ) eq 'certified',
    'set_status updates <form.status>' );
ok( $data{'form'}{'dirty'} == $dirty_before + 1,
    'set_status bumps <form.dirty> [ repaint ]'
);

$code{'form.chrome.set_status'}->(undef);
ok( !length( $data{'form'}{'status'} ), 'set_status undef clears the line' );

##[ summary ]#################################################################

print "\n$pass passed, $fail failed\n";
exit( $fail ? 1 : 0 );

#,,.,,.,,,..,,,,.,,.,,...,..,,,,,,.,,,,,,,.,.,..,,...,...,,.,,,,.,...,,,.,...,
#U5NOPQXLG23OUT6LZIRAXEJCX6QMQ62ITF55CMFBH7E6Q3IOU22BUFPNCKQ35ECITBOC7A6J2FVFW
#\\\|Z62DBK4STK6GECEOON5TEY5L7GQNCYBRFPKYNWEH3WDA3SXGZPF \ / AMOS7 \ YOURUM ::
#\[7]QXS6NI5QEZN54BVDZW47Q2OI2RFIB7QSEAI35EGDK5MLTMUOAMCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
