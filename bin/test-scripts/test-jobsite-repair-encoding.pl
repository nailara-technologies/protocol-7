#!/usr/bin/perl
use v5.24;
use strict;
use English;
use warnings;
use utf8;

###                                                                 ###
##  jobsite.util.repair_mojibake : standalone harness                ##
###                                                                 ###

## exercises the real translated module source of the repair-encoding ##
## sweep's per-string and per-job steps - no live zenka required :    ##
## - mojibake german is reversed, already correct german untouched    ##
## - double and triple encoding reversed, the 3 pass cap holds        ##
## - a real c1 control or a char above 0xFF : not reversible, kept    ##
## - a real 'ß' before nbsp is text, not a lead byte [ U+07E0 ]       ##
## - a failed attempt leaves the input string intact                  ##
## - job level : only the text fields, counts and escaped examples    ##

use Encode ();
use File::Spec;
use Cwd     qw| abs_path |;
use FindBin qw| $RealBin |;

binmode STDOUT, ':encoding(UTF-8)';

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

##[ p7 runtime environment stubs ]############################################

use constant TRUE  => 5;
use constant FALSE => 0;

our %data;
our %code;
our $call;

##[ module compilation [ same sub-wrapper shape as bin/Protocol-7 ] ]#########

my $fail_count = 0;

sub compile_module {
    my $module_name = shift;
    my $src_path
        = File::Spec->catfile( $main::root_path, 'src', $module_name );
    open( my $fh, '<:encoding(UTF-8)', $src_path )
        or die "cannot read $src_path : $!";
    my $src = join( '', <$fh> );
    close($fh);
    my $translated = p7_syntax__translate($src);
    my $cref       = eval "sub {\n# line 1 \"$module_name\"\n$translated\n}";
    die "compile failed for $module_name : $EVAL_ERROR"
        if not defined $cref;
    $code{$module_name} = $cref;
    return $cref;
}

compile_module($ARG) for qw|
    jobsite.util.repair_mojibake
    jobsite.repair_encoding.example
    jobsite.repair_encoding.job
    jobsite.repair_encoding.location
    |;

sub repair { return $code{'jobsite.util.repair_mojibake'}->(shift) }

##[ fixtures ]################################################################

## mojibake is generated, not pasted : utf-8 bytes read back as latin-1, n ##
## times [ a pasted 'Ãƒ' would hold U+0192, not the real byte 0x83 ]       ##
sub mojibake {
    my ( $text, $times ) = @ARG;
    $text = Encode::decode( 'latin1', Encode::encode( 'UTF-8', $text ) )
        for 1 .. $times // 1;
    return $text;
}

my $german = 'Systemadministrator für Linux-Server – Großraum '
    . 'Offenburg, Öffnungszeiten, Ärzte, Übernahme';

##[ tiny assertion framework ]################################################

sub ok ($;$) {
    my ( $cond, $label ) = @ARG;
    if ($cond) { say "  ok   : $label"; return }
    $fail_count++;
    say "  FAIL : $label";
    return;
}

sub is_str {
    my ( $got, $expected, $label ) = @ARG;
    return ok( 1, $label ) if defined $got and $got eq $expected;
    $fail_count++;
    say "  FAIL : $label";
    say "    expected : $expected";
    say '    got      : ' . ( $got // '<undef>' );
    return;
}

##[ 1 : mojibake german ]#####################################################

say ': mojibake german';

my $broken = mojibake($german);
ok( $broken =~ m|Ã¼|,            'fixture holds Ã¼ for ü' );
ok( $broken =~ m|â\x{80}\x{93}|, 'fixture holds â + c1 bytes for the dash' );

my $r = repair($broken);
is_str( $r->{'state'},  'repaired', 'state repaired' );
is_str( $r->{'text'},   $german,    'original text restored' );
is_str( $r->{'passes'}, 1,          'one pass' );

## known limit : text whose correct form is itself mojibake-shaped cannot ##
## be told apart from one more encoding level -- it is reversed too       ##
is_str( repair( mojibake('Ã¤rger') )->{'text'},
    'ärger', 'literal mojibake-shaped text : reversed as one more level' );

##[ 2 : already correct german ]##############################################

say ': already correct german';

$r = repair($german);
is_str( $r->{'state'}, 'clean', 'correct german is clean' );
is_str( $r->{'text'},  $german, 'text untouched' );

for my $plain ( 'Straße', 'Müller GmbH', 'café « ' . 'crème » ¿qué?',
    'ASCII only' ) {
    is_str( repair($plain)->{'state'}, 'clean', "clean : $plain" );
}
is_str( repair('')->{'state'},    'clean', 'empty string clean' );
is_str( repair(undef)->{'state'}, 'clean', 'undef clean' );

##[ 3 : double, triple and quadruple encoding ]###############################

say ': multiple encodings';

$r = repair( mojibake( $german, 2 ) );
is_str( $r->{'state'},  'repaired', 'double encoded : repaired' );
is_str( $r->{'text'},   $german,    'double encoded : original restored' );
is_str( $r->{'passes'}, 2,          'double encoded : two passes' );

$r = repair( mojibake( $german, 3 ) );
is_str( $r->{'text'},   $german, 'triple encoded : original restored' );
is_str( $r->{'passes'}, 3,       'triple encoded : three passes' );

my $quad = mojibake( $german, 4 );
$r = repair($quad);
is_str( $r->{'passes'}, 3, 'quadruple encoded : stops at the cap of 3' );
is_str(
    $r->{'text'},
    mojibake( $german, 1 ),
    'quadruple encoded : one level left after the cap'
);

##[ 4 : not reversible ]######################################################

say ': not reversible';

## real c1 control [ NEL ] after an ascii char : no utf-8 lead byte ##
my $c1      = mojibake('ändern') . " Zeile\x{85}Ende";
my $c1_copy = $c1;
$r = repair($c1);
is_str( $r->{'state'}, 'irreversible', 'real c1 control : irreversible' );
is_str( $r->{'text'},  $c1_copy,       'real c1 control : text kept' );
is_str( $c1,           $c1_copy,       'input string not clobbered' );

my $wide      = mojibake('Büro') . ' 10 €';
my $wide_copy = $wide;
$r = repair($wide);
is_str( $r->{'state'}, 'irreversible',
    'char above 0xFF mixed ' . 'in : irreversible' );
is_str( $wide, $wide_copy, 'input string not clobbered [ encode failure ]' );

## a lone continuation pair that does not form valid utf-8 ##
$r = repair("Ã\x{85}\x{85}");
is_str( $r->{'state'}, 'irreversible',
    'invalid utf-8 ' . 'sequence : irreversible' );

## a real 'ß' before nbsp is valid utf-8 as bytes [ U+07E0 ] : the  ##
## signature does not take it for a lead, nor the result for german ##
my $nbsp_text = "Hans Groß\x{A0}GmbH, Straße\x{A0}5";
is_str( repair($nbsp_text)->{'state'}, 'clean', 'ß + nbsp : clean' );
is_str( repair( mojibake($nbsp_text) )->{'text'},
    $nbsp_text, 'ß + nbsp mojibake : restored exactly' );
$r = repair( mojibake( $nbsp_text, 2 ) );
is_str( $r->{'text'}, $nbsp_text,
    'ß + nbsp double ' . 'encoded : no over-repair' );
is_str( $r->{'passes'}, 2, 'ß + nbsp double encoded : two passes' );
is_str( repair( mojibake('Büro') . " Groß\x{A0}GmbH" )->{'state'},
    'irreversible', 'mojibake mixed with a real ß + nbsp : irreversible' );

##[ 5 : job level ]###########################################################

say ': job level';

my $job = {
    'title'       => mojibake('Linux-Administrator (m/w/d) – Rechenzentrum'),
    'company'     => mojibake( 'Müller & Söhne GmbH', 2 ),
    'city'        => 'Offenburg',
    'description' => mojibake('Wir prüfen Ihre Unterlagen') . "\x{85}",
    'industry'    => mojibake('Öffentlicher Dienst'),
    'notes'       => mojibake('nicht prüfen'),
    'url'         => 'https://example.invalid/job',    ## example value ##
};
my %before = $job->%*;

my $check = $code{'jobsite.repair_encoding.job'}->($job);
is_str( $check->{'repaired'},     3, 'three fields repairable' );
is_str( $check->{'irreversible'}, 1, 'description with c1 : not reversible' );
is_str( $check->{'multi_pass'},   1, 'company double encoded' );
is_str(
    $check->{'fixed'}{'title'},
    'Linux-Administrator (m/w/d) – Rechenzentrum',
    'title restored'
);
is_str(
    $check->{'fixed'}{'company'},
    'Müller & Söhne GmbH',
    'company restored'
);
is_str(
    $check->{'fixed'}{'industry'},
    'Öffentlicher Dienst',
    'industry restored'
);
ok( !exists $check->{'fixed'}{'notes'},
    'non text field [ ' . 'notes ] left alone'
);
ok( !exists $check->{'fixed'}{'city'}, 'clean city not in the fix list' );
ok( !grep( { $job->{$ARG} ne $before{$ARG} } keys %before ),
    'job record not modified by the check' );

my ($ex) = grep { $ARG->{'field'} eq 'description' } $check->{'examples'}->@*;
ok( !defined $ex, 'no example for the not reversible field' );
($ex) = grep { $ARG->{'field'} eq 'title' } $check->{'examples'}->@*;
ok( defined $ex && $ex->{'before'} !~ m|[\x80-\x9F]|,
    'example before text has no raw c1 bytes'
);
ok( defined $ex && $ex->{'before'} =~ m|\\x\{80\}|,
    'example before text shows c1 bytes escaped'
);
ok( defined $ex && $ex->{'after'} =~ m|–|, 'example after text readable' );

##[ 6 : file locations ]######################################################

say ': file locations';

my $loc = $code{'jobsite.repair_encoding.location'};
is_str( $loc->( 7, 'review' )->{'rel_path'},
    'jobs/review/7.yaml', 'active job path' );
is_str(
    $loc->( 7, 'trash:V7ABCDE' )->{'rel_path'},
    'jobs/trash/V7ABCDE/7.yxz.B32',
    'packed trash path'
);
is_str( $loc->( 7, 'deleted:V7ABCDE' )->{'store'},
    'deleted', 'deleted store' );
is_str( $loc->( 7, 'blocked:V7ABCDE' )->{'rel_path'},
    'jobs/blocked/V7ABCDE/7.yaml', 'blocked stub path' );

##[ 7 : sweep over a temporary store [ dry run, then apply ] ]################

say ': sweep';

## the real command, tick handler and sweep steps. the store primitives    ##
## [ job.read \ job.write \ index.build ] are stand-ins writing plain yaml ##
## with the same path rules -- trash is not packed here                    ##
compile_module($ARG) for qw|
    jobsite.cmd.repair-encoding
    jobsite.handler.repair-encoding-tick
    jobsite.repair_encoding.load
    jobsite.repair_encoding.scan_one
    jobsite.repair_encoding.backup
    jobsite.repair_encoding.write_one
    jobsite.repair_encoding.finish
    |;

require File::Temp;
require File::Path;
require YAML::XS;
require Archive::Tar;
require IO::Compress::Xz;
require IO::Uncompress::UnXz;
require Time::HiRes;

my $var_dir = File::Temp::tempdir( CLEANUP => 1 );
my $jobsite = "$var_dir/jobsite";
$data{'system'}{'path'}{'zenka-dirs'} = { 'var_P7' => $var_dir };

my @timers;
my @replies;
my $write_count = 0;
$code{'base.logs'}               = sub {return};
$code{'base.perlmod.autoload'}   = sub { return TRUE };
$code{'base.ntime.b32'}          = sub { return 'V7TESTRUN' };
$code{'jobsite.job.index.build'} = sub {return};
$code{'event.add_timer'}         = sub { push @timers,  shift;   return };
$code{'base.callback.cmd_reply'} = sub { push @replies, $ARG[1]; return };
$code{'file.make_path'}
    = sub { File::Path::make_path( $ARG[0], { 'mode' => $ARG[1] } ) };

sub job_file {
    my ( $id, $index ) = @ARG;
    return "$jobsite/"
        . $code{'jobsite.repair_encoding.location'}->( $id, $index )
        ->{'rel_path'};
}
$code{'jobsite.job.read'} = sub {
    my $id = shift;
    return YAML::XS::LoadFile(
        job_file( $id, $data{'jobsite'}{'job'}{'index'}{$id} ) );
};
$code{'jobsite.job.write'} = sub {
    my ( $id, $job ) = @ARG;
    my $status = $job->{'status'} // 'new';
    my $index
        = $status =~ m{^(?:blocked|deleted|trash)$}
        ? "$status:" . ( $job->{"${status}_epoch"} // 'V7NOWNOW' )
        : $status;
    my $path = job_file( $id, $index );
    File::Path::make_path( $path =~ s|/[^/]+$||r );
    $job->{'last_modified'} = 'V7WRITTEN';
    YAML::XS::DumpFile( $path, $job );
    chmod 0640, $path;
    $data{'jobsite'}{'job'}{'index'}{$id} = $index;
    $write_count++;
    return TRUE;
};

my %fixture = (
    1 => [ 'review', { 'status' => 'review', 'title' => mojibake($german) } ],
    2 => [ 'new',    { 'status' => 'new',    'title' => $german } ],
    3 => [
        'deleted:V7AAAAA',
        {   'status'      => 'deleted',
            'description' => mojibake( 'Prüfung', 2 )
        }
    ],
    4 => [
        'trash:V7AAAAA',
        {   'status'      => 'trash',
            'trash_epoch' => 'V7AAAAA',
            'company'     => mojibake('Bäckerei')
        }
    ],
    5 => [ 'blocked:V7AAAAA', { 'status' => 'blocked', 'url' => 'x' } ],
    6 => [ 'review', { 'status' => 'applied', 'title' => mojibake('für') } ],
    7 => [ 'new',    { 'status' => 'new',     'city'  => $c1_copy } ],
    8 => [ 'deleted:V7AAAAA', { 'status' => 'blocked', 'url' => 'y' } ],
);
for my $id ( sort keys %fixture ) {
    my ( $index, $job ) = $fixture{$id}->@*;
    my $path = job_file( $id, $index );
    File::Path::make_path( $path =~ s|/[^/]+$||r );
    YAML::XS::DumpFile( $path, $job );
    chmod 0604, $path;
    $data{'jobsite'}{'job'}{'index'}{$id} = $index;
}
$data{'jobs'}{'store'}
    = {
    map { $ARG => YAML::XS::LoadFile( job_file( $ARG, $fixture{$ARG}[0] ) ) }
        qw| 1 2 6 7 | };
my $store_job = $data{'jobs'}{'store'}{1};

sub sweep {
    my $args = shift;
    local $call = { 'args' => $args, 'reply_id' => 1 };
    @replies = ();
    my $reply = $code{'jobsite.cmd.repair-encoding'}->();
    my $ticks = 0;
    while ( my $timer = shift @timers ) {
        my $event = bless { 'data' => $timer->{'data'} }, 'FakeEvent';
        $code{ $timer->{'handler'} }->($event);
        die 'sweep does not end' if ++$ticks > 1000;
    }
    return ( $reply, $replies[0] );
}

my ( $first, $report ) = sweep('');
is_str( $first->{'mode'}, 'deferred', 'dry run : deferred reply' );
ok( defined $report && $report->{'mode'} eq 'size', 'dry run : report sent' );
my $text = Encode::decode( 'UTF-8', $report->{'data'} // '' );
ok( $text
        =~ m|active  : 4 checked, 2 repairable \[ 2 strings, 0 multi-encoded, 1 skipped : status != dir \], 1 strings not reversible|,
    'dry run : active counts [ mismatch skipped, c1 counted ]'
);
ok( $text
        =~ m|deleted : 2 checked, 1 repairable \[ 1 strings, 1 multi-encoded, 0 skipped|,
    'dry run : deleted counts'
);
ok( $text =~ m|trash   : 1 checked, 1 repairable|, 'dry run : trash counts' );
ok( $text =~ m|blocked : 1 stubs|, 'dry run : blocked stubs counted' );
ok( $text =~ m|^dry run : 8 jobs indexed|,   'dry run : header line' );
ok( $text =~ m|before : .*\\x\{8[0-9A-F]\}|, 'dry run : escaped example' );
is_str( $write_count, 0, 'dry run : nothing written' );
ok( !-d "$jobsite/repair-encoding", 'dry run : no backup' );
my $busy = do {
    local $call = { 'args' => '', 'reply_id' => 2 };
    my $r1 = $code{'jobsite.cmd.repair-encoding'}->();
    my $r2 = $code{'jobsite.cmd.repair-encoding'}->();
    @timers = ();
    delete $data{'jobsite'}{'repair_encoding'};
    $r2;
};
is_str( $busy->{'mode'}, 'false', 'second sweep while one runs : refused' );

( $first, $report ) = sweep('apply');
$text = Encode::decode( 'UTF-8', $report->{'data'} // '' );
is_str( $write_count, 3, 'apply : three jobs written' );
ok( $text =~ m|backup : (\S+)|, 'apply : backup path in the reply' );
my $backup = $1 // '';
ok( -f $backup && ( ( stat $backup )[2] & 07777 ) == 0600,
    'apply : backup file exists, mode 0600' );

my ( $tar_xz, $tar_data );
{
    local $INPUT_RECORD_SEPARATOR;
    open my $fh, '<:raw', $backup;
    $tar_xz = <$fh>
}
IO::Uncompress::UnXz::unxz( \$tar_xz, \$tar_data );
open my $tar_fh, '<', \$tar_data;
my $tar = Archive::Tar->new($tar_fh);
is_str(
    join( ' ', sort $tar->list_files ),
    'jobs/deleted/V7AAAAA/3.yaml '
        . 'jobs/review/1.yaml jobs/trash/V7AAAAA/4.yxz.B32',
    'apply : backup holds exactly the changed files'
);
ok( $tar->get_content('jobs/review/1.yaml') =~ m|\\x80|,
    'apply : backup holds the original bytes'
);

is_str( YAML::XS::LoadFile( job_file( 1, 'review' ) )->{'title'},
    $german, 'apply : active job repaired on disk' );
is_str( $store_job->{'title'}, $german,
    'apply : in-memory ' . 'store record repaired' );
is_str( $store_job->{'last_modified'},
    'V7WRITTEN',
    'apply : store record stamped [ next sync push carries it ]' );
my $deleted = YAML::XS::LoadFile( job_file( 3, 'deleted:V7AAAAA' ) );
is_str( $deleted->{'description'},
    'Prüfung', 'apply : deleted ' . 'job repaired' );
is_str( $deleted->{'deleted_epoch'},
    'V7AAAAA', 'apply : deleted job kept in its epoch bucket' );
ok( !-d "$jobsite/jobs/deleted/V7NOWNOW", 'apply : no new epoch bucket' );
is_str( YAML::XS::LoadFile( job_file( 4, 'trash:V7AAAAA' ) )->{'company'},
    'Bäckerei', 'apply : trash job repaired' );
is_str( ( stat job_file( 1, 'review' ) )[2] & 07777,
    0604, 'apply : file mode kept' );
is_str( YAML::XS::LoadFile( job_file( 6, 'review' ) )->{'title'},
    mojibake('für'), 'apply : status mismatch job untouched' );
is_str( YAML::XS::LoadFile( job_file( 7, 'new' ) )->{'city'},
    $c1_copy, 'apply : not reversible job untouched' );

( undef, $report ) = sweep('apply');
is_str( $write_count, 3, 'second apply : nothing left to write' );
ok( $report->{'data'} !~ m|backup :|, 'second apply : no empty backup' );

package FakeEvent {
    sub w    { return $_[0] }
    sub data { return $_[0]{'data'} }
}

##[ result ]##################################################################

say '';
if ($fail_count) {
    say ":: $fail_count test(s) FAILED";
    exit 1;
}
say ':: all tests passed';
exit 0;

#,,..,.,.,.,.,,..,...,.,,,..,,,,,,..,,..,,..,,..,,...,...,.,,,,..,,..,,.,,.,,,
#SX2QSP7GYDIEU4X44TADWSWJBHBD27TFNC5C62VTQTSIVAENDDW7A6WWJA6XY3RXQ4N2GSNDPH5R6
#\\\|VN3UTYHTEEBGGRBIADOVDFONMDPGMCYZQBNEJXI6EKHUBFGCGGF \ / AMOS7 \ YOURUM ::
#\[7]ZJEMCDAJGKVWLHML2OFYCFDEDRD3A6X5NH3KXZ27MN5IIQFZREAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
