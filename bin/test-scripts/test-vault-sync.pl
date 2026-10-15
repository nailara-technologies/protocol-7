#!/usr/bin/perl
use v5.32.0;
use strict;
use English;
use warnings;

## p7-vault sync : file union between two copies of one vault. the remote   ##
## side is a local dir -- P7_VAULT_SSH points at a wrapper that ignores the ##
## host and runs the remote command with sh. no real vault touched scaling  ##
## : thousands of small files -- the name lists travel in a temp file \ on  ##
## the remote's stdin, never on a command line                              ##

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
ok( $out !~ m|invalid file name|,
    '  :.. no invalid names on a clean pair [ probe sections parsed apart ]'
);
ok( $out !~ m{Odd number|uninitialized|used only once},
    '  :.. no perl warnings' );
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

## scaling : 3000 small entry + blob files. valid names straight on disk,  ##
## the contents need not decrypt for a transfer test. the name lists go in ##
## a temp list file \ on the remote's stdin -- never on a command line     ##
## [ E2BIG 'argument list too long' with 6000 names otherwise ]            ##
my @b32d = ( 'A' .. 'Z', 2 .. 7 );

sub b32_of {
    my $n = shift;
    my $s = '';
    while ($n) { $s = $b32d[ $n % 32 ] . $s; $n = int( $n / 32 ) }
    return $s;
}

sub pad_b32 {
    my ( $n, $len ) = @ARG;
    my $s = b32_of($n);
    return ( 'A' x ( $len - length $s ) ) . $s;
}

sub write_small {
    my ( $path, $content ) = @ARG;
    open( my $fh, '>', $path ) or die "cannot write $path : $OS_ERROR";
    print {$fh} $content;
    close $fh;
}

for my $i ( 1 .. 3000 ) {
    my $ename = sprintf '%s.%014d.%s.vlt.B32',
        pad_b32( $i, 16 ), 20000000000000 + $i, pad_b32( $i * 7, 8 );
    my $bname = pad_b32( $i, 32 ) . '.vlb';
    write_small( "$dir_a/entries/$ename", "entry $i" );
    write_small( "$dir_a/blobs/$bname",   "blob $i" );
}

( $out, $rc ) = sync( $dir_a, $dir_b );
ok( $rc == 0 && $out !~ m|argument list too long|,
    'scaling : 3000 entry + blob files sync without E2BIG'
);
ok( $out =~ m|pushed 3000, pulled 0, conflicts 0|,
    'scaling : 3000 entries pushed' );
ok( $out =~ m|blobs : pushed 3000, pulled 0, conflicts 0|,
    'scaling : 3000 blobs pushed, none hashed'
);
ok( entries($dir_b) == 3003, 'scaling : the remote side holds them all' );
ok( blobs($dir_b) == 3001,   'scaling : the remote blobs too' );

open(
    my $vfh,
    '<',
    "$dir_b/entries/"
        . sprintf(
        '%s.%014d.%s.vlt.B32',
        pad_b32( 42, 16 ),
        20000000000042,
        pad_b32( 42 * 7, 8 )
        )
) or die $OS_ERROR;
ok( <$vfh> eq 'entry 42', 'scaling : a pushed entry arrives intact' );
close $vfh;

( $out, $rc ) = sync( $dir_a, $dir_b );
ok( $rc == 0
        && $out =~ m|pushed 0, pulled 0, conflicts 0|
        && $out =~ m|blobs : pushed 0, pulled 0, conflicts 0|,
    'scaling : a second sync transfers nothing'
);

## sync with several hosts : one after the other, a summary ; a refused ##
## target is counted, the others still run                              ##
{
    my ( $dir_c, $dir_d ) = ( "$tmp/multi-c", "$tmp/multi-d" );
    foreach my $copy ( $dir_c, $dir_d ) {
        mkdir $copy or die $OS_ERROR;
        system( 'cp', "$dir_a/vault.key.B32", "$copy/" ) == 0
            or die 'key copy failed';
    }
    my $out
        = qx{$vault_bin -d $dir_a sync fakehost:$dir_c fakehost:$dir_d 2>&1};
    my $rc = $? >> 8;
    $out =~ s|\e\[[0-9;]*m||g;
    ok( $rc == 0 && $out =~ m|all 2 hosts in sync|,
        'sync <host>... : both hosts, summary'
    );
    ok( "@{[ entries($dir_c) ]}" eq "@{[ entries($dir_a) ]}"
            && "@{[ entries($dir_d) ]}" eq "@{[ entries($dir_a) ]}",
        'sync <host>... : every host holds every entry'
    );
    $out
        = qx{$vault_bin -d $dir_a sync 'fakehost:bad;dir' fakehost:$dir_c 2>&1};
    $rc = $? >> 8;
    $out =~ s|\e\[[0-9;]*m||g;
    ok( $rc != 0
            && $out =~ m|1 of 2 hosts not in sync \[ fakehost:bad;dir \]|,
        'sync <host>... : a refused target is counted, the rest runs'
    );
}

## sync <path> : a directory [ an external drive ] -- no ssh, p7-vault runs ##
## the same commands with sh                                                ##
{
    my $drive = "$tmp/usb-drive/vault";
    my $run   = sub {
        my $out = qx{$vault_bin -d $dir_a sync @ARG 2>&1};
        my $rc  = $? >> 8;
        $out =~ s|\e\[[0-9;]*m||g;
        return ( $out, $rc );
    };
    my ( $out, $rc ) = $run->($drive);
    ok( $rc != 0
            && $out =~ m|mkdir -p -m 700 '\Q$drive\E'|
            && $out =~ m|cp '[^']+vault\.key\.B32' '\Q$drive\E'/|,
        'sync <path> : no vault there -- local mkdir \\ cp hint'
    );

    system( 'mkdir', '-p', '-m', '700', $drive ) == 0 or die 'mkdir failed';
    system( 'cp', "$dir_a/vault.key.B32", "$drive/" ) == 0
        or die 'key copy failed';
    ( $out, $rc ) = $run->($drive);
    ok( $rc == 0
            && "@{[ entries($drive) ]}" eq "@{[ entries($dir_a) ]}"
            && "@{[ blobs($drive) ]}" eq "@{[ blobs($dir_a) ]}",
        'sync <path> : entries and blobs on the drive'
    );
    ( $out, $rc ) = $run->($drive);
    ok( $rc == 0 && $out =~ m|pushed 0, pulled 0, conflicts 0|,
        'sync <path> : a second sync moves nothing'
    );

    entry_save( $v, undef,
        { type => 'note', title => 'mixed', body => 'm' } );
    ( $out, $rc ) = $run->( $drive, "fakehost:$tmp/multi-c" );
    ok( $rc == 0
            && $out =~ m|all 2 hosts in sync|
            && "@{[ entries($drive) ]}" eq "@{[ entries($dir_a) ]}"
            && "@{[ entries(qq|$tmp/multi-c|) ]}" eq "@{[ entries($dir_a) ]}",
        'sync <path> <host> : a drive and a host in one run'
    );

    my $vd = { %{$v}, dir => $drive };
    entry_save( $vd, undef,
        { type => 'note', title => 'on the drive', body => 'd' } );
    ( $out, $rc ) = $run->($drive);
    ok( $rc == 0
            && $out =~ m|pushed 0, pulled 1, conflicts 0|
            && "@{[ entries($drive) ]}" eq "@{[ entries($dir_a) ]}",
        'sync <path> : an entry only on the drive is pulled'
    );

    ( $out, $rc ) = $run->("$dir_a/");
    ok( $rc != 0 && $out =~ m|is this vault itself|,
        'sync <path> : the vault itself is refused'
    );
}

say "\npassed : $pass  failed : $fail";
exit( $fail ? 1 : 0 );

#,,,,,,..,,..,,,,,,,,,,.,,.,,,,,.,,,,,.,,,,,,,..,,...,...,,.,,,,,,,,.,.,,,.,,,
#VKAK7Y4FPJN7DXSJ3QWLDOU53OSEN2KWQYNMMWSS2ZISPDOQDRPS5Q6VMMUEHVB7FSTJQOTWZOUSE
#\\\|FRSIZF466O4Q2GXSK4SCEBSOGHGX2VRMDQGXVTE5UI73C4A4DWQ \ / AMOS7 \ YOURUM ::
#\[7]H6NRGWABFD7WM7OWKV7HODVXXC2AWVVJ6BZYU2GPIAGSG5XK7UAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
