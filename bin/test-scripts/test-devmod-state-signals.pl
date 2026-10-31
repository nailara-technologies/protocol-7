#!/usr/bin/perl
## devmod state signals : safe classification, deferred actions, and queues ##

use v5.32;
use strict;
use warnings;
use English;
use File::Spec;
use Cwd     qw| abs_path |;
use FindBin qw| $RealBin |;

BEGIN {
    my $up_dir = File::Spec->updir;
    $main::root_path = abs_path(
        File::Spec->rel2abs(
            File::Spec->catdir( $RealBin, $up_dir, $up_dir )
        )
    );
    $main::kill_count   = 0;
    *CORE::GLOBAL::kill = sub {
        $main::kill_count++;
        push $main::sent_signals->@*, [ $_[0], $_[1] ];
        return 1;
    };
}

use lib File::Spec->catdir( $main::root_path, qw| data lib-path pm | );
use AMOS7::Protocol::P7Syntax qw| p7_syntax__translate |;

use constant TRUE  => 5;
use constant FALSE => 0;

our %data;
our %code;
our $call;
my $fail_count = 0;
our $sent_signals = [];

sub ok ($;$) {
    my ( $condition, $label ) = @ARG;
    if ($condition) { say "  ok   : $label"; return }
    $fail_count++;
    say "  FAIL : $label";
    return;
}

sub read_src {
    my $name = shift;
    my $path = File::Spec->catfile( $main::root_path, 'src', $name );
    open my $fh, '<', $path or die "cannot read $path : $OS_ERROR";
    my $source = join '', <$fh>;
    close $fh;
    return $source;
}

sub compile_src {
    my $name   = shift;
    my $source = p7_syntax__translate( read_src($name) );
    my $cref   = eval "sub {\n# line 1 \"src/$name\"\n$source\n}";
    die "compile failed for $name : $EVAL_ERROR" if not defined $cref;
    return $cref;
}

my @safe = qw|
    b32-elf core-subs current-umask decode-harmonic-ref deparse-code dump
    dump-keys elf-b32 elf-num extract-line-map get inline-subroutines
    list-subs mem-allocated permission-setup receive-multiline since true
    true-int unload-devmod unload-unsafe
    |;
my @unsafe = qw|
    add-env change-log-verbosity del del-env eat-mem echo eval-code exec-sub
    free-mem keep-devmod-loaded set show-temp-heartbeat sleep switch-user
    test-strm test-strm-size utf8-stream-test utf8-test-buffer
    |;

my $cfg_path
    = File::Spec->catfile( $main::root_path, qw| cfg devmod-commands | );
open my $cfg_fh, '<', $cfg_path or die "cannot read $cfg_path : $OS_ERROR";
my $cfg = join '', <$cfg_fh>;
close $cfg_fh;
$cfg =~ s|\\\n\s+| |g;
my ($safe_cfg) = $cfg =~ m|^base\.devmod\.cmd_list\.safe\s*=\s*(.+)$|m;
my @cfg_safe   = split m| +|, $safe_cfg // '';
ok( join( ' ', @cfg_safe ) eq join( ' ', @safe ),
    'one safe allow-list contains the reviewed safe commands' );
ok( $cfg !~ m|cmd_list\.development_only|,
    'the second classification list is gone'
);

opendir my $src_dir, File::Spec->catdir( $main::root_path, 'src' )
    or die "cannot open src : $OS_ERROR";
my @all_commands = sort map {s|^devmod\.cmd\.||r}
    grep {m|^devmod\.cmd\.|} readdir $src_dir;
closedir $src_dir;
my %unsafe     = map  { $ARG => 1 } @unsafe;
my @cfg_unsafe = grep { exists $unsafe{$ARG} } @all_commands;
ok( @all_commands == 40, 'all 40 devmod commands are present' );
ok( join( ' ', @cfg_unsafe ) eq join( ' ', sort @unsafe ),
    'every remaining command has the reviewed unsafe classification'
);

$code{'base.devmod.safe_commands'} = sub { return @safe };
$code{'base.code.file_list'}       = sub {
    return map {"devmod.cmd.$ARG"} @safe, @unsafe, 'future-command';
};
$code{'base.sort'} = sub { return sort $_[0]->@* };
my $unsafe_commands = compile_src('base.devmod.unsafe_commands');
my @unsafe_result   = $unsafe_commands->();
ok( grep( { $ARG eq 'future-command' } @unsafe_result ),
    'an unknown future command defaults to unsafe'
);
ok( !grep( { $ARG eq 'get' } @unsafe_result ),
    'the unsafe complement excludes safe commands'
);

my $mask_recompiles = 0;
$code{'base.devmod.unsafe_commands'} = sub { return qw| eval-code set | };
$code{'base.disable_command'}        = sub { return TRUE };
$code{'base.parser.access_conf'} = sub { $mask_recompiles++; return TRUE };
$code{'devmod.cmd.get'}          = sub { return TRUE };
$code{'devmod.cmd.eval-code'}    = sub { return TRUE };
$code{'devmod.cmd.set'}          = sub { return TRUE };
my $unload_unsafe = compile_src('base.devmod.unload_unsafe');
$unload_unsafe->();
ok( !exists $code{'devmod.cmd.eval-code'}
        && !exists $code{'devmod.cmd.set'}
        && exists $code{'devmod.cmd.get'},
    'unsafe unloading removes code refs but retains safe commands'
);
ok( $mask_recompiles == 1,
    'unsafe unloading recompiles devcmd masks for loaded commands' );

say ': signal handlers only request deferred states';
my %expected_signal = qw| 50 off 51 safe 52 safe 53 full |;
foreach my $number ( sort keys %expected_signal ) {
    my $source = read_src("base.sig_NUM$number");
    ok( $source =~ m|requested_state.*$expected_signal{$number}|
            && $source !~ m|load_runtime_modules|,
        "NUM$number only records $expected_signal{$number}"
    );
}

say ': safe loading never compiles an unsafe command';
my @loaded;
$code{'base.devmod.safe_commands'} = sub { return @safe };
$code{'base.load_runtime_modules'} = sub { push @loaded, @ARG; return TRUE };
$code{'base.init_modules'}         = sub { return TRUE };
$code{'base.devmod.unload_unsafe'} = sub { return 0 };
$code{'base.parser.access_conf'}   = sub { return TRUE };
$code{'base.purge_code'}           = sub { return TRUE };
$code{'base.logs'}                 = sub { return TRUE };
my $process = compile_src('base.devmod.process_signal');

$data{'base'}{'devmod'}{'requested_state'} = 'safe';
$process->();
my %loaded = map { $ARG => 1 } @loaded;
ok( ( grep {m|^devmod\.cmd\.|} @loaded ) == @safe,
    'safe action loads exactly the safe command count'
);
ok( !grep( { exists $loaded{"devmod.cmd.$ARG"} } @unsafe ),
    'safe action never loads unsafe code first'
);

@loaded = ();
$data{'base'}{'devmod'}{'requested_state'} = 'full';
$process->();
ok( join( ' ', @loaded ) eq 'devmod', 'full action loads the whole module' );
ok( $data{'base'}{'devmod'}{'state'} eq 'full', 'full state is recorded' );

$data{'base'}{'devmod'}{'requested_state'} = 'off';
$process->();
ok( $data{'base'}{'devmod'}{'state'} eq 'off', 'off state is recorded' );

say ': v7 serializes each instance until its acknowledgement';
$code{'base.logs'} = sub { return TRUE };
$code{'v7-zenki.instance_ids'}
    = sub { return keys $data{'v7-zenki'}{'zenka'}{'instance'}->%* };
my $send_next = compile_src('v7-zenki.devmod.send_next');
$code{'v7-zenki.devmod.send_next'} = $send_next;
my $ack = compile_src('v7-zenki.zenka.cmd.devmod-ack');
$data{'v7-zenki'}{'zenka'}{'instance'}{7} = {
    'process'      => { 'id' => 4242 },
    'cube_sid'     => 77,
    'devmod_queue' => [ 'safe', 'full' ],
};
$send_next->(7);
$send_next->(7);
ok( @$sent_signals == 1 && $sent_signals->[0][0] == 51,
    'safe sends NUM51 and a duplicate call sends nothing'
);
$call = { 'args' => 'coding 77 safe safe' };
$ack->();
ok( @$sent_signals == 2 && $sent_signals->[1][0] == 53,
    'the safe ack releases full as NUM53' );
$call = { 'args' => 'coding 77 full full' };
$ack->();
ok( !defined $data{'v7-zenki'}{'zenka'}{'instance'}{7}{'devmod_pending'},
    'the full ack clears the pending action' );

$data{'v7-zenki'}{'zenka'}{'instance'}{7}{'devmod_queue'} = ['off'];
$send_next->(7);
ok( $sent_signals->[-1][0] == 50, 'off sends NUM50' );
$call = { 'args' => 'coding 77 off off' };
$ack->();
$data{'v7-zenki'}{'zenka'}{'instance'}{7}{'devmod_signaled_state'} = 'full';
$data{'v7-zenki'}{'zenka'}{'instance'}{7}{'devmod_queue'}          = ['safe'];
$send_next->(7);
ok( $sent_signals->[-1][0] == 52, 'full to safe sends NUM52' );

my $start_src = read_src('v7-zenki.zenka.start');
ok( $start_src =~ m|local \$ENV\{'PROTOCOL_7_DEVMOD_STATE'\}|,
    'restart state is supplied before exec' );
my $verify_src = read_src('v7-zenki.handler.instance_verification');
ok( $verify_src !~ m|kill 53|,
    'instance verification no longer sends a post-start signal' );

say '';
if ($fail_count) {
    say "FAILED : $fail_count check[s]";
    exit 1;
}
say 'all checks passed';
exit 0;

#,,,.,,.,,...,...,.,,,.,.,,..,,,.,,,.,,..,,,.,..,,...,...,..,,..,,,.,,.,.,.,.,
#4J2UWR2G64GGAGY2EVJLL464TY6FU4LGUYC7HSRP5U62C7QA3KCKFMQ6OTV6KFY3ST33XIZVS7O7A
#\\\|A2TJQEG5DCE2ABUZPUVJUZTH3GQVTSWWHCOW6X4U56DCTTS6HRA \ / AMOS7 \ YOURUM ::
#\[7]4QNXQSPRBMR5FCXWWPOZI4YQO62BODYW2IYZADQAISLYO36QFUAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
