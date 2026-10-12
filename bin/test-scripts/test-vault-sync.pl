#!/usr/bin/perl
use v5.32.0;
use strict;
use English;
use warnings;

## p7-vault sync : file union between two copies of one vault. the remote   ##
## side is a local dir -- P7_VAULT_SSH points at a wrapper that ignores the ##
## host and runs the remote command with sh. no real vault touched          ##

use FindBin;
use File::Temp qw| tempdir |;

use constant TRUE  => 5;    ##  TRUE.  ##
use constant FALSE => 0;    ##  false  ##

BEGIN { unshift @INC, "$FindBin::Bin/../../data/lib-path/pm" }

use AMOS7::Vault qw| vault_init entry_save blob_import |;

my ( $pass, $fail ) = ( 0, 0 );

sub ok {
    my ( $cond, $name ) = @ARG;
    if   ($cond) { $pass++; say "  ok    $name" }
    else         { $fail++; say "  FAIL  $name" }
}

my $vault_bin = "$FindBin::Bin/../p7-vault";
my %kdf       = ( t => 1, m => 8192, p => 1 );    ## cheap, test only ##
my $tmp       = tempdir( CLEANUP => 1 );

## ssh stand-in : 'wrapper <host> <command>' -> sh -c <command> ##
my $wrapper = "$tmp/fake-ssh";
open( my $wfh, '>', $wrapper ) or die "cannot write $wrapper : $OS_ERROR";
print {$wfh} qq{#!/bin/sh\nshift\nexec sh -c "\$1"\n};
close $wfh;
chmod 0755, $wrapper;
$ENV{'P7_VAULT_SSH'} = $wrapper;

sub entries {
    my $dir = shift;
    opendir( my $dh, "$dir/entries" ) or return ();
    my @names = sort grep { not m|^\.| } readdir $dh;
    closedir $dh;
    return @names;
}

sub sync {
    my ( $local, $remote ) = @ARG;
    my $out = qx{$vault_bin -d $local sync fakehost:$remote 2>&1};
    $out =~ s|\e\[[0-9;]*m||g;
    return ( $out, $? >> 8 );
}

sub blobs {
    my $dir = shift;
    opendir( my $dh, "$dir/blobs" ) or return ();
    my @names = sort grep { not m|^\.| } readdir $dh;
    closedir $dh;
    return @names;
}

## two copies of one vault : same key file, separate entries ##
my $dir_a = "$tmp/a";
my $v     = vault_init( $dir_a, 'pass phrase', undef, %kdf );
system( 'cp', '-a', $dir_a, "$tmp/b" ) == 0 or die 'copy failed';
my $dir_b = "$tmp/b";

entry_save( $v, undef, { type => 'note', title => 'from a', body => 'x' } );
my $vb = { %{$v}, dir => $dir_b };
entry_save( $vb, undef, { type => 'note', title => 'from b', body => 'y' } );
entry_save( $vb, undef, { type => 'note', title => 'b two',  body => 'z' } );

my @a0 = entries($dir_a);
my @b0 = entries($dir_b);
ok( @a0 == 1 && @b0 == 2, 'set-up : a holds 1 entry file, b holds 2' );

my ( $out, $rc ) = sync( $dir_a, $dir_b );
ok( $rc == 0,                                   'first sync succeeds' );
ok( $out =~ m|pushed 1, pulled 2, conflicts 0|, '  :.. pushed 1, pulled 2' );
ok( "@{[ entries($dir_a) ]}" eq "@{[ entries($dir_b) ]}",
    '  :.. both sides hold the union' );
ok( entries($dir_a) == 3, '  :.. three entry files each' );

( $out, $rc ) = sync( $dir_a, $dir_b );
ok( $out =~ m|pushed 0, pulled 0, conflicts 0|,
    'second sync transfers nothing' );

## blobs travel in the union too : one import on a, one sync ##
my $blob_src = "$tmp/blob-src.bin";
open( my $bfh, '>:raw', $blob_src ) or die $OS_ERROR;
print {$bfh} 'blob content ' x 1000;
close $bfh;
blob_import( $v, $blob_src );
( $out, $rc ) = sync( $dir_a, $dir_b );
ok( $rc == 0, 'blob sync succeeds' );
ok( $out =~ m|blobs : pushed 1, pulled 0, conflicts 0|,
    '  :.. the blob is pushed' );
ok( "@{[ blobs($dir_a) ]}" eq "@{[ blobs($dir_b) ]}",
    '  :.. both sides hold the blob' );
( $out, $rc ) = sync( $dir_a, $dir_b );
ok( $out =~ m|blobs : pushed 0, pulled 0, conflicts 0|,
    '  :.. a second sync moves no blob' );

## same name, different content : reported, never replaced ##
my $name = 'A' x 16 . '.' . '2' x 14 . '.' . 'B' x 8 . '.vlt.B32';
for my $side ( [ $dir_a, 'one' ], [ $dir_b, 'two' ] ) {
    open( my $fh, '>', "$side->[0]/entries/$name" ) or die $OS_ERROR;
    print {$fh} $side->[1];
    close $fh;
}
( $out, $rc ) = sync( $dir_a, $dir_b );
ok( $out =~ m|conflicts 1|, 'differing content : one conflict reported' );
ok( $rc != 0,               '  :.. sync exits non-zero on conflicts' );
open( my $cfh, '<', "$dir_a/entries/$name" ) or die $OS_ERROR;
ok( <$cfh> eq 'one', '  :.. local file left alone' );
close $cfh;
unlink "$dir_a/entries/$name", "$dir_b/entries/$name";

## a symlink with a valid entry name on the remote side is refused ##
my $link = 'C' x 16 . '.' . '3' x 14 . '.' . 'D' x 8 . '.vlt.B32';
symlink( '/etc/hostname', "$dir_b/entries/$link" ) or die $OS_ERROR;
( $out, $rc ) = sync( $dir_a, $dir_b );
ok( !-e "$dir_a/entries/$link", 'remote symlink not pulled' );
unlink "$dir_b/entries/$link";

## a different vault is refused ##
my $dir_c = "$tmp/c";
vault_init( $dir_c, 'other', undef, %kdf );
( $out, $rc ) = sync( $dir_a, $dir_c );
ok( $rc != 0 && $out !~ m|pushed|, 'different vault id refused' );
ok( entries($dir_c) == 0,          '  :.. nothing written there' );

## no vault on the remote side ##
( $out, $rc ) = sync( $dir_a, "$tmp/none" );
ok( $rc != 0, 'missing remote vault refused' );

say "\npassed : $pass  failed : $fail";
exit( $fail ? 1 : 0 );

#,,.,,,.,,.,,,.,.,...,.,,,..,,,,,,...,,,,,.,,,..,,...,...,...,,..,,.,,,,,,.,,,
#7AN5LNF5F5GDVM2B3IRQCCER2LISVHKP4IMWN2J4CYICOUD7OER4ZKASV6XX3PLQNHBYHTWZHULXE
#\\\|QXZU76CWVATBSE63F7QIGXDKOWZJGO5ERB2O5UTFF6B5252AJYS \ / AMOS7 \ YOURUM ::
#\[7]Z24S277BO4YHHJOPQMC33LO4GV3MYRJP6F6MADCQT4TC7UT4HYCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
