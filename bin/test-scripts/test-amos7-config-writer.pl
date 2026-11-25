#!/usr/bin/env perl
use v5.32;
use strict;
use warnings;
use English;
use utf8;

use Test::More;
use File::Spec;
use File::Temp qw| tempdir |;
use FindBin    qw| $RealBin |;

BEGIN {
    my $root = File::Spec->catdir( $RealBin, File::Spec->updir,
        File::Spec->updir );
    unshift @INC, File::Spec->catdir( $root, qw| data lib-path pm | );
    $main::root = $root;
}

use AMOS7::Config qw| normalize_lines |;
use AMOS7::Config::Reader;
use AMOS7::Config::Writer qw| write write_file |;

my $tmp     = tempdir( CLEANUP => 1 );
my $convert = File::Spec->catfile( $main::root, qw| bin p7-config-convert | );

sub read_native {
    my $text   = shift;
    my $source = bless { 'text' => $text }, 'P7ConfigWriterTest::Source';
    my $result = AMOS7::Config::Reader->read( 'test',
        { 'source' => $source, 'host_overlay' => 0 } );
    return scalar $result->all;
}

sub read_file {
    my ( $path, $raw ) = @ARG;
    CORE::open( my $fh, $raw ? '<:raw' : '<:encoding(UTF-8)', $path )
        or die "read $path : $OS_ERROR";
    local $INPUT_RECORD_SEPARATOR = undef;
    my $text = <$fh>;
    CORE::close($fh);
    return $text // '';
}

my $flat = {
    'alpha.empty'     => '',
    'alpha.equals'    => 'left=right',
    'alpha.hash'      => 'before # after',
    'alpha.long_key'  => 'plain',
    'alpha.spaces'    => '  both ends  ',
    'alpha.colon'     => 'left : right',
    'alpha.unicode'   => 'grüße 世界',
    'alpha.backslash' => 'ends\\',
    'z.last'          => 'last',
};
my $text = write($flat);
is_deeply( read_native($text), $flat,
    'flat values round trip through reader' );

my @assignments = grep {m{ = }} split m{\n}, $text;
my @keys        = map  { m{\A(\S+)} ? ${^CAPTURE}[0] : '' } @assignments;
is_deeply(
    \@keys,
    [ sort keys $flat->%* ],
    'keys sorted and prefixes grouped'
);

my @columns = map { index( $_, '=' ) } @assignments;
my %unique  = map { $_ => 1 } @columns;
is( scalar keys %unique, 1, 'all separators vertically aligned' );
like( $text, qr{alpha\.hash\s+= 'before \# after'}, 'hash value quoted' );
unlike( $text, qr{alpha\.colon\s+= '}, 'ordinary value not quoted' );
like(
    $text,
    qr{alpha\.backslash = 'ends\\'\n},
    'trailing backslash protected from continuation'
);

my $reversed = {};
foreach my $key ( reverse sort keys $flat->%* ) {
    $reversed->{$key} = $flat->{$key};
}
is( write($reversed), $text, 'insertion order does not matter' );
is( write( { 'group' => { 'one' => 1, 'two' => 2 } } ),
    "group.one = 1\ngroup.two = 2\n",
    'nested hashes flattened'
);
is( write( { 'a' => 1 }, { 'title' => 'example' } ),
    "   .:[ example ]:.\n\na = 1\n",
    'optional native header'
);

my $normalized
    = normalize_lines( [qq{key = 'value # kept' # removed\n}] )->[0]{'text'};
is( $normalized, q{key ='value # kept'},
    'only unquoted hash starts comment' );

my $atomic = File::Spec->catfile( $tmp, 'atomic.cfg' );
write_file( $atomic, $flat, { 'mode' => 0640, 'title' => 'atomic' } );
is_deeply( read_native( read_file( $atomic, 0 ) ),
    $flat, 'atomic file round trip' );
is( ( CORE::stat($atomic) )[2] & 07777, 0640, 'requested file mode applied' );
ok( !glob("$atomic.tmp.*"), 'atomic write leaves no temporary file' );

my $before = read_file( $atomic, 0 );
eval { write_file( $atomic, { 'bad' => "two\nlines" } ) };
like( $EVAL_ERROR, qr{multiline}, 'multiline value refused' );
is( read_file( $atomic, 0 ), $before, 'failed write preserves old file' );
eval { write( { 'bad' => "single ' quote" } ) };
like( $EVAL_ERROR, qr{single quote}, 'unsupported literal quote refused' );
eval { write( { 'a' => { 'b' => 1 }, 'a.b' => 2 } ); };
like( $EVAL_ERROR, qr{duplicate key}, 'flat and nested collision refused' );

my $native = File::Spec->catfile( $tmp, 'input.cfg' );
my $yaml   = File::Spec->catfile( $tmp, 'output.yaml' );
my $back   = File::Spec->catfile( $tmp, 'back.cfg' );
write_file( $native, $flat, { 'title' => 'converter' } );

my $status = CORE::system( $^X, $convert, 'native-to-yaml', $native, $yaml );
is( $status, 0, 'native to yaml converter exits successfully' );
require YAML::XS;
my $yaml_data = YAML::XS::Load( read_file( $yaml, 1 ) );
my $nested    = {};
foreach my $key ( keys $flat->%* ) {
    my ( $prefix, $leaf ) = split m{\.}, $key;
    $nested->{$prefix}{$leaf} = $flat->{$key};
}
is_deeply( $yaml_data, $nested, 'native keys become nested yaml mappings' );

$status = CORE::system( $^X, $convert, 'yaml-to-native', $yaml, $back );
is( $status, 0, 'yaml to native converter exits successfully' );
is_deeply( read_native( read_file( $back, 0 ) ),
    $flat, 'yaml native round trip' );
is( read_file( $back, 0 ), $text, 'converter returns stable native text' );

done_testing();

package P7ConfigWriterTest::Source;

sub exists { return 1 }
sub trust  { return 1 }

sub lines {
    my $self = shift;
    return [ split m{(?<=\n)}, $self->{'text'} // '' ];
}

1;

#,,.,,.,,,,..,,,,,...,.,,,...,...,,,,,,,,,,.,,..,,...,...,...,..,,,,.,...,.,,,
#6XXPALZIKUPGKIWENHREYKMKT6EXXZ4WYLSW5XIUMSBO6L7PY3RPHJ7Z3LZD2TWAZDG3P2DFLRZFK
#\\\|U5QLWFZTR5SDPMDAZYP6V4KEH3VY3QB74OUHD7OP4GJWVHF4RUN \ / AMOS7 \ YOURUM ::
#\[7]N66CFZK4JCSGVMJ3L3X45QTHUG5HLZWAQ2PWM7Y3LKYBVTO3QWBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
