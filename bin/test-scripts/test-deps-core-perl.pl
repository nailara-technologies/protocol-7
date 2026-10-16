#!/usr/bin/env perl
use v5.32;
use strict;
use English;
use warnings;
no warnings 'once';    ## single fully-qualified package var reads below ##

## bin/p7-deps and data/lib-path/pm/AMOS7/deps/*.pm must load and run on    ##
## CORE PERL ONLY [ plus data/lib-path/pm ] so a future standalone installer ##
## works on a bare Debian host. the real check is a child perl whose @INC is ##
## stripped to exactly [ data/lib-path/pm, $Config{privlibexp},              ##
## $Config{archlibexp} ] with PERL5LIB unset : every deps module,            ##
## AMOS7::TERM::Frame and the lib-path YAML::Tiny copy must load there, and  ##
## bin/p7-deps help \ check-service must exit 0 in that same stripped        ##
## environment [ check-service against a P7_DEPS_SERVICE_ROOT temp root with ##
## a stubbed systemctl ]. a second part runs in a normal perl : the          ##
## %AMOS7::TERM::p7_colors glob alias must be the very same hash as           ##
## %AMOS7::TERM::Frame::p7_colors [ refaddr ], AMOS7::TERM must still export  ##
## the frame subs, and frame_border_line and friends must render             ##
## byte-identically to their pre-move output [ literals captured from        ##
## AMOS7::TERM before the move into ::Frame ].                               ##

use Config;
use File::Spec;
use Cwd          qw| abs_path |;
use FindBin      qw| $RealBin |;
use File::Temp   qw| tempdir |;
use File::Path   qw| make_path |;
use Scalar::Util qw| refaddr |;
use B            qw| perlstring |;

use constant { TRUE => 5, FALSE => 0 };

BEGIN {
    my $root_path = abs_path(
        File::Spec->rel2abs(
            File::Spec->catdir(
                $RealBin, File::Spec->updir, File::Spec->updir
            )
        )
    );
    $main::root_path = $root_path;
    $main::lib_path
        = File::Spec->catdir( $root_path, qw| data lib-path pm | );
    unshift( @INC, $main::lib_path );
}

my $root_path = $main::root_path;
my $lib_path  = $main::lib_path;

my $pass_count = 0;
my $fail_count = 0;

sub check {
    my ( $label, $cond ) = @_;
    if ($cond) {
        $pass_count++;
        printf "ok   : %s\n", $label;
    } else {
        $fail_count++;
        printf "FAIL : %s\n", $label;
    }
    return $cond;
}

sub write_file {
    my ( $path, $content ) = @_;
    open my $fh, '>', $path or die "cannot write $path : $OS_ERROR";
    print {$fh} $content;
    close $fh;
    return TRUE;
}

sub slurp {
    my ($path) = @_;
    open my $fh, '<', $path or return undef;
    local $INPUT_RECORD_SEPARATOR = undef;
    my $content = <$fh>;
    close $fh;
    return $content;
}

## run a command, capture stdout and exit code [ list form exec, no shell ] ##

sub run_capture {
    my (@cmd) = @_;

    my $pid = open( my $pipe, '-|' ) // die "fork failed : $OS_ERROR";
    if ( $pid == 0 ) {
        exec(@cmd) or exit 127;
    }
    local $INPUT_RECORD_SEPARATOR = undef;
    my $output = <$pipe> // '';
    close($pipe);
    return ( $CHILD_ERROR >> 8, $output );
}

## --- part 1 : stripped-@INC child [ core perl only + data/lib-path/pm ]   ##
## ------------------------------------------------------------------------ ##

## every module load is its own child : a require failure must not mask the ##
## modules that come after it                                               ##

my @core_modules = qw|
    AMOS7::deps::backend::debian
    AMOS7::deps::debp
    AMOS7::deps::dist_upgr
    AMOS7::deps::module
    AMOS7::deps::os_package
    AMOS7::deps::service
    AMOS7::deps::tracked
    AMOS7::TERM::Frame
    |;

sub stripped_load {
    my ($module) = @_;
    my $child    = sprintf <<'EOF', B::perlstring($lib_path), $module;
BEGIN {
    my $lib = %s;
    use Config;
    @INC = ( $lib, $Config::Config{privlibexp},
        $Config::Config{archlibexp} );
}
my $mod = '%s';
my $ok  = eval "require $mod";
if ($ok) {
    printf "loaded %%s\n", $mod;
} else {
    ( my $err = $@ ) =~ s|\n.*||s;
    printf "FAIL %%s : %%s\n", $mod, $err;
    exit 1;
}
## nothing non-core may have been pulled in ##
for my $forbidden ( qw| File/Which.pm Event.pm Term/ReadLine.pm
    Crypt/PRNG/Fortuna.pm YAML/Tiny.pm | ) {
    if ( exists $INC{$forbidden} ) {
        printf "FAIL %%s pulled in %%s\n", $mod, $forbidden;
        exit 1;
    }
}
exit 0;
EOF
    local $ENV{'PERL5LIB'} = undef;
    my ( $exit, $out ) = run_capture( $EXECUTABLE_NAME, '-e', $child );
    chomp $out;
    return ( $exit, $out );
}

for my $module (@core_modules) {
    my ( $exit, $out ) = stripped_load($module);
    check "$module loads on core perl only", $exit == 0;
    printf "       : %s\n", $out if $exit != 0;
}

## YAML::Tiny must load from the lib-path copy, not from the system site    ##

{
    my $child = sprintf <<'EOF', B::perlstring($lib_path);
BEGIN {
    my $lib = %s;
    use Config;
    @INC = ( $lib, $Config::Config{privlibexp},
        $Config::Config{archlibexp} );
}
my $ok = eval { require YAML::Tiny; 1 };
if ( not $ok ) {
    ( my $err = $@ ) =~ s|\n.*||s;
    printf "FAIL YAML::Tiny : %%s\n", $err;
    exit 1;
}
if ( index( $INC{'YAML/Tiny.pm'}, shift(@ARGV) ) != 0 ) {
    printf "FAIL YAML::Tiny from %%s\n", $INC{'YAML/Tiny.pm'};
    exit 1;
}
printf "YAML::Tiny %%s from lib-path\n", $YAML::Tiny::VERSION;
exit 0;
EOF
    local $ENV{'PERL5LIB'} = undef;
    my ( $exit, $out )
        = run_capture( $EXECUTABLE_NAME, '-e', $child, $lib_path );
    chomp $out;
    check 'YAML::Tiny loads from the lib-path copy', $exit == 0;
    printf "       : %s\n", $out;
}

## the shared terminal helpers render in the stripped environment, plain ##
## and coloured, and pull in nothing beyond core perl                    ##

{
    my $child = sprintf <<'EOF', B::perlstring($lib_path);
BEGIN {
    my $lib = %s;
    use Config;
    @INC = ( $lib, $Config::Config{privlibexp},
        $Config::Config{archlibexp} );
}
use AMOS7::TERM::Frame qw| frame_color_enabled frame_column_line
    frame_title_banner frame_section_header frame_status_row
    frame_error_line frame_progress_bar |;
my $n = 0;
for my $color ( 0, 1 ) {
    my $o = { color => $color };
    for my $s (
        frame_column_line( ':', $o ), frame_title_banner( 't', $o ),
        frame_section_header( 's', $o ), frame_status_row( 'l', 'ok', $o ),
        frame_error_line( 'tool', 'm', $o ), frame_progress_bar( 1, 2, 'f', $o )
    ) {
        $n++ if length $s and ( index( $s, "\e" ) >= 0 ) == $color;
    }
}
frame_color_enabled();
if ( $n != 12 ) { print "FAIL rendered $n of 12\n"; exit 1 }
for my $forbidden ( qw| File/Which.pm Event.pm Term/ReadLine.pm
    Crypt/PRNG/Fortuna.pm YAML/Tiny.pm | ) {
    if ( exists $INC{$forbidden} ) { print "FAIL pulled in $forbidden\n"; exit 1 }
}
print "12 helper renders\n";
exit 0;
EOF
    local $ENV{'PERL5LIB'} = undef;
    my ( $exit, $out ) = run_capture( $EXECUTABLE_NAME, '-e', $child );
    chomp $out;
    check 'frame helpers render plain + coloured on core perl only',
        $exit == 0;
    printf "       : %s\n", $out;
}

## bin/p7-install compiles and answers --help with @INC stripped before it ##
## loads anything [ BEGIN strip, then do <script> ] -- every module it     ##
## pulls in comes from data/lib-path/pm or the core perl dirs              ##

{
    my $script  = "$root_path/bin/p7-install";
    my $sandbox = tempdir( CLEANUP => 1 );
    my $inc_log = File::Spec->catfile( $sandbox, 'inc.log' );
    my $child   = sprintf <<'EOF', B::perlstring($script),
BEGIN {
    use Config;
    @INC = ( $Config::Config{privlibexp}, $Config::Config{archlibexp} );
    $0 = %s;
    $main::pre_strip{$_} = 1 for keys %%INC;
}
END {
    open my $fh, '>', %s or die;
    print {$fh} "$INC{$_}\n" for grep { not $main::pre_strip{$_} } keys %%INC;
    close $fh;
}
do $0;
die $@ if $@;
EOF
        B::perlstring($inc_log);
    local $ENV{'PERL5LIB'} = undef;
    my ( $exit, $out )
        = run_capture( $EXECUTABLE_NAME, '-e', $child, '--', '--help' );
    check 'bin/p7-install --help exits 0 on core perl only', $exit == 0;

    my @paths = map { abs_path($_) // $_ }
        grep { length and $_ ne $script } split m|\n|,
        slurp($inc_log) // '';
    my @foreign = grep {
                index( $_, $lib_path ) != 0
            and index( $_, $Config{privlibexp} ) != 0
            and index( $_, $Config{archlibexp} )
            != 0
    } @paths;
    check 'bin/p7-install loads only lib-path and core perl modules',
        ( @paths > 0 and not @foreign );
    printf "       : foreign %s\n", $_ for @foreign;
}

## bin/p7-deps help and check-service in the stripped environment           ##

my $svc_sandbox = tempdir( CLEANUP => 1 );
my $svc_root    = File::Spec->catdir( $svc_sandbox, 'root' );
my $stub_dir    = File::Spec->catdir( $svc_sandbox, 'stub' );
make_path($stub_dir);

write_file(
    File::Spec->catfile( $stub_dir, 'systemctl' ),
    sprintf <<'EOF', ($svc_sandbox) x 2
#!/bin/sh
if [ "$1" = "is-enabled" ]; then
    cat "%s/enabled.out" 2>/dev/null || echo disabled
fi
if [ "$1" = "is-active" ]; then
    cat "%s/active.out" 2>/dev/null || echo inactive
fi
exit 0
EOF
);
chmod( 0755, File::Spec->catfile( $stub_dir, 'systemctl' ) );

{
    local $ENV{'PERL5LIB'}             = undef;
    local $ENV{'PATH'}                 = $stub_dir . ':' . $ENV{'PATH'};
    local $ENV{'P7_DEPS_SERVICE_ROOT'} = $svc_root;

    my ( $exit, $out )
        = run_capture( $EXECUTABLE_NAME,
        "$root_path/bin/p7-deps", qw| help | );
    check 'bin/p7-deps help exits 0 on core perl only', $exit == 0;
    check 'help shows the dependency manager title',
        $out =~ m|Protocol-7\sDependency\sManager|;

    ( $exit, $out )
        = run_capture( $EXECUTABLE_NAME,
        "$root_path/bin/p7-deps", qw| install-service | );
    check 'install-service exit 0 on a test root', $exit == 0;

    ( $exit, $out )
        = run_capture( $EXECUTABLE_NAME,
        "$root_path/bin/p7-deps", qw| check-service | );
    check 'check-service exit 0 when all parts ok', $exit == 0;
    check 'check-service reports unit ok',          $out =~ m|unit\s[.]+\sok|;
    printf "       : check-service said [%s]\n", ( split m|\n|, $out )[-1]
        if $exit != 0;
}

## --- part 2 : normal perl -- the move must not change any caller's view   ##
## ------------------------------------------------------------------------ ##

require AMOS7::TERM;    ## pulls Event and friends : normal perl only ##

##[ color palette ]###########################################################

my $frame_colors = \%AMOS7::TERM::Frame::p7_colors;
check '%AMOS7::TERM::p7_colors is the same hash as ::Frame [ refaddr ]',
    refaddr( \%AMOS7::TERM::p7_colors ) == refaddr($frame_colors);

my %expected_colors = (
    'p7_fg_0000' => "\e[38;2;68;39;172m",
    'p7_fg_0001' => "\e[38;2;38;46;153m",
    'p7_fg_0002' => "\e[38;2;170;94;2m",
    'p7_fg_0003' => "\e[38;2;9;170;94m",
    'p7_fg_0004' => "\e[38;2;6;71;195m",
    'p7_fg_0005' => "\e[38;2;197;141;7m",
    'p7_fg_0006' => "\e[38;2;71;195;6m",
);
my $palette_ok = keys(%AMOS7::TERM::p7_colors) == keys(%expected_colors);
for my $key ( keys %expected_colors ) {
    $palette_ok = FALSE
        if !exists $AMOS7::TERM::p7_colors{$key}
        or $AMOS7::TERM::p7_colors{$key} ne $expected_colors{$key};
}
check 'p7_colors palette unchanged after the move', $palette_ok;

##[ exports ]#################################################################

AMOS7::TERM->import(
    qw| frame_border_line frame_rule_line frame_colorize_content frame_bar |);
check 'AMOS7::TERM still exports frame_border_line',
    defined &main::frame_border_line;
check 'AMOS7::TERM still exports frame_rule_line',
    defined &main::frame_rule_line;
check 'AMOS7::TERM still exports frame_colorize_content',
    defined &main::frame_colorize_content;
check 'AMOS7::TERM still exports frame_bar', defined &main::frame_bar;
check 'AMOS7::TERM::Frame exports via @EXPORT_OK',
    defined &AMOS7::TERM::Frame::frame_border_line;

##[ byte-identical rendering ]################################################

## expected literals captured from AMOS7::TERM before the move into ::Frame ##

my $R  = "\e[0m";
my $gr = "\e[38;2;71;195;6m";
my $bl = "\e[38;2;6;71;195m";
my $pu = "\e[38;2;68;39;172m";
my $am = "\e[38;2;197;141;7m";

check 'frame_border_line fill-only bar byte-identical',
    frame_border_line(
    {   width    => 10,
        reset    => $R,
        elements =>
            [ { type => 'fill', char => '━', min => 1, color => $gr } ],
    }
    ) eq "\e[38;2;71;195;6m━━━━━━━━━━\e[0m";

check 'frame_rule_line title + dashes byte-identical',
    frame_rule_line( ' title ', 24,
    { title => $bl, fill => $pu, reset => $R } ) eq "\e[38;2;6;71;195m title "
    . "\e[0m\e[38;2;68;39;172m-----------------\e[0m";

check 'frame_border_line anchor+slot+fill byte-identical',
    frame_border_line(
    {   width    => 12,
        reset    => '',
        elements => [
            { type => 'anchor', value => 'A', color => '' },
            { type => 'slot',   name  => 'x', color => $am },
            { type => 'fill',   char  => '.', min   => 1, color => '' },
        ],
        values => { x => 'val' },
    }
    ) eq "A\e[38;2;197;141;7mval........";

check 'frame_border_line two-fill split byte-identical',
    frame_border_line(
    {   width    => 10,
        reset    => $R,
        elements => [
            { type => 'fill', char => '-', min => 1, color => $bl },
            { type => 'fill', char => '=', min => 3, color => $gr },
        ],
    }
    ) eq "\e[38;2;6;71;195m--\e[0m\e[38;2;71;195;6m========\e[0m";

check 'frame_colorize_content label line byte-identical',
    frame_colorize_content( ': label : value :',
    { fill_colon => $pu, fill_eq => $gr, label => $bl, value => $am }, $R )
    eq "\e[38;2;68;39;172m:\e[0m \e[38;2;197;141;7mlabel "
    . ": value\e[0m \e[38;2;68;39;172m:\e[0m";

check 'frame_colorize_content separator row byte-identical',
    frame_colorize_content( ':.  ====  .:',
    { fill_colon => $pu, fill_eq => $gr }, $R ) eq
    "\e[38;2;68;39;172m:\e[0m.  ====  .\e[0m\e[38;2;68;39;172m:\e[0m";

check 'frame_bar half ' . 'byte-identical',
    frame_bar( 0.5, 10, ':' ) eq ':::::     ';
check 'frame_bar over 1 clamps byte-identical',
    frame_bar( 1.3, 6 ) eq '::::::';
check 'frame_bar under 0 clamps byte-identical',
    frame_bar( -0.2, 4, '#' ) eq '    ';

my $stderr_got = '';
my $undef_ret;
{
    open( my $old_stderr, '>&', STDERR ) or die "dup STDERR : $OS_ERROR";
    close(STDERR);
    open( STDERR, '>', \$stderr_got ) or die "redirect STDERR : $OS_ERROR";
    $undef_ret = frame_border_line(
        { width => 10, elements => [ { color => $gr } ] } );
    close(STDERR);
    open( STDERR, '>&', $old_stderr ) or die "restore STDERR : $OS_ERROR";
}
check 'frame_border_line without ' . 'type still returns undef',
    not defined $undef_ret;
check 'frame_border_line without type still warns on STDERR',
    $stderr_got =~ m|element type not defined|;

##[ probe_binary contract kept ]##############################################

require AMOS7::deps::os_package;
check 'probe_binary ' . 'finds sh',
    AMOS7::deps::os_package::probe_binary('sh') == 1;
check 'probe_binary misses a nonexistent name',
    AMOS7::deps::os_package::probe_binary('p7-definitely-not-a-binary') == 0;
check 'probe_binary by relative path',
    AMOS7::deps::os_package::probe_binary('/bin/sh') == 1;

## summary ##

printf "\n: %d checks passed, %d failed\n", $pass_count, $fail_count;
exit( $fail_count ? 1 : 0 );

#,,..,,.,,.,,,,..,.,.,.,,,,,.,...,..,,.,.,...,..,,...,...,,,.,,,,,,,.,,..,,..,
#TQQJEM66V337L3I6F37HIFC6DVEBADVNY4R6I6ZFD5WW3JGCG2XJ77WOKF3BKEBMRY5TU47CV5J42
#\\\|MCFX23CPPR5WAIHVAG4IOR42KFODRU5BSK7AVDRAPEQ567ITWDG \ / AMOS7 \ YOURUM ::
#\[7]L47OCUZ5Y547IQWQZJTD2YWQ3RFGS5XQ7XRTJGM2VCIPJ5PD5SBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
