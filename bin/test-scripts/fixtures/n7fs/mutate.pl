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
        edit =>
            [ [ "        ) if \$signed_present;\n", "        ) if 0;\n" ] ],
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
            [   "    my \$store = store_key_signer( %opt, qw| id | => \$id "
                    . ");\n    my \$state = state_read( \$id->{'path'}, "
                    . "\$id->{'store_pub'} );\n    my \$lock  = "
                    . "\$opt{'dry_run'} ? undef : disk_lock(\$id);",
                "    my \$store = undef;\n    my \$state = state_read( "
                    . "\$id->{'path'}, \$id->{'store_pub'} );\n    my \$lock "
                    . " = \$opt{'dry_run'} ? undef : disk_lock(\$id);"
            ]
        ],
    },
    {   name => 'the disk lock removed',
        file => 'N7FS/Store.pm',
        test => 'test-n7fs-format3.pl',
        edit => [
            [   "my \$lock  = \$opt{'dry_run'} ? undef : disk_lock(\$id);",
                "my \$lock  = undef;"
            ],
        ],
    },
    {   name => 'a journal entry is signed unchecked',
        file => 'N7FS/Journal.pm',
        test => 'test-n7fs-format3.pl',
        edit => [ [ "    _operations( \\%payload, \$replay );\n", "" ] ],
    },
    {   name => 'an unjournaled node may be imported onto',
        file => 'N7FS/Store.pm',
        test => 'test-n7fs-format3.pl',
        edit => [
            [   "        and not \$replay->{'nodes'}{ \$entry->{'addr'} };",
                "        and 0;"
            ],
        ],
    },
    {   name => 'upgrade store key requirement removed',
        file => 'N7FS/Convert.pm',
        test => 'test-n7fs-format2.pl',
        edit => [
            [   "sub upgrade {\n    my %opt     = \@ARG;\n    my \$lock    = "
                    . "disk_lock( disk_read_id(%opt) );\n    my \$id      = "
                    . "disk_require_attached(%opt);\n    my \$store   = "
                    . "store_key_signer( %opt, qw| id | => \$id );\n",
                "sub upgrade {\n    my %opt     = \@ARG;\n    my \$lock    = "
                    . "disk_lock( disk_read_id(%opt) );\n    my \$id      = "
                    . "disk_require_attached(%opt);\n    my \$store   = "
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
            [   "    witness_note_format(\n        %opt,\n        qw| id |   "
                    . "       => \$id,\n        qw| state |       => "
                    . "\\%next,\n        qw| journal_seq | => "
                    . "\$journal_seq\n    );\n",
                ""
            ]
        ],
    },
    {   name => 'journal signature check removed',
        file => 'N7FS/Journal.pm',
        test => 'test-n7fs-format3.pl',
        edit => [
            [   "        if not verify( \$id->{'store_pub'}, "
                    . "\$rec->{'signed'}, \$rec->{'sig'} );\n",
                "        if 0;\n"
            ]
        ],
    },
    {   name => 'journal foreign store key accepted',
        file => 'N7FS/Journal.pm',
        test => 'test-n7fs-format3.pl',
        edit => [
            [   "        if \$rec->{'signer_pub'} ne \$id->{'store_pub'};\n",
                "        if 0;\n"
            ]
        ],
    },
    {   name => 'journal disk binding removed',
        file => 'N7FS/Journal.pm',
        test => 'test-n7fs-format3.pl',
        edit => [
            [   "        if ( \$p->{'disk'} // '' ) ne \$id->{'disk'};\n",
                "        if 0;\n"
            ]
        ],
    },
    {   name => 'journal contiguous sequence check removed',
        file => 'N7FS/Journal.pm',
        test => 'test-n7fs-format3.pl',
        edit => [
            [   "            if \$p->{'seq'} != \$seq + 1;\n",
                "            if 0;\n"
            ]
        ],
    },
    {   name => 'journal previous hash check removed',
        file => 'N7FS/Journal.pm',
        test => 'test-n7fs-format3.pl',
        edit => [
            [   "            if \$p->{'prev'} ne \$previous;\n",
                "            if 0;\n"
            ]
        ],
    },
    {   name => 'journal fork check removed',
        file => 'N7FS/Journal.pm',
        test => 'test-n7fs-format3.pl',
        edit => [
            [   "            if \$seen_prev{ \$p->{'prev'} }++;\n",
                "            if 0;\n"
            ]
        ],
    },
    {   name => 'reference signature check removed',
        file => 'N7FS/Reference.pm',
        test => 'test-n7fs-format3.pl',
        edit => [
            [   "        if not verify( \$expected->{'store_pub'}, "
                    . "\$rec->{'signed'},\n        \$rec->{'sig'} );\n",
                "        if 0;\n"
            ]
        ],
    },
    {   name => 'reference foreign store key accepted',
        file => 'N7FS/Reference.pm',
        test => 'test-n7fs-format3.pl',
        edit => [
            [   "        if \$rec->{'signer_pub'} "
                    . "ne \$expected->{'store_pub'};\n",
                "        if 0;\n"
            ]
        ],
    },
    {   name => 'reference path binding removed',
        file => 'N7FS/Reference.pm',
        test => 'test-n7fs-format3.pl',
        edit => [
            [   "            if ( \$p->{\$field} "
                    . "// '' ) ne \$expected->{\$field};\n",
                "            if 0;\n"
            ]
        ],
    },
    {   name => 'missing journal-set items accepted',
        file => 'N7FS/Store.pm',
        test => 'test-n7fs-format3.pl',
        edit => [
            [   "    if ( \$cmp->{'missing'}->\@* ) {\n        my \$item = "
                    . "\$cmp->{'missing'}[0];\n        refuse( 'format 3 : "
                    . "missing",
                "    if (0) {\n        my \$item = \$cmp->{'missing'}[0];\n "
                    . "       refuse( 'format 3 : missing"
            ]
        ],
    },
    {   name => 'unlisted journal-set items accepted',
        file => 'N7FS/Store.pm',
        test => 'test-n7fs-format3.pl',
        edit =>
            [ [ "    if ( \$cmp->{'extra'}->\@* ) {\n", "    if (0) {\n" ] ],
    },
    {   name => 'repair candidate verification removed',
        file => 'N7FS/Store.pm',
        test => 'test-n7fs-format3.pl',
        edit => [
            [   "        node_verify( \$id->{'path'}, \$node, 3, \$id );\n",
                ""
            ]
        ],
    },
    {   name => 'journal witness rollback check removed',
        file => 'N7FS/Disk.pm',
        test => 'test-n7fs-format3.pl',
        edit => [
            [   "    return TRUE\n        if \$seq >= ( \$w->{'journal_seq'} "
                    . "// 0 )\n        or \$opt{'allow_rollback'};\n",
                "    return TRUE;\n"
            ]
        ],
    },
    {   name => 'drop of non-live reference prechecks removed',
        file => 'N7FS/Store.pm',
        test => 'test-n7fs-format3.pl',
        edit => [
            [ "        if not \@live;\n", "        if 0;\n" ],
            [   "        if not \$replay->{'references'}{\$key}\n    "
                    . "    or \$replay->{'references'}{\$key}{'dropped'};\n",
                "        if 0;\n"
            ]
        ],
    },
    {   name => 'empty assimilate batch writes a journal entry',
        file => 'N7FS/Store.pm',
        test => 'test-n7fs-format3.pl',
        edit => [
            [   "        if (   \$add->{'nodes'}->\@*\n            or "
                    . "\$add->{'meta'}->\@*\n            or "
                    . "\$add->{'references'}->\@* ) {\n",
                "        if (1) {\n"
            ]
        ],
    },
    {   name => 'conversion 2 to 3 does not rebind the epoch',
        file => 'N7FS/Convert.pm',
        test => 'test-n7fs-convert3.pl',
        edit => [
            [   "                    %{\$ARG},\n                        qw| "
                    . "epoch | => epoch_b32( \$node->{'addr'}{'epoch'} )\n",
                "                    %{\$ARG}\n"
            ]
        ],
    },
    {   name => 'conversion baseline marker removed',
        file => 'N7FS/Journal.pm',
        test => 'test-n7fs-convert3.pl',
        edit => [
            [   "    \$payload{'baseline'} = "
                    . "JSON::PP::true if \$flags->{'baseline'};\n",
                ""
            ]
        ],
    },
    {   name => 'converted reference marker removed',
        file => 'N7FS/Reference.pm',
        test => 'test-n7fs-convert3.pl',
        edit => [
            [   "    \$payload{'converted'} = "
                    . "JSON::PP::true if \$converted;\n",
                ""
            ]
        ],
    },
    {   name => 'format 3 meta signature check removed',
        file => 'N7FS/Store.pm',
        test => 'test-n7fs-format3.pl',
        edit => [ [ "        if not \$verified;\n", "        if 0;\n" ] ],
    },
    {   name => 'format 3 meta foreign store key accepted',
        file => 'N7FS/Store.pm',
        test => 'test-n7fs-format3.pl',
        edit => [ [ "        if \$foreign;\n", "        if 0;\n" ] ],
    },
    {   name => 'format 3 meta location binding removed',
        file => 'N7FS/Store.pm',
        test => 'test-n7fs-format3.pl',
        edit =>
            [ [ "            if not \$located;\n", "            if 0;\n" ] ],
    },
    {   name => 'lost tombstone not noticed',
        file => 'N7FS/Release.pm',
        test => 'test-n7fs-release.pl',
        edit => [
            [   "            if not \$held{\$address};\n",
                "            if 0;\n"
            ]
        ],
    },
    {   name => 'stale aside not cleared',
        file => 'N7FS/Release.pm',
        test => 'test-n7fs-release.pl',
        edit => [
            [   "    remove_tree(\$aside) if "
                    . "defined \$node and -e \$aside;\n",
                "    refuse('both') if defined \$node and -e \$aside;\n"
            ]
        ],
    },
    {   name => 'empty release reason kept',
        file => 'N7FS/Release.pm',
        test => 'test-n7fs-release.pl',
        edit => [
            [   "            if not defined "
                    . "\$reason or not length \$reason;\n",
                "            if not defined \$reason;\n"
            ]
        ],
    },
    {   name => 'previous form copy not named',
        file => 'N7FS/Release.pm',
        test => 'test-n7fs-release.pl',
        edit => [
            [   "    if ( ref \$state->{'previous'} eq qw| HASH | ) {\n",
                "    if (0) {\n"
            ]
        ],
    },
    {   name => 'release live-reference refusal removed',
        file => 'N7FS/Release.pm',
        test => 'test-n7fs-release.pl',
        edit => [
            [   "            if \@live and not \$opt{'force'};\n",
                "            if 0;\n"
            ]
        ],
    },
    {   name => 'release amos address validation removed',
        file => 'N7FS/Release.pm',
        test => 'test-n7fs-release.pl',
        edit => [
            [   "        if not defined \$epoch\n     "
                    . "   or amos_of_bmw(\$bmw) ne \$amos;\n",
                "        if 0;\n"
            ]
        ],
    },
    {   name => 'reclaim ignores live references',
        file => 'N7FS/Release.pm',
        test => 'test-n7fs-release.pl',
        edit => [
            [   "        next if grep { not \$ARG->{'dropped'} } \@refs;\n",
                "        next if 0;\n"
            ]
        ],
    },
    {   name => 'reclaim dry-run releases nodes',
        file => 'N7FS/Release.pm',
        test => 'test-n7fs-release.pl',
        edit => [
            [ "        next if \$opt{'dry_run'};\n", "        next if 0;\n" ]
        ],
    },
    {   name => 'reclaim age filter removed',
        file => 'N7FS/Release.pm',
        test => 'test-n7fs-release.pl',
        edit => [
            [   "            and \$newest > ntime_now() - \$opt{'older'};\n",
                "            and 0;\n"
            ]
        ],
    },
    {   name => 'tombstone signature check removed',
        file => 'N7FS/Release.pm',
        test => 'test-n7fs-release.pl',
        edit => [
            [   "        if not verify( \$id->{'store_pub'}, "
                    . "\$rec->{'signed'}, \$rec->{'sig'} );\n",
                "        if 0;\n"
            ]
        ],
    },
    {   name => 'tombstone write removed',
        file => 'N7FS/Release.pm',
        test => 'test-n7fs-release.pl',
        edit => [
            [   "    write_new_file( \$path,\n        signed_record_pack( "
                    . "qw| tombstone |, \\%payload, \$store, 3 ) );\n",
                ""
            ]
        ],
    },
    {   name => 'repair does not finish releases',
        file => 'N7FS/Store.pm',
        test => 'test-n7fs-release.pl',
        edit => [
            [   "    my \$finished\n        = "
                    . "AMOS7::N7FS::Release::release_repair( \$id, \$state, "
                    . "\$replay );\n",
                "    my \$finished = [];\n"
            ]
        ],
    },
    {   name => 'revival does not advance tombstone ntime',
        file => 'N7FS/Store.pm',
        test => 'test-n7fs-release.pl',
        edit => [
            [   "        \$ntime = \$tombstone->{'ntime'} + 1\n            "
                    . "if defined \$tombstone and \$ntime <= "
                    . "\$tombstone->{'ntime'};\n",
                ""
            ]
        ],
    },
    {   name => 'get by released address loses its clear error',
        file => 'N7FS/Journal.pm',
        test => 'test-n7fs-release.pl',
        edit =>
            [ [ "        \$expected->{'released'}{\$node} = TRUE;\n", "" ] ],
    },
    {   name => 'release-epoch now confirmation removed',
        file => 'N7FS/Convert.pm',
        test => 'test-n7fs-release.pl',
        edit => [ [ "        if not \$opt{'now'};\n", "        if 0;\n" ] ],
    },
    {   name => 'release-epoch confirmed check removed',
        file => 'N7FS/Convert.pm',
        test => 'test-n7fs-release.pl',
        edit => [
            [ "        if not \$state->{'confirmed'};\n", "        if 0;\n" ]
        ],
    },
    {   name => 'release-epoch active check removed',
        file => 'N7FS/Convert.pm',
        test => 'test-n7fs-release.pl',
        edit => [
            [   "    refuse('release-epoch : the active epoch cannot be "
                    . "released')\n        if grep { \$ARG == \$epoch } "
                    . "\$state->{'epochs'}->\@*;\n",
                "    refuse('release-epoch : the active "
                    . "epoch cannot be released')\n        if 0;\n"
            ]
        ],
    },
    {   name => 'repair forgets revived release asides',
        file => 'N7FS/Release.pm',
        test => 'test-n7fs-release.pl',
        edit => [
            [   "    foreach my \$address ( "
                    . "\$replay->{'release_order'}->\@* ) {\n",
                "    foreach my \$address ( keys "
                    . "\$replay->{'released'}->%* ) {\n"
            ]
        ],
    },
    {   name => 'prune without remove accepted',
        file => 'N7FS/Store.pm',
        test => 'test-n7fs-link.pl',
        edit => [
            [   "        if \$opt{'prune'} and not \$opt{'remove'};\n",
                "        if 0;\n"
            ]
        ],
    },
    {   name => 'conversion ignores st_dev',
        file => 'N7FS/Store.pm',
        test => 'test-n7fs-link.pl',
        edit => [
            [   "            and \$DEVICE->(\$source) == \$dst_dev ) {",
                "            and 1 ) {"
            ]
        ],
    },
    {   name => 'conversion does not fall back after a failed link',
        file => 'N7FS/Store.pm',
        test => 'test-n7fs-link.pl',
        edit => [
            [   "            \$node->{'content_note'} "
                    . "= \"hard link failed : \$OS_ERROR\";",
                "            refuse('hard link failed');"
            ]
        ],
    },
    {   name => 'new content is writable',
        file => 'N7FS/Store.pm',
        test => 'test-n7fs-link.pl',
        edit => [ [ "        0444\n    );", "        0600\n    );" ] ],
    },
    {   name => 'prune follows symlinks',
        file => 'N7FS/Store.pm',
        test => 'test-n7fs-link.pl',
        edit => [
            [   "        my \@st   = lstat \$path;",
                "        my \@st   = stat \$path;"
            ]
        ],
    },
    {   name => 'prune removes named roots',
        file => 'N7FS/Store.pm',
        test => 'test-n7fs-link.pl',
        edit =>
            [ [ "        while ( not \$keep{\$path}", "        while ( 1" ] ],
    },
    {   name => 'prune dry-run removes directories',
        file => 'N7FS/Store.pm',
        test => 'test-n7fs-link.pl',
        edit => [ [ "        if (\$dry_run) {", "        if (0) {" ] ],
    },
    {   name => 'prune recursively removes non-empty directories',
        file => 'N7FS/Store.pm',
        test => 'test-n7fs-link.pl',
        edit => [
            [   "        next if not rmdir \$path;",
                "        next if not remove_tree(\$path);"
            ]
        ],
    },
    {   name => 'linked content is not verified after linking',
        file => 'N7FS/Convert.pm',
        test => 'test-n7fs-link.pl',
        edit => [
            [   "            \$new->{'verify_node'}->( "
                    . "\$final, \$node->{'addr'}, \$context );\n",
                ""
            ],
            [   "        \$new->{'verify_node'}->( \$ARG->{'path'}, "
                    . "\$ARG, \$context )\n            for \@written;\n",
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
        map {"N7FS/$ARG.pm"}
        qw| Sum Sign Disk Store Convert Journal Reference Release | ) {
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

#,,,.,...,...,,,,,,,,,,,.,.,,,...,.,.,...,.,,,..,,...,...,,..,...,...,..,,...,
#C3LYX4KBOC7VVBWKEB74YF32TSFO4W3MGQXIDMUWHFUUVSY4MAY6LR3BRTI6LP726VAMVSUWNIFCK
#\\\|6M3QOEVF4PKXI3CFUHXVF4W5UA3XN542IAG5Z6LJW4N4PXZP2QH \ / AMOS7 \ YOURUM ::
#\[7]UZZOEXQHTHAQIVPXLTCMTVZZE6L5RTTRGSI2YP73TABGRK3J3IDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
