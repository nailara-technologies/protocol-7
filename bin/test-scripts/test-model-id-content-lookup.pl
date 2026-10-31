#!/usr/bin/env perl
use v5.24;
use strict;
use English;
use warnings;
## the production runtime [ bin/Protocol-7 : use utf8 + Encode ] loads the ##
## bytes pragma transitively ; keep it so compiled modules resolve it.     ##
use bytes;

## model ids on another host : '<path>:<content>' keeps its content half  ##
## when the file sits under another parent dir. a pin written on one host ##
## must resolve on the next by that content half :                        ##
## - models.registry.lookup : exact composite, ':<content>', and a        ##
## composite whose path half is unknown here                              ##
## - coding.mode.local_model_id : pins map to the id this host serves     ##
## - coding.mode.task_model : ':model:' pins with and without path half   ##

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
    my $local_lib_path
        = File::Spec->catdir( $root_path, qw| data lib-path pm | );
    die "not found : $local_lib_path" if !-d $local_lib_path;
    unshift( @INC, $local_lib_path );
    $main::root_path = $root_path;
}

use AMOS7::Protocol::P7Syntax qw| p7_syntax__translate |;

use constant TRUE    => 5;
use constant FALSE   => 0;
use constant UNKNOWN => 2;

our %code;
our %data;
our $call;

$OUTPUT_AUTOFLUSH = 1;

my $fail_count = 0;
my $pass_count = 0;

sub ok ($;$) {
    my ( $cond, $label ) = @ARG;
    if ($cond) { $pass_count++; say "  ok   : $label"; return }
    $fail_count++;
    say "  FAIL : $label";
    return;
}

## $prefix : source prepended inside the compiled sub [ constants ]        ##
my $runtime_pragmas = q{no bytes; use File::stat; use File::Spec;
    use File::Spec::Functions qw| catfile |;
    use open qw| :encoding(UTF-8) |;};
my $module_prefix = q{use constant TRUE => 5; use constant FALSE => 0;};

sub compile_module {
    my ($module_name) = @ARG;
    my $src_path
        = File::Spec->catfile( $main::root_path, 'src', $module_name );
    open( my $fh, '<', $src_path ) or die "cannot read $src_path : $!";
    my $src = join( '', <$fh> );
    close($fh);
    my $translated = p7_syntax__translate($src);
    my $cref
        = eval "$runtime_pragmas sub {\n$module_prefix\n# "
        . "line 1 \"$module_name\"\n$translated\n}";
    die "compile failed for $module_name : $EVAL_ERROR"
        if not defined $cref;
    $code{$module_name} = $cref;
    return $cref;
}

my @perl_warnings;
local $SIG{__WARN__} = sub { push @perl_warnings, @ARG };

$code{'base.logs'}   = sub {return};
$code{'base.s_warn'} = sub {return};

compile_module($ARG) for qw|
    models.registry.lookup models.resolve.entry models.cmd.get_path_by_amos
    coding.mode.local_model_id coding.mode.task_model coding.mode.setting |;

## ---------------------------------------------------------------------- ##
## registry lookup and models zenka path resolution                       ##

my $here  = 'KMUVFQQ:QDBKEXY';
my $there = 'OFSQC4I:QDBKEXY';
$data{'models'}{'registry'} = {
    $here             => { 'file_path' => '/data/models/a/b/9b.gguf' },
    'AAAAAAA:BBBBBBB' => { 'file_path' => '/data/models/c/d/14b.gguf' },
};
my $lookup = $code{'models.registry.lookup'};

ok( ( $lookup->($here) // {} )->{'file_path'} eq '/data/models/a/b/9b.gguf',
    'exact composite id' );
ok( ( $lookup->(':QDBKEXY') // {} )->{'file_path'} eq
        '/data/models/a/b/9b.gguf',
    'content half alone [ :<content> ]'
);
ok( ( $lookup->('QDBKEXY') // {} )->{'file_path'} eq
        '/data/models/a/b/9b.gguf',
    'content half alone [ no colon ]'
);
ok( ( $lookup->($there) // {} )->{'file_path'} eq '/data/models/a/b/9b.gguf',
    'other host\'s path half -> same content here'
);
ok( !defined $lookup->('ZZZZZZZ:CCCCCCC'), 'unknown content stays unknown' );

$data{'models'}{'registry'}{$here}{'file_path'} = __FILE__;
for my $id ( $here, ':QDBKEXY' ) {
    local $call = { 'args' => $id };
    my $reply = $code{'models.cmd.get_path_by_amos'}->();
    ok( $reply->{'data'} =~ m|\nfile_path: |, "path lookup resolves $id" );
}

local $call = { 'args' => ':CCCCCCC' };
my $reply = $code{'models.cmd.get_path_by_amos'}->();
ok( $reply->{'data'} =~ m|matches no installed model|,
    'path lookup reports an unknown content id'
);

$data{'models'}{'registry'}{$there} = { 'file_path' => __FILE__ };
ok( !defined $lookup->(':QDBKEXY'), 'ambiguous content half is refused' );
ok( defined $lookup->('QDBKEXY'),   'bare content keeps legacy resolution' );

local $call = { 'args' => ':QDBKEXY' };
$reply = $code{'models.cmd.get_path_by_amos'}->();
ok( $reply->{'data'} =~ m|ambiguous.*2 installed matches|,
    'path lookup reports an ambiguous content id'
);
delete $data{'models'}{'registry'}{$there};

## ---------------------------------------------------------------------- ##
## local model id                                                         ##

my $local = $code{'coding.mode.local_model_id'};
$data{'inference'}{'backend'}{'cpu'}{'model_id'} = $here;

ok( $local->($there) eq $here,     'pin from another host -> local id' );
ok( $local->(':QDBKEXY') eq $here, ':<content> -> local id' );
ok( $local->( lc $here ) eq $here, 'local id stays [ case folded ]' );
ok( $local->('AAAAAAA:BBBBBBB') eq 'AAAAAAA:BBBBBBB',
    'a model this host does not serve stays as given'
);
ok( !defined $local->(''), 'empty pin -> undef' );

$data{'coding'}{'inference_servers'}{'gpu'}{'model'} = 'AAAAAAA:BBBBBBB';
ok( $local->('XXXXXXX:BBBBBBB') eq 'AAAAAAA:BBBBBBB',
    'loaded server model counts as known'
);

## a content-only pin for a model this host has but does not serve right   ##
## now [ another model loaded ] : the registry supplies a unique path half ##
$data{'coding'}{'model_metadata'} = {
    'DDDDDDD:EEEEEEE' => { 'amos' => 'DDDDDDD:EEEEEEE', 'available' => TRUE },
    'FFFFFFF:EEEEEEE' =>
        { 'amos' => 'FFFFFFF:EEEEEEE', 'available' => FALSE },
    'yaml named' => { 'amos' => 'yaml named' },
};
ok( $local->(':EEEEEEE') eq ':EEEEEEE',
    'ambiguous :<content> stays unresolved [ never a guess ]' );
ok( $local->('EEEEEEE') eq 'DDDDDDD:EEEEEEE',
    'bare content keeps its registry preference'
);
ok( $local->(':GGGGGGG') eq ':GGGGGGG',
    'content in neither served nor registry stays as given' );
$data{'coding'}{'model_metadata'}{$there} = { 'amos' => $there };
ok( $local->(':QDBKEXY') eq ':QDBKEXY',
    'loaded and registry copies together are still ambiguous' );
delete $data{'coding'}{'model_metadata'}{$there};
ok( $local->('XXXXXXX:BBBBBBB') eq 'AAAAAAA:BBBBBBB',
    'served model still wins over the registry'
);

## ---------------------------------------------------------------------- ##
## task model                                                             ##

my $task_model = $code{'coding.mode.task_model'};
my $task_of    = sub {
    return { 'request' => { 'description' => shift } };
};
ok( $task_model->( $task_of->(":model:$there: assess this") ) eq $here,
    ':model: pin with foreign path half' );
ok( $task_model->( $task_of->(':model::QDBKEXY: assess this') ) eq $here,
    ':model: pin with content half alone' );
ok( !defined $task_model->( $task_of->('no pin here') ), 'no pin -> undef' );

ok( !@perl_warnings, 'no perl warnings' ) or print @perl_warnings;

say '';
say "passed : $pass_count  failed : $fail_count";
exit( $fail_count ? 1 : 0 );

#,,..,.,,,,.,,,..,...,..,,.,,,,.,,.,,,,,,,...,..,,...,...,,..,,,,,,.,,,,,,,.,,
#ABZN3IQ7REAX53ZX7LQ6XHO2CZPYIDEOZDZKAIYVSWG7UETVUQXUD2PPSMFTYFGZX2OW257XQZ2NG
#\\\|TS7TAEUVJZE2VGXXYSLBQ2AQLYYATXAGBQHRDSZMJAICM2WUM7O \ / AMOS7 \ YOURUM ::
#\[7]Q4QOTBSRVQMIVHJW5VOEO2ICIORJJ2T7WOGVWOO4WUI5QEISBEDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
