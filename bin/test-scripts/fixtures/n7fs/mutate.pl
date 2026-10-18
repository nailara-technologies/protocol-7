#!/usr/bin/perl
use v5.32.0;
use strict;
use English;
use warnings;

## mutation check for the n7fs tests : each mutation removes ONE rule from a
## temp copy of the AMOS7::N7FS modules [ put first through N7FS_TEST_LIB ],
## then runs the test that guards it -- the test must FAIL. the repo files are
## never changed.
##
## perl bin/test-scripts/fixtures/n7fs/mutate.pl [ <name filter> ]

use FindBin;
use File::Temp qw| tempdir |;

my $repo = "$FindBin::Bin/../../../..";
my $lib  = "$repo/data/lib-path/pm/AMOS7";
my $test = "$repo/bin/test-scripts";

my @mutations = (
    {   name => 'trusted parent anchors ignored',
        file => 'N7FS/Disk.pm',
        test => 'test-n7fs-id.pl',
        edit => [
            [   "        if \@anchors\n        and not grep",
                "        if 0\n        and not grep"
            ]
        ],
    },
    {   name => 'init collision does not step the ntime',
        file => 'N7FS/Disk.pm',
        test => 'test-n7fs-id.pl',
        edit => [
            [   "        \$ntime++;    ## collision",
                "        last;    ## collision"
            ]
        ],
    },
    {   name => 'id.l13 check removed',
        file => 'N7FS/Disk.pm',
        test => 'test-n7fs-id.pl',
        edit => [
            [   "        if \$id_l13 ne l13_standin(\$bytes);\n",
                "        if 0;\n"
            ]
        ],
    },
    {   name => 'host dir not protected',
        file => 'N7FS/Store.pm',
        test => 'test-n7fs-assimilate.pl',
        edit => [
            [   "        host_dir(%opt), ( \$opt{'protect'} // [] )->\@*;",
                "        ( \$opt{'protect'} // [] )->\@*;"
            ]
        ],
    },
    {   name => 'index + remove allowed without a base',
        file => 'N7FS/Store.pm',
        test => 'test-n7fs-assimilate.pl',
        edit => [
            [   "        and not defined \$opt{'index_base'};\n",
                "        and 0;\n"
            ]
        ],
    },
    {   name => 'parent signature check removed',
        file => 'N7FS/Disk.pm',
        test => 'test-n7fs-id.pl',
        edit => [
            [   "parent signature does not verify', \$disk )\n        if\n   "
                    . "     not verify( \$rec->{'signer_pub'}, "
                    . "\$rec->{'signed'}, \$rec->{'sig'} );\n",
                "parent signature does not verify', \$disk )\n        if 0;\n"
            ]
        ],
    },
    {   name => 'directory name == id check removed',
        file => 'N7FS/Disk.pm',
        test => 'test-n7fs-id.pl',
        edit => [ [ "        if \$amos ne \$disk;\n", "        if 0;\n" ] ],
    },
    {   name => 'rollback refusal removed',
        file => 'N7FS/Disk.pm',
        test => 'test-n7fs-id.pl',
        edit => [
            [   "            if not " . "\$opt->{'allow_rollback'};" . "\n",
                "            if 0;\n"
            ]
        ],
    },
    {   name => 'clone divergence check removed',
        file => 'N7FS/Disk.pm',
        test => 'test-n7fs-id.pl',
        edit => [
            [   "            if not grep { \$ARG->{'name'} "
                    . "eq \$w->{'last_record'} } \@{\$history};\n",
                "            if 0;\n"
            ]
        ],
    },
    {   name => 'witness timestamp check removed',
        file => 'N7FS/Disk.pm',
        test => 'test-n7fs-id.pl',
        edit => [
            [   "            if ( \$p->{\$field} "
                    . "// '' ) !~ m|\\A\\d{14}\\z|;\n",
                "            if 0;\n"
            ]
        ],
    },
    {   name => 'keep by default removed',
        file => 'N7FS/Store.pm',
        test => 'test-n7fs-assimilate.pl',
        edit => [ [ "    if ( not \$remove ) {\n", "    if (0) {\n" ] ],
    },
    {   name => 'dry run writes',
        file => 'N7FS/Store.pm',
        test => 'test-n7fs-assimilate.pl',
        edit => [ [ "    if ( \$opt->{'dry_run'} ) {\n", "    if (0) {\n" ] ],
    },
    {   name => 'source re-verify before removal removed',
        file => 'N7FS/Store.pm',
        test => 'test-n7fs-assimilate.pl',
        edit => [
            [   "    refuse( '%s : changed during assimilate', \$path )\n",
                "    0 and refuse( '%s : changed "
                    . "during assimilate', \$path )\n"
            ],
            [   "    refuse( '%s : replaced before removal', \$path )\n",
                "    0 and refuse( '%s : replaced before removal', \$path )\n"
            ],
        ],
    },
    {   name => 'verify before the switch removed',
        file => 'N7FS/Convert.pm',
        test => 'test-n7fs-convert.pl',
        edit => [
            [   "            \$new->{'verify_node'}->( "
                    . "\$final, \$node->{'addr'} );\n",
                ""
            ],
            [   "        \$new->{'verify_node'}->( "
                    . "\$ARG->{'path'}, \$ARG ) for \@written;\n",
                ""
            ],
        ],
    },
    {   name => 'upgrade does not use the window [ lands in current ]',
        file => 'N7FS/Convert.pm',
        test => 'test-n7fs-convert.pl',
        edit => [
            [   "    my \$epoch = \$opt{'epoch'} // "
                    . "epoch_next( write_epoch(\$state) );\n",
                "    my \$epoch = \$opt{'epoch'} // write_epoch(\$state);\n"
            ]
        ],
    },
    {   name => 'partial new epoch not removed on failure',
        file => 'N7FS/Convert.pm',
        test => 'test-n7fs-convert.pl',
        edit => [ [ "        remove_tree(\$edir);\n", "" ] ],
    },
);

my $filter = shift // '';
my ( $caught, $survived ) = ( 0, 0 );

foreach my $m (@mutations) {
    next if length $filter and index( $m->{'name'}, $filter ) < 0;

    my $tmp = tempdir( 'n7fs-mutant-XXXXXXXX', TMPDIR => 1, CLEANUP => 1 );
    mkdir "$tmp/AMOS7";
    mkdir "$tmp/AMOS7/N7FS";
    foreach my $f ( 'N7FS.pm',
        map {"N7FS/$ARG.pm"} qw| Sum Sign Disk Store Convert | ) {
        open( my $in, '<:raw', "$lib/$f" ) or die "read $lib/$f : $OS_ERROR";
        my $text = do { local $INPUT_RECORD_SEPARATOR; <$in> };
        close $in;
        if ( $f eq $m->{'file'} ) {
            foreach my $e ( $m->{'edit'}->@* ) {
                my $count = () = $text =~ m|\Q$e->[0]\E|g;
                die "mutation '$m->{'name'}' : pattern found $count times\n"
                    if $count != 1;
                $text =~ s|\Q$e->[0]\E|$e->[1]|;
            }
        }
        open( my $out, '>:raw', "$tmp/AMOS7/$f" ) or die "write : $OS_ERROR";
        print {$out} $text;
        close $out;
    }

    local $ENV{'N7FS_TEST_LIB'} = $tmp;
    my $pid = open( my $run, '-|' ) // die "fork : $OS_ERROR";
    if ( $pid == 0 ) {
        open( STDERR, '>&', \*STDOUT );
        exec( $EXECUTABLE_NAME, "$test/$m->{'test'}" ) or exit 99;
    }
    my @fails = grep {m|^  FAIL|} <$run>;
    close $run;
    my $exit = $CHILD_ERROR >> 8;

    if ($exit) {
        $caught++;
        say "  caught    $m->{'name'} " . "[ $m->{'test'} : ", scalar @fails,
            ' failed ]';
        say "            $ARG"
            for map { s|^\s+FAIL\s+||r =~ s|\n||r }
            @fails[ 0 .. ( $#fails < 2 ? $#fails : 2 ) ];
    } else {
        $survived++;
        say "  SURVIVED  $m->{'name'} [ $m->{'test'} ]";
    }
}

say "\n  $caught caught, $survived survived";
exit( $survived ? 1 : 0 );

#,,..,,..,,,.,...,,.,,.,.,..,,..,,.,,,...,..,,..,,...,...,..,,.,.,.,.,,,,,.,.,
#C3W2WIXBJJAQD23D3VNGAMRI6YDWCYVCWT5SBNGJO63F3SI5I2ND6XZYCVG5NKEBDTCNGB54L4JYA
#\\\|XULZMY5L665OSTDZI3IJ254S2DFZMGRLB2YTXJ6BSZWTBHROXQJ \ / AMOS7 \ YOURUM ::
#\[7]GGUOW2OGFND3P4MRYGOWKJIXTF7RLOHSRQ3HCVUGJNOPJJ5UT6BA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
