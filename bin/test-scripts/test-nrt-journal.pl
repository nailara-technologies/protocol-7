#!/usr/bin/perl
use v5.32.0;
use strict;
use English;
use warnings;

use FindBin;
BEGIN { unshift @INC, "$FindBin::RealBin/../../data/lib-path/pm" }

use Test::More;
use File::Temp qw| tempdir |;
use File::Path qw| remove_tree |;
use IPC::Open3 qw| open3 |;
use Symbol     qw| gensym |;
use Math::BigInt;
use AMOS7::N7FS::Sign  qw| key_file_write key_file_signer verify |;
use AMOS7::cell::canon qw| bmw384_b32 pack_head parse_head record_address |;
use AMOS7::cell::canon::list qw| pack_body |;
use AMOS7::NRT::drops qw| MAX_DROPS amount bounded add multiply divide pair |;
use AMOS7::NRT::journal qw| read_file replay common commit verify_head |;
use AMOS7::NRT::journal::canon             qw| kind |;
use AMOS7::NRT::transaction                qw| prepare_issue |;
use AMOS7::NRT::user::account::transaction qw| prepare_transfer |;

my $root = "$FindBin::RealBin/../..";
my $tmp  = tempdir( 'nrt-journal-test.XXXXXX', TMPDIR => 1, CLEANUP => 1 );
my $time = '31703855078';
my %key_path;
my %signer;
my $seed = 17;
for my $name (qw| witness alice bob carol dave other |) {
    $key_path{$name} = "$tmp/$name.key";
    key_file_write( $key_path{$name}, chr($seed) x 32 );
    $signer{$name} = key_file_signer( $key_path{$name} );
    $seed += 13;
}

sub write_bytes {
    my ( $path, $bytes ) = @ARG;
    open( my $fh, '>:raw', $path ) or die "$path : $OS_ERROR";
    print {$fh} $bytes             or die "$path : $OS_ERROR";
    close $fh                      or die "$path : $OS_ERROR";
    chmod 0600, $path;
    return;
}

sub cli {
    my ( $dir, @args ) = @_;
    my $env = ref $args[-1] eq q|HASH| ? pop @args : {};
    local $ENV{'NRT_DIR'}        = $dir;
    local $ENV{'NRT_TEST_NTIME'} = $env->{'ntime'} // $time;
    my $error = gensym;
    my $pid   = open3( my $in, my $out, $error, $^X, "$root/bin/nrt", @args );
    close $in;
    local $INPUT_RECORD_SEPARATOR;
    my $stdout = <$out>   // '';
    my $stderr = <$error> // '';
    close $out;
    close $error;
    waitpid( $pid, 0 );
    return { code => $CHILD_ERROR >> 8, out => $stdout, err => $stderr };
}

sub command_ok {
    my ( $name, $dir, @args ) = @_;
    my $result = cli( $dir, @args );
    is( $result->{'code'}, 0, $name ) or diag $result->{'err'};
    return $result;
}

sub ledger {
    my ( $name, $issue ) = @_;
    $issue //= 10000;
    my $dir = "$tmp/$name";
    command_ok( "$name init", $dir, 'init', $dir, '-witness',
        $key_path{'witness'} );
    for my $account (qw| alice bob carol dave |) {
        command_ok( "$name account $account",
            $dir, 'account', 'add', $account, '-key', $key_path{$account} );
    }
    command_ok( "$name test issue",
        $dir, 'issue', 'alice', $issue,
        '-witness', $key_path{'witness'}, '-test' );
    return $dir;
}

sub snapshot {
    my $dir = shift;
    return [ read_file("$dir/journal"), read_file("$dir/head") ];
}

sub same_snapshot {
    my ( $name, $before, $dir ) = @_;
    is_deeply( snapshot($dir), $before, $name );
    return;
}

sub refused {
    my ( $name, $dir, @args ) = @_;
    my $before = snapshot($dir);
    my $result = cli( $dir, @args );
    isnt( $result->{'code'}, 0, $name );
    like( $result->{'err'}, qr|nrt|, "$name has a refusal" );
    same_snapshot( "$name leaves journal and head byte-identical",
        $before, $dir );
    return $result;
}

sub verify_ok {
    my ( $name, $dir, $supply ) = @_;
    my $result = command_ok( $name, $dir, 'verify' );
    like( $result->{'out'}, qr|zero sum : 0|, "$name reports zero sum" );
    like( $result->{'out'}, qr|supply   : \d+ drops|,
        "$name reports supply" );
    like(
        $result->{'out'},
        qr|supply   : \Q$supply\E drops|,
        "$name has the expected supply"
    ) if defined $supply;
    return $result;
}

sub verify_bad {
    my ( $name, $dir, $expected ) = @_;
    my $result = cli( $dir, 'verify' );
    isnt( $result->{'code'}, 0, $name );
    like( $result->{'err'}, qr|seq|,   "$name names a seq" );
    like( $result->{'err'}, $expected, "$name has the expected refusal" )
        if defined $expected;
    return $result;
}

sub records {
    my $dir = shift;
    return replay($dir)->{'records'};
}

sub replace_record {
    my ( $dir, $seq, $bytes ) = @_;
    my $records = records($dir);
    my @bytes   = map { $ARG->{'bytes'} } $records->@*;
    $bytes[ $seq - 1 ] = $bytes;
    write_bytes( "$dir/journal", join q||, @bytes );
    return;
}

sub mutate_record {
    my ( $dir, $seq, $change ) = @_;
    my $record = records($dir)->[ $seq - 1 ];
    my $bytes  = $record->{'bytes'};
    $change->( \$bytes, $record );
    replace_record( $dir, $seq, $bytes );
    return;
}

sub append_bytes {
    my ( $dir, $bytes ) = @_;
    open( my $fh, '>>:raw', "$dir/journal" ) or die $OS_ERROR;
    print {$fh} $bytes                       or die $OS_ERROR;
    close $fh                                or die $OS_ERROR;
    return;
}

sub parsed_record {
    my ( $dir, $seq ) = @_;
    my $record = records($dir)->[ $seq - 1 ];
    return (
        $record,
        parse_head(
            $record->{'bytes'},
            kind( $record->{'kind'} ),
            verify => \&verify
        )
    );
}

sub resign_record {
    my ( $dir, $seq, $key ) = @_;
    my ( $record, $parsed ) = parsed_record( $dir, $seq );
    my $bytes = pack_head(
        kind( $record->{'kind'} ),
        $parsed->{'values'},
        signer => $signer{$key}
    ) . $record->{'body'};
    replace_record( $dir, $seq, $bytes );
    return;
}

sub head_signer {
    return key_file_signer( read_file("$ARG[0]/.witness-key") =~ s|\n\z||r );
}

sub raw_transaction_attempt {
    my ( $dir, $body, $drops, $rows ) = @_;
    my $before = snapshot($dir);
    my $state  = replay($dir);
    verify_head( $dir, $state );
    my $values = common($state);
    @{$values}{qw| reason by drops basis rows body |}
        = ( 'transfer', '0', $drops, undef, $rows, bmw384_b32($body) );
    my $error = do {
        local $EVAL_ERROR;
        eval {
            commit( $dir, $state, 'transaction', $values, $signer{'alice'},
                $body, head_signer($dir) );
            1;
        } ? undef : $EVAL_ERROR;
    };
    ok( defined $error, 'raw transaction fixture refused' )
        or diag 'invalid raw transaction was accepted';
    same_snapshot( 'raw transaction refusal is byte-identical',
        $before, $dir );
    return $error;
}

subtest '1 : zero sum and supply after every command' => sub {
    my $dir = "$tmp/zero-sum";
    command_ok( 'init', $dir, 'init', $dir, '-witness',
        $key_path{'witness'} );
    verify_ok( 'verify init', $dir, 0 );
    for my $account (qw| alice bob carol dave |) {
        command_ok( "add $account", $dir, 'account', 'add', $account,
            '-key', $key_path{$account} );
        verify_ok( "verify after $account", $dir, 0 );
    }
    command_ok( 'trusted test issue',
        $dir, 'issue', 'alice', 4200,
        '-witness', $key_path{'witness'}, '-test' );
    verify_ok( 'verify issue', $dir, 4200 );
    command_ok( 'transfer', $dir, 'transaction', 'alice', 'bob', 1200,
        '-key', $key_path{'alice'} );
    my $verified = verify_ok( 'verify transfer', $dir, 4200 );
    my $state    = replay($dir);
    my $issues   = Math::BigInt->bzero;
    for my $record ( $state->{'records'}->@* ) {
        next if $record->{'kind'} ne qw| transaction |;
        next if $record->{'values'}{'reason'} ne qw| issue |;
        $issues->badd( $record->{'values'}{'drops'} );
    }
    is( $state->{'supply'}, $issues->bstr,
        'supply equals the sum of issues' );
    like(
        read_file("$dir/journal"),
        qr|basis += test|,
        'stage 1a issue is labelled as a test'
    );
};

subtest '2 : refused commands are byte-identical' => sub {
    my $dir = ledger('refusals');
    refused( 'overdraft', $dir, 'transaction', 'alice', 'bob', 10001,
        '-key', $key_path{'alice'} );
    for my $drops ( '0', '-1', '+1', '01', '1.0', '1e3', ' 1', '1 ',
        '10000000000000' ) {
        refused( "bad drops [ $drops ]",
            $dir,   'transaction', 'alice', 'bob',
            $drops, '-key',        $key_path{'alice'} );
    }
    refused( 'giver is also a receiver',
        $dir,    'transaction', 'alice',
        'alice', 1, '-key', $key_path{'alice'} );
    refused( 'unknown receiver',
        $dir,   'transaction', 'alice', 'nobody', 1,
        '-key', $key_path{'alice'} );
    refused( 'unknown giver',
        $dir, 'transaction', 'nobody', 'bob', 1, '-key', $key_path{'other'} );
    refused( 'transaction signed by another account key',
        $dir, 'transaction', 'alice', 'bob', 1, '-key', $key_path{'bob'} );
    refused( 'issue signed by another key',
        $dir, 'issue', 'alice', 1, '-witness', $key_path{'other'}, '-test' );
    refused( 'issue requires the test flag',
        $dir, 'issue', 'alice', 1, '-witness', $key_path{'witness'} );
};

subtest '3 : domain bound and exact arithmetic' => sub {
    is( add( MAX_DROPS, MAX_DROPS )->bstr,
        '19999999999998', 'sum of two 13 digit values is exact' );
    is( multiply( MAX_DROPS, MAX_DROPS )->bstr,
        '99999999999980000000000001',
        'product of two 13 digit values is exact'
    );
    my ( $whole, $carry ) = divide( MAX_DROPS, 4200, 4199 );
    is( $whole->bstr, '2380952381', 'exact division whole part' );
    is( $carry->bstr, '3998',       'exact division carry' );
    is_deeply( [ map { $ARG->bstr } pair('4200 : 13') ],
        [qw| 4200 13 |], 'drops : units uses positive integers' );
    my $over  = Math::BigInt->new(MAX_DROPS)->badd(1)->bstr;
    my $error = eval { bounded($over); 1 } ? undef : $EVAL_ERROR;
    like( $error, qr|9999999999999 drop bound|, 'balance bound is named' );
    my $dir     = ledger( 'supply-bound', MAX_DROPS );
    my $refusal = refused( 'issue above the domain supply bound',
        $dir, 'issue', 'bob', 1, '-witness', $key_path{'witness'}, '-test' );
    like(
        $refusal->{'err'},
        qr|9999999999999 drop bound|,
        'issue refusal names the bound'
    );
    verify_ok( 'maximum supply still verifies', $dir, MAX_DROPS );
    my $state = replay($dir);
    is( $state->{'balances'}{ $state->{'accounts'}{'alice'}{'address'} },
        MAX_DROPS, 'a 13 digit account balance is stored exactly' );
};

subtest '4 and 7 : every kind has an enforced signer' => sub {
    for my $seq ( 1, 2, 5, 6, 7 ) {
        my $dir = ledger("wrong-key-$seq");
        command_ok( 'add a recovery void',
            $dir, 'recover', '-witness', $key_path{'witness'} );
        verify_ok( 'void verifies', $dir, 10000 );
        my $kind = records($dir)->[ $seq - 1 ]{'kind'};
        resign_record( $dir, $seq, 'other' );
        verify_bad( "wrong key for $kind seq $seq",
            $dir, qr{witness|signature|pub|proof} );
    }
    my $dir  = ledger('wrong-head-key');
    my $head = parse_head( read_file("$dir/head"), kind('head'),
        verify => \&verify );
    write_bytes(
        "$dir/head",
        pack_head(
            kind('head'), $head->{'values'}, signer => $signer{'other'}
        )
    );
    verify_bad( 'wrong witness key for head', $dir, qr{witness|signature} );

    my $cross = ledger('cross-kind');
    mutate_record(
        $cross, 1,
        sub {
            my $bytes = shift;
            $$bytes =~ s|\Ap7 nrt init v1|p7 nrt account v1|;
        }
    );
    verify_bad( 'a signature does not cross a label', $cross, qr{canon|seq} );
};

subtest '5 : canonical head strictness' => sub {
    my @cases = (
        [ 'repeated key', sub { $_[0] =~ s|^(seq += .*\n)|$1$1|m } ],
        [ 'unknown key',  sub { $_[0] =~ s|^pub |extra = value\npub |m } ],
        [ 'missing key',  sub { $_[0] =~ s|^seq .*\n||m } ],
        [   'swapped key order',
            sub {
                my @lines = split m|(?<=\n)|, $_[0];
                ( $lines[2], $lines[3] ) = ( $lines[3], $lines[2] );
                $_[0] = join q||, @lines;
            }
        ],
        [ 'one space too few',  sub { $_[0] =~ s|^seq +=|seq =|m } ],
        [ 'one space too many', sub { $_[0] =~ s|^seq +=|seq  =|m } ],
        [ 'trailing space',     sub { $_[0] =~ s|^(seq += \d+)|$1 |m } ],
        [ 'carriage return',    sub { $_[0] =~ s|^(seq += .*\n)|$1\r|m } ],
        [ 'missing final LF',   sub { $_[0] =~ s|\n\n\z|\n| } ],
        [ 'missing label',      sub { $_[0] =~ s|^[^\n]*\n|| } ],
        [ 'changed label',      sub { $_[0] =~ s|\Ap7 nrt|p7 nrt changed| } ],
        [   'kind key line',
            sub { $_[0] =~ s|^ledger |kind = transaction\nledger |m }
        ],
        [ 'single separator spacing', sub { $_[0] =~ s|^seq +=|seq =|m } ],
    );
    for my $case (@cases) {
        my ( $name, $change ) = @{$case};
        ( my $fixture = $name ) =~ s|[^a-z0-9._-]+|-|g;
        my $dir = ledger("format-$fixture");
        mutate_record( $dir, 5, sub { $change->( ${ $_[0] } ) } );
        verify_bad( "canonical refusal : $name",
            $dir, qr{canon|missing|changed|seq} );
    }
};

subtest '6 : journal and chain tamper' => sub {
    my $dir      = ledger('tamper');
    my $original = read_file("$dir/journal");
    mutate_record( $dir, 6,
        sub { ${ $_[0] } =~ s|drops += 10000|drops = 10001| } );
    verify_bad( 'changed digit', $dir, qr{signature|seq} );
    write_bytes( "$dir/journal", $original );

    my @records = map { $ARG->{'bytes'} } records($dir)->@*;
    write_bytes( "$dir/journal", join( q||, @records[ 0 .. 3, 5 ] ) );
    verify_bad( 'removed record', $dir, qr|seq| );

    write_bytes( "$dir/journal",
        join( q||, @records[ 0 .. 3 ], $records[5], $records[4] ) );
    verify_bad( 'swapped records', $dir, qr|seq| );

    write_bytes( "$dir/journal", $original . $records[4] );
    verify_bad( 'copied record appended again', $dir, qr|seq| );

    my $other   = ledger('other-ledger');
    my $foreign = records($other)->[4]{'bytes'};
    write_bytes( "$dir/journal", $original . $foreign );
    verify_bad( 'record from another ledger', $dir, qr{seq|ledger|prev} );
};

subtest '8 : head binding and witness-only rebuild' => sub {
    my $dir  = ledger('head-rules');
    my $head = parse_head( read_file("$dir/head"), kind('head'),
        verify => \&verify );
    my %lower = %{ $head->{'values'} };
    $lower{'seq'} = Math::BigInt->new( $lower{'seq'} )->bsub(1)->bstr;
    write_bytes( "$dir/head",
        pack_head( kind('head'), \%lower, signer => $signer{'witness'} ) );
    verify_bad( 'head with a lower seq', $dir, qr|head seq| );

    my %foreign = %{ $head->{'values'} };
    $foreign{'ledger'} = 'another-ledger';
    write_bytes( "$dir/head",
        pack_head( kind('head'), \%foreign, signer => $signer{'witness'} ) );
    verify_bad( 'head for another ledger', $dir, qr|another ledger| );

    unlink "$dir/head" or die $OS_ERROR;
    verify_bad( 'missing head', $dir, qr|missing head| );
    refused( 'head is not rebuilt without the witness', $dir, 'recover' );
    command_ok( 'witness rebuilds missing head',
        $dir, 'recover', '-witness', $key_path{'witness'} );
    verify_ok( 'rebuilt head verifies', $dir, 10000 );

    my $records = records($dir);
    my @bytes   = map { $ARG->{'bytes'} } $records->@*;
    pop @bytes;
    write_bytes( "$dir/journal", join q||, @bytes );
    verify_bad( 'journal shorter than its head', $dir, qr|seq| );
    refused( 'recover refuses a head above the whole journal',
        $dir, 'recover', '-witness', $key_path{'witness'} );
};

subtest '9 : fail-closed clock and explicit acceptance' => sub {
    my $dir  = ledger('clock');
    my $last = replay($dir)->{'ntime'};
    refused( 'clock behind the last record',
        $dir, 'transaction', 'alice',
        'bob', 1, '-key', $key_path{'alice'}, { ntime => $last - 100 } );
    command_ok(
        'explicit clock acceptance', $dir,
        'transaction',               'alice',
        'bob',                       1,
        '-key',                      $key_path{'alice'},
        '-accept-clock', { ntime => $last - 100 }
    );
    my $record = replay($dir)->{'records'}[-1];
    cmp_ok( $record->{'values'}{'ntime'},
        'ge', $last, 'accepted clock never lowers record ntime' );
    verify_ok( 'clock-accepted record verifies', $dir, 10000 );
};

subtest '10 : concurrent transactions share one lock' => sub {
    my $dir = ledger('concurrent');
    my @children;
    for my $receiver (qw| bob carol |) {
        my $pid = fork;
        die 'fork failed' if not defined $pid;
        if ( $pid == 0 ) {
            open STDOUT, '>', "$tmp/$receiver.out" or die $OS_ERROR;
            open STDERR, '>', "$tmp/$receiver.err" or die $OS_ERROR;
            $ENV{'NRT_DIR'}        = $dir;
            $ENV{'NRT_TEST_NTIME'} = $time;
            exec $^X, "$root/bin/nrt", 'transaction', 'alice', $receiver, 100,
                '-key', $key_path{'alice'};
            die $OS_ERROR;
        }
        push @children, $pid;
    }
    for my $pid (@children) {
        waitpid( $pid, 0 );
        is( $CHILD_ERROR >> 8, 0, 'concurrent transaction succeeded' );
    }
    my $state = replay($dir);
    is( scalar $state->{'records'}->@*, 8, 'both appends are present' );
    verify_ok( 'concurrent journal verifies', $dir, 10000 );
};

subtest '11 : journal and head are sufficient state' => sub {
    my $dir           = ledger('only-state');
    my $verify_before = verify_ok( 'before cache deletion', $dir, 10000 );
    my $balance_before
        = command_ok( 'balances before cache deletion', $dir, 'balance' );
    opendir( my $dh, $dir ) or die $OS_ERROR;
    my @entries = grep { $ARG ne '.' and $ARG ne '..' } readdir $dh;
    closedir $dh;
    for my $entry (@entries) {
        next if $entry eq qw| journal | or $entry eq qw| head |;
        my $path = "$dir/$entry";
        -d $path ? remove_tree($path) : unlink $path;
    }
    my $verify_after = verify_ok( 'after cache deletion', $dir, 10000 );
    my $balance_after
        = command_ok( 'balances after cache deletion', $dir, 'balance' );
    is( $verify_after->{'out'},
        $verify_before->{'out'},
        'verify answer is unchanged'
    );
    is( $balance_after->{'out'},
        $balance_before->{'out'},
        'balance answer is unchanged'
    );
};

subtest '12 and 29 : scanner and shared parser round trip' => sub {
    my @files = qw|
        data/lib-path/pm/AMOS7/NRT/journal.pm
        data/lib-path/pm/AMOS7/NRT/journal/canon.pm
        data/lib-path/pm/AMOS7/NRT/transaction.pm
        data/lib-path/pm/AMOS7/NRT/frame.pm
        data/lib-path/pm/AMOS7/NRT/drops.pm
        data/lib-path/pm/AMOS7/NRT/user/account.pm
        data/lib-path/pm/AMOS7/NRT/user/account/transaction.pm
        bin/nrt
        |;
    my $json_token = join q|::|, qw| JSON |;
    my $sha_token  = join q|::|, qw| Digest SHA |;

    for my $file (@files) {
        diag "scanner checks $file";
        my $source = read_file("$root/$file");
        unlike( $source, qr|\Q$json_token\E|i,
            "$file has no forbidden data codec" );
        unlike( $source, qr|\Q$sha_token\E|i,
            "$file has no forbidden digest" );
        unlike(
            $source,
            qr{sub (?:parse|pack)},
            "$file defines no record codec"
        );
    }
    my $dir = ledger('round-trip');
    for my $record ( records($dir)->@* ) {
        my $parsed = parse_head(
            $record->{'bytes'},
            kind( $record->{'kind'} ),
            verify => \&verify
        );
        is( pack_head( kind( $record->{'kind'} ), $parsed->{'values'} ),
            $record->{'head'}, "$record->{'kind'} head packs byte equal" );
        if ( $record->{'kind'} eq qw| transaction | ) {
            my $list = AMOS7::cell::canon::list->new(
                AMOS7::NRT::journal::canon::body(),
                $record->{'body'},
                rows => $record->{'values'}{'rows'},
                body => $record->{'values'}{'body'},
            );
            $list->validate;
            is( pack_body( AMOS7::NRT::journal::canon::body(), $list->rows ),
                $record->{'body'},
                'transaction body packs byte equal'
            );
        }
    }
};

subtest '27 : one giver and three receivers in one record' => sub {
    my $dir = ledger('three-receivers');
    command_ok( 'three receiver transfer',
        $dir,  'transaction', 'alice',
        'bob', 100, 'carol', 200, 'dave', 300, '-key', $key_path{'alice'} );
    my $state  = replay($dir);
    my $record = $state->{'records'}[-1];
    is( $record->{'kind'}, 'transaction', 'one transaction record' );
    is( scalar $record->{'rows'}->@*, 4,
        'one giver and three receiver rows' );
    is( $state->{'balances'}{ $state->{'accounts'}{'bob'}{'address'} }, 100 );
    is( $state->{'balances'}{ $state->{'accounts'}{'carol'}{'address'} },
        200 );
    is( $state->{'balances'}{ $state->{'accounts'}{'dave'}{'address'} },
        300 );
    verify_ok( 'three receiver transaction verifies', $dir, 10000 );

    my $alice = $state->{'accounts'}{'alice'}{'address'};
    my $bob   = $state->{'accounts'}{'bob'}{'address'};
    my $carol = $state->{'accounts'}{'carol'}{'address'};
    my $count = Math::BigInt->new( $state->{'used'}{$alice} )->badd(1)->bstr;
    my $valid_body = pack_body(
        AMOS7::NRT::journal::canon::body(),
        [   [ '-', $alice, $count, 300 ],
            [ '+', $bob,   100 ],
            [ '+', $carol, 200 ]
        ],
    );
    my @body_lines = split m|(?<=\n)|, $valid_body;
    raw_transaction_attempt( $dir, join( q||, reverse @body_lines ), 300, 3 );
    raw_transaction_attempt(
        $dir,
        pack_body(
            AMOS7::NRT::journal::canon::body(),
            [   [ '-', $alice, $count, 100 ],
                [ '+', $bob,   50 ],
                [ '+', $bob,   50 ]
            ],
        ),
        100, 3
    );
    raw_transaction_attempt(
        $dir,
        pack_body(
            AMOS7::NRT::journal::canon::body(),
            [ [ '-', $alice, $count, 100 ], [ '+', $alice, 100 ] ],
        ),
        100, 2
    );
    raw_transaction_attempt( $dir, $valid_body, 301, 3 );
    my $changed = $valid_body;
    substr( $changed, -2, 1 ) = substr( $changed, -2, 1 ) eq 'A' ? 'B' : 'A';
    raw_transaction_attempt( $dir, $changed,    300, 3 );
    raw_transaction_attempt( $dir, $valid_body, 300, 4 );
    my $two_body = AMOS7::NRT::transaction::prepare(
        {},
        [   [ '-', $alice, $count, 100 ],
            [ '-', $bob,   1,      100 ],
            [ '+', $carol, 200 ]
        ],
    );
    raw_transaction_attempt( $dir, $two_body, 200, 3 );
};

subtest 'head signer precheck and post-append error reporting' => sub {
    my $dir   = ledger('wrong-head-before-append');
    my $state = replay($dir);
    verify_head( $dir, $state );
    my $values = common($state);
    my $body   = prepare_transfer( $state, 'alice', [ [ 'bob', 1 ] ],
        $signer{'alice'}, $values );
    my $before = snapshot($dir);
    my $error  = do {
        local $EVAL_ERROR;
        eval {
            commit( $dir, $state, 'transaction', $values, $signer{'alice'},
                $body, $signer{'other'} );
            1;
        } ? undef : $EVAL_ERROR;
    };
    like(
        $error,
        qr|head rebuild requires the witness key|,
        'wrong head signer is refused before append'
    );
    same_snapshot( 'wrong head signer changes no bytes', $before, $dir );

    $dir   = ledger('head-stale-after-append');
    $state = replay($dir);
    verify_head( $dir, $state );
    $values = common($state);
    $body   = prepare_transfer( $state, 'alice', [ [ 'bob', 1 ] ],
        $signer{'alice'}, $values );
    my $expected_seq = Math::BigInt->new( $state->{'seq'} )->badd(1)->bstr;
    unlink "$dir/head" or die $OS_ERROR;
    mkdir "$dir/head"  or die $OS_ERROR;
    $error = do {
        local $EVAL_ERROR;
        eval {
            commit( $dir, $state, 'transaction', $values, $signer{'alice'},
                $body, $signer{'witness'} );
            1;
        } ? undef : $EVAL_ERROR;
    };
    like(
        $error,
        qr|record committed seq \Q$expected_seq\E, head stale -- run recover, do not retry|,
        'head publication failure reports the committed sequence'
    );
    my $after = replay($dir);
    is( $after->{'seq'}, $expected_seq,
        'whole record remains after head failure' );
    is( $after->{'balances'}{ $after->{'accounts'}{'bob'}{'address'} },
        1, 'committed transfer is not presented as an ordinary refusal' );
};

subtest '28 : torn recovery preserves every whole record' => sub {
    my $dir      = ledger('torn-recovery');
    my $whole    = read_file("$dir/journal");
    my $count    = scalar records($dir)->@*;
    my $fragment = "p7 nrt transaction v1\nledger = torn-recovery\n";
    append_bytes( $dir, $fragment );
    verify_bad( 'torn bytes fail verification', $dir, qr|seq| );
    my $result = command_ok( 'recover torn bytes',
        $dir, 'recover', '-witness', $key_path{'witness'} );
    like( $result->{'out'}, qr|void :|, 'recover appends a void record' );
    my $after = read_file("$dir/journal");
    is( substr( $after, 0, length $whole ),
        $whole, 'every whole record remains byte for byte' );
    is( scalar records($dir)->@*,
        $count + 1, 'recovery increases the whole record count' );
    my ($torn_path) = glob "$dir/torn/*";
    ok( defined $torn_path, 'fragment moved to torn directory' );
    is( read_file($torn_path), $fragment, 'torn fragment is preserved' );
    verify_ok( 'recovered journal verifies', $dir, 10000 );
};

subtest '30 : record addresses match prev and head on both perls' => sub {
    my $dir   = ledger('addresses');
    my $state = replay($dir);
    for my $index ( 0 .. $state->{'records'}->$#* ) {
        my $record = $state->{'records'}[$index];
        is( record_address( $record->{'bytes'}, kind( $record->{'kind'} ) ),
            $record->{'address'},
            'record address is stable when computed twice'
        );
        if ( $index < $state->{'records'}->$#* ) {
            is( $state->{'records'}[ $index + 1 ]{'values'}{'prev'},
                $record->{'address'}, 'next prev equals record address' );
        }
    }
    my $head = parse_head( read_file("$dir/head"), kind('head'),
        verify => \&verify );
    is( $head->{'values'}{'last'},
        $state->{'last'}, 'head last equals the final record address' );
    my $record  = $state->{'records'}[-1];
    my $program = join q| ;|,
        'use AMOS7::cell::canon qw| record_address |',
        'use AMOS7::NRT::journal::canon qw| kind |',
        'my $bytes = join q||, <STDIN>',
        'print record_address( $bytes, kind(q|transaction|) )';
    my %seen;
    for my $perl ( '/usr/bin/perl', $^X ) {
        next if $seen{$perl}++;
        my $error = gensym;
        my $pid   = open3( my $in, my $out, $error, $perl, '-I',
            "$root/data/lib-path/pm", '-e', $program );
        print {$in} $record->{'bytes'};
        close $in;
        local $INPUT_RECORD_SEPARATOR;
        my $address = <$out>   // '';
        my $stderr  = <$error> // '';
        close $out;
        close $error;
        waitpid( $pid, 0 );
        is( $CHILD_ERROR >> 8, 0, "address computation runs under $perl" )
            or diag $stderr;
        is( $address, $record->{'address'}, "address is stable under $perl" );
    }
};

subtest '13 : scratch state is cleaned' => sub {
    ok( -d $tmp, 'all test state lived in a scratch directory' );
    remove_tree("$tmp/cleanup-check");
    ok( !-e "$tmp/cleanup-check", 'scratch cleanup works' );
};

done_testing;

#,,.,,,,.,,.,,,.,,,..,.,,,,..,,,,,...,,,,,,.,,..,,...,...,,.,,...,.,.,..,,,.,,
#LXC7D4TTQVIXJF6P5467HLUQBEQ3URFLA3VPXSUFZQRVYIAIB3LIC6I2VXTFP5LSNYEJ7N5NHLJAY
#\\\|D4RWN5TU67H7WRPOWZ4NRNITNRBDOVRI5CEXERUAKH5SICQIKLL \ / AMOS7 \ YOURUM ::
#\[7]Z6RZAHMYJE3JVI3O2GODLYEI4G6BXAWBODRD52UFJGZFNFYGVOBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
