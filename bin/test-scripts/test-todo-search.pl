#!/usr/bin/env perl
use v5.24;
use strict;
use warnings;
use English;
use utf8;

use Cwd        qw| abs_path |;
use File::Copy qw| copy |;
use File::Spec;
use File::Temp qw| tempdir |;
use FindBin    qw| $RealBin |;
use IPC::Open3;
use Symbol qw| gensym |;
use YAML::PP;

my $up_dir = File::Spec->updir;
my $root   = abs_path(
    File::Spec->rel2abs( File::Spec->catdir( $RealBin, $up_dir, $up_dir ) ) );
my $todo = "$root/bin/todo";
my $temp = tempdir( 'todo-search-XXXXXX', TMPDIR => 1, CLEANUP => 1 );
my $yaml = "$temp/base.yaml";
copy( "$root/data/yaml/todo/base.yaml", $yaml )
    or die "cannot copy todo yaml: $OS_ERROR\n";

my $yp   = YAML::PP->new;
my $data = $yp->load_file($yaml);
my %used = map { $_->{id} => 1 } $data->{items}->@*;
die "fixture id already exists\n" if $used{'ZXQ'} or $used{'ZXR'};
push $data->{items}->@*,
    {
    id       => 'ZXQ',
    text     => 'ZxqTextNeedle open text',
    status   => 'open',
    priority => 'normal',
    tags     => ['zxqtagneedle'],
    details  => "before context\nZxqDetailNeedle detail\nafter context",
    added    => '3TESTOPEN',
    done_at  => undef,
    },
    {
    id       => 'ZXR',
    text     => 'ZxqDoneNeedle done text',
    status   => 'done',
    priority => 'normal',
    tags     => ['zxqdonetag'],
    details  => 'done detail',
    added    => '3TESTDONE',
    done_at  => '3TESTDONE',
    };
$yp->dump_file( $yaml, $data );

my $tests = 0;
my $fails = 0;

sub check {
    my ( $label, $condition ) = @_;
    $tests++;
    if ($condition) {
        say "ok $tests - $label";
    } else {
        $fails++;
        say "not ok $tests - $label";
    }
}

sub run_search {
    my @args = @_;
    my $err  = gensym;
    my $pid  = open3(
        undef, my $out, $err,  $EXECUTABLE_NAME,
        $todo, '-file', $yaml, 'search',
        @args
    );
    local $/;
    my $stdout = <$out> // '';
    my $stderr = <$err> // '';
    waitpid $pid, 0;
    return ( $CHILD_ERROR >> 8, $stdout, $stderr );
}

my ( $status, $text_out, $text_err ) = run_search('zxqtextneedle');
check( 'text match exits successfully',  $status == 0 );
check( 'text match finds open item',     $text_out =~ m{ZXQ.*ZxqTextNeedle} );
check( 'text match has no error output', $text_err eq '' );

my ( undef, $tag_out ) = run_search('zxqtagneedle');
check( 'tag match finds tagged item', $tag_out =~ m{ZXQ.*zxqtagneedle} );

my ( undef, $detail_out ) = run_search('zxqdetailneedle');
check( 'detail match prints matching line',
    $detail_out =~ m{: 002 : ZxqDetailNeedle detail} );
check(
    'detail match prints preceding context',
    $detail_out =~ m{: 001 : before context}
);
check(
    'detail match prints following context',
    $detail_out =~ m{: 003 : after context}
);

my ( undef, $id_out ) = run_search('ZXQ');
check( 'id match finds item', $id_out =~ m{ZXQ.*ZxqTextNeedle} );

my ( $done_status, $done_open_out ) = run_search('zxqdoneneedle');
check( 'done item excluded by default',
    $done_status == 0 && $done_open_out =~ m{^no matches} );
my ( undef, $done_all_out ) = run_search( '-all', 'zxqdoneneedle' );
check( '-all includes done item', $done_all_out =~ m{ZXR.*ZxqDoneNeedle} );

my ( $none_status, $none_out ) = run_search('zxqabsentneedle');
check( 'no match uses ncode success status', $none_status == 0 );
check( 'no match prints clear message',      $none_out =~ m{^no matches} );

my ( $bad_status, $bad_out, $bad_err ) = run_search('[');
check( 'invalid regex exits nonzero', $bad_status != 0 );
check(
    'invalid regex prints clean error',
    $bad_err =~ m{^todo: invalid search pattern:}
        && $bad_err !~ m{bin/todo line}
);

check( 'plain output has no ansi', $text_out !~ m{\e\[} );
my ( undef, $text_out_again ) = run_search('zxqtextneedle');
check( 'plain output is stable', $text_out eq $text_out_again );

my ( $case_status, $case_out ) = run_search('ZXQTEXTNEEDLE');
check(
    'uppercase pattern is case-sensitive',
    $case_status == 0 && $case_out =~ m{^no matches}
);

say "1..$tests";
say $fails ? "failed $fails of $tests" : "all $tests tests passed";
exit( $fails ? 1 : 0 );

#,,,.,,.,,,,.,.,,,.,,,,,,,..,,.,.,,.,,,..,.,,,..,,...,...,..,,...,...,..,,.,,,
#RGLE52UE2SYZWLARUHWURTWRDOQQATLPRAU3AMCGN3WUII4WDXUUQSC2MZRD7NJCPSXLTMIQIARG4
#\\\|KPDNXNVZPNSK4BTODEV4LTK4BNCPACZMSYSU22NFO6G37OJ7GQH \ / AMOS7 \ YOURUM ::
#\[7]VORVEN2276JEEHQKROS5ZAZRN2WWFW7BJDTLF4F5EUTNA4PCEQCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
