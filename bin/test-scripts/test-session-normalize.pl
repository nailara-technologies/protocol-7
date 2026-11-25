#!/usr/bin/env perl
use v5.32.0;
use strict;
use English;
use warnings;
use Cwd         qw| abs_path |;
use FindBin     qw| $RealBin |;
use File::Temp  qw| tempdir |;
use JSON::PP    ();
use Time::Local qw| timegm_modern |;

BEGIN { unshift @INC, "$RealBin/../../data/lib-path/pm" }

use AMOS7::NTIME qw| unix_to_ntime |;

my $root = abs_path("$RealBin/../..");
my $tmp  = tempdir( 'session-normalize-XXXXXX', TMPDIR => 1, CLEANUP => 1 );
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

my @secret = (
    'Bearer FAKE.bearer-value.123456',
    'sk-ant-FAKEtoken123456789',
    'sk-FAKEtoken123456789',
    'ghp_FAKEtoken123456789',
    'xoxb-FAKE-token-123456789',
    'AKIAFAKEACCOUNT12345',
    'RkFLRWJhc2U2NGtleTEyMzQ1Njc4OTAxMjM0NQ==',
    'eyJFAKEHEADER9.eyJFAKEPAYLOAD9.FAKESIGNATURE9',
    '-----BEGIN PRIVATE '
        . 'KEY-----FAKE-PRIVATE-MATERIAL-----END PRIVATE KEY-----',
    'access_token=FAKE-access-123456',
    'accountUuid: FAKE-account-123456',
);
my $long
    = 'first result line '
    . join( ' ', @secret ) . ' '
    . ( '~' x 460 )
    . "\nsecond result line";
my $session = 'fake-session-0000-0000-000000000000';
my @events  = (
    {   'type'      => 'system',
        'subtype'   => 'init',
        'sessionId' => $session,
        'timestamp' => '2026-01-02T03:04:05.000Z',
    },
    {   'type'      => 'user',
        'sessionId' => $session,
        'timestamp' => '2026-01-02T03:04:06.125Z',
        'message'   => {
            'role'    => 'user',
            'content' => "fake unicode : héllo 世界\nsecond line $secret[0]",
        },
    },
    {   'type'      => 'assistant',
        'sessionId' => $session,
        'timestamp' => '2026-01-02T03:04:07.250Z',
        'message'   => {
            'role'    => 'assistant',
            'model'   => 'fake-model-1',
            'content' => [
                { 'type' => 'text', 'text' => 'a fake answer' },
                {   'type'  => 'tool_use',
                    'name'  => 'FakeRead',
                    'input' => {
                        'file_path' => '/tmp/fake-世界',
                        'token'     => $secret[2],
                    },
                },
            ],
        },
    },
    {   'type'      => 'user',
        'sessionId' => $session,
        'timestamp' => '2026-01-02T03:04:08.375Z',
        'message'   => {
            'role'    => 'user',
            'content' => [
                {   'type'    => 'tool_result',
                    'content' => $long,
                },
            ],
        },
    },
    {   'type'      => 'system',
        'subtype'   => 'done',
        'sessionId' => $session,
        'timestamp' => '2026-01-02T03:04:09.500Z',
    },
);
my $input = "$tmp/fake.jsonl";
write_fake_transcript( $input, \@events );

my $command = "$root/bin/p7-session-normalize $input";
my $stdout  = qx{$command};
ok( $CHILD_ERROR == 0, 'normalizer exits successfully' );
my $output = "$tmp/native.txt";
system( $EXECUTABLE_NAME, "$root/bin/p7-session-normalize",
    $input, '-out', $output );
ok( $CHILD_ERROR == 0, '-out exits successfully' );
open my $fh, '<:encoding(UTF-8)', $output or die "$output : $OS_ERROR";
my $native = do { local $INPUT_RECORD_SEPARATOR; <$fh> };
close $fh;
ok( $stdout eq $native, 'stdout and -out are identical' );

my $first = '3125199189000.0000';
my $last  = '3125199205800.2100';
my @want  = (
    'archive.format = session-events-v1',
    "session.id = $session",
    'session.agent = claude',
    'session.model = fake-model-1',
    "session.first = $first",
    "session.last = $last",
    'count.source-lines = 5',
    'count.events = 5',
    'count.assistant = 1',
    'count.system = 2',
    'count.user = 2',
    '',
    "$first system system [ source 1 ] : init",
    '3125199193200.0525 user text [ source 2 ] : fake '
        . 'unicode : héllo 世界 / second line [ masked bearer ]',
    '3125199197400.1050 assistant text [ source 3 ] : a fake answer',
    '3125199197400.1050 assistant tool_use [ source 3 ] : '
        . 'FakeRead file_path=/tmp/fake-世界 token=[ masked api-token ]',
    '3125199201600.1575 user tool_result [ source 4 ] : '
        . length($long)
        . ' chars : first result line ',
    "$last system system [ source 5 ] : done",
);
my @actual_lines    = split m{\n}, $native;
my $expected_prefix = $want[-2];
ok( @actual_lines == @want, 'header and every event line are present' );
my $ordinary_match
    = join( "\n", @actual_lines[ 0 .. 15 ], $actual_lines[17] ) eq
    join( "\n", @want[ 0 .. 15 ], $want[17] );
ok( $ordinary_match, 'native header and ordinary events match' );
my $cut_match
    = $actual_lines[16] =~ m{\A\Q$expected_prefix\E.*\[ cut \d+ chars \]$};
ok( $cut_match, 'long result carries its original size and cut length' );
say "cut expected : $expected_prefix\ncut actual   : $actual_lines[16]"
    if not $cut_match;
ok( $native =~ m{héllo 世界} && $native =~ m{/tmp/fake-世界},
    'unicode survives decoding and encoding' );
my $reference_match = $native =~ m{\[ source 1 \].*\[ source 5 \]}s;
ok( $reference_match, 'source line references span the fake transcript' );
ok( $native =~ m{\Qfirst result line\E} && $native !~ m{second result line},
    'tool result keeps size and first line only' );
my $leaked = grep { index( $native, $ARG ) >= 0 } @secret;
ok( !$leaked, 'no fake secret reaches the native output' );
my $credential_masks = () = $native =~ m{\[ masked credential \]}g;
ok( $credential_masks >= 2, 'named token and account fields are masked' );
ok( $native !~ m{\r},       'output remains line oriented' );

say "\n# $pass passed, $fail failed";
exit( $fail ? 1 : 0 );

#,,.,,,..,...,,,.,,,,,,.,,,,.,..,,,.,,,,.,.,,,..,,...,...,,.,,,..,,,.,,.,,,,,,
#K7275KKWPJULFLLKFLOU5ILLVO6GC4UROIG74KFYIX3HL27AY4I5QNYOUXLWAYIUFMBIAPBDMQ3UG
#\\\|CBSXJ4MF2KU5UMYKPPVDZSZ2RI2OGH55XNW3YTYIDF3ZFKLWZMV \ / AMOS7 \ YOURUM ::
#\[7]JBWR2UOJOPDQ7HVEXC43WHJOJQMIGRDJFH2OA4KWNLEDFOJE2OCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
