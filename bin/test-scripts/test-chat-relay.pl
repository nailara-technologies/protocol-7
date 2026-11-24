#!/usr/bin/env perl
use v5.32;
use strict;
use English;
use warnings;

## bin/chat relay : a copied chat tree and a fake p7c, never a real session ##

use File::Spec;
use File::Temp qw| tempdir |;
use File::Path qw| make_path |;
use File::Copy qw| copy |;
use Cwd        qw| abs_path |;
use FindBin    qw| $RealBin |;
use IPC::Open3 ();
use Symbol     qw| gensym |;

my $root = abs_path(
    File::Spec->catdir( $RealBin, File::Spec->updir, File::Spec->updir ) );
my $tmp       = tempdir( 'chat-relay-XXXXXX', 'TMPDIR' => 1, 'CLEANUP' => 1 );
my $fake_root = "$tmp/root";
make_path( "$fake_root/bin", "$fake_root/data", "$tmp/bin", "$tmp/home" );
copy( "$root/bin/chat", "$fake_root/bin/chat" ) or die $OS_ERROR;
chmod 0700, "$fake_root/bin/chat";
symlink( "$root/data/lib-path", "$fake_root/data/lib-path" ) or die $OS_ERROR;

my $fake = <<'FAKE';
#!/usr/bin/env perl
use v5.32;
use strict;
use warnings;
use Encode qw| decode_utf8 |;
BEGIN { unshift @INC, $ENV{'FAKE_P7C_LIB'} }
use Crypt::Misc qw| decode_b32r |;

my $dir = $ENV{'FAKE_P7C_DIR'};
my $command = shift @ARGV // '';
open my $log, '>>:encoding(UTF-8)', "$dir/calls" or die $!;
my $arg = $ARGV[0] // '';
my $text = $arg;
## only ask-reply takes base32 ; the session commands get plain text ##
if ( length $arg and $command eq 'kimi.ask-reply' ) {
    my $decoded = eval { decode_utf8( decode_b32r($arg) ) };
    $text = $decoded if defined $decoded;
}
$text =~ s{[\r\n]+}{ / }g;
print {$log} "$command\t$text\n";
close $log;

sub append_event {
    my ( $model, $kind, $line ) = @_;
    open my $fh, '>>:encoding(UTF-8)', "$dir/$model-events" or die $!;
    print {$fh} "12:00:00 $kind : $line\n";
    close $fh;
}
sub tail {
    my $model = shift;
    return if not -f "$dir/$model-events";
    open my $fh, '<:encoding(UTF-8)', "$dir/$model-events" or die $!;
    print while <$fh>;
    close $fh;
}
if ( $command eq 'kimi.acp-send' ) {
    if ( -f "$dir/acp-error" ) {
        print ": error : acp unavailable\n";
        exit 1;
    }
    my $n = 1;
    $n++ while -f "$dir/kimi-reply-$n";
    open my $mark, '>', "$dir/kimi-reply-$n" or die $!;
    close $mark;
    append_event( 'kimi', 'agent', "acp reply $n" );
    append_event( 'kimi', 'done', 'prompt ended [ end_turn ]' );
    print "sent\n";
} elsif ( $command eq 'kimi.acp-tail' ) {
    tail('kimi');
} elsif ( $command eq 'kimi.ask-reply' ) {
    print "fallback reply\n";
} elsif ( $command eq 'claude.send' ) {
    append_event( 'claude', 'text', 'claude reply' );
    append_event( 'claude', 'final', 'success : done' );
    print "turn sent\n";
} elsif ( $command eq 'claude.tail' ) {
    tail('claude');
} else {
    print ": error : unexpected $command\n";
    exit 2;
}
FAKE
open my $fake_fh, '>:encoding(UTF-8)', "$tmp/bin/p7c" or die $OS_ERROR;
print {$fake_fh} $fake;
close $fake_fh;
chmod 0700, "$tmp/bin/p7c";

my ( $pass, $fail ) = ( 0, 0 );

sub ok ($$) {
    my ( $condition, $label ) = @ARG;
    if   ($condition) { $pass++; say "ok   - $label" }
    else              { $fail++; say "FAIL - $label" }
}

sub slurp {
    my $path = shift;
    return '' if not -f $path;
    open my $fh, '<:encoding(UTF-8)', $path or die $OS_ERROR;
    local $/;
    my $text = <$fh> // '';
    close $fh;
    return $text;
}

sub run_chat {
    my @args = @_;
    local %ENV = %ENV;
    $ENV{'PATH'}           = "$tmp/bin:$ENV{'PATH'}";
    $ENV{'HOME'}           = "$tmp/home";
    $ENV{'P7_CHAT_CALLER'} = 'user';
    $ENV{'FAKE_P7C_DIR'}   = $tmp;
    $ENV{'FAKE_P7C_LIB'}   = "$root/data/lib-path/pm";
    my $err = gensym;
    my $pid = IPC::Open3::open3( undef, my $out, $err,
        $EXECUTABLE_NAME, "$fake_root/bin/chat", @args );
    my $stdout = do { local $/; <$out> // '' };
    my $stderr = do { local $/; <$err> // '' };
    waitpid $pid, 0;
    return ( $stdout . $stderr, $CHILD_ERROR >> 8 );
}

sub call_count {
    my $command = shift;
    my $calls   = slurp("$tmp/calls");
    return scalar grep {m{^\Q$command\E\t}} split m{\n}, $calls;
}
my $history = "$fake_root/data/development/chat/channel/main/history";

my ( $out, $status ) = run_chat('-help');
$out =~ s{\e\[[0-9;]*m}{}g;
ok( $status == 0 && $out =~ m{-relay off} && $out =~ m{-relay on},
    'help describes the relay switch' );
( $out, $status ) = run_chat( '-q', '-m', 'kimi', 'hello acp' );
my $written = slurp($history);
my $label   = 'kimi uses acp and labels its history reply';
ok( $status == 0 && $written =~ m{<kimi>\s+\[acp\] acp reply}, $label );
ok( call_count('kimi.acp-send') == 1 && call_count('kimi.ask-reply') == 0,
    'successful acp does not call ask-reply' );
ok( slurp("$tmp/calls") =~ m{^kimi\.acp-send\t[^\n]*hello acp}m,
    'kimi.acp-send gets the text as plain text [ not base32 ]'
);
open my $error_fh, '>', "$tmp/acp-error" or die $OS_ERROR;
close $error_fh;
run_chat( '-q', '-m', 'kimi', 'hello fallback' );
$written = slurp($history);
$label   = 'an acp error falls back and labels ask-reply';
ok( $written =~ m{<kimi>\s+\[ask-reply\] fallback reply}, $label );
unlink "$tmp/acp-error";
run_chat( '-q', '-m', 'claude', 'hello claude' );
ok( slurp("$tmp/calls") =~ m{^claude\.send\t[^\n]*hello claude}m,
    'claude.send gets the text as plain text [ not base32 ]'
);
$written = slurp($history);
$label   = 'claude uses the zenka and labels its history reply';
ok( $written =~ m{<claude>\s+\[zenka\] claude reply}, $label );
ok( !-e "$fake_root/data/development/chat/inbox/claude",
    'the unread claude inbox file is not written'
);

run_chat( '-q', '-relay', 'off', 'kimi' );
my $before = call_count('kimi.acp-send');
run_chat( '-q', '-m', 'kimi', 'paused one' );
run_chat( '-q', '-m', 'kimi', 'paused two' );
ok( call_count('kimi.acp-send') == $before,
    'relay off pauses kimi delivery' );
my $held = slurp($history);
ok( $held =~ m{paused one} && $held =~ m{paused two},
    'paused messages stay in channel history'
);
run_chat( '-q', '-relay', 'off',    'claude' );
run_chat( '-q', '-m',     'claude', 'claude held' );
run_chat( '-q', '-relay', 'on',     'kimi' );
ok( call_count('kimi.acp-send') == $before + 2,
    'on delivers pending messages for one target'
);
( $out, $status ) = run_chat( '-q', '-relay' );
ok( $out =~ m{relay claude\s+: off, queued 1}
        && $out =~ m{relay kimi\s+: on, queued 0},
    'relay state is per target with queued counts'
);
$before = call_count('claude.send');
run_chat( '-q', '-relay', 'off', 'claude', '-drop' );
run_chat( '-q', '-relay', 'on', 'claude' );
$written = slurp($history);
ok( call_count('claude.send') == $before && $written =~ m{claude held},
    'drop discards delivery but retains history' );

run_chat( '-q', '-relay', 'off', 'kimi', '-for', '1s' );
run_chat( '-q', '-m', 'kimi', 'timed pause' );
$before = call_count('kimi.acp-send');
sleep 2;
( $out, $status ) = run_chat( '-q', '-relay' );
ok( call_count('kimi.acp-send') == $before + 1
        && $out =~ m{relay kimi\s+: on, queued 0},
    'a -for pause expires on a later chat call'
);
my $stored_relay = slurp("$fake_root/data/development/chat/relay");
ok( $stored_relay !~ m{relay\.kimi\.until = [1-9]},
    'expiry clears the stored until time'
);

run_chat( '-q', '-relay', 'off' );
my $kimi_before_all   = call_count('kimi.acp-send');
my $claude_before_all = call_count('claude.send');
run_chat( '-q', '-m', 'all', 'held broadcast' );
ok( call_count('kimi.acp-send') == $kimi_before_all
        && call_count('claude.send') == $claude_before_all,
    'all pauses every delivery target'
);
run_chat( '-q', '-relay', 'on' );
ok( call_count('kimi.acp-send') == $kimi_before_all + 1
        && call_count('claude.send') == $claude_before_all + 1,
    'on all releases both targets'
);

run_chat( '-q', '-relay', 'off',  'kimi' );
run_chat( '-q', '-m',     'kimi', "overflow $_" ) for 1 .. 14;
$before = call_count('kimi.acp-send');
run_chat( '-q', '-relay', 'on', 'kimi' );
ok( call_count('kimi.acp-send') == $before + 14,
    'beyond thirteen pending messages sends thirteen plus one note' );
my $calls = slurp("$tmp/calls");
ok( $calls
        =~ m{kimi\.acp-send\t1 more in \#main \(1\) since .*history: .*channel/main/history},
    'the overflow note has count, channel, time and history pointer'
);
my $final_history = slurp($history);
my $lost          = 0;
$lost++ for grep { $final_history !~ m{overflow $_\b} } 1 .. 14;
ok( $lost == 0, 'no queued message is lost from history' );

if ($fail) {
    say "# calls:\n$calls";
    say '# relay state: ' . slurp("$fake_root/data/development/chat/relay");
    say "# last relay output:\n$out";
    say "# history:\n$final_history";
}
say "# $pass passed, $fail failed";
exit( $fail ? 1 : 0 );

#,,.,,..,,.,,,,,,,,,,,..,,,..,.,,,.,,,.,.,..,,..,,...,...,,,,,.,,,...,,,.,..,,
#36WFY26VZCO33MO25WT57IUIIKCR3Y6YEK2EYVIFCYWUWJ46P4GHR6SNQJEVFRXACJMUUYH47XURK
#\\\|WQ2NLOXLEME55CLARYRPBE7IZLUHDV3OBO2MCZSD3MKRP4NH6OM \ / AMOS7 \ YOURUM ::
#\[7]PATEH7PKX6XSIQYFKRW75QPM6WBYSJ766HFU7ZWZMU2QHBARPACY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
