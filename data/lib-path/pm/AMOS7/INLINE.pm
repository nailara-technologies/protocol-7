
package AMOS7::INLINE; #######################################################

use vars qw| @EXPORT $VERSION |;

##[ global constants ]##
use constant TRUE  => 5;    ##  TRUE.  ##
use constant FALSE => 0;    ##  false  ##

use Exporter;
use base qw| Exporter |;

use v5.24;
use strict;
use English;
use warnings;
use Config;
use Cwd             qw| abs_path |;
use File::Find      ();
use File::Temp      ();
use File::Path      qw| make_path |;
use Fcntl           qw| O_RDWR O_CREAT O_NOFOLLOW LOCK_EX LOCK_NB |;
use List::MoreUtils qw| minmax |;

## optional digest module : the core fallback below keeps this module    ##
## loadable without it [ cf. the Inline/C guard further down ] -- path   ##
## names stay printable and deterministic ; AMOS7::B32 is pure perl and  ##
## byte-identical to Crypt::Misc, so no optional dependency for encoding ##
use AMOS7::B32 qw| encode_b32r |;
eval { require Digest::BMW; Digest::BMW->import(qw| bmw_256 |) };

##[ AMOS MODULE ]#############################################################

use AMOS7;          ## error handling ##
use AMOS7::FILE;    ## get_homepath ##

our $devmod_output_to_console = FALSE;    ##  display build warnings  ##

##  set TRUE before this module compiles : pure-perl alternatives only   ##
our $force_pure_perl;

## known inline sourcecode modules ##
use AMOS7::INLINE::src::BitConv;
use AMOS7::INLINE::src::AMOS_13_ELF;
use AMOS7::INLINE::src::TruthAssertion;

##[ INITIALIZATIONS ]#########################################################

my $source_registry = {
    qw| inline_elf  |     => \&AMOS7::INLINE::src::AMOS_13_ELF::inline_elf,
    qw|  true_int   |     => \&AMOS7::INLINE::src::TruthAssertion::true_int,
    qw| true_float  |     => \&AMOS7::INLINE::src::TruthAssertion::true_float,
    qw|num_to_bit_string| => \&AMOS7::INLINE::src::BitConv::num_to_bit_string,
    qw|bit_string_to_num| => \&AMOS7::INLINE::src::BitConv::bit_string_to_num,
};

##  internal code_ref registry  ##
my $subroutines_installed //= {};

##  without Inline::C every subroutine takes its pure-perl alternative  ##
##
## $force_pure_perl : set before this module compiles                       ##
## [ e.g. in a BEGIN block ahead of the first 'use AMOS7::..' ] to skip the ##
## Inline::C probe and bind path unconditionally -- for processes that must ##
## never dlopen a compiled object out of the user-writable unsigned inline  ##
## cache [ ~/.7/inline-code, data/md/design/INLINE-OBJECT-TRUST.md ]        ##
my $inline_c_available = FALSE;

if ( not $force_pure_perl ) {
    eval qq| require 'Inline/C.pm' |;
    $inline_c_available = length $EVAL_ERROR ? FALSE : TRUE;
}
warn_err(
    "'Inline::C' is not available [ installed ? ] -- using pure-perl"
        . ' alternatives',
    1
) if not $inline_c_available and not $force_pure_perl;
## the forced switch stays silent on purpose : it is a deliberate       ##
## process-level choice [ not an abnormal state ], and load-time stderr ##
## noise breaks tooling that compiles files -- the choosing process     ##
## documents the switch at its own BEGIN block                          ##

@EXPORT = qw| compile_inline_source $VERSION |;

$VERSION = qw| AMOS7::INLINE-VERSION.YTOFXDA |;

return TRUE;    ## true ##

##[ COMPILATION TO TARGET PATH ]##############################################

sub compile_inline_source {
    my $params = shift // {};
    error_exit('expected hash reference <{C1}>')
        if defined $params and ref $params ne qw| HASH |;

    my $subroutine_name  = $params->{'subroutine-name'};
    my $target_package   = $params->{'target-package'};       ## optional ##
    my $inline_directory = $params->{'target-path'};          ## optional ##
    my $re_compile = $params->{'update-routine'} // FALSE;    ## optional ##

    my $uid = $params->{'uid'};                               ## optional ##
    my $gid = $params->{'gid'};                               ## optional ##

    ## check if root or current user and reset if required ## [LLL]

    return warn_err( "inline sourcecode for '%s' not defined",
        1, $subroutine_name )
        if defined $subroutine_name
        and not defined $source_registry->{$subroutine_name};

    my @subroutines
        = defined $subroutine_name
        ? ($subroutine_name)
        : reverse sort keys $source_registry->%*;

    return warn_err( 'no inline subroutines defined', 1 )
        if not @subroutines;

    ## keep track for error reporting ##
    my $total_subroutine_count = scalar @subroutines;

    ## target directory permissions and owner ##
    my @params = ( qw| mode | => 0755 );
    push( @params, qw|  uid  | => $uid ) if defined $uid;
    push( @params, qw| group | => $gid ) if defined $gid;

    my $success_count = 0;
    my $sub_coderefs  = {};
    my $single_func   = length( $subroutine_name // '' ) ? 1 : 0;

    foreach my $current_sub_name (@subroutines) {

        my $custom_inline_dir;    ##  common if specified  ##

        ### [RE]COMPILING \ LOADING .., ###

        if (   not defined $source_registry->{$current_sub_name}
            or not defined &{ $source_registry->{$current_sub_name} } ) {
            warn_err( "<< registry callback for '%s' not defined >>",
                0, $current_sub_name );
            next;
        }

        my $function_href;        ##  subroutine source  ##
        $function_href = $source_registry->{$current_sub_name}->();

        if ( ref $function_href ne qw| HASH | ) {
            warn_err( "<< expected hash ref for '%s' routine >>",
                0, $current_sub_name );
            next;
        } elsif ( not defined $function_href->{'source'} ) {
            warn_err( "<< '%s' sourcecode not present >>",
                0, $current_sub_name );
            next;
        }

        my $cleaned_source = clean_source( $function_href->{'source'} );
        my $fallback_ref   = $function_href->{'fallback'};   ## alternative ##
        $target_package //= $function_href->{'package'};     ## install to ##

        warn_err("target_package for $current_sub_name not defined")
            if not defined $target_package;

        ## skip already installed routines unless update-routine ##
        ##
        if (not $re_compile
            and defined $subroutines_installed->{
                sprintf '%s::%s',
                $target_package, $current_sub_name
            }
        ) {
            $total_subroutine_count--;    ## do not warn ##
            next;
        }

        ## preparing inline directory ##
        if ( defined $inline_directory and length $inline_directory ) {

            $custom_inline_dir = $inline_directory;

        } else {    ##  generate based on elf-chksum of subroutine source  ##

            $custom_inline_dir = gen_inline_path(
                sprintf qw| %s.%s.%s |,              $current_sub_name,
                encoded_bmw_chksum($cleaned_source), toolchain_key()
            );
        }

        ## check \ create inline directory ##
        ##
        return warn_err( 'inline directory not defined', 0 )
            if not defined $custom_inline_dir
            or not length $custom_inline_dir;

        return warn_err( "inline directory '%s' not readable [ repair ., ]",
            0, $custom_inline_dir )
            if -d $custom_inline_dir and not -r $custom_inline_dir;

        ## only the parent is created here : the object dir itself appears ##
        ## by one rename from a private build dir [ _build_slot ] -- no    ##
        ## build without Inline::C, a pure-perl process creates no dir     ##
        my ( $parent_dir, $object_dir_name )
            = $custom_inline_dir =~ m|^(.*)/([^/]+)/*$|;
        return warn_err( "inline directory '%s' has no parent",
            0, $custom_inline_dir )
            if not defined $object_dir_name
            or not length $parent_dir;

        if (    !-d $parent_dir
            and $inline_c_available
            and not $force_pure_perl ) {

            make_path( $parent_dir, {@params} )
                or return warn_err( ': %s : %s', 1,
                format_error( $OS_ERROR, -1 ), $parent_dir );

            return warn_err( "cannot create inline directory '%s'",
                1, $parent_dir )
                if !-d $parent_dir;
        }
        ## prepare matching precise @INC path ##
        $custom_inline_dir = sprintf '%s/%s',
            abs_path($parent_dir) // $parent_dir, $object_dir_name;

        ## remove previous installation ##
        eval "undef \\&$current_sub_name";
        eval "undef *${target_package}::$subroutine_name";

        ## temporary namespace to avoid subroutine 'redefined' : keyed on   ##
        ## the source chksum, not a load-order counter -- the name lands in ##
        ## the object [ boot symbol, build path ], so the same source       ##
        ## builds the same bytes in every process                           ##
        ## [ INLINE-OBJECT-TRUST.md ]                                       ##
        my $compilation_namespace = sprintf 'COMPILE::K%s::%s',
            encoded_bmw_chksum($cleaned_source), $target_package;

        my $compilation_target = sprintf '%s::%s',
            $compilation_namespace, $current_sub_name;

        ###                                                 ###
        ##  COMPILATION \ INSTALLATION OF INLINE SUBROUTINE  ##
        ###                                                 ###

        ## the dir Inline works in + lock + publish target ##
        my $build_slot;
        eval {
            die "'Inline::C' is not available\n"
                if not $inline_c_available or $force_pure_perl;
            $build_slot = _build_slot($custom_inline_dir);
            die "$build_slot->{'error'}\n" if defined $build_slot->{'error'};
            Inline->bind(
                qw|  C  |         => $cleaned_source,
                qw| name |        => $compilation_target,
                qw|  directory  | => $build_slot->{'dir'},
                qw| BUILD_NOISY | => $devmod_output_to_console,
                reproducible_build_flags( $build_slot->{'dir'} )
            );
        };
        ## keep compilation errors ##
        my $comp_err = $EVAL_ERROR;
        _publish_build( $build_slot, length $comp_err ? FALSE : TRUE );

        ## final installation target ##
        my $target_subname
            = sprintf( '%s::%s', $target_package, $subroutine_name );

        ## keep own registry
        $subroutines_installed->{$target_subname} = \&$current_sub_name;

        ## install to target namespace ##
        eval "*$target_subname = \\&$current_sub_name";

        ## clean-up temporary namespace : delete the WHOLE per-iteration    ##
        ## stash [ 'COMPILE::NNN::' , where a package name not nested       ##
        ## inside an open 'package' block actually lives, as a child of     ##
        ## %main:: ] in one shot -- it holds the just-compiled sub,         ##
        ## dl_load_flags, and any other DynaLoader/XS glue Inline installed ##
        ## under it, none of which need to survive past this point now that ##
        ## the real sub is installed at its target above. the previous      ##
        ## 'undef &${compilation_target}::$ARG' / 'undef *COMPILE' pair     ##
        ## never matched anything real -- $compilation_target already ends  ##
        ## in '::$current_sub_name', so appending '::$ARG' targeted a       ##
        ## namespace one level too deep, and '*COMPILE' [ this package's    ##
        ## own AMOS7::INLINE::COMPILE glob, never assigned to ] has nothing ##
        ## to do with the dynamically numbered 'COMPILE::NNN::..' namespace ##
        ## actually created above -- both were silent no-ops, leaking one   ##
        ## full package stash [ sub + XS/DynaLoader glue ] on every compile ##
        my ($iteration_key) = $compilation_namespace =~ m|^COMPILE::(\w+?::)|;
        ## 'exists' first : without a compilation the stash was never made, ##
        ## and the nested delete would autovivify %main::'s 'COMPILE::' as  ##
        ## a plain hash ref [ not a glob -- breaks %main:: symbol scans ]   ##
        delete $main::{'COMPILE::'}{$iteration_key}
            if defined $iteration_key
            and exists $main::{'COMPILE::'};

        #######################################################

        if ($comp_err    ## $EVAL_ERROR of compilation ##
            or ref $subroutines_installed->{$target_subname} ne qw| CODE |
        ) {
            ## without Inline::C the fallback is expected : announced once ##
            ## at load, not per subroutine                                 ##
            ## [ zenka init counts warnings as errors ] -- only a failing  ##
            ## fallback is reported below                                  ##
            warn_err( "<< compilation of '%s' not successful >>",
                0, $current_sub_name )
                if $inline_c_available and not $force_pure_perl;
            if ( defined &{$fallback_ref} ) {
                warn_err(
                    "   : installing pure-perl alternative for '%s' ..,",
                    1, $current_sub_name )
                    if $inline_c_available;

                ## $fallback_ref ##

                eval "*${target_package}::${subroutine_name}= \$fallback_ref";
                warn_err(
                    '  : :. installation not successful [ %s ]',
                    0,
                    format_error(
                        length $EVAL_ERROR
                        ? $EVAL_ERROR
                        : 'expected subroutine is not defined',
                        -1
                    )
                    )
                    if $EVAL_ERROR
                    or not defined &{"${target_package}::${subroutine_name}"};

            } else {
                warn_err(
                    "   : no pure-perl alternative for '%s' available ..,",
                    1, $current_sub_name );
            }
        } else {    ## installing to target name space ##

            eval "*${target_package}::$current_sub_name=\\&$current_sub_name";

            if ($EVAL_ERROR) {    ## LLL : check defined subname ##
                warn_err(
                    "  : :. installation not successful [ %s ]",
                    0,
                    format_error(
                        length $EVAL_ERROR
                        ? $EVAL_ERROR
                        : 'expected subroutine is not defined',
                        -1
                    )
                );
            } else {
                $sub_coderefs->{$current_sub_name} ## collect sub code refs ##
                    = \&{"${target_package}::$current_sub_name"};
                $success_count++;
            }
        }

        ## removing ,./lib/ from @INC again ., ##
        shift @INC if $INC[0] =~ m|^$custom_inline_dir/lib|;

        $subroutine_name = $current_sub_name;    ## setting return value ##
    }

    ## report if less than expected ##
    warn_err( '%d of %d subroutines compiled and installed',
        1, $success_count, $total_subroutine_count )
        if $success_count < $total_subroutine_count
        and $inline_c_available
        and not $force_pure_perl;

    ## returning code-ref to compiled routine ##
    return \&{"${target_package}::$subroutine_name"} if $single_func;

    return $sub_coderefs;    ## returning hash with code references ##
}

##[ SOURCE CODE CLEAN-UP ]####################################################

## return cleaned up code for filtering false-positive change detection ##

sub clean_source {
    my $source_code = shift // '';
    error_exit('expected source code to parse <{C1}>')
        if not length $source_code;

    $source_code =~ s{\s*/\*(([^\*]|\*(*nla:/))+)\*/\ *}{}sg;   ## comments ##
    $source_code =~ s{\s*//.+$}{}mg;     ## single line comments ##
    $source_code =~ s{\n\s*\n}{\n}sg;    ## empty lines ##
    $source_code =~ s{^\n|\n$}{}sg;      ## empty lines [ first and last ] ##
    $source_code =~ s{\s+$}{}sg;         ## trailing tabs|spaces ##
    ( my $min_indent, undef ) = minmax map { m|^\s+| ? length($MATCH) : 0 }
        split( "\n", $source_code );
    $source_code =~ s|^\s{$min_indent}||mg;    ## indent to start of source ##

    return $source_code;    ## return cleaned source code version ##
}

##[ GENERATING INLINE DIRECTORY PATH ]########################################

sub gen_inline_path {
    my $code_name = shift;
    my $abs_path;
    if (@ARG) {             ## given base path ##
        ( my $base_path = shift ) =~ s|/$||;
        my $user = getpwuid $UID;
        $abs_path = sprintf( qw| %s/%s/.7/inline-code/%s |,
            $base_path, $user, $code_name );
    } else {                ## user home dir ##
        my $home_path = AMOS7::FILE::get_homepath();
        $abs_path = sprintf qw| %s/.7/inline-code/%s |, $home_path,
            $code_name;

    }
    return $abs_path;
}

##[ BUILD SLOT : LOCK, PRIVATE BUILD DIR, ONE RENAME ]########################

## seconds a process waits for another one building the same object ; after ##
## that it runs pure perl [ the build lock only saves duplicate work, never ##
## correctness -- INLINE-OBJECT-TRUST.md ]                                  ##
our $build_wait_seconds;    ## undef : 120 [ set before load to change ] ##

## a published object dir : complete by construction                   ##
## [ it appeared by one rename after a successful build ], Inline only ##
## loads from it                                                       ##
sub _object_published {
    my $object_dir = shift // return FALSE;
    return FALSE if not -d $object_dir or -l $object_dir;
    my $found = FALSE;
    File::Find::find(
        {   no_chdir => 1,
            wanted   => sub { $found = TRUE if m|\.inl$| and -f $ARG }
        },
        "$object_dir/lib/auto"
    ) if -d "$object_dir/lib/auto";
    return $found;
}

## where Inline may work : the published dir [ load only ], or a fresh 0700 ##
## build dir next to it while holding the per-object lock                   ##
sub _build_slot {
    my $object_dir = shift;
    return { qw| dir | => $object_dir } if _object_published($object_dir);

    my $lock_path = "$object_dir.lock";
    sysopen( my $lock_fh, $lock_path, O_RDWR | O_CREAT | O_NOFOLLOW, 0600 )
        or return {
        qw| error | => sprintf "build lock '%s' : %s",
        $lock_path, $OS_ERROR
        };
    my @lock_stat = stat $lock_fh;
    return { qw| error | => "build lock '$lock_path' is not a plain file"
            . ' owned by this user' }
        if not -f _
        or $lock_stat[4] != $UID;

    my $deadline = time + ( $build_wait_seconds // 120 );
    until ( flock $lock_fh, LOCK_EX | LOCK_NB ) {
        return {
            qw| error | => "build lock '$lock_path' busy -- using pure perl" }
            if time >= $deadline;
        select undef, undef, undef, 0.25;
    }
    ## the holder before us may have published it ##
    return { qw| dir | => $object_dir, qw| lock | => $lock_fh }
        if _object_published($object_dir);

    ## holding the lock, every build dir of this object is ours : the rest ##
    ## is left from a killed builder                                       ##
    foreach my $stale_dir ( glob quotemeta($object_dir) . '.build-*' ) {
        File::Path::remove_tree($stale_dir)
            if -d $stale_dir and !-l $stale_dir;
    }

    my $build_dir = eval {
        File::Temp::tempdir( "$object_dir.build-XXXXXX", CLEANUP => 0 );
    };
    return { qw| error | => "no private build dir for '$object_dir'" }
        if not defined $build_dir;
    chmod 0700, $build_dir;
    return {
        qw|   dir   | => $build_dir,
        qw| publish | => $object_dir,
        qw|  lock   | => $lock_fh
    };
}

## a successful private build becomes the object dir by one rename ; a ##
## failed one is removed. the lock goes with its file handle           ##
sub _publish_build {
    my ( $slot, $built ) = @ARG;
    return if ref $slot ne qw| HASH | or not defined $slot->{'publish'};
    my ( $build_dir, $object_dir ) = @{$slot}{qw| dir publish |};
    if ( $built and not -e $object_dir ) {
        rename $build_dir,
            $object_dir
            or warn_err( "cannot publish inline object '%s' : %s",
            0, $object_dir, $OS_ERROR );
    }
    File::Path::remove_tree($build_dir) if -d $build_dir;
    close $slot->{'lock'}               if defined $slot->{'lock'};
    return;
}

##[ REPRODUCIBLE BUILDS ]#####################################################

## short key over the toolchain : a compiler \ perl \ flags change gets a ##
## new directory instead of rebuilding in place over the old object       ##
sub toolchain_key {
    state $key;
    return $key if defined $key;
    my $toolchain = join "\n", map { $_ // '' } $Config{'cc'},
        $Config{'gccversion'}, $Config{'archname'}, $Config{'version'},
        $Config{'ccflags'}, $Config{'lddlflags'},
        $Inline::C::VERSION, _reproducible_flag_set();
    $key = encode_b32r( substr( _src_digest($toolchain), 0, 3 ) );
    return $key;
}

## gcc 8 \ clang 10 know -ffile-prefix-map, older ones the debug variant ##
sub _reproducible_flag_set {
    my ($gcc_major) = ( $Config{'gccversion'} // '' ) =~ m|^(\d+)|;
    return ( $gcc_major // 0 ) >= 8
        ? qw| -ffile-prefix-map |
        : qw| -fdebug-prefix-map |;
}

## the build dir is embedded in the debug info and the gnu build id hashes ##
## it : map it to '.' and drop the build id                                ##
sub reproducible_build_flags {
    my $build_dir = shift // return;
    return (
        qw| CCFLAGSEX | =>
            sprintf( '%s=%s=.', _reproducible_flag_set(), $build_dir ),
        qw| LDDLFLAGS | =>
            sprintf( '%s -Wl,--build-id=none', $Config{'lddlflags'} // '' ),
    );
}

##[ SOURCECODE CHECKSUM ]#####################################################

sub encoded_bmw_chksum {
    my $subroutine_source = shift // '';
    return warn_err( 'expecting subroutine source code', 0 )
        if not length $subroutine_source;

    ## shortened BMW chksum for path name creation [ core SHA-256 fallback  ##
    ## when the optional module is absent -- path names stay printable \    ##
    ## deterministic ; AMOS7::B32 keeps the base32 form identical to the    ##
    ## Crypt::Misc one, and hosts that later install Digest::BMW simply get ##
    ## BMW-keyed names, old caches keyed on them stay untouched ]           ##
    my $bmw_checksum   = _src_digest($subroutine_source);
    my $src_chksum_bin = sprintf qw| BMW=%s |, substr( $bmw_checksum, 0, 5 );

    return encode_b32r($src_chksum_bin);    ## required printable prefix ##
}

## BMW-256 over the base32 form when available, core SHA-256 otherwise -- ##
## both deterministic, so path names remain stable per host               ##
sub _src_digest {
    my $source = shift // '';
    return bmw_256( encode_b32r($source) ) if defined &bmw_256;
    require Digest::SHA;
    return Digest::SHA::sha256_hex( encode_b32r($source) );
}

return TRUE ##################################################################

#,,.,,,..,,,,,..,,,.,,.,.,,,,,...,,,,,,.,,...,..,,...,..,,...,,,.,.,.,.,.,,,,,
#OOVO3WIJS4UQOSQL3E4PXWFDRQ7AOJSXT2V7AXWY6MXTX73MWR727EEHMACQDHCIS47S3KNZTRDTS
#\\\|CXWWQS5RMNSVCUYCVQ7J3EQV5U27VS3ZWZKQASZ3HLMQM5JV3QI \ / AMOS7 \ YOURUM ::
#\[7]L5WP4DRZFIRSDWZ5PR7MREZHM6AVWVT4JHEI5BEUNJTPMWWZ4CAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
