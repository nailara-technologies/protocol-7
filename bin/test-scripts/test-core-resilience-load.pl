#!/usr/bin/perl
use v5.24;
use strict;
use English;
use warnings;

###                                                                 ###
## core startup resilience : the truth-check chain loads without          ##
## Digest::BMW \ Crypt::Misc [ azurum 2026-10-27 : minimal profile lacked ##
## them and bin/Protocol-7 died at compile time ]                         ##
###                                                                 ###

## - normal load : BMW-keyed path names
## - degraded load [ modules hidden via an @INC hook ] :  the chain still
## compiles, chksum names stay printable \ deterministic
## - the degraded chksum differs from the BMW one [ real fallback used ]

use File::Spec;
use Cwd     qw| abs_path |;
use FindBin qw| $RealBin |;

BEGIN {
    my $up_dir    = File::Spec->updir;
    my $root_path = abs_path(
        File::Spec->rel2abs(
            File::Spec->catdir( $RealBin, $up_dir, $up_dir )
        )
    );
    unshift @INC, File::Spec->catdir( $root_path, 'data', 'lib-path', 'pm' );
}

my $checks = 0;
my $failed = 0;

sub check {
    my ( $label, $condition ) = @_;
    $checks++;
    if ($condition) {
        printf "  ok   : %s\n", $label;
    } else {
        $failed++;
        printf "  FAIL : %s\n", $label;
    }
    return;
}

## hide a module from require : the hook hands perl a handle whose content
## dies -- require fails, exactly as a missing install does
sub _hide {
    my (@names) = @_;
    my $re      = join '|', map {quotemeta} @names;
    unshift @INC, sub {
        my ( $code, $file ) = @_;
        return undef unless $file =~ m{^($re)\.pm$};
        open my $fh, '<', \"die q|hidden by resilience test|;\n" or die;
        return $fh;
    };
    return;
}

my @hidden = qw| Digest/BMW |;

##[ AMOS7::B32 : byte-identical to Crypt::Misc when it is installed ]#########

my $b32_check = run_perl(
    [],
    q| require AMOS7::B32;
        eval { require Crypt::Misc };
        if ( defined &Crypt::Misc::encode_b32r ) {
            my $data = join '', map { chr } 0 .. 255;
            die "b32 mismatch"
                if AMOS7::B32::encode_b32r($data)
                ne Crypt::Misc::encode_b32r($data);
            die "b32 decode mismatch"
                if AMOS7::B32::decode_b32r( Crypt::Misc::encode_b32r($data) )
                ne $data;
        }
        print "b32 ok\n"; |
);

check 'B32 : matches Crypt::Misc when present', $b32_check->{'exit'} == 0;

##[ normal ]##################################################################

my $normal = run_perl( [], <<'PERLEOF' );
    require AMOS7::Assert::Truth;
    require AMOS7::TEMPLATE;
    my $name = AMOS7::INLINE::encoded_bmw_chksum(q|sub foo { 1 }|);
    print $name, "\n";
PERLEOF

check 'normal : chain loads',   $normal->{'exit'} == 0;
check 'normal : b32 path name', $normal->{'out'} =~ m{\A[A-Z2-7]+\n?\z};

##[ degraded ]################################################################

my $degraded = run_perl( \@hidden, <<'PERLEOF' );
    require AMOS7::Assert::Truth;
    require AMOS7::TEMPLATE;
    die "bmw_256 leaked" if defined &AMOS7::INLINE::bmw_256;
    my $name = AMOS7::INLINE::encoded_bmw_chksum(q|sub foo { 1 }|);
    die "not printable" unless $name =~ m{\A[0-9a-zA-Z=]+\z};
    print $name, "\n";
PERLEOF

check 'degraded : chain loads',    $degraded->{'exit'} == 0;
check 'degraded : printable name', $degraded->{'out'} =~ m{\A[A-Z2-7]+\n?\z};
check 'degraded : fallback differs from BMW name', length( $normal->{'out'} )
    && $degraded->{'out'} ne $normal->{'out'};

printf "\n: %d checks passed, %d failed\n", $checks - $failed, $failed;
exit( $failed ? 1 : 0 );

##[ helper ]##################################################################

sub run_perl {
    my ( $hidden, $code ) = @_;

    my $out_path = File::Spec->catfile( File::Spec->tmpdir,
        sprintf 'p7-resilience-%d.out', $PID );
    my $pid = fork // die "fork failed";
    if ( $pid == 0 ) {
        open STDOUT, '>',  $out_path or exit 127;
        open STDERR, '>&', \*STDOUT;
        _hide( @{$hidden} ) if @{$hidden};
        eval $code;
        print STDERR $EVAL_ERROR if length $EVAL_ERROR;
        exit length $EVAL_ERROR ? 1 : 0;
    }
    waitpid $pid, 0;
    my $exit = $CHILD_ERROR >> 8;

    open my $fh, '<', $out_path or return { 'exit' => $exit, 'out' => '' };
    my $out = do { local $INPUT_RECORD_SEPARATOR = undef; <$fh> }
        // '';
    close($fh);
    unlink $out_path;
    return { 'exit' => $exit, 'out' => $out };
}

#,,,.,,,,,,.,,...,,,.,..,,.,,,...,.,,,.,.,.,.,.,.,...,...,..,,.,,,,.,,.,.,.,.,
#OAR65T6PXWZ2RIYT6LRLSJZTFZRTHYXLBDWB4DCLWJNHKES33ACF3EJWE4DZL43245UARVZBUSCVQ
#\\\|E7D4FE5FTOYPMAKF3TWINM3WPC7VRENN4A2D6YI5LTD2IOFLHRE \ / AMOS7 \ YOURUM ::
#\[7]4Y43UX6ZCXSBBCKSBWN2TIVXA6CMQROLKFLSM5TXK2EZNW7XFIDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
