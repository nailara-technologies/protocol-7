#!/usr/bin/env perl
# Protocol-7 Auth-Keypair Helper for C Client (p-7-r.c)
# Provides auth-keypair credentials (C25519 pubkey + Ed25519 signature)
#
# This helper is called by p-7-r.c via popen() to perform operations
# that are complex to implement directly in C code.

use strict;
use warnings;
use FindBin qw($RealBin);
use File::Spec;
use Cwd qw(abs_path);
use English;

##[ Setup Library Paths ]#####################################################

BEGIN {
    # Add Protocol-7 lib path
    my $up_dir   = File::Spec->updir;
    my $root     = abs_path( File::Spec->catdir( $RealBin, $up_dir ) );
    my $lib_path = File::Spec->catdir( $root, 'data', 'lib-path', 'pm' );

    die "Library path not found: $lib_path\n" unless -d $lib_path;
    unshift @INC, $lib_path;
}

# Import crypto modules
use Crypt::Misc qw(encode_b32r decode_b32r);
use Crypt::PRNG::Fortuna;
use Crypt::Curve25519 qw(curve25519_public_key);
use Crypt::Ed25519;
use IO::AIO;
use Digest::BMW;
use Fcntl      qw(O_WRONLY O_CREAT O_EXCL);
use File::Path qw(make_path);

## wire v2 [ data/md/design/AUTH-LINK-BINDING.md ] : every argv value of the
## verbs below is PUBLIC [ username, nonce, S_pub, ephemeral pubkeys,
## nonce_sid, encoding, host, port, signatures, delegation ] ; the client's
## secret is loaded from its key file by this helper, never passed in

## host-root delegation [ data/md/design/HOST-ROOT-DELEGATION.md ] : the
## select reply's 4th field. upper bound on its b32 length -- the SAME number
## p-7-r.c uses [ DLG_B32_MAX ]
use constant DLG_LABEL   => "p7 delegation v1\0";
use constant DLG_B32_MAX => 2048;

## chain verify [ TRUST-CHAIN-STEP2.md ] : refused before anything parses
use constant DLG_CHAIN_MAX => 4;

##[ Main Entry Point ]########################################################

my $operation = shift @ARGV // 'help';

if ( $operation eq 'gen-auth' ) {
    op_gen_auth(@ARGV);
} elsif ( $operation eq 'check-pin' ) {
    op_check_pin(@ARGV);
} elsif ( $operation eq 'gen-bind' ) {
    op_gen_bind(@ARGV);
} elsif ( $operation eq 'verify-bind' ) {
    op_verify_bind(@ARGV);
} elsif ( $operation eq 'self-test' ) {
    op_self_test();
} elsif ( $operation eq 'help'
    || $operation eq '-h'
    || $operation eq '--help' ) {
    print "Usage: p7-auth-keypair-helper.pl <verb> [args]\n  gen-auth    "
        . "<username> <server_nonce> <s_pub>\n  check-pin   <host> "
        . "<port> <s_pub> <delegation> [strict]\n  gen-bind    "
        . "<username> <server_nonce> <s_pub> <server_eph> <client_eph> "
        . "<nonce_sid> <encoding>\n  verify-bind <server_bind_sig> "
        . "<username> <server_nonce> <s_pub> <server_eph> <client_eph> "
        . "<nonce_sid> <encoding>\n  self-test\n  [ keys \\ nonces \\ "
        . "sigs : b32, RFC 4648, no padding ]\n";
    exit 0;
} else {
    print STDERR "Unknown operation: $operation\n";
    exit 1;
}

##[ Message builders : the ONE place for the pack templates ]#################

sub auth_message {
    my ( $server_nonce, $s_pub, $session_pub, $username ) = @_;
    return pack(
        'Z* a32 a32 a32 n/a*',
        'p7 auth-keypair v2',
        $server_nonce, $s_pub, $session_pub, $username
    );
}

sub bind_transcript {
    my ( $server_nonce, $s_pub, $server_eph, $client_eph, $nonce_sid,
        $encoding, $username )
        = @_;
    return pack( 'a32 a32 a32 a32 N n/a* n/a*',
        $server_nonce, $s_pub, $server_eph, $client_eph, $nonce_sid,
        $encoding,     $username );
}

sub bind_message {
    my ( $role, $transcript ) = @_;
    die "bind role must be client or server\n"
        unless defined $role and $role =~ m{^(?:client|server)\z};
    return pack( 'Z*', "p7 link-bind v1 $role" ) . $transcript;
}

## true only for a 64 byte server_bind_sig valid under s_pub
sub verify_server_bind {
    my ( $sig, $s_pub, $transcript ) = @_;
    return 0 unless length($sig) == 64 and length($s_pub) == 32;
    return Crypt::Ed25519::verify( bind_message( 'server', $transcript ),
        $s_pub, $sig ) ? 1 : 0;
}

##[ Host-root delegation [ HOST-ROOT-DELEGATION.md ] ]########################

## the statement bytes [ the spec's pack template ; self-test builds with it ]
sub delegation_statement {
    my ( $issuer_pub, $subject_pub, $name, $not_before, $not_after, $scope )
        = @_;
    die "delegation : issuer \\ subject must be 32 bytes\n"
        unless length($issuer_pub) == 32 and length($subject_pub) == 32;
    return pack(
        'Z* a32 a32 n/a* N N n/a*',
        'p7 delegation v1',
        $issuer_pub, $subject_pub, $name, $not_before, $not_after, $scope
    );
}

## host-root key id : bmw384 of the raw 32 byte public key, b32 [ 77 ]
sub key_id {
    my ($pub) = @_;
    die "key id : expected a 32 byte public key\n"
        unless defined $pub and length($pub) == 32;
    return encode_b32r( Digest::BMW::bmw_384($pub) );
}

## wire bytes [ statement . sig ] -> fields ; dies with a reason. exact parse
## : literal label, every length checked, no trailing bytes
sub parse_delegation {
    my ($wire) = @_;
    my $label = DLG_LABEL;
    die "too short\n"
        unless defined $wire
        and length($wire) >= length($label) + 32 + 32 + 2 + 4 + 4 + 2 + 64;

    my $statement = substr( $wire, 0, length($wire) - 64 );
    my $sig       = substr( $wire, -64 );
    die "wrong label\n"
        unless substr( $statement, 0, length($label) ) eq $label;

    my $pos  = length($label);
    my $take = sub {
        my ($n) = @_;
        die "truncated statement\n" if $pos + $n > length($statement);
        my $bytes = substr( $statement, $pos, $n );
        $pos += $n;
        return $bytes;
    };
    my %dlg;
    $dlg{'issuer_pub'}  = $take->(32);
    $dlg{'subject_pub'} = $take->(32);
    $dlg{'name'}        = $take->( unpack( 'n', $take->(2) ) );
    $dlg{'not_before'}  = unpack( 'N', $take->(4) );
    $dlg{'not_after'}   = unpack( 'N', $take->(4) );
    $dlg{'scope'}       = $take->( unpack( 'n', $take->(2) ) );
    die "trailing bytes in statement\n" if $pos != length($statement);

    $dlg{'statement'} = $statement;
    $dlg{'sig'}       = $sig;
    return \%dlg;
}

## a name inside a scope pattern ? [ the caller handles '' \ '*' ] -- the SAME
## rule as src/trust.verify : '<prefix>.*' is strictly below prefix
sub name_in_scope {
    my ( $scope, $name ) = @_;
    return 1 if $scope eq '*';
    my ($prefix) = $scope =~ m|\A(.+)\.\*\z|;
    ## strictly below : something must follow "<prefix>."
    return ( index( $name, "$prefix." ) == 0
            and length($name) > length($prefix) + 1 ) ? 1 : 0
        if defined $prefix;
    return $name eq $scope ? 1 : 0;
}

## $sub STRICTLY within $iss ? [ '' handled by the caller : always allowed ;
## both are checked patterns before this runs ] -- the SAME rule as
## src/trust.verify : equal scope refuses, an exact name has only '' below
sub scope_within {
    my ( $iss, $sub ) = @_;
    return 1 if $iss eq '*';
    return 0 if $iss eq '';
    my ($i_pre) = $iss =~ m|\A(.+)\.\*\z|;
    return 0 if not defined $i_pre;    ## an exact name : only '' below
    my ($s_core) = $sub =~ m|\A(.+?)(?:\.\*)?\z|;
    return ( index( $s_core, "$i_pre." ) == 0
            and length($s_core) > length($i_pre) + 1 ) ? 1 : 0;
}

## walk a delegation chain [ RAW wires, anchor-most first ] from the first
## statement whose issuer key id is pinned down to the subject key -- the SAME
## rules & refusal reasons as src/trust.verify [ TRUST-CHAIN- STEP2.md ] : the
## statements before the anchor are ignored, every later issuer must be the
## previous subject, per statement : exact parse -> sig
## -> not_before <= now <= not_after -> [ last : subject ] -> name charset
## -> scope [ a statement carrying scope '*' refuses ]. -> ( { key id, name,
## anchor, issuer_pub, not_after, depth }, undef ) or ( undef, reason ) ;
## depth = statements actually verified. $distrust [ optional, key ids ] :
## checked first, over every statement -- the SAME rule as trust.verify
sub verify_chain {
    my ( $chain, $anchors, $subject, $now, $distrust ) = @_;

    my $refuse = sub {
        my ($reason) = @_;
        return ( undef, $reason );
    };

    my $re_name  = qr|\A[A-Za-z0-9][A-Za-z0-9._-]{0,254}\z|;
    my $re_scope = qr|\A[A-Za-z0-9][A-Za-z0-9._-]{0,254}(?:\.\*)?\z|;

    return $refuse->('chain missing')
        if ref $chain ne 'ARRAY' or not $chain->@*;
    return $refuse->('chain too long') if $chain->@* > DLG_CHAIN_MAX;
    return $refuse->('anchors missing')
        if ref $anchors ne 'ARRAY'
        or not grep { defined $ARG and not ref $ARG and length $ARG }
        $anchors->@*;
    return $refuse->('subject not 32 bytes')
        if not defined $subject
        or ref $subject
        or length($subject) != 32;
    return $refuse->('time not valid')
        if not defined $now
        or ref $now
        or $now !~ m|\A[0-9]{1,10}\z|;

    return $refuse->('distrust not a list')
        if defined $distrust and ref $distrust ne 'ARRAY';

    ## distrusted keys anywhere in the chain [ also before the anchor ] :
    ## issuer + subject at fixed offsets after the label, and the subject
    my %distrusted = map { $ARG => 1 }
        grep { defined $ARG and not ref $ARG and length $ARG }
        ( $distrust // [] )->@*;
    if (%distrusted) {
        my $label_len = length(DLG_LABEL);
        my @key       = ($subject);
        foreach my $wire ( $chain->@* ) {
            next if not defined $wire or ref $wire;
            next if length($wire) < $label_len + 64;
            push @key, substr( $wire, $label_len, 32 ),
                substr( $wire, $label_len + 32, 32 );
        }
        return $refuse->('distrusted key in chain')
            if grep { exists $distrusted{ key_id($ARG) } } @key;
    }

    my %anchor = map { $ARG => 1 }
        grep { defined $ARG and not ref $ARG and length $ARG } $anchors->@*;

    ## verification starts at the first statement whose issuer key id is
    ## pinned ; the ones before it are ignored [ not checked ]
    my $start;
    my $anchor_fp;
    foreach my $index ( 0 .. $chain->$#* ) {
        my $st = eval { parse_delegation( $chain->[$index] ) };
        next if not defined $st;
        my $fp = key_id( $st->{'issuer_pub'} );
        next if not exists $anchor{$fp};
        $start     = $index;
        $anchor_fp = $fp;
        last;
    }
    return $refuse->('no pinned anchor in chain') if not defined $start;

    my $issuer_scope = '*';    ## the anchor's implicit scope
    my $prev_subject;
    my $last;

    foreach my $index ( $start .. $chain->$#* ) {
        my $at = sprintf 'statement %d', $index + 1;

        my $st = eval { parse_delegation( $chain->[$index] ) };
        if ( not defined $st ) {
            ( my $why = $@ || 'unparsable' ) =~ s{\s+\z}{};
            return $refuse->("$at : $why");
        }

        return $refuse->("$at : issuer is not the previous subject")
            if $index > $start and $st->{'issuer_pub'} ne $prev_subject;

        return $refuse->("$at : signature not valid")
            unless Crypt::Ed25519::verify( $st->{'statement'},
            $st->{'issuer_pub'}, $st->{'sig'} );

        return $refuse->("$at : not_after before not_before")
            if $st->{'not_after'} < $st->{'not_before'};
        return $refuse->("$at : not yet valid")
            if $now < $st->{'not_before'};
        return $refuse->("$at : expired") if $now > $st->{'not_after'};

        my $is_last = $index == $chain->$#*;

        return $refuse->("$at : subject mismatch")
            if $is_last and $st->{'subject_pub'} ne $subject;

        return $refuse->("$at : name not valid") if $st->{'name'} !~ $re_name;

        ## the issuer may certify this name ?
        return $refuse->("$at : issuer scope is empty")
            if $issuer_scope eq '';
        return $refuse->("$at : name outside issuer scope")
            if not name_in_scope( $issuer_scope, $st->{'name'} );

        ## the subject's own scope : a valid pattern, strictly narrower
        my $scope = $st->{'scope'};
        if ( $scope ne '' ) {
            return $refuse->("$at : scope pattern not valid")
                if $scope !~ $re_scope;
            return $refuse->("$at : scope not within issuer scope")
                if not scope_within( $issuer_scope, $scope );
        }

        ## the leaf certifies nothing
        return $refuse->("$at : leaf scope not empty")
            if $is_last and $scope ne '';

        $issuer_scope = $scope;
        $prev_subject = $st->{'subject_pub'};
        $last         = $st;
    }

    return (
        {   'key_id'     => $anchor_fp,
            'name'       => $last->{'name'},
            'anchor'     => $anchor_fp,
            'issuer_pub' => $last->{'issuer_pub'},
            'not_after'  => $last->{'not_after'},
            'depth'      => $chain->$#* - $start + 1,
        },
        undef
    );
}

## client pin verdict [ TRUST-CHAIN-STEP2.md 'pins' ] -- the twin of
## src/trust.pin_decide, the SAME rules, shared cases in bin/test-scripts/
## trust-pin-vectors.pl. chain : RAW wires, anchor-most first ; host_pin :
## undef | { fp, name | undef, since } -> ( { verdict fp name since write
## anchor owner name_differs }, undef ) or ( undef, reason ). fp \ name \
## since = what the host pin holds afterwards ; write = none \ new \ replace.
## a pinned name never changes, rotation is forward only [ since ], an owner
## key id is never returned for pinning
sub pin_decide {
    my ($p) = @_;
    return ( undef, 'parameters not a hash' ) if ref $p ne 'HASH';
    my ( $chain, $subject, $now, $host_pin, $owners, $distrust, $strict )
        = @{$p}{qw| chain subject now host_pin owners distrust strict |};

    return ( undef, 'chain missing' )
        if ref $chain ne 'ARRAY' or not $chain->@*;
    return ( undef, 'host pin not valid' )
        if defined $host_pin
        and ( ref $host_pin ne 'HASH'
        or not defined $host_pin->{'fp'}
        or $host_pin->{'fp'} !~ m|\A[A-Z2-7]{77}\z| );
    foreach my $list ( $owners, $distrust ) {
        return ( undef, 'owners \ distrust not a list' )
            if defined $list and ref $list ne 'ARRAY';
    }
    my @owner
        = grep { defined $ARG and m|\A[A-Z2-7]{77}\z| } ( $owners // [] )->@*;
    my %is_owner = map { $ARG => 1 } @owner;

    my $verify = sub {
        my ($anchors) = @_;
        return verify_chain( $chain, $anchors, $subject, $now,
            $distrust // [] );
    };

    my $leaf = eval { parse_delegation( $chain->[-1] ) };
    if ( not defined $leaf ) {
        ( my $why = $@ || 'unparsable' ) =~ s{\s+\z}{};
        return (
            undef,
            sprintf 'statement ' . '%d : %s',
            scalar $chain->@*, $why
        );
    }
    my $leaf_fp = key_id( $leaf->{'issuer_pub'} );

    my ( $self, $self_why ) = $verify->( [$leaf_fp] );
    return ( undef, $self_why ) if not defined $self;

    my $name   = $self->{'name'};
    my $result = sub {
        my (%r) = @_;
        return (
            {   'verdict'      => $r{'verdict'},
                'fp'           => $leaf_fp,
                'name'         => $r{'name'}  // $name,
                'since'        => $r{'since'} // 0,
                'write'        => $r{'write'} // 'none',
                'anchor'       => $r{'anchor'},
                'owner'        => $r{'owner'}        ? 1 : 0,
                'name_differs' => $r{'name_differs'} ? 1 : 0,
            },
            undef
        );
    };

    ## an owner pin covers the chain ? -> ( owner anchor, since ) or () ;
    ## since = not_before of the statement certifying the leaf's issuer
    my $by_owner = sub {
        return () if not @owner;
        my ($v) = $verify->( [@owner] );
        return () if not defined $v;
        return () if not exists $is_owner{ $v->{'anchor'} };
        my $cert
            = $v->{'depth'} >= 2
            ? eval { parse_delegation( $chain->[-2] ) }
            : $leaf;
        return () if not defined $cert;
        return ( $v->{'anchor'}, $cert->{'not_before'} );
    };

    if ( defined $host_pin ) {
        my $pinned_since = $host_pin->{'since'} // 0;
        my ($by_host) = $verify->( [ $host_pin->{'fp'} ] );
        if ( defined $by_host ) {
            my $pinned_name = $host_pin->{'name'};
            return $result->(
                'verdict' => 'PIN_VALID',
                'anchor'  => $host_pin->{'fp'},
                'since'   => $pinned_since,
                'write'   => 'replace',
            ) if not defined $pinned_name;    ## a step 1 pin gains its name
            return $result->(
                'verdict'      => 'PIN_VALID',
                'anchor'       => $host_pin->{'fp'},
                'name'         => $pinned_name,
                'since'        => $pinned_since,
                'name_differs' => $pinned_name ne $name,
            );
        }
        my ( $anchor, $since ) = $by_owner->();
        return $result->(
            'verdict' => 'PIN_ROTATED',
            'anchor'  => $anchor,
            'since'   => $since,
            'write'   => 'replace',
            'owner'   => 1,
            )
            if defined $anchor
            and defined $host_pin->{'name'}
            and $host_pin->{'name'} eq $name
            and $since > $pinned_since;
        return $result->(
            'verdict' => 'PIN_MISMATCH',
            'since'   => $pinned_since,
        );
    }

    my ( $anchor, $since ) = $by_owner->();
    return $result->(
        'verdict' => 'PIN_NEW',
        'anchor'  => $anchor,
        'since'   => $since,
        'write'   => 'new',
        'owner'   => 1,
    ) if defined $anchor;
    return $result->( 'verdict' => 'PIN_UNPINNED' ) if $strict;
    return $result->(
        'verdict' => 'PIN_NEW',
        'anchor'  => $leaf_fp,
        'write'   => 'new',
    );
}

## one-hop verify [ anchor = the issuer, scope '*' ] of a delegation for the
## announced S at time now -> ( { key id, name }, undef ) or ( undef, reason )
## -- a 1 statement verify_chain with the legacy reason strings.  the pin
## compare is the CALLER's step, after this
sub verify_delegation {
    my ( $wire, $s_pub, $now ) = @_;

    my $dlg = eval { parse_delegation($wire) };
    if ( not defined $dlg ) {
        ( my $why = $@ || 'unparsable' ) =~ s{\s+\z}{};
        return ( undef, "statement $why" );
    }
    my ( $verified, $reason )
        = verify_chain( [$wire], [ key_id( $dlg->{'issuer_pub'} ) ],
        $s_pub, $now );
    return ( $verified, undef ) if defined $verified;

    return ( undef, legacy_reason($reason) );
}

## the legacy one-hop wording [ the self-test \ p-7-r see these ] for a
## 'statement 1 : ..' reason ; any other reason is kept as is
sub legacy_reason {
    my ($reason) = @_;
    my %legacy = (
        'subject not 32 bytes' => 'subject is not the announced server key',
        'signature not valid'  => 'bad signature',
        'not_after before not_before' => 'not_before after not_after',
        'not yet valid'               => 'not yet valid',
        'expired'                     => 'expired',
        'subject mismatch'     => 'subject is not the announced server key',
        'name not valid'       => 'name not printable',
        'leaf scope not empty' => 'subject scope not empty',
        'scope pattern not valid' => 'subject scope not valid',
    );
    if ( $reason =~ s{\Astatement 1 : }{} ) {
        $reason = $legacy{$reason} // "statement $reason";
    }
    return $reason;
}

## the chain field [ select reply 4th field : b32 statements, '.' between,
## LEAF FIRST ] -> RAW wires, anchor-most first ; dies with a reason -- the
## twin of src/trust.chain 'split' [ same limits, same order flip ]
sub chain_split {
    my ($field) = @_;
    die "chain missing\n" unless defined $field and length $field;
    die "chain too long\n" if length($field) > DLG_B32_MAX;
    die "chain not b32\n" unless $field =~ m|\A[A-Z2-7.]+\z|;
    die "chain has an empty statement\n"
        if $field =~ m|\A\.|
        or $field =~ m|\.\z|
        or index( $field, '..' ) != -1;
    my @b32 = split m|\.|, $field;
    die "chain has too many statements\n" if @b32 > DLG_CHAIN_MAX;
    my @raw;

    foreach my $index ( 0 .. $#b32 ) {
        my $bin = eval { decode_b32r( $b32[$index] ) };
        die sprintf( "chain statement %d not b32\n", $index + 1 )
            unless defined $bin
            and length $bin
            and encode_b32r($bin) eq $b32[$index];
        push @raw, $bin;
    }
    return [ reverse @raw ];
}

## host pin file [ TRUST-CHAIN-STEP2.md 'pins' ] : line 1 the 77 char
## host-root key id, line 2 [ optional, a step 1 pin has none ] the leaf name,
## line 3 [ optional ] since [ forward-only rotation ] -> undef [ no pin ] or
## { fp, name, since } ; a file that exists but is  unreadable \ empty \ not a
## key id -> die [ never re-pinned ]
sub pin_read {
    my ($pin_file) = @_;
    return undef unless -e $pin_file or -l $pin_file;
    open my $fh, '<', $pin_file
        or die "pin file unreadable : $pin_file : $!\n";
    my $pinned = <$fh>;
    my $name   = <$fh>;
    my $since  = <$fh>;
    close $fh;
    die "pin file empty : $pin_file\n" unless defined $pinned;
    s{\s+\z}{} foreach grep {defined} $pinned, $name, $since;
    die "pin file holds a server key, not a host-root key id [ pre host-root "
        . "pin ; verify the host-root out of band, then remove it ] : "
        . "$pin_file\n"
        if $pinned =~ m|^[A-Z2-7]{52}\z|;
    die "pin file corrupt : $pin_file\n"
        unless $pinned =~ m|^[A-Z2-7]{77}\z|;
    $name = undef if defined $name and not length $name;
    die "pin file corrupt : $pin_file\n"
        if defined $name
        and $name !~ m|\A[A-Za-z0-9][A-Za-z0-9._-]{0,254}\z|;
    $since = 0 if not defined $since or not length $since;
    die "pin file corrupt : $pin_file\n" unless $since =~ m|\A[0-9]{1,10}\z|;
    return { 'fp' => $pinned, 'name' => $name, 'since' => 0 + $since };
}

## write the host pin : 'new' [ O_EXCL ] or 'replace' [ temp + rename ], 0600,
## content '<fp>\n<name>\n<since>\n' ; dies on failure
sub pin_store {
    my ( $pin_dir, $pin_file, $fp, $name, $since, $how ) = @_;
    make_path( $pin_dir, { mode => 0700 } )  unless -d $pin_dir;
    die "cannot create pin dir : $pin_dir\n" unless -d $pin_dir;
    my $target = $how eq 'new' ? $pin_file : "$pin_file.$$.tmp";
    sysopen( my $fh, $target, O_WRONLY | O_CREAT | O_EXCL, 0600 )
        or die "cannot create pin file : $target : $!\n";
    print {$fh} "$fp\n$name\n$since\n" or die "pin write failed : $!\n";
    close $fh                          or die "pin write failed : $!\n";
    if ( $how ne 'new' and not rename( $target, $pin_file ) ) {
        my $why = $!;
        unlink $target;
        die "cannot replace pin file : $pin_file : $why\n";
    }
    return 1;
}

## owner pins : <dir>/*.public, line 1 a 77 char key id ; symlinks \ malformed
## entries skipped [ never trusted ]. written only by an explicit command,
## never by this helper
sub owner_pins {
    my ($owner_dir) = @_;
    my @owner;
    opendir( my $dh, $owner_dir ) or return [];
    foreach my $entry ( sort readdir $dh ) {
        next unless $entry =~ m|\A[^/]+\.public\z|;
        my $path = "$owner_dir/$entry";
        next if -l $path           or not -f $path;
        open( my $fh, '<', $path ) or next;
        my $line = <$fh> // '';
        close $fh;
        $line =~ s{\s+\z}{};
        push @owner, $line if $line =~ m|\A[A-Z2-7]{77}\z|;
    }
    closedir $dh;
    return \@owner;
}

## local distrust list : one key id per line, '#' comments ; present but
## unreadable \ malformed -> die [ fail closed ]
sub distrust_list {
    my ($path) = @_;
    return [] unless -e $path  or -l $path;
    open( my $fh, '<', $path ) or die "distrust file unreadable : $path\n";
    my @fp;
    while ( my $line = <$fh> ) {
        $line =~ s{#.*}{};
        $line =~ s{\A\s+|\s+\z}{}g;
        next unless length $line;
        die "distrust file corrupt : $path\n"
            unless $line =~ m|\A[A-Z2-7]{77}\z|;
        push @fp, $line;
    }
    close $fh;
    return \@fp;
}

##[ Argument checks [ fail closed ] ]#########################################

sub arg_b32 {
    my ( $value, $bytes, $what ) = @_;
    my $chars = int( ( $bytes * 8 + 4 ) / 5 );
    die "$what : expected $chars b32 chars\n"
        unless defined $value and $value =~ m|^[A-Z2-7]{$chars}\z|;
    my $bin = decode_b32r($value);
    die "$what : b32 decode failed\n"
        unless defined $bin and length($bin) == $bytes;
    die "$what : non-canonical b32\n" unless encode_b32r($bin) eq $value;
    return $bin;
}

## variable length b32 [ 1 .. max chars ], canonical, no padding
sub arg_b32_var {
    my ( $value, $max, $what ) = @_;
    die "$what : expected 1 .. $max b32 chars\n"
        unless defined $value and $value =~ m|^[A-Z2-7]{1,$max}\z|;
    die "$what : invalid b32 length\n"
        unless grep { length($value) % 8 == $ARG } ( 0, 2, 4, 5, 7 );
    my $bin = decode_b32r($value);
    die "$what : b32 decode failed\n"
        unless defined $bin and length($bin);
    die "$what : non-canonical b32\n" unless encode_b32r($bin) eq $value;
    return $bin;
}

sub arg_username {
    my ($value) = @_;
    die "username : invalid\n"
        unless defined $value
        and $value =~ m|^[A-Za-z0-9_][A-Za-z0-9._-]{0,63}\z|;
    return $value;
}

sub arg_nonce_sid {
    my ($value) = @_;
    die "nonce_sid : expected 1 .. 4294967295\n"
        unless defined $value
        and $value =~ m|^[1-9][0-9]{0,9}\z|
        and $value <= 4294967295;
    return 0 + $value;
}

sub arg_encoding {
    my ($value) = @_;
    die "encoding : invalid\n"
        unless defined $value and $value =~ m|^[A-Za-z0-9._-]{1,64}\z|;
    return $value;
}

## the binding transcript from the seven public argv fields
sub transcript_from_args {
    my ($username,  $nonce_b32, $s_pub_b32, $s_eph_b32,
        $c_eph_b32, $nonce_sid, $encoding
    ) = @_;
    $username = arg_username($username);
    return (
        $username,
        bind_transcript(
            arg_b32( $nonce_b32, 32, 'server_nonce' ),
            arg_b32( $s_pub_b32, 32, 's_pub' ),
            arg_b32( $s_eph_b32, 32, 'server_eph' ),
            arg_b32( $c_eph_b32, 32, 'client_eph' ),
            arg_nonce_sid($nonce_sid),
            arg_encoding($encoding),
            $username
        )
    );
}

##[ Operations ]##############################################################

sub op_gen_auth {
    my ( $username, $nonce_b32, $s_pub_b32 ) = @_;

    die "Usage: p7-auth-keypair-helper.pl gen-auth "
        . "<username> <server_nonce> <s_pub>\n"
        unless @_ == 3;
    $username = arg_username($username);
    my $server_nonce = arg_b32( $nonce_b32, 32, 'server_nonce' );
    my $s_pub        = arg_b32( $s_pub_b32, 32, 's_pub' );

    my ( $ed25519_secret_bin, $ed25519_pubkey_bin, $ed25519_private_bin )
        = load_client_key($username);

    # Generate ephemeral C25519 keypair for session (new random secret)
    my $prng              = Crypt::PRNG::Fortuna->new();
    my $c25519_secret     = $prng->bytes(32);
    my $c25519_pubkey_bin = curve25519_public_key($c25519_secret);
    die "Failed to generate C25519 keypair\n"
        unless defined $c25519_pubkey_bin && length($c25519_pubkey_bin) == 32;

    # Lock C25519 secret in memory
    IO::AIO::aio_mlock( $c25519_secret, 0, 32 );

    my $c25519_pubkey_b32 = encode_b32r($c25519_pubkey_bin);

    ## v2 auth_sig : binds the server nonce, the announced S_pub, the session
    ## pubkey and the username [ no replay, no other server ]
    my $ed25519_sig_bin = Crypt::Ed25519::sign(
        auth_message( $server_nonce, $s_pub, $c25519_pubkey_bin, $username ),
        $ed25519_pubkey_bin,    # signer's public key (32 bytes)
        $ed25519_private_bin    # signer's private key (64 bytes)
    );
    die "Failed to generate Ed25519 signature\n"
        unless defined $ed25519_sig_bin && length($ed25519_sig_bin) == 64;
    my $ed25519_sig_b32 = encode_b32r($ed25519_sig_bin);

    # Output credentials (one per line)
    print "$c25519_pubkey_b32\n";
    print "$ed25519_sig_b32\n";

    # Securely wipe sensitive key material from memory before exit
    # Overwrite with random data to prevent key recovery from memory dumps
    erase_buffer_secure( \$ed25519_secret_bin );
    erase_buffer_secure( \$ed25519_private_bin );
    erase_buffer_secure( \$c25519_secret );

    exit 0;
}

## the client identity key C [ <user>.base ] : ( seed, pub, private )
sub load_client_key {
    my ($username) = @_;

    die "HOME not set\n" unless defined $ENV{HOME} and length $ENV{HOME};
    my $key_dir = "$ENV{HOME}/.n/user-keys";
    die "Key directory not found: $key_dir\n" unless -d $key_dir;

    # Load user's Ed25519 secret key
    my $ed25519_secret_file = "$key_dir/$username.base.secret";
    die "Ed25519 secret not " . "found: $ed25519_secret_file\n"
        unless -f $ed25519_secret_file;

    open my $fh, '<', $ed25519_secret_file
        or die "Cannot read " . "secret key: $!\n";
    my $ed25519_secret_b32 = <$fh>;
    close $fh;
    die "Empty secret key file\n" unless defined $ed25519_secret_b32;
    chomp $ed25519_secret_b32;

    # Decode base32 secret to binary
    my $ed25519_secret_bin = decode_b32r($ed25519_secret_b32);
    erase_buffer_secure( \$ed25519_secret_b32 );
    die "Failed to decode Ed25519 secret\n"
        unless defined $ed25519_secret_bin
        && length($ed25519_secret_bin) >= 34;

    # Strip the 2-byte format prefix
    substr( $ed25519_secret_bin, 0, 2, '' );
    die "Failed to strip " . "format prefix\n"
        unless length($ed25519_secret_bin) == 32;

   # Generate Ed25519 keypair from secret (same as load_keys_from_secret does)
    my ( $ed25519_pubkey_bin, $ed25519_private_bin )
        = Crypt::Ed25519::generate_keypair($ed25519_secret_bin);
    die "Failed to generate Ed25519 keypair from secret\n"
        unless defined $ed25519_pubkey_bin && defined $ed25519_private_bin;
    die "Invalid public " . "key length\n"
        unless length($ed25519_pubkey_bin) == 32;
    die "Invalid private " . "key length\n"
        unless length($ed25519_private_bin) == 64;

    # Lock Ed25519 secret and private key in memory to prevent swapping
    IO::AIO::aio_mlock( $ed25519_secret_bin,  0, 32 );
    IO::AIO::aio_mlock( $ed25519_private_bin, 0, 64 );

    return ( $ed25519_secret_bin, $ed25519_pubkey_bin, $ed25519_private_bin );
}

## host-root pin [ HOST-ROOT-DELEGATION.md ] :
## ~/.n/remote-keys/servers/<host>_<port>.public holds the host-root
## KEY ID [ 77 b32 chars ]. the delegation [ select reply field 4 ] is
## verified FIRST [ sig under its issuer pub, not_before <= now <=
## not_after, subject == s_pub, name \ scope ] -- only then the pin :
##   PIN_VALID <fp> <name>     exit 0 [ incl. a rotated S the pinned
##                                      host-root delegates ]
##   PIN_NEW <fp> <name>       exit 0 [ first contact, pinned now ]
##   PIN_UNPINNED <fp> <name>  exit 5 [ strict, nothing written ]
##   PIN_MISMATCH <fp> <name>  exit 6 [ other host-root, never re-pinned ]
##   DELEGATION_INVALID <why>  exit 7 [ nothing read \ written ]
##   PIN_ERROR <why>           exit 8 [ pin file present but unreadable \
##                                      corrupt \ an old S_pub pin ;
##                                      never re-pinned ]
sub op_check_pin {
    my ( $host, $port, $s_pub_b32, $chain_field, $mode ) = @_;

    die "Usage: p7-auth-keypair-helper.pl check-pin <host> "
        . "<port> <s_pub> <delegation chain> [strict]\n"
        unless @_ == 4
        or ( @_ == 5 and defined $mode and $mode eq 'strict' );
    die "host : invalid\n"
        unless defined $host
        and $host =~ m|^[A-Za-z0-9.:-]{1,253}\z|
        and $host =~ m{[A-Za-z0-9]};
    die "port : invalid\n"
        unless defined $port
        and $port =~ m|^[1-9][0-9]{0,4}\z|
        and $port <= 65535;
    my $s_pub = arg_b32( $s_pub_b32, 32, 's_pub' );
    my $chain = eval { chain_split($chain_field) };
    if ( not defined $chain ) {
        ( my $why = $@ || 'not valid' ) =~ s{\s+\z}{};
        print "DELEGATION_INVALID $why\n";
        exit 7;
    }
    die "HOME not set\n" unless defined $ENV{HOME} and length $ENV{HOME};

    ## same file name as auth.client.server_pin.check : lowercase, : -> _
    ( my $host_safe = lc $host ) =~ tr/:/_/;
    my $keys_dir = "$ENV{HOME}/.n/remote-keys";
    my $pin_dir  = "$keys_dir/servers";
    my $pin_file = "$pin_dir/${host_safe}_$port.public";

    my ( $host_pin, $distrust );
    my $loaded = eval {
        $host_pin = pin_read($pin_file);
        $distrust = distrust_list("$keys_dir/distrust");
        1;
    };
    if ( not $loaded ) {
        print STDERR $@;
        print 'PIN_ERROR '
            . (
              $@ =~ m{holds a server key} ? 'old server key pin'
            : $@ =~ m{distrust} ? 'distrust file ' . 'unreadable or invalid'
            :                     'pin file unreadable or invalid'
            ) . "\n";
        exit 8;
    }

    my ( $decided, $why ) = pin_decide(
        {   'chain'    => $chain,
            'subject'  => $s_pub,
            'now'      => time(),
            'host_pin' => $host_pin,
            'owners'   => owner_pins("$keys_dir/owners"),
            'distrust' => $distrust,
            'strict'   => defined $mode ? 1 : 0,
        }
    );
    if ( not defined $decided ) {
        print 'DELEGATION_INVALID ' . legacy_reason($why) . "\n";
        exit 7;
    }
    my ( $verdict, $fp, $name ) = @{$decided}{qw| verdict fp name |};

    ## the decider says what to write [ none \ new \ replace ], nothing else
    my $stored = eval {
        pin_store( $pin_dir, $pin_file, $fp, $name, $decided->{'since'},
            $decided->{'write'} )
            if $decided->{'write'} ne 'none';
        1;
    };
    print STDERR ": pinned name kept [ $name ] -- the "
        . "server now names itself differently\n"
        if $decided->{'name_differs'};
    if ( not $stored ) {
        print STDERR $@;
        print "PIN_ERROR pin file not written\n";
        exit 8;
    }

    ## PIN_NEW from an owner pin is reported as PIN_OWNER [ the C client says
    ## so ] -- both are a new host pin
    $verdict = 'PIN_OWNER' if $verdict eq 'PIN_NEW' and $decided->{'owner'};
    print "$verdict $fp $name\n";
    exit(
        {   'PIN_VALID'    => 0,
            'PIN_NEW'      => 0,
            'PIN_OWNER'    => 0,
            'PIN_ROTATED'  => 0,
            'PIN_UNPINNED' => 5,
            'PIN_MISMATCH' => 6,
        }->{$verdict}
    );
}

## client_bind_sig b32 for the transcript given on argv [ public fields ]
sub op_gen_bind {
    die "Usage: p7-auth-keypair-helper.pl gen-bind <username> <server_nonce> "
        . "<s_pub> <server_eph> <client_eph> <nonce_sid> <encoding>\n"
        unless @_ == 7;
    my ( $username, $transcript ) = transcript_from_args(@_);

    my ( $secret, $pub, $private ) = load_client_key($username);
    my $sig = Crypt::Ed25519::sign( bind_message( 'client', $transcript ),
        $pub, $private );
    erase_buffer_secure( \$secret );
    erase_buffer_secure( \$private );

    die "Failed to generate bind signature\n"
        unless defined $sig and length($sig) == 64;
    print encode_b32r($sig) . "\n";
    exit 0;
}

## server_bind_sig check against the [ pinned ] s_pub : BIND_OK exit 0,
## anything else BIND_FAIL exit 1 [ argument errors die, exit != 0 ]
sub op_verify_bind {
    die "Usage: p7-auth-keypair-helper.pl verify-bind <server_bind_sig> "
        . "<username> <server_nonce> <s_pub> <server_eph> <client_eph> "
        . "<nonce_sid> <encoding>\n"
        unless @_ == 8;
    my ( $sig_b32, @fields ) = @_;
    my $sig = arg_b32( $sig_b32, 64, 'server_bind_sig' );
    my ( undef, $transcript ) = transcript_from_args(@fields);
    my $s_pub = arg_b32( $fields[2], 32, 's_pub' );

    if ( verify_server_bind( $sig, $s_pub, $transcript ) ) {
        print "BIND_OK\n";
        exit 0;
    }
    print "BIND_FAIL\n";
    exit 1;
}

## spec test vector [ AUTH-LINK-BINDING.md ] through the same builders, plus
## negative cases ; exit 1 on any mismatch
sub op_self_test {
    my %want = (
        'c_pub'    => 'RKEOHXLUBHYZL7KS3MWTZOS5OLFGOCN7DWKBEG7TOSEADNAPN5OA',
        's_pub'    => 'QE4XODVIPULV6VVDKRTMGTD6ZTFY3CURWTXDPIS56YHVXD6JWOKA',
        'auth_msg' => '703720617574682d6b657970616972207632001111111111111111'
            . '111111111111111111111111111111111111111111111111'
            . '8139770ea87d175f56a35466c34c7ecccb8d8a91b4ee37a2'
            . '5df60f5b8fc9b39422222222222222222222222222222222'
            . '222222222222222222222222222222220009746573742d75'
            . '736572',
        'auth_sig' => 'NJHBPUDRFYSLYCCZ57DJN5OVNOIWSNWGU7QZZJU26ZT445Q3PBQOUC'
            . 'UQS36W5KFEFYIBSDSY4XZD6FCWC6TETBCBSQWI7ICVRMTCUC' . 'I',
        'transcript' => '1111111111111111111111111111111111111111111111111111'
            . '1111111111118139770ea87d175f56a35466c34c7ecccb'
            . '8d8a91b4ee37a25df60f5b8fc9b3943333333333333333'
            . '3333333333333333333333333333333333333333333333'
            . '3344444444444444444444444444444444444444444444'
            . '444444444444444444441234567800046e6f6e65000974'
            . '6573742d75736572',
        'client_bind_sig' =>
            'ANRNMKHTKZ6QDI2EJOUZYXZSNKLQQY3TF57NXSNREYEX3PDVL6K'
            . 'EVQ2LLLTS3V26U4GSKYVC6XCFO2U7BU5JQXEGLHCGPKDJ6HLYSDA',
        'server_bind_sig' =>
            'KLXXZEZPHTKESLFK7NLYD4VZBXWEEP3WQG4T62UKGIFHNUOUW3A'
            . '7ZEVM4BIFC5TQUW3DJJG37XQYJRZFSVXWHPYZZYJ5RWJDVPKHUDA',
    );

    my @failed;
    my $check = sub {
        my ( $name, $got, $expected ) = @_;
        if ( defined $got and $got eq $expected ) {
            print "ok   $name\n";
        } else {
            print "FAIL $name\n  got  "
                . ( $got // 'undef' )
                . "\n  want $expected\n";
            push @failed, $name;
        }
    };

    ## throwaway test keys [ fixed seeds, never real ]
    my ( $c_pub, $c_private )
        = Crypt::Ed25519::generate_keypair( "\x01" x 32 );
    my ( $s_pub, $s_private )
        = Crypt::Ed25519::generate_keypair( "\x02" x 32 );
    $check->( 'c_pub', encode_b32r($c_pub), $want{'c_pub'} );
    $check->( 's_pub', encode_b32r($s_pub), $want{'s_pub'} );

    my $auth_msg
        = auth_message( "\x11" x 32, $s_pub, "\x22" x 32, 'test-user' );
    $check->( 'auth_msg hex', unpack( 'H*', $auth_msg ), $want{'auth_msg'} );
    $check->(
        'auth_sig',
        encode_b32r( Crypt::Ed25519::sign( $auth_msg, $c_pub, $c_private ) ),
        $want{'auth_sig'}
    );

    ## transcript through the argv path [ covers argument decoding too ]
    my ( undef, $transcript ) = transcript_from_args(
        'test-user',                encode_b32r( "\x11" x 32 ),
        encode_b32r($s_pub),        encode_b32r( "\x33" x 32 ),
        encode_b32r( "\x44" x 32 ), '305419896',
        'none'
    );
    $check->(
        'transcript hex',
        unpack( 'H*', $transcript ),
        $want{'transcript'}
    );

    my $client_sig
        = Crypt::Ed25519::sign( bind_message( 'client', $transcript ),
        $c_pub, $c_private );
    my $server_sig
        = Crypt::Ed25519::sign( bind_message( 'server', $transcript ),
        $s_pub, $s_private );
    $check->(
        'client_bind_sig',
        encode_b32r($client_sig),
        $want{'client_bind_sig'}
    );
    $check->(
        'server_bind_sig',
        encode_b32r($server_sig),
        $want{'server_bind_sig'}
    );

    ## verify path [ the same sub verify-bind uses ]
    my $server_sig_vec = arg_b32( $want{'server_bind_sig'}, 64, 'sig' );
    $check->(
        'verify server_bind_sig',
        verify_server_bind( $server_sig_vec, $s_pub, $transcript ), 1
    );

    my $flipped = $transcript;
    substr( $flipped, 40, 1 ) ^= "\x01";
    $check->(
        'reject flipped transcript byte',
        verify_server_bind( $server_sig_vec, $s_pub, $flipped ), 0
    );
    my $bad_sig = $server_sig_vec;
    substr( $bad_sig, 7, 1 ) ^= "\x80";
    $check->(
        'reject flipped sig byte',
        verify_server_bind( $bad_sig, $s_pub, $transcript ), 0
    );
    $check->(
        'reject client sig as server sig',
        verify_server_bind( $client_sig, $c_pub, $transcript ), 0
    );
    $check->(
        'reject server sig under wrong key',
        verify_server_bind( $server_sig_vec, $c_pub, $transcript ), 0
    );

    ## argument checks fail closed
    my $refused = sub {
        my ($code) = @_;
        return eval { $code->(); 1 } ? 0 : 1;
    };
    $check->(
        'refuse nonce_sid ' . '0',
        $refused->( sub { arg_nonce_sid('0') } ), 1
    );
    $check->(
        'refuse nonce_sid 2**32',
        $refused->( sub { arg_nonce_sid('4294967296') } ), 1
    );
    $check->(
        'refuse short b32',
        $refused->( sub { arg_b32( substr( $want{'s_pub'}, 1 ), 32, 'x' ) } ),
        1
    );
    $check->(
        'refuse b32 shell chars',
        $refused->( sub { arg_b32( '$(id)' . ( 'A' x 47 ), 32, 'x' ) } ), 1
    );
    $check->(
        'refuse username slash',
        $refused->( sub { arg_username('../x') } ), 1
    );

    delegation_self_test( $check, $refused, $s_pub );

    if (@failed) {
        print "self-test FAILED : " . join( ', ', @failed ) . "\n";
        exit 1;
    }
    print "self-test ok\n";
    exit 0;
}

## host-root delegation : the fixed vector, every refusal, the pin store [
## temp dir ] and the real check-pin verb as a subprocess
sub delegation_self_test {
    my ( $check, $refused, $s_pub ) = @_;

    ## SELF-BUILT vector [ lane 3 ; to be replaced by the spec's TEST VECTOR
    ## once lane 1 publishes it ] : host-root = seed 32 x \x03, S = seed 32 x
    ## \x02 [ the AUTH-LINK-BINDING S ], name test-host.cube, not_before
    ## 1700000000, not_after 1702592000 [ + 30 d ], scope ''
    my %want = (
        'root_pub'  => '5VESRRRI2HBMN2XJAM4JAWMVMEUVSJZ2LRR7SNRWYFDBJLEHG7IQ',
        'statement' => '70372064656c65676174696f6e20763100ed4928c628d1c2c6eae'
            . '90338905995612959273a5c63f93636c14614ac8737d181'
            . '39770ea87d175f56a35466c34c7ecccb8d8a91b4ee37a25'
            . 'df60f5b8fc9b394000e746573742d686f73742e63756265'
            . '6553f100657b7e000000',
        'sig' => 'LAL3UIQD4LJVCGNJWXL3TO7DZUD2PCAJ43B2XXPTNWQAQZDDX7G'
            . 'PYH3DYOFIJZUJEUDB2MKQSBZ4HSXBGCQX4GM5LOA4IOSEBMPFQAQ',
        'key_id' => 'ZF3ZY24EH66GU56YWPU2R2ZOXZLRVEUQJGHM3A'
            . 'WUQWVUNEJIYFOXRWF4XUSHAAXSUFOXWG2JGKC7G',
    );
    my ( $nb, $na ) = ( 1700000000, 1702592000 );
    my $now = 1701000000;

    my ( $root_pub, $root_priv )
        = Crypt::Ed25519::generate_keypair( "\x03" x 32 );
    my ( $rot_pub, $rot_priv )
        = Crypt::Ed25519::generate_keypair( "\x04" x 32 );
    my ( $foreign_pub, $foreign_priv )
        = Crypt::Ed25519::generate_keypair( "\x05" x 32 );
    $check->( 'host-root pub', encode_b32r($root_pub), $want{'root_pub'} );

    my $wire = sub {
        my ( $ipub, $ipriv, $subject, $from, $to, %opt ) = @_;
        my $st
            = delegation_statement( $ipub, $subject,
            $opt{'name'} // 'test-host.cube',
            $from, $to, $opt{'scope'} // '' );
        return $st . Crypt::Ed25519::sign( $st, $ipub, $ipriv );
    };
    my $statement = delegation_statement( $root_pub, $s_pub,
        'test-host.cube', $nb, $na, '' );
    $check->(
        'delegation statement hex',
        unpack( 'H*', $statement ),
        $want{'statement'}
    );
    $check->(
        'delegation sig',
        encode_b32r(
            Crypt::Ed25519::sign( $statement, $root_pub, $root_priv )
        ),
        $want{'sig'}
    );
    $check->( 'host-root key id', key_id($root_pub), $want{'key_id'} );

    ## the vector through the wire path [ b32 argv check + parse + verify ]
    my $vec_wire
        = arg_b32_var(
        encode_b32r( $statement . arg_b32( $want{'sig'}, 64, 'sig' ) ),
        DLG_B32_MAX, 'delegation' );
    my $verdict = sub {
        my ( $dlg, $subject, $at ) = @_;
        my ( $ok, $why ) = verify_delegation( $dlg, $subject, $at );
        return $ok ? "ok $ok->{'key_id'} $ok->{'name'}" : $why;
    };
    my $ok_line = "ok $want{'key_id'} test-host.cube";
    $check->(
        'delegation ok',
        $verdict->( $vec_wire, $s_pub, $now ), $ok_line
    );
    $check->(
        'delegation ok at not_before',
        $verdict->( $vec_wire, $s_pub, $nb ), $ok_line
    );
    $check->(
        'delegation ok at not_after',
        $verdict->( $vec_wire, $s_pub, $na ), $ok_line
    );
    $check->(
        'refuse expired',
        $verdict->( $vec_wire, $s_pub, $na + 1 ), 'expired'
    );
    $check->(
        'refuse not yet valid',
        $verdict->( $vec_wire, $s_pub, $nb - 1 ),
        'not yet valid'
    );
    $check->(
        'refuse wrong subject',
        $verdict->( $vec_wire, $rot_pub, $now ),
        'subject is not the announced server key'
    );

    my $bad_sig = $vec_wire;
    substr( $bad_sig, -20, 1 ) ^= "\x01";
    $check->(
        'refuse bad sig',
        $verdict->( $bad_sig, $s_pub, $now ),
        'bad signature'
    );
    my $bad_body = $vec_wire;
    substr( $bad_body, 90, 1 ) ^= "\x01";    ## inside the name
    $check->(
        'refuse altered statement',
        $verdict->( $bad_body, $s_pub, $now ),
        'bad signature'
    );
    $check->(
        'refuse sig by another key',
        $verdict->(
            substr( $vec_wire, 0, -64 )
                . Crypt::Ed25519::sign(
                $statement, $foreign_pub, $foreign_priv
                ),
            $s_pub, $now
        ),
        'bad signature'
    );

    ## structure refusals [ each correctly signed, so only the parser \ field
    ## rule can refuse ]
    my $signed = sub {
        my ( $st, $ipub, $ipriv ) = @_;
        return $st . Crypt::Ed25519::sign( $st, $ipub, $ipriv );
    };
    ( my $other_label = $statement )
        =~ s{^p7 delegation v1}{p7 delegation v2};
    $check->(
        'refuse wrong label',
        $verdict->(
            $signed->( $other_label, $root_pub, $root_priv ), $s_pub,
            $now
        ),
        'statement wrong label'
    );
    $check->(
        'refuse trailing byte',
        $verdict->(
            $signed->( $statement . "\0", $root_pub, $root_priv ),
            $s_pub, $now
        ),
        'statement trailing bytes in statement'
    );
    $check->(
        'refuse truncated statement',
        $verdict->(
            $signed->( substr( $statement, 0, -1 ), $root_pub, $root_priv ),
            $s_pub, $now
        ),
        'statement truncated statement'
    );
    $check->(
        'refuse too short',
        $verdict->( 'x' x 100, $s_pub, $now ),
        'statement too short'
    );
    $check->(
        'refuse not_before after not_after',
        $verdict->(
            $wire->( $root_pub, $root_priv, $s_pub, $na, $nb ),
            $s_pub, $now
        ),
        'not_before after not_after'
    );
    $check->(
        'refuse non-empty subject scope',
        $verdict->(
            $wire->(
                $root_pub, $root_priv, $s_pub, $nb, $na,
                'scope' => 'test-host.cube'
            ),
            $s_pub, $now
        ),
        'subject scope not empty'
    );
    ## scope '*' is never issued [ TRUST-CHAIN-STEP2.md ] : refused at the
    ## pattern, before the leaf check
    $check->(
        'refuse subject scope *',
        $verdict->(
            $wire->(
                $root_pub, $root_priv, $s_pub, $nb, $na, 'scope' => '*'
            ),
            $s_pub, $now
        ),
        'subject scope not valid'
    );
    $check->(
        'refuse unprintable name',
        $verdict->(
            $wire->(
                $root_pub, $root_priv, $s_pub, $nb, $na,
                'name' => "evil\e[2Jhost.cube"
            ),
            $s_pub, $now
        ),
        'name not printable'
    );
    $check->(
        'refuse delegation b32 too long',
        $refused->(
            sub { arg_b32_var( 'A' x ( DLG_B32_MAX + 1 ), DLG_B32_MAX, 'x' ) }
        ),
        1
    );
    $check->(
        'refuse delegation b32 bad length',
        $refused->( sub { arg_b32_var( 'AAA', DLG_B32_MAX, 'x' ) } ), 1
    );

    ## the shared chain vectors [ TRUST-CHAIN-STEP2.md ] : the SAME cases
    ## bin/test-scripts/test-host-root-delegation.pl runs through the
    ## src/trust.verify module [ wires b32 there, raw here ] -- both
    ## implementations must give the same accept \ refuse \ reason
    {
        my $vec_root
            = abs_path( File::Spec->catdir( $RealBin, File::Spec->updir ) );
        my $vec_file = File::Spec->catfile( $vec_root, 'bin',
            'test-scripts', 'trust-chain-vectors.pl' );
        my $build = do $vec_file;
        die "cannot load $vec_file : $@ $!\n" if ref $build ne 'CODE';
        foreach my $case ( $build->()->@* ) {
            my ( $r, $why ) = verify_chain(
                $case->{'chain'},   $case->{'anchors'},
                $case->{'subject'}, $case->{'now'},
                $case->{'distrust'}
            );
            if ( $case->{'expect'} eq 'ok' ) {
                $check->(
                    "chain vector : $case->{'label'}",
                    (           ref $r eq 'HASH'
                            and $r->{'name'} eq $case->{'name'}
                            and $r->{'anchor'} eq $case->{'anchor'}
                            and $r->{'depth'} == $case->{'depth'}
                        )
                    ? 'accept'
                    : ( $why // 'result fields mismatch' ),
                    'accept'
                );
            } elsif ( $case->{'expect'} eq 'refuse' ) {
                $check->(
                    "chain vector : $case->{'label'}",
                    defined $r ? 'accepted' : 'refuse', 'refuse'
                );
            } else {
                $check->(
                    "chain vector : $case->{'label'}",
                    defined $r ? 'accepted' : $why,
                    $case->{'expect'}
                );
            }
        }
    }

    ## the shared pin verdict vectors [ the SAME cases as src/trust.
    ## pin_decide in test-host-root-delegation.pl ]
    {
        my $vec_root
            = abs_path( File::Spec->catdir( $RealBin, File::Spec->updir ) );
        my $vec_file = File::Spec->catfile( $vec_root, 'bin',
            'test-scripts', 'trust-pin-vectors.pl' );
        my $build = do $vec_file;
        die "cannot load $vec_file : $@ $!\n" if ref $build ne 'CODE';
        foreach my $case ( $build->()->@* ) {
            my ( $r, $why ) = pin_decide(
                {   map { $ARG => $case->{$ARG} }
                        qw| chain subject now host_pin owners distrust strict |
                }
            );
            my $got
                = defined $r
                ? join( ' ',
                map { $r->{$ARG} // '-' }
                    qw| verdict fp name owner since write | )
                : $why;
            my $want
                = $case->{'expect'} =~ m|\APIN_|
                ? join( ' ',
                map { $case->{$ARG} } qw| expect fp name owner since write | )
                : $case->{'expect'};
            $check->( "pin vector : $case->{'label'}", $got, $want );
        }
    }

    ## pin store [ temp dir, never a real key dir ]
    require File::Temp;
    my $tmp      = File::Temp::tempdir( CLEANUP => 1 );
    my $pin_dir  = "$tmp/servers";
    my $pin_file = "$pin_dir/test-host_7.public";
    my $fp       = $want{'key_id'};
    my ($rot_ok)
        = verify_delegation(
        $wire->( $root_pub, $root_priv, $rot_pub, $nb, $na ),
        $rot_pub, $now );
    my ($foreign_ok)
        = verify_delegation(
        $wire->( $foreign_pub, $foreign_priv, $s_pub, $nb, $na ),
        $s_pub, $now );

    $check->( 'pin none yet', ( defined pin_read($pin_file) ? 1 : 0 ), 0 );
    pin_store( $pin_dir, $pin_file, $fp, 'test-host.cube', 0, 'new' );
    $check->(
        'pin file mode 0600',
        sprintf( '%04o', ( stat($pin_file) )[2] & 07777 ), '0600'
    );
    $check->(
        'pin read back',
        join( ' ', @{ pin_read($pin_file) }{qw| fp name |} ),
        "$fp test-host.cube"
    );
    $check->(
        'pin new refuses an existing file',
        $refused->(
            sub { pin_store( $pin_dir, $pin_file, $fp, 'x.cube', 0, 'new' ) }
        ),
        1
    );
    pin_store( $pin_dir, $pin_file, $rot_ok ? $fp : 'x',
        'other.cube', 7, 'replace' );
    $check->(
        'pin replace',
        join( ' ', @{ pin_read($pin_file) }{qw| fp name since |} ),
        "$fp other.cube 7"
    );
    open my $sfh, '>', $pin_file or die "cannot write $pin_file : $!\n";
    print {$sfh} "$fp\n";
    close $sfh;
    $check->(
        'pin step 1 [ no name line ]',
        ( pin_read($pin_file)->{'name'} // 'undef' ), 'undef'
    );
    $check->(
        'pin foreign host-root differs',
        ( $foreign_ok and $foreign_ok->{'key_id'} ne $fp ) ? 1 : 0, 1
    );

    my $old_pin = "$pin_dir/old_7.public";
    open my $ofh, '>', $old_pin or die "cannot write $old_pin : $!\n";
    print {$ofh} encode_b32r($s_pub) . "\n";
    close $ofh;
    $check->(
        'pin refuse an old S_pub pin',
        $refused->( sub { pin_read($old_pin) } ), 1
    );
    $check->(
        'chain field : empty statement',
        $refused->( sub { chain_split('AAAA..AAAA') } ), 1
    );
    $check->(
        'chain field : five statements',
        $refused->( sub { chain_split( join '.', ('AE') x 5 ) } ), 1
    );
    $check->(
        'chain field : leaf first -> anchor-most first',
        join( ',', map { unpack 'H*', $ARG } chain_split('AE.AI')->@* ),
        '02,01'
    );

    ## the real verb, as p-7-r runs it [ temp HOME, times around now ]
    my $self = abs_path(__FILE__);
    my $t    = time();
    my $verb = sub {
        my ( $port, $subject, $dlg, @strict ) = @_;
        local $ENV{HOME} = $tmp;
        my $field = join '.',
            map { encode_b32r($ARG) } ref $dlg ? $dlg->@* : $dlg;
        open( my $ph, '-|', $EXECUTABLE_NAME, $self, 'check-pin',
            'Test-Host', $port, encode_b32r($subject), $field, @strict )
            or return 'cannot run';
        my $line = <$ph> // '';
        close $ph;
        chomp $line;
        $line =~ s{ \S+ \S+\z}{}
            if $line
            =~ m{^PIN_(?:VALID|NEW|OWNER|ROTATED|UNPINNED|MISMATCH) };
        return sprintf( '%s exit %d', $line, $CHILD_ERROR >> 8 );
    };
    my $live = $wire->( $root_pub, $root_priv, $s_pub, $t - 60, $t + 3600 );
    $check->(
        'check-pin strict unpinned',
        $verb->( 9, $s_pub, $live, 'strict' ),
        'PIN_UNPINNED exit 5'
    );
    $check->(
        'check-pin first contact',
        $verb->( 9, $s_pub, $live ),
        'PIN_NEW exit 0'
    );
    $check->(
        'check-pin second contact',
        $verb->( 9, $s_pub, $live ),
        'PIN_VALID exit 0'
    );
    $check->(
        'check-pin rotated S',
        $verb->(
            9, $rot_pub,
            $wire->( $root_pub, $root_priv, $rot_pub, $t - 60, $t + 3600 )
        ),
        'PIN_VALID exit 0'
    );
    $check->(
        'check-pin foreign host-root',
        $verb->(
            9, $s_pub,
            $wire->(
                $foreign_pub, $foreign_priv, $s_pub, $t - 60, $t + 3600
            )
        ),
        'PIN_MISMATCH exit 6'
    );
    $check->(
        'check-pin expired',
        $verb->(
            9, $s_pub,
            $wire->( $root_pub, $root_priv, $s_pub, $t - 7200, $t - 3600 )
        ),
        'DELEGATION_INVALID expired exit 7'
    );
    $check->(
        'check-pin subject != announced S',
        $verb->( 9, $rot_pub, $live ),
        'DELEGATION_INVALID subject is not the announced server key exit 7'
    );
    $check->(
        'check-pin pin file [ lowercased host ]',
        ( -f "$tmp/.n/remote-keys/servers/test-host_9.public" ? 1 : 0 ), 1
    );
    rename( $old_pin, "$tmp/.n/remote-keys/servers/test-host_10.public" )
        or die "cannot move $old_pin : $!\n";
    $check->(
        'check-pin old S_pub pin',
        do {
            open( my $save, '>&', \*STDERR )            or die "dup : $!\n";
            open( STDERR,   '>',  File::Spec->devnull ) or die "null : $!\n";
            my $got = $verb->( 10, $s_pub, $live );
            open( STDERR, '>&', $save ) or die "restore : $!\n";
            $got;
        },
        'PIN_ERROR old server key pin exit 8'
    );

    ## owner path [ TRUST-CHAIN-STEP2.md 'pins' ] : owner 06 certifies the
    ## host-root [ test-host.* ] ; a rotated host-root 08 under the same owner
    my ( $own_pub, $own_priv )
        = Crypt::Ed25519::generate_keypair( "\x06" x 32 );
    my ( $new_pub, $new_priv )
        = Crypt::Ed25519::generate_keypair( "\x08" x 32 );
    my $sw = sub {   ## issuer pub, priv, subject, name, scope [, not_before ]
        my ( $ip, $ik, $sp, $name, $scope, $from ) = @_;
        my $st = delegation_statement( $ip, $sp, $name, $from // $t - 60,
            $t + 3600, $scope );
        return $st . Crypt::Ed25519::sign( $st, $ip, $ik );
    };
    my $o2h
        = $sw->( $own_pub, $own_priv, $root_pub, 'test-host', 'test-host.*' );
    ## the rotation : the owner certifies the new host-root LATER
    my $o2n = $sw->(
        $own_pub, $own_priv, $new_pub, 'test-host', 'test-host.*', $t - 30
    );
    my $h2s = $sw->( $root_pub, $root_priv, $s_pub, 'test-host.cube', '' );
    my $n2s = $sw->( $new_pub,  $new_priv,  $s_pub, 'test-host.cube', '' );
    my $n2b = $sw->( $new_pub,  $new_priv,  $s_pub, 'other.cube',     '' );
    make_path( "$tmp/.n/remote-keys/owners", { mode => 0700 } );
    open my $owfh, '>', "$tmp/.n/remote-keys/owners/test.public"
        or die "cannot write owner pin : $!\n";
    print {$owfh} key_id($own_pub) . "\n";
    close $owfh;

    $check->(
        'check-pin owner chain, strict, no host pin',
        $verb->( 11, $s_pub, [ $h2s, $o2h ], 'strict' ),
        'PIN_OWNER exit 0'
    );
    $check->(
        'check-pin owner chain : host pin written with the name',
        join(
            ' ',
            @{  pin_read("$tmp/.n/remote-keys/servers/test-host_11.public")
            }{qw| fp name |}
        ),
        key_id($root_pub) . ' test-host.cube'
    );
    $check->(
        'check-pin owner chain, again',
        $verb->( 11, $s_pub, [ $h2s, $o2h ] ),
        'PIN_VALID exit 0'
    );
    $check->(
        'check-pin rotated host-root, owner covers',
        $verb->( 11, $s_pub, [ $n2s, $o2n ] ),
        'PIN_ROTATED exit 0'
    );
    $check->(
        'check-pin rotated : pin now the new host-root, since moved forward',
        join(
            ' ',
            @{  pin_read("$tmp/.n/remote-keys/servers/test-host_11.public")
            }{qw| fp since |}
        ),
        key_id($new_pub) . ' ' . ( $t - 30 )
    );
    $check->(
        'check-pin rotate BACK to the old host-root : refused',
        $verb->( 11, $s_pub, [ $h2s, $o2h ] ),
        'PIN_MISMATCH exit 6'
    );
    ## the owner does not cover a leaf outside its scope : no owner trust [
    ## strict : unpinned ] -- under a host pin the statements above the pinned
    ## host-root are ignored [ trust.verify ], so this needs a new port
    $check->(
        'check-pin leaf outside the owner scope, strict',
        $verb->( 12, $s_pub, [ $n2b, $o2n ], 'strict' ),
        'PIN_UNPINNED exit 5'
    );
    open my $dfh, '>', "$tmp/.n/remote-keys/distrust"
        or die "cannot write distrust : $!\n";
    print {$dfh} "# test\n" . key_id($new_pub) . "\n";
    close $dfh;
    $check->(
        'check-pin distrusted host-root',
        $verb->( 11, $s_pub, [ $n2s, $o2n ] ),
        'DELEGATION_INVALID distrusted key in chain exit 7'
    );
    unlink "$tmp/.n/remote-keys/distrust";

    return;
}

##[ Helper: Secure buffer erasure ]###########################################

sub erase_buffer_secure {
    my ($buffer_sref) = @_;
    return 0 unless ref $buffer_sref eq 'SCALAR';
    return 0 unless defined $buffer_sref->$*;

    my $len = length( $buffer_sref->$* );
    return 0 if $len == 0;

    # Overwrite with random data multiple times for security
    my $prng = Crypt::PRNG::Fortuna->new();
    substr( $buffer_sref->$*, 0, $len, $prng->bytes($len) );
    substr( $buffer_sref->$*, 0, $len, $prng->bytes($len) );

    # Truncate to zero
    $buffer_sref->$* = '';

    return $len;
}

#,,..,,..,,,.,.,,,,..,,.,,,,.,,,,,,..,,,.,,.,,..,,...,...,..,,..,,.,.,.,,,..,,
#673LTFGOQ6EGD5D2EKUXBI4KXYIWG6KLSIZQ4Z2C5ANZPJWSBSV3PYMUEYEDGVCS7DOU3HCIZH3IE
#\\\|D3OIILQWZX57LSOAZV76RKLUPWFFITEFOF6Y3GAPA4XIHL4EP2W \ / AMOS7 \ YOURUM ::
#\[7]JRTQGDM5XND4PSMPJYP77LGQTRZLZIC7OLJA6DRVTTFIH3C72ACY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
