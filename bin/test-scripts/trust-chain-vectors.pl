## [:< ##

# name   = trust-chain-vectors.pl [ test data, not a module ]
# descr  = shared trust chain vectors [ TRUST-CHAIN-STEP2.md ] for the two
#          verifiers : src/trust.verify [ test-host-root-delegation.pl,
#          wires b32-encoded ] and verify_chain in bin/
#          p7-auth-keypair-helper.pl [ its self-test, wires raw ]. both
#          harnesses do() this file and assert the SAME accept \ refuse \
#          reason for every case -- a verdict mismatch between the two
#          implementations is a test failure.
#
# usage  : my $build = do <path> ; my $cases = $build->() ;
#          cases : [ { label, chain => [ <raw wire bytes>, .. ] [ anchor-
#          most first ], anchors => [ <fingerprint>, .. ], subject =>
#          <raw 32 byte pub>, now => <unix>, distrust => [ <fp>, .. ]
#          [ optional ], expect => 'ok' | 'refuse' |
#          <exact reason>, name => <leaf name>, anchor => <fp>, depth =>
#          <n> } ] [ name \ anchor \ depth asserted for 'ok' only ;
#          'refuse' asserts refusal without pinning a reason -- the ONE
#          case where the parsers' reasons legitimately differ ]

use strict;
use warnings;
use Crypt::Ed25519;
use Crypt::Misc qw| encode_b32r |;
use Digest::BMW;

die 'shared fixture : do() this file and call the returned builder, '
    . "see the usage header\n"
    unless caller;

return sub {

    ## throwaway fixed-seed keys [ never real ] : owner 06, host-root 03 [ the
    ## spec vector ], zenka 07 \ 08, leaf S 02 [ the AUTH-LINK- BINDING S ],
    ## foreign 05
    my %key;
    foreach my $seed (qw| 02 03 05 06 07 08 |) {
        $key{$seed}
            = [ Crypt::Ed25519::generate_keypair( chr( hex $seed ) x 32 ) ];
    }
    my $fp = sub { encode_b32r( Digest::BMW::bmw_384(shift) ) };

    my ( $nb, $na ) = ( 1700000000, 1702592000 );
    my $now = 1701000000;

    my $wire = sub {
        my (%o) = @_;
        my $st = pack(
            'Z* a32 a32 n/a* N N n/a*',
            'p7 delegation v1',
            @o{qw| issuer subject name not_before not_after scope |}
        );
        my $sig = Crypt::Ed25519::sign( $st, $o{'issuer'}, $o{'priv'} );
        $sig = ~$sig if $o{'bad_sig'};
        return $st . $sig;
    };
    my $dlg = sub {    ## issuer seed, subject seed, name, scope, options
        my ( $i, $s, $name, $scope, %o ) = @_;
        return $wire->(
            issuer     => $key{$i}[0],
            priv       => $key{$i}[1],
            subject    => $key{$s}[0],
            name       => $name,
            scope      => $scope,
            not_before => $o{'not_before'} // $nb,
            not_after  => $o{'not_after'}  // $na,
            bad_sig    => $o{'bad_sig'}    // 0,
        );
    };

    ## the canonical chains [ anchor-most first ] ##
    my $o2h  = $dlg->( '06', '03', 'atom',             'atom.*' );
    my $h2s  = $dlg->( '03', '02', 'atom.cube',        '' );
    my $h2n  = $dlg->( '03', '07', 'atom.zenka',       'atom.zenka.*' );
    my $n2s  = $dlg->( '07', '02', 'atom.zenka.httpd', '' );
    my $leaf = $dlg->( '03', '02', 'test-host.cube',   '' );

    my @cases = (

        ## --- accept ---------------------------------------------------
        {   label   => 'one hop leaf [ step 1 shape ]',
            chain   => [$leaf],
            anchors => [ $fp->( $key{'03'}[0] ) ],
            subject => $key{'02'}[0],
            now     => $now,
            expect  => 'ok',
            name    => 'test-host.cube',
            anchor  => $fp->( $key{'03'}[0] ),
            depth   => 1,
        },
        {   label   => 'owner -> host -> leaf, owner pinned',
            chain   => [ $o2h, $h2s ],
            anchors => [ $fp->( $key{'06'}[0] ) ],
            subject => $key{'02'}[0],
            now     => $now,
            expect  => 'ok',
            name    => 'atom.cube',
            anchor  => $fp->( $key{'06'}[0] ),
            depth   => 2,
        },
        {   label => 'same chain, only the host '
                . 'pinned [ anchor in the middle ]',
            chain   => [ $o2h, $h2s ],
            anchors => [ $fp->( $key{'03'}[0] ) ],
            subject => $key{'02'}[0],
            now     => $now,
            expect  => 'ok',
            name    => 'atom.cube',
            anchor  => $fp->( $key{'03'}[0] ),
            depth   => 1,
        },
        {   label   => 'owner -> host -> zenka -> leaf [ nested prefixes ]',
            chain   => [ $o2h, $h2n, $n2s ],
            anchors => [ $fp->( $key{'06'}[0] ) ],
            subject => $key{'02'}[0],
            now     => $now,
            expect  => 'ok',
            name    => 'atom.zenka.httpd',
            anchor  => $fp->( $key{'06'}[0] ),
            depth   => 3,
        },

        ## --- anchor position ------------------------------------------
        {   label   => 'only the leaf SUBJECT pinned [ never an issuer ]',
            chain   => [ $o2h, $h2s ],
            anchors => [ $fp->( $key{'02'}[0] ) ],
            subject => $key{'02'}[0],
            now     => $now,
            expect  => 'no pinned anchor in chain',
        },
        {   label   => 'no anchor in the chain',
            chain   => [ $o2h, $h2s ],
            anchors => [ $fp->( $key{'05'}[0] ) ],
            subject => $key{'02'}[0],
            now     => $now,
            expect  => 'no pinned anchor in chain',
        },

        ## --- scope : widening \ equality \ boundary -------------------
        {   label => 'scope widening [ atom.* -> beta.* ]',
            chain =>
                [ $o2h, $dlg->( '03', '07', 'atom.zenka', 'beta.*' ), $n2s ],
            anchors => [ $fp->( $key{'06'}[0] ) ],
            subject => $key{'02'}[0],
            now     => $now,
            expect  => 'statement 2 : scope not within issuer scope',
        },
        {   label => 'scope not narrower [ atom.* -> atom.* ]',
            chain =>
                [ $o2h, $dlg->( '03', '07', 'atom.zenka', 'atom.*' ), $n2s ],
            anchors => [ $fp->( $key{'06'}[0] ) ],
            subject => $key{'02'}[0],
            now     => $now,
            expect  => 'statement 2 : scope not within issuer scope',
        },
        {   label => 'exact scope [ atom.cube -> atom.cube.* ]',
            chain => [
                $dlg->( '06', '03', 'atom',      'atom.cube' ),
                $dlg->( '03', '02', 'atom.cube', 'atom.cube.*' ),
            ],
            anchors => [ $fp->( $key{'06'}[0] ) ],
            subject => $key{'02'}[0],
            now     => $now,
            expect  => 'statement 2 : scope not within issuer scope',
        },
        {   label   => 'name outside issuer scope [ atom.* vs beta.cube ]',
            chain   => [ $o2h, $dlg->( '03', '02', 'beta.cube', '' ) ],
            anchors => [ $fp->( $key{'06'}[0] ) ],
            subject => $key{'02'}[0],
            now     => $now,
            expect  => 'statement 2 : name outside issuer scope',
        },
        {   label   => 'prefix boundary [ atom.* vs atomx.cube ]',
            chain   => [ $o2h, $dlg->( '03', '02', 'atomx.cube', '' ) ],
            anchors => [ $fp->( $key{'06'}[0] ) ],
            subject => $key{'02'}[0],
            now     => $now,
            expect  => 'statement 2 : name outside issuer scope',
        },
        {   label   => 'prefix boundary [ atom.* vs atom itself ]',
            chain   => [ $o2h, $dlg->( '03', '02', 'atom', '' ) ],
            anchors => [ $fp->( $key{'06'}[0] ) ],
            subject => $key{'02'}[0],
            now     => $now,
            expect  => 'statement 2 : name outside issuer scope',
        },
        {   label => 'prefix boundary [ atom.* vs atom. -- empty remainder ]',
            chain => [ $o2h, $dlg->( '03', '02', 'atom.', '' ) ],
            anchors => [ $fp->( $key{'06'}[0] ) ],
            subject => $key{'02'}[0],
            now     => $now,
            expect  => 'statement 2 : name outside issuer scope',
        },
        {   label => 'scope boundary [ atom.* vs '
                . 'atom..* -- empty remainder ]',
            chain   => [ $o2h, $dlg->( '03', '02', 'atom.x', 'atom..*' ) ],
            anchors => [ $fp->( $key{'06'}[0] ) ],
            subject => $key{'02'}[0],
            now     => $now,
            expect  => 'statement 2 : scope not within issuer scope',
        },
        {   label   => 'statement scope * refused',
            chain   => [ $dlg->( '06', '03', 'atom', '*' ) ],
            anchors => [ $fp->( $key{'06'}[0] ) ],
            subject => $key{'03'}[0],
            now     => $now,
            expect  => 'statement 1 : scope pattern not valid',
        },
        {   label => 'leaf scope not empty',
            chain => [ $o2h, $dlg->( '03', '02', 'atom.cube', 'atom.cube' ) ],
            anchors => [ $fp->( $key{'06'}[0] ) ],
            subject => $key{'02'}[0],
            now     => $now,
            expect  => 'statement 2 : leaf scope not empty',
        },
        {   label => 'scope charset violation [ a space ]',
            chain =>
                [ $o2h, $dlg->( '03', '07', 'atom.zenka', 'a b' ), $n2s ],
            anchors => [ $fp->( $key{'06'}[0] ) ],
            subject => $key{'02'}[0],
            now     => $now,
            expect  => 'refuse',    ## the parsers word this differently
        },
        {   label => 'scope pattern violation [ atom.*x ]',
            chain =>
                [ $o2h, $dlg->( '03', '07', 'atom.zenka', 'atom.*x' ), $n2s ],
            anchors => [ $fp->( $key{'06'}[0] ) ],
            subject => $key{'02'}[0],
            now     => $now,
            expect  => 'statement 2 : scope pattern not valid',
        },

        ## --- chain shape ----------------------------------------------
        {   label => 'chain length 5 refused [ before parsing ]',
            chain => [
                $o2h, $h2n,
                $dlg->( '07', '08', 'atom.zenka.httpd', 'atom.zenka.*' ),
                $dlg->( '08', '02', 'atom.zenka.x',     '' ), $n2s,
            ],
            anchors => [ $fp->( $key{'06'}[0] ) ],
            subject => $key{'02'}[0],
            now     => $now,
            expect  => 'chain too long',
        },
        {   label   => 'issuer != previous subject',
            chain   => [ $o2h, $dlg->( '05', '02', 'atom.cube', '' ) ],
            anchors => [ $fp->( $key{'06'}[0] ) ],
            subject => $key{'02'}[0],
            now     => $now,
            expect  => 'statement 2 : issuer is not the previous subject',
        },
        {   label => 'expired middle statement',
            chain => [
                $dlg->( '06', '03', 'atom', 'atom.*', not_after => $now - 1 ),
                $h2s,
            ],
            anchors => [ $fp->( $key{'06'}[0] ) ],
            subject => $key{'02'}[0],
            now     => $now,
            expect  => 'statement 1 : expired',
        },
        {   label => 'bad signature in the middle',
            chain => [
                $dlg->( '06', '03', 'atom', 'atom.*', bad_sig => 1 ), $h2s
            ],
            anchors => [ $fp->( $key{'06'}[0] ) ],
            subject => $key{'02'}[0],
            now     => $now,
            expect  => 'statement 1 : signature not valid',
        },

        ## --- order : a leaf-first list fed as anchor-most first -------
        {   label   => 'reversed chain, host pinned [ fails closed ]',
            chain   => [ $h2s, $o2h ],
            anchors => [ $fp->( $key{'03'}[0] ) ],
            subject => $key{'02'}[0],
            now     => $now,
            expect  => 'statement 2 : issuer is not the previous subject',
        },
        {   label   => 'reversed chain, owner pinned [ fails closed ]',
            chain   => [ $h2s, $o2h ],
            anchors => [ $fp->( $key{'06'}[0] ) ],
            subject => $key{'02'}[0],
            now     => $now,
            expect  => 'statement 2 : subject mismatch',
        },

        ## --- distrust [ checked first, over every statement ] ---------
        {   label    => 'distrusted host-root under an owner pin',
            chain    => [ $o2h, $h2s ],
            anchors  => [ $fp->( $key{'06'}[0] ) ],
            distrust => [ $fp->( $key{'03'}[0] ) ],
            subject  => $key{'02'}[0],
            now      => $now,
            expect   => 'distrusted key in chain',
        },
        {   label    => 'distrusted owner ABOVE a pinned host-root',
            chain    => [ $o2h, $h2s ],
            anchors  => [ $fp->( $key{'03'}[0] ) ],
            distrust => [ $fp->( $key{'06'}[0] ) ],
            subject  => $key{'02'}[0],
            now      => $now,
            expect   => 'distrusted key in chain',
        },
        {   label    => 'distrusted leaf subject',
            chain    => [$leaf],
            anchors  => [ $fp->( $key{'03'}[0] ) ],
            distrust => [ $fp->( $key{'02'}[0] ) ],
            subject  => $key{'02'}[0],
            now      => $now,
            expect   => 'distrusted key in chain',
        },
        {   label    => 'unrelated distrust entry [ accepted ]',
            chain    => [ $o2h, $h2s ],
            anchors  => [ $fp->( $key{'06'}[0] ) ],
            distrust => [ $fp->( $key{'05'}[0] ) ],
            subject  => $key{'02'}[0],
            now      => $now,
            expect   => 'ok',
            name     => 'atom.cube',
            anchor   => $fp->( $key{'06'}[0] ),
            depth    => 2,
        },
    );

    return \@cases;
};

#,,..,,.,,,,.,,..,...,,,.,..,,...,.,,,,.,,,,,,..,,...,..,,...,.,.,.,.,.,.,,,,,
#DCNO6XVI52A2JPPEQLXJGGSL243OPCKHVH2DXET5U5KFWHRCMCA7N5WWROCEBNMZOJNGCTNXLASXE
#\\\|YZXK5OPVTME66DGER2HOMKJ4T4DLC4KEEBE3TRQVTZ73IJ6S4XH \ / AMOS7 \ YOURUM ::
#\[7]BSFOBBYRFFJQSY4J432TQDKWSCJJDF56P5JGI663T3FNZOSUAIBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
