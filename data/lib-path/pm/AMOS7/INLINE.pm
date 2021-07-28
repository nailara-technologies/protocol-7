
package AMOS7::INLINE; #######################################################

use vars qw| @EXPORT $VERSION |;

use Exporter;
use base qw| Exporter |;

use v5.24;
use strict;
use English;
use warnings;
use Cwd qw| abs_path |;
use File::Path qw| make_path |;
use List::MoreUtils qw| minmax |;

use Digest::BMW qw| bmw_256 |;    ## path name generation ##
use Crypt::Misc qw| encode_b32r |;

##[ AMOS MODULE ]#############################################################

use AMOS7;                        ## error handling ##

our $devmod_output_to_console = 0; ##  display build warnings  ##

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

eval qq| require 'Inline/C.pm' |;
die "'Inline::C' is not available [ installed ? ]" if length $EVAL_ERROR;

@EXPORT = qw| compile_inline_source $VERSION |;

$VERSION = qw| AMOS-INLINE-VER-MEMMQXQ |;

return 5;    ## true ##

##[ COMPILATION TO TARGET PATH ]##############################################

sub compile_inline_source {
    my $params = shift // {};
    error_exit('expected hash reference <{C1}>')
        if defined $params and ref $params ne qw| HASH |;

    my $subroutine_name  = $params->{'subroutine-name'};
    my $target_package   = $params->{'target-package'};         ## optional ##
    my $inline_directory = $params->{'target-path'};            ## optional ##
    my $re_compile       = $params->{'update-routine'} // 0;    ## optional ##

    my $uid = $params->{'uid'};                                 ## optional ##
    my $gid = $params->{'gid'};                                 ## optional ##

    ## check if root or current user and reset if required ## [LLL]

    return warn_err( "inline sourcecode for '%s' not defined",
        1, $subroutine_name )
        if defined $subroutine_name
        and not defined $source_registry->{$subroutine_name};

    my @subroutines
        = defined $subroutine_name
        ? ($subroutine_name)
        : reverse sort keys %{$source_registry};

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
        if ( not $re_compile
            and defined $subroutines_installed->{ sprintf '%s::%s',
                $target_package, $current_sub_name } ) {
            $total_subroutine_count--;    ## do not warn ##
            next;
        }

        ## preparing inline directory ##
        if ( defined $inline_directory and length $inline_directory ) {

            $custom_inline_dir = $inline_directory;

        } else {    ##  generate based on elf-chksum of subroutine source  ##

            $custom_inline_dir = gen_inline_path( sprintf qw| %s.%s |,
                $current_sub_name, encoded_bmw_chksum($cleaned_source) );
        }

        ## check \ create inline directory ##
        ##
        return warn_err( 'inline directory not defined', 0 )
            if not defined $custom_inline_dir
            or not length $custom_inline_dir;

        return warn_err( "inline directory '%s' not readable [ repair ., ]",
            0, $custom_inline_dir )
            if -d $custom_inline_dir and !-r $custom_inline_dir;

        if ( !-d $custom_inline_dir ) {

            make_path( $custom_inline_dir, {@params} )
                or return warn_err( ": %s : %s", 1,
                format_error( $OS_ERROR, -1 ),
                $custom_inline_dir );

            return warn_err( "cannot create inline directory '%s'",
                1, $custom_inline_dir )
                if !-d $custom_inline_dir;
        }
        ## prepare matching precise @INC path ##
        $custom_inline_dir = abs_path($custom_inline_dir);

        ## remove previous installation ##
        eval "undef \\&$current_sub_name";
        eval "undef *${target_package}::$subroutine_name";

        state $iteration //= 0;

        ## temporary namespace to avoid subroutine 'redefined' ##
        my $compilation_namespace = sprintf 'COMPILE::%03d::%s',
            $iteration++, $target_package;

        my $compilation_target = sprintf '%s::%s',
            $compilation_namespace, $current_sub_name;

        ###                                                 ###
        ##  COMPILATION \ INSTALLATION OF INLINE SUBROUTINE  ##
        ###                                                 ###

        eval {
            Inline->bind(
                qw|  C  |         => $cleaned_source,
                qw| name |        => $compilation_target,
                qw|  directory  | => $custom_inline_dir,
                qw| BUILD_NOISY | => $devmod_output_to_console
            );
        };
        ## keep compilation errors ##
        my $comp_err = $EVAL_ERROR;

        ## final installation target ##
        my $target_subname
            = sprintf( '%s::%s', $target_package, $subroutine_name );

        ## keep own registry
        $subroutines_installed->{$target_subname} = \&$current_sub_name;

        ## install to target namespace ##
        eval "*$target_subname = \\&$current_sub_name";

        ## clean-up temporary namespace ##
        map { eval "undef &${compilation_target}::$ARG" }
            ( $current_sub_name, qw| dl_load_flags | );
        ## entire package ##
        undef *COMPILE;

        #######################################################

        if ($comp_err    ## $EVAL_ERROR of compilation ##
            or ref $subroutines_installed->{$target_subname} ne qw| CODE |
        ) {
            warn_err( "<< compilation of '%s' not successful >>",
                0, $current_sub_name );
            if ( defined &{$fallback_ref} ) {
                warn_err(
                    "   : installing pure-perl alternative for '%s' ..,",
                    1, $current_sub_name );

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
        if $success_count < $total_subroutine_count;

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
    ( my $base_path = shift // qw| /var/tmp | ) =~ s|/$||;
    my $user     = getpwuid $UID;
    my $abs_path = sprintf( qw| %s/%s/.7/inline-code/%s |,
        $base_path, $user, $code_name );
    return $abs_path;
}

##[ SOURCECODE CHECKSUM ]#####################################################

sub encoded_bmw_chksum {
    my $subroutine_source = shift // '';
    return warn_err( 'expecting subroutine source code', 0 )
        if not length $subroutine_source;

    ## shortened BMW chksum for path name creation ##
    my $bmw_checksum   = bmw_256( encode_b32r($subroutine_source) );
    my $src_chksum_bin = sprintf 'BMW=%s', substr( $bmw_checksum, 0, 5 );

    return encode_b32r($src_chksum_bin);  ## required printable char prefix ##
}

return 1;  ###################################################################

#,,..,...,,,.,,,.,...,..,,..,,.,.,...,.,.,.,.,..,,...,...,.,.,...,..,,.,.,...,
#VKI3FVEPENWSWWRNZF7D4SIMEH2BOWK24MV527T554IDZ3LQGKS5XKJAOXXZIFB2LDVR5NWS5XPOU
#\\\|QD7BORSPJKH3LQGVXMDA4G5LZGYWJBV5R2BZ2MZAZ4I4DB6I5QU \ / AMOS7 \ YOURUM ::
#\[7]CVFRRI7MHQ6HTAMQ4VXUFY6YUUV5APKVX2DQY2VVBRJJTEW4PECI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
