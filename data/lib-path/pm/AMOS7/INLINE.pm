
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
use Fcntl           qw| O_RDWR O_CREAT O_NOFOLLOW LOCK_EX LOCK_NB LOCK_UN |;
use POSIX           ();
use Time::HiRes     ();
use Scalar::Util    qw| refaddr |;
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

## build \ upgrade settings                                                 ##
## [ declared above the load-time return, so the defaults are assigned ] -- ##
## see the call-driven upgrade section                                      ##
our $build_wait_seconds;    ## undef : 120 [ set before load to change ] ##
our $build_time_limit = 77;    ## detached build : hard limit [ s ] ##
our $build_cap        = 2;     ## concurrent detached builds per user ##
our $build_cc;                      ## undef : the perl config compiler ##
our $pure_perl_warn_seconds = 187;  ## one warning after this long ##
our $trusted_objects_ref;           ## undef : no signed list yet ##
our $require_trusted;               ## key holder : list match or pure perl ##
my $warned_unverified = {};         ## once per unverified object ##

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

$VERSION = qw| AMOS7::INLINE-VERSION.FGDHT4Y |;

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

        ## no published object yet and a pure-perl alternative exists : the ##
        ## alternative is installed AT ONCE behind a thin wrapper, the      ##
        ## build runs detached and the wrapper swaps the compiled sub in on ##
        ## a later call [ call-driven, no event loop assumed ]. no          ##
        ## alternative : the blocking build below, as before                ##
        my $deferred;
        if (    $inline_c_available
            and not $force_pure_perl
            and ref $fallback_ref eq qw| CODE |
            and defined &{$fallback_ref}
            and not _object_published($custom_inline_dir) ) {
            $deferred = _defer_build(
                {   qw| dir |      => $custom_inline_dir,
                    qw| parent |   => $parent_dir,
                    qw| source |   => $cleaned_source,
                    qw| fallback | => $fallback_ref,
                    qw| package |  => $target_package,
                    qw| name |     => $current_sub_name,
                    qw| target |   => $compilation_target,
                }
            );
        }

        ## the dir Inline works in + lock + publish target ##
        my $build_slot;
        eval {
            return if defined $deferred;
            die "'Inline::C' is not available\n"
                if not $inline_c_available or $force_pure_perl;
            ## a key holder never compiles in process : it loads a     ##
            ## published object found on the signed list, nothing else ##
            die "key holder : no published object to verify\n"
                if $require_trusted
                and not _object_published($custom_inline_dir);
            $build_slot = _build_slot($custom_inline_dir);
            die "$build_slot->{'error'}\n" if defined $build_slot->{'error'};
            ## a published object is verified BEFORE it is mapped ##
            if ( not defined $build_slot->{'publish'} ) {
                my ( $trusted, $why ) = _object_trust($custom_inline_dir);
                die "$why\n" if not $trusted;
            }
            _inline_bind( $cleaned_source, $compilation_target,
                $build_slot->{'dir'} );
        };
        ## keep compilation errors ##
        my $comp_err = $EVAL_ERROR;
        _publish_build( $build_slot, length $comp_err ? FALSE : TRUE );

        ## final installation target ##
        my $target_subname
            = sprintf( '%s::%s', $target_package, $subroutine_name );

        ## keep own registry
        $subroutines_installed->{$target_subname} = \&$current_sub_name
            if not defined $deferred;

        ## install to target namespace ##
        eval "*$target_subname = \\&$current_sub_name"
            if not defined $deferred;

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

        if ( defined $deferred ) {    ## wrapper bridges until the upgrade ##

            my $wrapped_name = sprintf '%s::%s', $target_package,
                $current_sub_name;
            {
                no strict qw| refs |;
                no warnings qw| redefine |;
                *{$wrapped_name} = $deferred;
            }
            $subroutines_installed->{$wrapped_name} = $deferred;
            $sub_coderefs->{$current_sub_name}      = $deferred;
            $success_count++;

        } elsif (
            $comp_err    ## $EVAL_ERROR of compilation ##
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
    ## the checksum is taken BEFORE the object becomes visible : the record ##
    ## travels inside the dir, one rename publishes both                    ##
    if ($built) {
        my $chksum = _object_chksum($build_dir);
        if ( defined $chksum and open my $record_fh,
            '>', "$build_dir/chksum" ) {
            print {$record_fh} "$chksum\n";
            close $record_fh;
            $slot->{'chksum'} = $chksum;
        } else {
            $built = FALSE;    ## no object file to take a checksum of ##
            warn_err( "no loadable object in '%s' -- not published",
                0, $build_dir );
        }
    }
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

##[ CALL-DRIVEN UPGRADE : DETACHED BUILD, WRAPPER, TRUST ]####################

## hard limit [ seconds ] for one detached build : only guards a hung     ##
## compiler, these sources compile in seconds. the build child is its own ##
## session \ process group, the limit takes the compiler down with it     ##

## concurrent detached builds per user                                     ##
## [ slot lock files next to the object dirs ] ; no free slot : pure perl, ##
## the wrapper retries on a later call                                     ##

## compiler override [ undef : the perl config one ] -- a wrapper script ##

## seconds of pure perl after which one warning is logged [ not a round ##
## minute : the wrapper never runs on a timer, only on calls ]          ##

## object trust [ INLINE-OBJECT-TRUST.md ] ##
##
## $trusted_objects_ref : undef while there is no signed list ; later a     ##
## hash reference, object checksum => true. $require_trusted : set by a key ##
## holder -- it loads a compiled object only on a list match, else it stays ##
## pure perl. everybody else loads, and warns once on an unverified object  ##
## only when a list exists                                                  ##

## checksum of the loadable part of a built object : its shared object file ##
## [ reproducible builds make it comparable between hosts ] ; undef when    ##
## there is none                                                            ##
sub _object_chksum {
    my $object_dir = shift // return;
    my @shared;
    File::Find::find(
        {   no_chdir => 1,
            wanted   => sub { push @shared, $ARG if -f $ARG and m|\.so$| }
        },
        "$object_dir/lib/auto"
    ) if -d "$object_dir/lib/auto";
    return if @shared != 1;
    open my $object_fh, '<:raw', $shared[0] or return;
    local $INPUT_RECORD_SEPARATOR;
    my $content = <$object_fh>;
    close $object_fh;
    return if not defined $content or not length $content;
    return _src_digest($content);
}

## may this process map the published object ? [ ok, why ] ##
sub _object_trust {
    my $object_dir = shift;
    my $list       = $trusted_objects_ref;
    if ( not defined $list ) {
        return ( FALSE, 'key holder : no signed object list yet' )
            if $require_trusted;
        return TRUE;    ## no list : nothing to verify against ##
    }
    my $chksum = _object_chksum($object_dir);
    return TRUE
        if defined $chksum
        and ref $list eq qw| HASH |
        and $list->{$chksum};
    return ( FALSE,
        "key holder : object '$object_dir' is not on the signed list" )
        if $require_trusted;
    warn_err( "inline object '%s' is not on the signed list [ unverified ]",
        1, $object_dir )
        if not $warned_unverified->{$object_dir}++;
    return TRUE;
}

## the one Inline->bind : compile [ build dir ] or load only [ published ] ##
sub _inline_bind {
    my ( $source, $target, $dir ) = @ARG;
    Inline->bind(
        qw|  C  |         => $source,
        qw| name |        => $target,
        qw|  directory  | => $dir,
        qw| BUILD_NOISY | => $devmod_output_to_console,
        ( defined $build_cc ? ( qw| CC | => $build_cc ) : () ),
        reproducible_build_flags($dir)
    );
    return;
}

## one lock file per cap slot, next to the object dirs ; the holder keeps ##
## the handle open for the build [ flock dies with its holder ]           ##
sub _acquire_build_cap {
    my $parent = shift // return;
    foreach my $slot_no ( 0 .. ( $build_cap // 2 ) - 1 ) {
        sysopen(
            my $slot_fh,
            "$parent/.build-slot.$slot_no",
            O_RDWR | O_CREAT | O_NOFOLLOW, 0600
        ) or next;
        my @slot_stat = stat $slot_fh;
        next if not -f _ or $slot_stat[4] != $UID;
        return $slot_fh if flock $slot_fh, LOCK_EX | LOCK_NB;
    }
    return;
}

## is a builder working on this object ? [ its per-object lock is held ] ##
sub _builder_active {
    my $object_dir = shift;
    return FALSE
        if not
        sysopen( my $lock_fh, "$object_dir.lock", O_RDWR | O_NOFOLLOW );
    my @lock_stat = stat $lock_fh;
    return FALSE if not -f _ or $lock_stat[4] != $UID;
    return TRUE if not flock $lock_fh, LOCK_EX | LOCK_NB;
    flock $lock_fh, LOCK_UN;
    return FALSE;
}

## the build child : double fork, so nobody has to reap it                  ##
## [ no SIGCHLD handler, no waitpid later ] ; POSIX::_exit never runs END   ##
## blocks or DESTROY of the parent ; setsid gives the child its own process ##
## group and the time limit kills the compiler with it                      ##
sub _spawn_builder {
    my $state  = shift;
    my $cap_fh = _acquire_build_cap( $state->{'parent'} ) // return 'cap';
    my $first  = fork;
    if ( not defined $first ) {
        close $cap_fh;
        return 'fork';
    }
    if ($first) {    ## parent : the middle child exits at once ##
        waitpid $first, 0;
        close $cap_fh;
        return 'spawned';
    }
    ## middle child ##
    my $second = fork;
    POSIX::_exit(0) if not defined $second or $second;
    ## build child ##
    POSIX::setsid() > 0 or POSIX::_exit(1);
    my $status = eval { _builder_main( $state, $cap_fh ); 0 } // 1;
    ## the group kill takes a still running compiler with the child ##
    kill qw| KILL |, -$PID;
    POSIX::_exit($status);
}

sub _builder_main {
    my ( $state, $cap_fh ) = @ARG;

    $SIG{$ARG} = qw| DEFAULT | foreach qw| CHLD PIPE HUP INT TERM USR1 USR2 |;
    ## inherited descriptors [ sockets of a zenka ] stay open in a detached ##
    ## child for the whole build : close all but the cap slot               ##
    my $keep_fd = fileno $cap_fh;
    foreach my $fd ( 3 .. 255 ) {
        POSIX::close($fd) if $fd != $keep_fd;
    }
    open STDIN, '<', '/dev/null';
    if ( not $devmod_output_to_console ) {
        open STDOUT, '>',  '/dev/null';
        open STDERR, '>&', \*STDOUT;
    }

    ## the child never refuses its own object, never waits on a lock : a ##
    ## busy lock means another builder is on it                          ##
    $require_trusted    = FALSE;
    $build_wait_seconds = 0;

    local $SIG{ALRM} = sub {
        local $SIG{TERM} = qw| IGNORE |;
        kill qw| TERM |, -$PID;    ## own group : the compiler too ##
        die "build time limit reached\n";
    };
    alarm( $build_time_limit // 77 );

    my $slot = _build_slot( $state->{'dir'} );
    if ( defined $slot->{'error'} or not defined $slot->{'publish'} ) {
        alarm 0;
        return;                    ## busy \ already published ##
    }
    eval { _inline_bind( @{$state}{qw| source target |}, $slot->{'dir'} ) };
    my $failed = $EVAL_ERROR;
    alarm 0;
    _publish_build( $slot, length $failed ? FALSE : TRUE );
    return;
}

## growth of the re-check gap : short first, x1.2 .. 1.6 with jitter, a ##
## jittered cap around 13 minutes [ AMOS7 is standalone : a tiny local  ##
## version of the base.interval rhythm ]                                ##
sub _next_gap {
    my $state = shift;
    my $gap   = $state->{'gap'} //= 0.4 * ( 0.8 + 0.4 * rand );
    my $cap   = 780 * ( 0.85 + 0.3 * rand );
    $state->{'gap'} = $gap * ( 1.2 + 0.4 * rand );
    $state->{'gap'} = $cap if $state->{'gap'} > $cap;
    return $gap;
}

sub _try_spawn {
    my $state = shift;
    return if $force_pure_perl;
    ## a key holder builds only once a signed list exists ##
    return if $require_trusted and not defined $trusted_objects_ref;
    ## just spawned [ the child may not hold its lock yet ] : wait ##
    my $grace = ( $build_time_limit // 77 ) + 7;
    return
        if defined $state->{'spawned_at'}
        and Time::HiRes::time() < $state->{'spawned_at'} + $grace;
    return if _builder_active( $state->{'dir'} );
    my $result = _spawn_builder($state);
    $state->{'spawned_at'} = Time::HiRes::time() if $result eq 'spawned';
    $state->{'last_spawn'} = $result;
    return;
}

## load only : the object is published, nothing is built ##
sub _load_published {
    my $state = shift;
    my ( $trusted, $why ) = _object_trust( $state->{'dir'} );
    if ( not $trusted ) {
        warn_err( "inline object stays unloaded : %s", 1, $why )
            if not $state->{'warned_untrusted'}++;
        return;
    }
    eval { _inline_bind( @{$state}{qw| source target |}, $state->{'dir'} ); };
    shift @INC if @INC and $INC[0] eq "$state->{'dir'}/lib";
    my $bind_err = $EVAL_ERROR;
    {
        my ($key) = $state->{'target'} =~ m|^COMPILE::(\w+?::)|;
        delete $main::{'COMPILE::'}{$key}
            if defined $key and exists $main::{'COMPILE::'};
    }
    if ( length $bind_err ) {
        warn_err( "inline object '%s' did not load : %s",
            0, $state->{'dir'}, format_error( $bind_err, -1 ) )
            if not $state->{'warned_load'}++;
        return;
    }
    no strict qw| refs |;
    my $loaded = \&{"AMOS7::INLINE::$state->{'name'}"};
    return defined &{$loaded} ? $loaded : undef;
}

## the call-driven part : published ? load + swap. else make sure a builder ##
## exists. runs only on a call that finds the gap used up                   ##
sub _upgrade_check {
    my $state = shift;
    return if defined $state->{'compiled'};
    return if $force_pure_perl;
    my $now = Time::HiRes::time();
    return if $now < ( $state->{'next_check'} // 0 );

    if ( _object_published( $state->{'dir'} ) ) {
        my $compiled = _load_published($state);
        if ( defined $compiled ) {
            $state->{'compiled'} = $compiled;
            ## the wrapper is gone for new lookups : zero cost afterwards ##
            no strict qw| refs |;
            no warnings qw| redefine |;
            my $name = "$state->{'package'}::$state->{'name'}";
            if ( refaddr( \&{$name} ) == $state->{'wrapper'} ) {
                *{$name} = $compiled;
                $subroutines_installed->{$name} = $compiled;
            }
            return;
        }
    } else {
        _try_spawn($state);
        warn_err(
            "'%s' still runs pure perl after %d s [ build %s ] -- retrying",
            1,
            $state->{'name'},
            $now - $state->{'started'},
            $state->{'last_spawn'} // 'pending'
            )
            if $now - $state->{'started'} > $pure_perl_warn_seconds
            and not $state->{'warned_stuck'}++;
    }
    $state->{'next_check'} = $now + _next_gap($state);
    return;
}

## install-at-once wrapper : calls the pure-perl alternative until the ##
## compiled sub is loaded. the build starts here, detached             ##
sub _defer_build {
    my $state = shift;
    $state->{'started'} = Time::HiRes::time();
    _try_spawn($state);
    $state->{'next_check'} = $state->{'started'} + _next_gap($state);

    my $wrapper = sub {
        if ( not defined $state->{'compiled'}
            and Time::HiRes::time() >= $state->{'next_check'} ) {
            ## a call must never see the check : its own error \ OS state ##
            local ( $EVAL_ERROR, $OS_ERROR, $CHILD_ERROR );
            eval { _upgrade_check($state) };
        }
        goto &{ $state->{'compiled'} // $state->{'fallback'} };
    };
    $state->{'wrapper'} = refaddr $wrapper;
    return $wrapper;
}

##[ REPRODUCIBLE BUILDS ]#####################################################

## short key over the toolchain : a compiler \ perl \ flags change gets a ##
## new directory instead of rebuilding in place over the old object       ##
sub toolchain_key {
    state $key;
    return $key if defined $key;
    my $toolchain = join "\n", map { $_ // '' } $build_cc // $Config{'cc'},
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

#,,..,,.,,.,.,,,.,,..,,.,,,,.,...,...,...,...,..,,...,...,...,.,,,.,.,,,,,,..,
#5AAXZHMS6Z5DBAYQDZKDIWD5ST533O5DJCAD3AB6AM2SMZGBA2AB4GJFL6QQMXCOXHC7XF5MWO4HY
#\\\|VZ5GSLPJCTCYKCOVVNNXG7GUPCIKOFN2PAD5OLRL7UNN4T5SOTP \ / AMOS7 \ YOURUM ::
#\[7]UAEJWGL57KD5IOHUCWCPWFQZHYP3AGSGPS5ZIPCRW32YIX4FNQDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
