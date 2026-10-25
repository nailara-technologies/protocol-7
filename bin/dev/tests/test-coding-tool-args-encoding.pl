#!/usr/bin/perl
## [:< ##
## regression test : tool-call argument encoding layers [ 2026-10-25 ]      ##
##                                                                          ##
## bug class : an em-dash in a model's xml tool-call argument arrived       ##
## UTF-8-mangled [ E2 80 94 -> U+00E2 U+0080 U+0094 ] and was written       ##
## double-encoded [ C3 A2 C2 80 C2 94 ] ; the model's own arguments then    ##
## re-encoded in message history, self-sustaining the mojibake              ##
##                                                                          ##
## run INSIDE the Protocol-7 environment : bin/Protocol-7 sets `use open    ##
## qw| :encoding(UTF-8) |` -- the test declares the same default, and every ##
## synthetic input round-trips through a real file write+read under that    ##
## layer. a test that downgrades/encodes by hand hides this defect class    ##
## [ feedback-zenka-open-default-utf8-layer ]                               ##

use v5.24;
use strict;
use warnings;
use English qw( -no_match_vars );

## the bin/Protocol-7 global default -- REQUIRED, never remove ##
use open qw| :encoding(UTF-8) |;

use JSON::PP ();    ## fully-qualified calls only : no prototype clash ##
## with JSON::PP's importer                                 ##
use JSON::XS ();
use Encode   qw| encode_utf8 |;
use FindBin  qw| $Bin |;
use Cwd      qw| abs_path |;

my $root = abs_path("$Bin/../../..") or die "cannot locate protocol-7 root";

my ( $pass, $fail ) = ( 0, 0 );

sub ok {
    my ( $cond, $label ) = @_;
    if   ($cond) { $pass++; print "ok     - $label\n"; }
    else         { $fail++; print "NOT OK - $label\n"; }
}

## zenka modules are raw perl bodies with <[module.name]> call syntax      ##
## resolve those to %code subs exactly like bin/Protocol-7 does, then wrap ##
## the body in an anonymous sub                                            ##
## [ lexical `use open` scope of this test applies to the eval'd code ]    ##
my %code;
$code{'base.logs'} = sub { };

sub load_module {
    my $name = shift;
    my $path = "$root/src/$name";
    open( my $fh, '<', $path ) or die "cannot read $path : $OS_ERROR";
    my $src = do { local $RS = undef; <$fh> };
    close($fh);
    $src =~ s|\<\[([\w\-\.]+)\]\>\s*->\(|\$code{'$1'}->(|g;
    $src =~ s|\<\[([\w\-\.]+)\]\>|\$code{'$1'}->()|g;
    my $cref = eval "sub {\n$src\n}";
    die "compile error in $name : $EVAL_ERROR" if length $EVAL_ERROR;
    return $cref;
}

my $xml_parse   = load_module('coding.parse.xml_tool_calls');
my $args_decode = load_module('coding.async.tool_args_decode');

## scratch file for layer round-trips [ gitignored .test-*-output dir ] ##
my $scratch_dir = "$root/.test-enc-output";
mkdir $scratch_dir if not -d $scratch_dir;
my $scratch = "$scratch_dir/args-encoding-test.txt";

## the em-dash we track through every layer ##
my $EMDASH     = "\x{2014}";
my $EMDASH_B   = "\xe2\x80\x94";                ## correct UTF-8 octets ##
my $MOJIBAKE_B = "\xc3\xa2\xc2\x80\xc2\x94";    ## double-encoded damage ##

## (0) build the synthetic model content through the REAL layer : a single ##
## write + read under `use open` mirrors the http path                     ##
## [ server body bytes -> JSON::XS utf8 decode -> character string ]       ##
my $model_content
    = "<tool_call>\n<function=replace_in_file>\n"
    . "<parameter=path>.test-enc-output/x.txt</parameter>\n"
    . "<parameter=new_string>em-dash $EMDASH here</parameter>\n"
    . "</function>\n</tool_call>\n";

open( my $wfh, '>', $scratch ) or die "scratch write failed : $OS_ERROR";
print {$wfh} $model_content;
close($wfh);

open( my $rfh, '<', $scratch ) or die "scratch read failed : $OS_ERROR";
my $content = do { local $RS = undef; <$rfh> };
close($rfh);

ok( index( $content, $EMDASH ) >= 0,
    '(0) model content round-trips the layer as characters [ em-dash ]' );

## (1) xml content parse : arguments must be a CHARACTER string        ##
my $calls = $xml_parse->($content);
ok( ref $calls eq qw| ARRAY | && @$calls == 1,
    '(1) xml_tool_calls extracted one tool call'
);

my $args_str = $calls->[0]->{'function'}->{'arguments'} // '';

my $from_chars  = eval { JSON::PP->new->utf8(0)->decode($args_str); 1 } // 0;
my $from_octets = eval { JSON::PP::decode_json($args_str);          1 } // 0;
ok( $from_chars == 1 && $from_octets == 0,
    '(1) arguments are character json [ utf8(0) decodes, decode_json dies ]'
);

## (2) the tool_executor parse path : U+2014 survives, no Latin-1      ##
my ( $args, $args_str_out, $err )
    = $args_decode->( $args_str, 'replace_in_file' );

ok( defined $args and ref $args eq qw| HASH |,
    '(2) tool_args_decode returned a hashref'
);
ok( ( $args->{'new_string'} // '' ) eq "em-dash $EMDASH here",
    '(2) decoded em-dash is U+2014, not Latin-1 mojibake'
);
ok( index( $args->{'new_string'} // '', "\x{e2}\x{80}\x{94}" ) == -1,
    '(2) no U+00E2 U+0080 U+0094 sequence in decoded value'
);

## (3) octet input [ api path / old encode_json producer ] : same ##
## characters out -- this is the exact bug A input shape          ##
my $octets = JSON::PP::encode_json( { 'new_string' => "x $EMDASH y" } );
ok( utf8::is_utf8($octets) ? 0 : 1,
    '(3) encode_json fixture is a plain octet string' );

my ($args_oct) = $args_decode->( $octets, 'replace_in_file' );
ok( ( $args_oct->{'new_string'} // '' ) eq "x $EMDASH y",
    '(3) octet arguments decode to the same characters [ bug A ]'
);

## (4) character input [ api tool_calls path ] : same characters out   ##
my ($args_chr) = $args_decode->(
    JSON::PP->new->utf8(0)->encode( { 'new_string' => "y $EMDASH z" } ),
    'replace_in_file'
);
ok( ( $args_chr->{'new_string'} // '' ) eq "y $EMDASH z",
    '(4) character arguments decode correctly [ api path ]'
);

## (5) state_machine store path [ bug B ] : sanitize + store, then the ##
## single JSON::XS->new->utf8 request-body encode must produce exactly ##
## single-encoded UTF-8 for the model's own past arguments             ##
my $tc = {
    'id'       => 'call_test_1',
    'type'     => 'function',
    'function' => { 'name' => 'replace_in_file', 'arguments' => $octets },
};
{
    ## mirror of the coding.async.state_machine sanitize block          ##
    my $raw = $tc->{'function'}->{'arguments'} // '{}';
    my ($parsed) = $args_decode->( $raw, $tc->{'function'}->{'name'} );
    if ( defined $parsed and ref $parsed eq qw| HASH | ) {
        ## character json : the request body gets encoded exactly once ##
        $tc->{'function'}->{'arguments'}
            = JSON::PP->new->utf8(0)->encode($parsed);
    } else {
        $tc->{'function'}->{'arguments'} = '{}';
    }
}
my $body = JSON::XS->new->utf8->canonical->encode(
    {   'messages' => [
            {   'role'       => 'assistant',
                'content'    => '',
                'tool_calls' => [$tc],
            }
        ]
    }
);
ok( index( $body, $EMDASH_B ) >= 0,
    '(5) request body holds single-encoded em-dash octets E2 80 94' );
ok( index( $body, $MOJIBAKE_B ) == -1,
    '(5) request body has NO double-encoded C3 A2 C2 80 C2 94 [ bug B ]' );

## (6) end-to-end write through the layer, bytes on disk checked raw : the  ##
## decoded value written via a plain open                                   ##
## [ implicit UTF-8 layer, like base.file.put ] must land as single-encoded ##
## bytes                                                                    ##
open( my $ofh, '>', $scratch ) or die "scratch write failed : $OS_ERROR";
print {$ofh} $args->{'new_string'};
close($ofh);

open( my $bfh, '<:raw', $scratch ) or die "scratch read failed : $OS_ERROR";
my $raw_bytes = do { local $RS = undef; <$bfh> };
close($bfh);

ok( $raw_bytes eq encode_utf8("em-dash $EMDASH here"),
    '(6) bytes on disk are exactly E2 80 94 -- no double-encode'
);

unlink $scratch;

print "\n$pass passed, $fail failed\n";
exit( $fail ? 1 : 0 );

#,,.,,,.,,,,.,,.,,...,..,,,..,,.,,...,.,,,...,.,.,...,...,,.,,,,.,,.,,,,,,,.,,
#W3RXUNRPI7VVGJJDVQXXQM4YO76XWOUP454KFUXSI2E2BWPZBVG3JKY66BNTJAHXJZDWWHZFF4EYQ
#\\\|6IJIHA7YIFWZ66D44P4LADWWSWA3PSLGVHEW7TTMQB6PSOQNT6H \ / AMOS7 \ YOURUM ::
#\[7]EANCD6TYUQNNO6EYO4A2WNP4LNZMUSIO5OIKYAZEA5I4B6SFI4BQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
