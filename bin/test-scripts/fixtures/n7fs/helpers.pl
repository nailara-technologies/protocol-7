#!/usr/bin/perl
## shared helpers for bin/test-scripts/test-n7fs*.pl [ require'd ] : temp
## roots, test signers, a fixed clock, full-tree snapshots.
##
## everything lives under one File::Temp directory : root, host dir, HOME
## [ a forgotten default lands there too ], sources. nothing outside it is
## written.

use v5.32.0;
use strict;
use English;
use warnings;

use File::Temp  qw| tempdir |;
use Digest::SHA qw| sha256_hex |;

use AMOS7::N7FS;
use AMOS7::N7FS::Sign qw| seed_signer new_seed |;
use AMOS7::N7FS::Sum  qw| epoch_int |;

our ( $PASS, $FAIL ) = ( 0, 0 );

## the name is taken from the END : a failed match as the last operand of the
## condition returns an EMPTY LIST in list context
## [ ok( $x =~ m|y|, 'name' ) ] -- the name would become the condition and
## pass
sub ok {
    my $name = pop;
    my $cond = @ARG ? shift : 0;
    if   ($cond) { $PASS++; say "  ok    $name" }
    else         { $FAIL++; say "  FAIL  $name" }
    return $cond;
}

## runs $code, expects a refusal matching $re
sub refused {
    my ( $code, $re, $name ) = @ARG;
    my $ok  = eval { $code->(); 1 };
    my $err = $EVAL_ERROR // '';
    chomp $err;
    ok( !$ok && $err =~ $re, $name . ( $ok ? ' [ not refused ]' : '' ) );
    say "        got : $err" if $ok or $err !~ $re;
    return $err;
}

sub done {
    say "\n  $PASS passed, $FAIL failed";
    exit( $FAIL ? 1 : 0 );
}

## a fresh sandbox : { base root host home src }. HOME and the n7fs env point
## into it
sub sandbox {
    my $base = tempdir( qw| n7fs-test-XXXXXXXX |, TMPDIR => 1, CLEANUP => 1 );
    my %box  = ( qw| base | => $base );
    foreach my $sub (qw| root host home src |) {
        mkdir "$base/$sub", 0700 or die "mkdir $base/$sub : $OS_ERROR";
        $box{$sub} = "$base/$sub";
    }
    $ENV{'HOME'}          = $box{'home'};
    $ENV{'N7FS_ROOT'}     = $box{'root'};
    $ENV{'N7FS_HOST_DIR'} = $box{'host'};
    return \%box;
}

sub test_signer { return seed_signer( new_seed() ) }

## the injectable clock : whole ntime units, settable
our $NOW;

sub clock_now { return $NOW }

sub clock_real {
    $NOW = AMOS7::NTIME::unix_to_ntime( Time::HiRes::time(), 0 );
    $AMOS7::N7FS::CLOCK = sub { return $NOW++ };
    return $NOW;
}

## the first ntime of an epoch [ + a margin ]
sub clock_epoch {
    my $epoch = shift;
    my $nt    = int( $epoch * $AMOS7::N7FS::Sum::EPOCH_DIVISOR ) + 4200;
    $NOW                = $nt;
    $AMOS7::N7FS::CLOCK = sub { return $NOW++ };
    return $nt;
}

## every path under the given dirs : type, mode, size, content hash, symlink
## target. two equal snapshots = no change on disk
sub snapshot {
    my %snap;
    my $walk;
    $walk = sub {
        my $path = shift;
        my @st   = lstat $path or return;
        my $mode = sprintf '%04o', $st[2] & 07777;
        if ( -l _ ) {
            $snap{$path} = 'l ' . readlink($path);
        } elsif ( -d _ ) {
            $snap{$path} = "d $mode";
            opendir( my $dh, $path ) or die "opendir $path : $OS_ERROR";
            my @e = grep { $ARG ne '.' and $ARG ne '..' } readdir $dh;
            closedir $dh;
            $walk->("$path/$ARG") for @e;
        } else {
            my $content = AMOS7::N7FS::read_file($path) // '';
            $snap{$path} = sprintf 'f %s %d %s', $mode, $st[7],
                sha256_hex($content);
        }
    };
    $walk->($ARG) for @ARG;
    return \%snap;
}

sub snap_equal {
    my ( $a, $b ) = @ARG;
    my %k    = map  { $ARG => 1 } keys %{$a}, keys %{$b};
    my @diff = grep { ( $a->{$ARG} // '-' ) ne ( $b->{$ARG} // '-' ) }
        sort keys %k;
    say "        " . "changed : $ARG"
        for @diff[ 0 .. ( $#diff < 4 ? $#diff : 4 ) ];
    return @diff ? 0 : 1;
}

sub write_file {
    my ( $path, $content ) = @ARG;
    open( my $fh, '>:raw', $path ) or die "write $path : $OS_ERROR";
    print {$fh} $content;
    close $fh or die "close $path : $OS_ERROR";
    return $path;
}

## copies a tree [ perl only, list-form, keeps modes ]
sub copy_tree {
    my ( $from, $to ) = @ARG;
    my @st = lstat $from or die "lstat $from : $OS_ERROR";
    if ( -d _ ) {
        mkdir $to, $st[2] & 07777 or die "mkdir $to : $OS_ERROR";
        opendir( my $dh, $from ) or die "opendir $from : $OS_ERROR";
        my @e = grep { $ARG ne '.' and $ARG ne '..' } readdir $dh;
        closedir $dh;
        copy_tree( "$from/$ARG", "$to/$ARG" ) for @e;
        chmod $st[2] & 07777, $to;
    } else {
        write_file( $to, AMOS7::N7FS::read_file($from) );
        chmod $st[2] & 07777, $to;
    }
    return $to;
}

1;

#,,..,.,.,..,,,,.,,,.,,.,,,,.,,,.,...,,..,.,.,..,,...,...,..,,.,,,,..,,.,,,..,
#NRZ6TLPEPZNX4YALZO3DAL5BMXSVQZ3B4RKTW7UWRZDTLJNQSJ5ZX7L3GDV4LG4KBJF4EBBL55QQU
#\\\|CJBBKB35SBG5ASQU6IOZW7GGIQEWQ6H6FL6FHE56VCZZHZLN5YG \ / AMOS7 \ YOURUM ::
#\[7]PB252J3DEBFE4IUHEENTVWDFLIPMCJCI5RB2UAX34KBBGTSI26DI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
