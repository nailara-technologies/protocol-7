#!/usr/bin/perl
use v5.30.0;
use strict;
use warnings;
use English;
use File::Spec;
use FindBin;

our %code;
our %data;

## load AMOS7::CHKSUM ##
use lib 'data/lib-path/pm';
use AMOS7::CHKSUM;

## stub subroutines ##
$code{'chk-sum.amos'}          = sub { AMOS7::CHKSUM::amos_chksum(shift) };
$code{'base.chk-sum.amos'}     = $code{'chk-sum.amos'};
$code{'base.time'}             = sub { sprintf '%.*f', $_[0] // 7, time };
$code{'base.logs'}             = sub { my ( $lvl, $fmt, @args ) = @_; };
$code{'base.log'}              = sub { };
$code{'base.perlmod.load'}     = sub { eval "require $_[0]" };
$code{'format.yaml.load_file'} = sub {
    my $path = shift;
    require YAML::XS;
    YAML::XS::LoadFile($path);
};

## helper to transform protocol-7 syntax ##
sub transform_p7_code {
    my ($src) = @_;
    $src =~ s|(?<!\\)<\[(\$\w+)\]>\s*->\(|\$code{$1}->(|g;
    $src =~ s|(?<!\\)<\[(\$\w+)\]>|\$code{$1}->()|g;
    $src =~ s|(?<!\\)<\[(\w[\w\-\.]*)\]>\s*->\(|\$code{'$1'}->(|g;
    $src =~ s|(?<!\\)<\[(\w[\w\-\.]*)\]>|\$code{'$1'}->()|g;
    $src =~ s|(?<!\\)<([\w\-:]+\.[\w\-\.:]+)>|
        do { my $k = "\$data{'$1'}"; $k =~ s<\.><'}{'>g; $k }|ge;
    return $src;
}

## load module file ##
sub load_module {
    my ($mod_name) = @_;
    my $path = "modules/$mod_name";
    open my $fh, '<', $path or die "cannot read $path: $!";
    local $/ = undef;
    my $src = <$fh>;
    close $fh;
    $src = transform_p7_code($src);
    my $sub = eval '
        use constant TRUE  => 5;
        use constant FALSE => 0;
        sub { ' . $src . ' }
    ';
    die "compile error in $mod_name: $@" if $@;
    $code{$mod_name} = $sub;
}

## initialize state ##
$data{'ncode'}{'patterns'}           = {};
$data{'ncode'}{'pending'}            = {};
$data{'ncode'}{'workflows'}          = {};
$data{'ncode'}{'cfg'}{'pattern_dir'} = 'data/yaml/ncode-patterns';
$data{'system'}{'root_path'}         = File::Spec->rel2abs('.');

## load modules in dependency order ##
load_module('ncode.init_code');
load_module('space.template.chain');
load_module('ncode.regex.load');
load_module('ncode.regex.save');
load_module('ncode.regex.apply');
load_module('ncode.cmd.suggest');
load_module('ncode.cmd.apply');
load_module('ncode.cmd.workflow');

## run init ##
$code{'ncode.init_code'}->();

print "=== test 1: load patterns ===\n";
my $load_result = $code{'ncode.regex.load'}
    ->( { 'file' => 'data/yaml/ncode-patterns/p7-common.yaml' } );
print "load mode: ", $load_result->{'mode'}, "\n";
print "patterns loaded: ", scalar( keys %{ $data{'ncode'}{'patterns'} } ),
    "\n";
print "workflows loaded: ", scalar( keys %{ $data{'ncode'}{'workflows'} } ),
    "\n";

## create test file with issues ##
my $test_file = 'modules/test.ncode-issues';
open my $tfh, '>', $test_file or die $!;
print {$tfh} <<'TESTCODE';
## [:< ##

# name  = test.ncode-issues
# descr = test file with known issues for ncode patterns

my $data = $_;

my $tree = $data{'space'}{'node'}{'value'};
my $flat = data..space.name;

if ( exists $code{'base.logs'} ) {
    print "module loaded\n";
}

## THIS IS AN UPPERCASE COMMENT -- bad style

#,,.,,,..,,,,,,.,,,,..,,,,,...,,.,,,..,.,.,.,,,..,,...,...,.,,,.,.,.,.,,..,,..,
#QVUNDNH3UA46OV5L4PUHRA2UXEI7CAZW2GUQWSUQ4TUF3E4GSAQX5MFB6L44G7BLTLQT2QTB7EG5G

TESTCODE
close $tfh;

print "\n=== test 2: suggest fixes ===\n";
my $suggest_result
    = $code{'ncode.cmd.suggest'}->( { 'files' => [$test_file] } );
print "suggest mode: ", $suggest_result->{'mode'}, "\n";
print "output:\n",      $suggest_result->{'data'}, "\n";

## extract session and fix_id from output ##
my ($session_root) = $suggest_result->{'data'} =~ m|^session:\s*(\S+)|m;
my @fix_ids = $suggest_result->{'data'} =~ m|^([A-Z0-9]{7})\s+|mg;
print "session root: $session_root\n" if $session_root;
print "fix ids found: ", join( ', ', @fix_ids ), "\n" if @fix_ids;

print "\n=== test 3: apply by first fix_id ===\n";
if (@fix_ids) {
    my $apply_result
        = $code{'ncode.cmd.apply'}->( { 'ids' => [ $fix_ids[0] ] } );
    print "apply mode: ", $apply_result->{'mode'}, "\n";
    print "result: ",     $apply_result->{'data'}, "\n";
}

print "\n=== test 4: apply all from session ===\n";
if ($session_root) {
    ## reset test file ##
    open my $tfh2, '>', $test_file or die $!;
    print {$tfh2} <<'TESTCODE';
## [:< ##

# name  = test.ncode-issues
# descr = test file with known issues for ncode patterns

my $data = $_;

if ( exists $code{'base.logs'} ) {
    print "module loaded\n";
}

## THIS IS AN UPPERCASE COMMENT -- bad style

#,,.,,,..,,,,,,.,,,,..,,,,,...,,.,,,..,.,.,.,,,..,,...,...,.,,,.,.,.,.,,..,,..,
#QVUNDNH3UA46OV5L4PUHRA2UXEI7CAZW2GUQWSUQ4TUF3E4GSAQX5MFB6L44G7BLTLQT2QTB7EG5G

TESTCODE
    close $tfh2;

    my $apply_result
        = $code{'ncode.cmd.apply'}->( { 'session' => $session_root } );
    print "apply mode: ", $apply_result->{'mode'}, "\n";
    print "result: ",     $apply_result->{'data'}, "\n";
}

print "\n=== test 5: run workflow frame ===\n";
## reset test file again ##
open my $tfh3, '>', $test_file or die $!;
print {$tfh3} <<'TESTCODE';
## [:< ##

# name  = test.ncode-issues
# descr = test file with known issues for ncode patterns

my $data = $_;

if ( exists $code{'base.logs'} ) {
    print "module loaded\n";
}

## THIS IS AN UPPERCASE COMMENT -- bad style

#,,.,,,..,,,,,,.,,,,..,,,,,...,,.,,,..,.,.,.,,,..,,...,...,.,,,.,.,.,.,,..,,..,
#QVUNDNH3UA46OV5L4PUHRA2UXEI7CAZW2GUQWSUQ4TUF3E4GSAQX5MFB6L44G7BLTLQT2QTB7EG5G

TESTCODE
close $tfh3;

my $wf_result = $code{'ncode.cmd.workflow'}->(
    {   'name'  => 'kimi-output-review',
        'files' => [$test_file]
    }
);
print "workflow mode: ", $wf_result->{'mode'}, "\n";
print "result: ",        $wf_result->{'data'}, "\n";

## clean up ##
unlink $test_file;
print "\n=== cleaned test file ===\n";

## verify patterns still in memory ##
print "patterns in memory: ", scalar( keys %{ $data{'ncode'}{'patterns'} } ),
    "\n";
print "workflows in memory: ",
    scalar( keys %{ $data{'ncode'}{'workflows'} } ), "\n";

print "\nall tests completed.\n";

#,,,.,,..,,..,,.,,,,,,,..,,,,,,,.,.,,,.,,,,..,..,,...,...,,,.,..,,,..,,..,,,.,
#OQCJY2TVG34HSSXSSC5RYWWJ3LHAILCFZPSTO5OKRGBTUB5KFIQW65C2MTQG3TXEY6OZJGO42VBPM
#\\\|MGXRN5DASYP6FKZJ3L56WGRZPUPTNQZWWBMSMMCNEDAGDRXCZW4 \ / AMOS7 \ YOURUM ::
#\[7]T7U4WWFTKKOOUOYYZZ32MTBT6V3TS4J27JJKCRIQWXQ57ZNQ3ACY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
