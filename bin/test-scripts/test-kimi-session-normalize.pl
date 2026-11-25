#!/usr/bin/env perl
use v5.32.0;
use strict;
use English;
use warnings;
use Cwd        qw| abs_path |;
use FindBin    qw| $RealBin |;
use File::Path qw| make_path |;
use File::Temp qw| tempdir |;
use JSON::PP   ();

my $root = abs_path("$RealBin/../..");
my $tmp
    = tempdir( 'kimi-session-normalize-XXXXXX', TMPDIR => 1, CLEANUP => 1 );
my $json = JSON::PP->new->utf8->canonical;
my ( $pass, $fail ) = ( 0, 0 );

sub ok {
    if   ( $_[0] ) { $pass++; say "ok   - $_[1]" }
    else           { $fail++; say "FAIL - $_[1]" }
}

sub write_fake_transcript {
    my ( $path, $events ) = @ARG;
    open my $fh, '>:raw', $path or die "$path : $OS_ERROR";
    print {$fh} $json->encode($ARG) . "\n" foreach @{$events};
    close $fh or die "$path : $OS_ERROR";
}

my $bearer = 'Bearer FAKE.kimi-bearer.123456';
my $token  = 'sk-FAKEkimiToken123456789';
my $long   = 'first kimi result ' . $bearer . "\nsecond kimi result";
my @events = (
    {   'type'             => 'metadata',
        'protocol_version' => '1.5',
        'created_at'       => 1767323045000,
    },
    {   'type'  => 'turn.prompt',
        'time'  => 1767323045125,
        'input' => [
            {   'type' => 'text',
                'text' => "fake kimi prompt : héllo 世界\n$bearer",
            },
        ],
    },
    {   'type'  => 'llm.request',
        'time'  => 1767323045250,
        'model' => 'fake-kimi-model',
    },
    {   'type'  => 'context.append_loop_event',
        'time'  => 1767323045375,
        'event' => { 'type' => 'step.begin', 'step' => 1 },
    },
    {   'type'  => 'context.append_loop_event',
        'time'  => 1767323045500,
        'event' => {
            'type' => 'content.part',
            'part' => { 'type' => 'think', 'think' => 'fake kimi reasoning' },
        },
    },
    {   'type'  => 'context.append_loop_event',
        'time'  => 1767323045625,
        'event' => {
            'type' => 'content.part',
            'part' => { 'type' => 'text', 'text' => 'fake kimi answer' },
        },
    },
    {   'type'  => 'context.append_loop_event',
        'time'  => 1767323045750,
        'event' => {
            'type' => 'tool.call',
            'name' => 'FakeRead',
            'args' => {
                'file_path' => '/tmp/kimi-世界',
                'token'     => $token,
            },
        },
    },
    {   'type'  => 'context.append_loop_event',
        'time'  => 1767323045875,
        'event' => {
            'type'   => 'tool.result',
            'result' => { 'output' => $long },
        },
    },
    {   'type'    => 'context.append_message',
        'time'    => 1767323046000,
        'message' => {
            'role'    => 'assistant',
            'content' =>
                [ { 'type' => 'text', 'text' => 'appended kimi answer' }, ],
            'toolCalls' => [
                {   'name' => 'FakeWrite',
                    'args' => { 'path' => '/tmp/kimi-output' },
                },
            ],
        },
    },
    {   'type'  => 'usage.record',
        'time'  => 1767323046125,
        'model' => 'fake-kimi-model',
    },
);
my $session = 'fake-kimi-0000-0000-000000000000';
my $dir     = "$tmp/session_$session/agents/main";
make_path($dir);
my $input = "$dir/wire.jsonl";
write_fake_transcript( $input, \@events );

my $command = "$root/bin/p7-session-normalize $input";
my $stdout  = qx{$command};
ok( $CHILD_ERROR == 0, 'kimi normalizer exits successfully' );
my $output = "$tmp/native.txt";
system( $EXECUTABLE_NAME, "$root/bin/p7-session-normalize",
    $input, '-out', $output );
ok( $CHILD_ERROR == 0, 'kimi -out exits successfully' );
open my $fh, '<:encoding(UTF-8)', $output or die "$output : $OS_ERROR";
my $native = do { local $INPUT_RECORD_SEPARATOR; <$fh> };
close $fh;
ok( $stdout eq $native, 'kimi stdout and -out are identical' );

my $first = '3125199189000.0000';
my $last  = '3125199193725.0000';
my @want  = (
    'archive.format = session-events-v1',
    "session.id = $session",
    'session.agent = kimi',
    'session.model = fake-kimi-model',
    "session.first = $first",
    "session.last = $last",
    'count.source-lines = 10',
    'count.events = 10',
    'count.context.append_loop_event = 5',
    'count.context.append_message = 1',
    'count.llm.request = 1',
    'count.metadata = 1',
    'count.turn.prompt = 1',
    'count.usage.record = 1',
    '',
    "$first system metadata [ source 1 ] : metadata",
    '3125199189525.0000 user text [ source 2 ] : '
        . 'fake kimi prompt : héllo 世界 / [ masked bearer ]',
    '3125199190050.0000 system llm.request [ source 3 ] : llm.request',
    '3125199190575.0000 system step.begin [ source 4 ] : 1',
    '3125199191100.0000 assistant thinking '
        . '[ source 5 ] : fake kimi reasoning',
    '3125199191625.0000 assistant text [ source 6 ] : fake kimi answer',
    '3125199192150.0000 assistant tool_use [ source 7 ] : '
        . 'FakeRead file_path=/tmp/kimi-世界 token=[ masked api-token ]',
    '3125199192675.0000 system tool_result [ source 8 ] : '
        . length($long)
        . ' chars : first kimi result [ masked bearer ]',
    '3125199193200.0000 assistant text [ source 9 ] : appended kimi answer',
    '3125199193200.0000 assistant tool_use [ '
        . 'source 9 ] : FakeWrite path=/tmp/kimi-output',
    "$last system usage.record [ source 10 ] : usage.record",
);
my @actual_lines = split m{\n}, $native;
ok( @actual_lines == @want, 'kimi header and every event line are present' );
ok( join( "\n", @actual_lines ) eq join( "\n", @want ),
    'kimi native header and events match' );

if ( join( "\n", @actual_lines ) ne join( "\n", @want ) ) {
    say "expected :\n" . join( "\n", @want );
    say "actual :\n$native";
}
ok( $native =~ m{héllo 世界} && $native =~ m{/tmp/kimi-世界},
    'kimi unicode survives decoding and encoding'
);
ok( index( $native, $bearer ) < 0 && index( $native, $token ) < 0,
    'no fake kimi secret reaches the native output' );
ok( $native !~ m{second kimi result},
    'kimi tool result keeps first line only'
);
ok( $native !~ m{\r}, 'kimi output remains line oriented' );

say "\n# $pass passed, $fail failed";
exit( $fail ? 1 : 0 );

#,,.,,,,.,..,,,..,.,.,,,,,,.,,,.,,.,,,,,.,...,..,,...,...,..,,...,,..,,..,...,
#B7O3XDH7225MSTVG7V6BOO3BNPA5NND5L66HLP6ZUDRZ7ND3JRQBJEGSP6242NM7BY2X4MJLH6SZE
#\\\|RZ5NQUHK6KJ26CSR5T5CVZTSAHPJAJP56XSFFZUQDSP6BKWN4ZZ \ / AMOS7 \ YOURUM ::
#\[7]DWOKK5A2OHVV6ZR4ZY7LXXEDLV3XDH2LMLKWZLYNDVZA7EJJIKBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
