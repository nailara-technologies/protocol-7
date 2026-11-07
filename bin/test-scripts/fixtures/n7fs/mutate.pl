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
                    . "\$final, \$node->{'addr'}, \$context );\n",
                ""
            ],
            [   "        \$new->{'verify_node'}->( \$ARG->{'path'}, "
                    . "\$ARG, \$context )\n            for \@written;\n",
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
    {   name => 'format 2 record labels fall back to v1',
        file => 'N7FS.pm',
        test => 'test-n7fs-format2.pl',
        edit => [
            [   "    return \$LABEL_VERSION{\$kind}{\$format}\n        if "
                    . "exists \$LABEL_VERSION{\$kind}\n        and exists "
                    . "\$LABEL_VERSION{\$kind}{\$format};\n",
                "    return \$LABEL{\$kind} if \$format == 2;\n"
            ]
        ],
    },
    {   name => 'plain format 2 records allowed',
        file => 'N7FS.pm',
        test => 'test-n7fs-format2.pl',
        edit => [
            [   "        if \$SIGNED_FORMAT{\$kind}{\$format};\n",
                "        if 0;\n"
            ]
        ],
    },
    {   name => 'state signature check removed',
        file => 'N7FS/Disk.pm',
        test => 'test-n7fs-format2.pl',
        edit => [
            [   "            if not verify( \$store_pub, "
                    . "\$rec->{'signed'}, \$rec->{'sig'} );\n",
                "            if 0;\n"
            ]
        ],
    },
    {   name => 'state foreign store key accepted',
        file => 'N7FS/Disk.pm',
        test => 'test-n7fs-format2.pl',
        edit => [
            [   "            if \$rec->{'signer_pub'} ne \$store_pub;\n",
                "            if 0;\n"
            ]
        ],
    },
    {   name => 'signed state can claim format 1',
        file => 'N7FS/Disk.pm',
        test => 'test-n7fs-format2.pl',
        edit => [
            [   "        and \$rec->{'format'} != \$p->{'store_format'};\n",
                "        and 0;\n"
            ]
        ],
    },
    {   name => 'plain state downgrade with signed states accepted',
        file => 'N7FS/Disk.pm',
        test => 'test-n7fs-format2.pl',
        edit => [
            [ "            if \$signed_present;\n", "            if 0;\n" ]
        ],
    },
    {   name => 'witness highest store format ignored',
        file => 'N7FS/Disk.pm',
        test => 'test-n7fs-format2.pl',
        edit => [
            [   "    return TRUE\n        if \$state->{'store_format'} >= ( "
                    . "\$w->{'store_format'} // 1 )\n        or "
                    . "\$opt{'allow_rollback'};\n",
                "    return TRUE;\n"
            ]
        ],
    },
    {   name => 'meta signature check removed',
        file => 'N7FS/Store.pm',
        test => 'test-n7fs-format2.pl',
        edit => [
            [   "        if not verify( \$id->{'store_pub'}, "
                    . "\$rec->{'signed'}, \$rec->{'sig'} );\n",
                "        if 0;\n"
            ]
        ],
    },
    {   name => 'meta foreign store key accepted',
        file => 'N7FS/Store.pm',
        test => 'test-n7fs-format2.pl',
        edit => [
            [   "        if \$rec->{'signer_pub'} ne \$id->{'store_pub'};\n",
                "        if 0;\n"
            ]
        ],
    },
    {   name => 'meta location binding removed',
        file => 'N7FS/Store.pm',
        test => 'test-n7fs-format2.pl',
        edit => [
            [   "            if ( \$meta->{\$field} "
                    . "// '' ) ne \$bind{\$field};\n",
                "            if 0;\n"
            ]
        ],
    },
    {   name => 'unsigned meta header accepted',
        file => 'N7FS/Store.pm',
        test => 'test-n7fs-format2.pl',
        edit => [
            [   "        if not defined \$bytes\n        or length \$bytes < "
                    . "5\n        or substr( \$bytes, 0, 5 ) ne "
                    . "\"P7FN\\x02\";\n",
                "        if 0;\n"
            ]
        ],
    },
    {   name => 'assimilate store key requirement removed',
        file => 'N7FS/Store.pm',
        test => 'test-n7fs-format2.pl',
        edit => [
            [   "    my \$store  = store_key_signer( "
                    . "%opt, qw| id | => \$id );\n",
                "    my \$store  = undef;\n"
            ]
        ],
    },
    {   name => 'upgrade store key requirement removed',
        file => 'N7FS/Convert.pm',
        test => 'test-n7fs-format2.pl',
        edit => [
            [   "sub upgrade {\n    my %opt   = \@ARG;\n    my \$id    = "
                    . "disk_require_attached(%opt);\n    my \$store = "
                    . "store_key_signer( %opt, qw| id | => \$id );\n",
                "sub upgrade {\n    my %opt   = \@ARG;\n    my \$id    = "
                    . "disk_require_attached(%opt);\n    my \$store = "
                    . "undef;\n"
            ]
        ],
    },
    {   name => 'conversion provenance marker removed',
        file => 'N7FS/Convert.pm',
        test => 'test-n7fs-convert.pl',
        edit => [
            [   "                    qw| "
                    . "converted_from_unsigned | => JSON::PP::true,\n",
                ""
            ]
        ],
    },
    {   name => 'upgrade witness format observation removed',
        file => 'N7FS/Convert.pm',
        test => 'test-n7fs-convert.pl',
        edit => [
            [   "    witness_note_format( %opt, qw| id "
                    . "| => \$id, qw| state | => \\%next );\n",
                ""
            ]
        ],
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
        say "  caught    $m->{'name'} [ $m->{'test'} : ", scalar @fails,
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

#,,,.,.,,,.,.,...,.,,,,..,,.,,.,,,,.,,.,.,,..,..,,...,...,..,,,..,,,,,,,,,,,,,
#IJZYS56Y3VE3OBQJW4UMYG5ECJY6UBDJG24RWODP6X2BM3UTY2CSDYKH3LKOCCQDHFYBPHEQ46V7Y
#\\\|H33TSEP3FUZ6BP6N746J2FEO5U377F5HSF46WLPOKUB76AQM7EM \ / AMOS7 \ YOURUM ::
#\[7]AZLLZJQE4MCKYYRMCMJ3CWRPL2UB5MVTZM52XWYFN5WRR624R2BA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
