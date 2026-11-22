#!/usr/bin/env perl
use v5.32;
use strict;
use English;
use warnings;
use bytes;
use File::Spec;
use File::Temp qw| tempdir |;
use FindBin    qw| $RealBin |;
use Cwd        qw| abs_path |;
use Sys::Hostname;

use constant { TRUE => 5, FALSE => 0 };

BEGIN {
    my $up   = File::Spec->updir;
    my $root = abs_path( File::Spec->catdir( $RealBin, $up, $up ) );
    $main::root_path = $root;
    unshift @INC, File::Spec->catdir( $root, qw| data lib-path pm | );
}
use AMOS7::Protocol::P7Syntax qw| p7_syntax__translate |;

my $checks = 0;
my $failed = 0;

sub ok {
    my ( $cond, $label ) = @ARG;
    $checks++;
    if ($cond) { say "ok   : $label"; return TRUE }
    $failed++;
    say "FAIL : $label";
    return FALSE;
}

my $module = 'base.X-11.write_xauth_file';
my $path   = File::Spec->catfile( $main::root_path, 'src', $module );
open( my $fh, '<:raw', $path ) or die;
my $source = join( '', <$fh> );
close($fh);
my $compiled = eval 'sub { ' . p7_syntax__translate($source) . ' }';
die "xauth writer compile : $EVAL_ERROR" if not $compiled;

my $tmp    = tempdir( CLEANUP => 1 );
my $xauth  = File::Spec->catfile( $tmp, 'Xauthority' );
my $cookie = '001122aabbcc';
my $args   = {
    'display'    => ':13',
    'protocol'   => 'MIT-MAGIC-COOKIE-1',
    'cookie_hex' => $cookie,
    'path'       => $xauth,
    'uid'        => $UID,
    'gid'        => $GID,
};
ok( $compiled->($args), 'writer creates an xauthority file' );
ok( -f $xauth && ( ( CORE::stat($xauth) )[2] & 0777 ) == 0600,
    'xauthority mode is 0600' );

open( my $read, '<:raw', $xauth ) or die;
local $INPUT_RECORD_SEPARATOR;
my $body = <$read>;
close($read);
my $offset = 0;

sub take_short {
    my $value = unpack( 'n', substr( $body, $offset, 2 ) );
    $offset += 2;
    return $value;
}

sub take_field {
    my $length = take_short();
    my $value  = substr( $body, $offset, $length );
    $offset += $length;
    return $value;
}
ok( take_short() == 256,        'entry uses local-family 256' );
ok( take_field() eq hostname(), 'entry carries the local hostname' );
ok( take_field() eq '13',       'entry carries display number 13' );
ok( take_field() eq 'MIT-MAGIC-COOKIE-1', 'entry carries protocol name' );
ok( unpack( 'H*', take_field() ) eq $cookie,
    'entry carries exact cookie bytes'
);
ok( $offset == length($body), 'no trailing xauthority data' );

my $second_cookie = 'ffee';
$args->{'cookie_hex'} = $second_cookie;
ok( $compiled->($args), 'owned file is replaced for a later session' );
open( $read, '<:raw', $xauth ) or die;
$body = <$read>;
close($read);
ok( $body =~ m|\xee$|, 'replacement contains the new cookie' );

$args->{'path'} = File::Spec->catfile( $tmp, 'linked' );
symlink( '/nonexistent', $args->{'path'} ) or die;
ok( !$compiled->($args), 'symlink destination is refused' );
$args->{'path'}    = File::Spec->catfile( $tmp, 'bad-display' );
$args->{'display'} = 'tcp/host:13';
ok( !$compiled->($args) && !-e $args->{'path'},
    'nonlocal display syntax is refused'
);
$args->{'display'}    = ':13';
$args->{'cookie_hex'} = 'not-hex';
ok( !$compiled->($args) && !-e $args->{'path'},
    'invalid cookie is refused before file creation'
);

say '';
say sprintf ':: %d checks, %d failed', $checks, $failed;
exit( $failed ? 1 : 0 );

#,,.,,,..,,.,,.,.,,,,,,,.,.,.,..,,..,,.,,,,,.,..,,...,...,,..,,.,,...,,.,,,.,,
#7USKRK37JI3L3MSCR5UONYWAIMN6AC77MXFEZJGZX3ZDPMY7PTJTRZIEFBIMNFK7I6EMJ6XOIGZ54
#\\\|G6MOJ3EOS3BFLJNGVCVNEOAM4ROFPWYUWD6SIUXZQAHQAW7JWKP \ / AMOS7 \ YOURUM ::
#\[7]U7L5TIAYW2JFCKNY5INWINU5WGZDM5FFN2ZYWFNBGLCYO2ARA6CI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
