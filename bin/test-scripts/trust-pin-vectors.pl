## [:< ##

# name   = trust-pin-vectors.pl [ test data, not a module ]
# descr  = shared client pin verdict vectors [ TRUST-CHAIN-STEP2.md 'pins' ]
#          for the two pin deciders : src/trust.pin_decide [ test-host-root-
#          delegation.pl, wires b32-encoded ] and pin_decide in bin/
#          p7-auth-keypair-helper.pl [ its self-test, wires raw ]. both
#          assert the SAME verdict \ fp \ name \ owner flag, or the same
#          refusal reason, for every case.
#
# usage  : my $build = do <path> ; my $cases = $build->() ;
#          cases : [ { label, chain => [ <raw wire bytes>, .. ] [ anchor-
#          most first ], subject, now, host_pin => undef | { fp, name },
#          owners => [ fp, .. ], distrust => [ fp, .. ], strict => 0|1,
#          expect => <verdict> | 'refuse' | <exact reason>, fp, name,
#          owner, since, write } ] [ asserted for verdicts only ; host_pin
#          may carry since ]

use strict;
use warnings;
use Crypt::Ed25519;
use Crypt::Misc qw| encode_b32r |;
use Digest::BMW;

die 'shared fixture : do() this file and call the returned builder, '
    . "see the usage header\n"
    unless caller;

return sub {

    ## throwaway fixed-seed keys [ never real ] : owner 06, foreign owner 05,
    ## atom host-root 03, atom's rotated host-root 08, beta host-root 07, leaf
    ## S 02
    my %key;
    foreach my $seed (qw| 02 03 05 06 07 08 |) {
        $key{$seed}
            = [ Crypt::Ed25519::generate_keypair( chr( hex $seed ) x 32 ) ];
    }
    my $fp
        = sub { encode_b32r( Digest::BMW::bmw_384( $key{ shift() }[0] ) ) };

    my ( $nb, $na ) = ( 1700000000, 1702592000 );
    my $now = 1701000000;

    my $dlg = sub {    ## issuer seed, subject seed, name, scope, options
        my ( $i, $s, $name, $scope, %o ) = @_;
        my $st = pack(
            'Z* a32 a32 n/a* N N n/a*',
            'p7 delegation v1',
            $key{$i}[0], $key{$s}[0], $name,
            $o{'not_before'} // $nb,
            $o{'not_after'} // $na, $scope
        );
        my $sig = Crypt::Ed25519::sign( $st, $key{$i}[0], $key{$i}[1] );
        $sig = ~$sig if $o{'bad_sig'};
        return $st . $sig;
    };

    my @step1   = ( $dlg->( '03', '02', 'atom.cube', '' ) );
    my @owned   = ( $dlg->( '06', '03', 'atom',      'atom.*' ), @step1 );
    my @rotated = (
        $dlg->( '06', '08', 'atom',      'atom.*' ),
        $dlg->( '08', '02', 'atom.cube', '' )
    );
    my @beta = (
        $dlg->( '06', '07', 'beta',      'beta.*' ),
        $dlg->( '07', '02', 'beta.cube', '' )
    );
    my @foreign = ( $dlg->( '05', '03', 'atom', 'atom.*' ), @step1 );

    my $pin_atom = { fp => $fp->('03'), name => 'atom.cube' };

    my %base = ( subject => $key{'02'}[0], now => $now, strict => 0 );

    my @cases = (

        ## --- no host pin ----------------------------------------------
        {   label  => 'no pins : tofu pins the host-root',
            chain  => [@step1],
            expect => 'PIN_NEW',
            fp     => $fp->('03'),
            name   => 'atom.cube',
            owner  => 0,
            since  => 0,
            write  => 'new',
        },
        {   label  => 'no pins, strict : unpinned',
            chain  => [@step1],
            strict => 1,
            expect => 'PIN_UNPINNED',
            fp     => $fp->('03'),
            name   => 'atom.cube',
            owner  => 0,
            since  => 0,
            write  => 'none',
        },
        {   label  => 'owner pinned, owned chain : new host pin [ owner ]',
            chain  => [@owned],
            owners => [ $fp->('06') ],
            expect => 'PIN_NEW',
            fp     => $fp->('03'),
            name   => 'atom.cube',
            owner  => 1,
            since  => $nb,
            write  => 'new',
        },
        {   label  => 'owner pinned, strict : owner-verified is not tofu',
            chain  => [@owned],
            owners => [ $fp->('06') ],
            strict => 1,
            expect => 'PIN_NEW',
            fp     => $fp->('03'),
            name   => 'atom.cube',
            owner  => 1,
            since  => $nb,
            write  => 'new',
        },
        {   label  => 'owner pinned, chain of a foreign owner : tofu',
            chain  => [@foreign],
            owners => [ $fp->('06') ],
            expect => 'PIN_NEW',
            fp     => $fp->('03'),
            name   => 'atom.cube',
            owner  => 0,
            since  => 0,
            write  => 'new',
        },

        ## --- host pin matches -----------------------------------------
        {   label    => 'host pin, step 1 chain : valid',
            chain    => [@step1],
            host_pin => $pin_atom,
            expect   => 'PIN_VALID',
            fp       => $fp->('03'),
            name     => 'atom.cube',
            owner    => 0,
            since    => 0,
            write    => 'none',
        },
        {   label    => 'step 1 pin without a name : valid, name returned',
            chain    => [@step1],
            host_pin => { fp => $fp->('03') },
            expect   => 'PIN_VALID',
            fp       => $fp->('03'),
            name     => 'atom.cube',
            owner    => 0,
            since    => 0,
            write    => 'replace',
        },
        {   label    => 'host pin, owned chain, no owner pin : valid',
            chain    => [@owned],
            host_pin => $pin_atom,
            expect   => 'PIN_VALID',
            fp       => $fp->('03'),
            name     => 'atom.cube',
            owner    => 0,
            since    => 0,
            write    => 'none',
        },
        {   label    => 'host pin AND owner pin : the host pin decides',
            chain    => [@owned],
            host_pin => $pin_atom,
            owners   => [ $fp->('06') ],
            expect   => 'PIN_VALID',
            fp       => $fp->('03'),
            name     => 'atom.cube',
            owner    => 0,
            since    => 0,
            write    => 'none',
        },

        ## --- host pin differs -----------------------------------------
        {   label    => 'host-root rotated, owner covers, same name',
            chain    => [@rotated],
            host_pin => $pin_atom,
            owners   => [ $fp->('06') ],
            expect   => 'PIN_ROTATED',
            fp       => $fp->('08'),
            name     => 'atom.cube',
            owner    => 1,
            since    => $nb,
            write    => 'replace',
        },
        {   label    => 'host-root rotated, no owner pin : mismatch',
            chain    => [@rotated],
            host_pin => $pin_atom,
            expect   => 'PIN_MISMATCH',
            fp       => $fp->('08'),
            name     => 'atom.cube',
            owner    => 0,
            since    => 0,
            write    => 'none',
        },
        {   label => 'compromised sibling [ beta.cube '
                . 'on the atom pin ] : mismatch',
            chain    => [@beta],
            host_pin => $pin_atom,
            owners   => [ $fp->('06') ],
            expect   => 'PIN_MISMATCH',
            fp       => $fp->('07'),
            name     => 'beta.cube',
            owner    => 0,
            since    => 0,
            write    => 'none',
        },
        {   label    => 'rotated under a step 1 pin [ no name ] : mismatch',
            chain    => [@rotated],
            host_pin => { fp => $fp->('03') },
            owners   => [ $fp->('06') ],
            expect   => 'PIN_MISMATCH',
            fp       => $fp->('08'),
            name     => 'atom.cube',
            owner    => 0,
            since    => 0,
            write    => 'none',
        },
        {   label    => 'rotated, only a foreign owner pinned : mismatch',
            chain    => [@rotated],
            host_pin => $pin_atom,
            owners   => [ $fp->('05') ],
            expect   => 'PIN_MISMATCH',
            fp       => $fp->('08'),
            name     => 'atom.cube',
            owner    => 0,
            since    => 0,
            write    => 'none',
        },

        ## --- a pinned name never changes -------------------------------
        {   label    => 'named pin, same host-root, other leaf name : kept',
            chain    => [ $dlg->( '03', '02', 'atom2.cube', '' ) ],
            host_pin => $pin_atom,
            expect   => 'PIN_VALID',
            fp       => $fp->('03'),
            name     => 'atom.cube',
            owner    => 0,
            since    => 0,
            write    => 'none',
        },

        ## --- rotation is forward only ---------------------------------
        {   label => 'rotate BACK to an old host-root under '
                . 'a still valid owner statement : mismatch',
            chain    => [@owned],
            host_pin => {
                fp    => $fp->('08'),
                name  => 'atom.cube',
                since => $nb + 1000
            },
            owners => [ $fp->('06') ],
            expect => 'PIN_MISMATCH',
            fp     => $fp->('03'),
            name   => 'atom.cube',
            owner  => 0,
            since  => $nb + 1000,
            write  => 'none',
        },
        {   label => 'rotate forward past the pinned since',
            chain => [
                $dlg->(
                    '06', '08', 'atom', 'atom.*', not_before => $nb + 2000
                ),
                $rotated[1]
            ],
            host_pin => { %$pin_atom, since => $nb + 1000 },
            owners   => [ $fp->('06') ],
            expect   => 'PIN_ROTATED',
            fp       => $fp->('08'),
            name     => 'atom.cube',
            owner    => 1,
            since    => $nb + 2000,
            write    => 'replace',
        },
        {   label    => 'rotate with an EQUAL since : mismatch',
            chain    => [@rotated],
            host_pin => { %$pin_atom, since => $nb },
            owners   => [ $fp->('06') ],
            expect   => 'PIN_MISMATCH',
            fp       => $fp->('08'),
            name     => 'atom.cube',
            owner    => 0,
            since    => $nb,
            write    => 'none',
        },

        ## --- refused before any pin is looked at ----------------------
        {   label    => 'distrusted host-root, owner pinned',
            chain    => [@owned],
            owners   => [ $fp->('06') ],
            distrust => [ $fp->('03') ],
            expect   => 'distrusted key in chain',
        },
        {   label    => 'distrusted owner above a matching host pin',
            chain    => [@owned],
            host_pin => $pin_atom,
            distrust => [ $fp->('06') ],
            expect   => 'distrusted key in chain',
        },
        {   label => 'bad leaf signature',
            chain => [ $dlg->( '03', '02', 'atom.cube', '', bad_sig => 1 ) ],
            host_pin => $pin_atom,
            expect   => 'statement 1 : signature not valid',
        },
        {   label => 'expired leaf under an owner',
            chain => [
                $owned[0],
                $dlg->( '03', '02', 'atom.cube', '', not_after => $now - 1 )
            ],
            owners => [ $fp->('06') ],
            expect => 'statement 2 : expired',
        },
        {   label    => 'leaf for another subject',
            chain    => [ $dlg->( '03', '05', 'atom.cube', '' ) ],
            host_pin => $pin_atom,
            expect   => 'statement 1 : subject mismatch',
        },
    );

    return [
        map {
            { %base, owners => [], distrust => [], $ARG->%* }
        } @cases
    ];
};

#,,,.,...,,.,,...,,,,,.,.,..,,,..,,,.,,..,..,,..,,...,...,...,.,,,,,.,..,,...,
#5FEIQ2GM3KOVQQIXPGHEIWMP6YAPDXHVQVBWQAFYO3O6R6YMY57GU6NUDLM3ZQETVLWAVMMXJAZ52
#\\\|KIF4RUTRUWOWK5VYNO7Y3VB3LON7TCJARRCIREHT2F4SV6LVXRF \ / AMOS7 \ YOURUM ::
#\[7]RSJEZ3UBM4RFDIN4PM5DN3DGQCRR4Y37TRRT23VUGUAJMOB46WCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
