
package AMOS::INLINE;  #######################################################

use vars qw| @EXPORT |;

use Exporter;
use base qw| Exporter |;

use v5.24;
use strict;
use English;
use warnings;
use List::Util;

use File::Path qw| make_path |;

use Digest::Elf;    ## creating directory path names ##
use Crypt::Misc qw| encode_b32r |;

##[ AMOS MODULE ]#############################################################

use AMOS;           ## error handling ##

## known inline sourcecode modules ##
use AMOS::INLINE::src::BinConversion;

##[ INITIALIZATIONS ]#########################################################

my $source_registry = {    ## AMOS::INLINE::src::Elf::elf
    qw| bit_to_num | => \&AMOS::INLINE::src::BinConversion::bitstring_to_num,

   # qw| num_to_bit | => \&AMOS::INLINE::src::BinConversion::num_to_bitstring,
   # qw| inline_elf | => \&AMOS::CHKSUM::ELF::Inline::return_elf_c_sourcecode,
};

eval qq| require 'Inline/C.pm' |;
die "'Inline::C' is not available [ installed ? ]" if $EVAL_ERROR;

@EXPORT = qw| compile_inline_source $VERSION |;

## inline elf source code version ##
##
our $VERSION = qw| AMOS-INLINE-3PVIREI |;

return 5;    ## true ##

##[ COMPILATION TO TARGET PATH ]##############################################

sub compile_inline_source {
    my $params = shift // {};
    error_exit('expected hash reference <{C1}>')
        if defined $params and ref $params ne qw| HASH |;

    my $subroutine_name  = $params->{'subroutine-name'};
    my $target_package   = $params->{'target-package'};    ## optional ##
    my $inline_directory = $params->{'target-path'};       ## optional ##

    my $uid = $params->{'uid'};                            ## optional ##
    my $gid = $params->{'gid'};                            ## optional ##

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

        my $function_href;        ##  subroutine source  ##
        $function_href = $source_registry->{$current_sub_name}->()
            if defined $source_registry->{$current_sub_name}
            and defined &{ $source_registry->{$current_sub_name} };

        if ( ref $function_href ne qw| HASH |
            or not defined $function_href->{'source'} ) {
            warn_err( "<< sourcecode of '%s' not defined >>",
                0, $current_sub_name );
            next;
        }

        my $cleaned_source = clean_source( $function_href->{'source'} );
        my $fallback_ref   = $function_href->{'fallback'};   ## alternative ##
        $target_package //= $function_href->{'package'};     ## install to ##

        ## preparing inline directory ##
        if ( defined $inline_directory and length $inline_directory ) {

            $custom_inline_dir = $inline_directory;

        } else {    ##  generate based on elf-chksum of subroutine source  ##

            $custom_inline_dir = gen_inline_path( sprintf qw| %s.%s |,
                $current_sub_name, encoded_elf_chksum($cleaned_source) );
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
                format_error( l $OS_ERROR, -1 ),
                $custom_inline_dir );

            return warn_err( "cannot create inline directory '%s'",
                1, $custom_inline_dir )
                if !-d $custom_inline_dir;
        }
        ##

        ###                                                 ###
        ##  COMPILATION \ INSTALLATION OF INLINE SUBROUTINE  ##
        ###                                                 ###

        eval {
            no warnings;    # <-- 'redefine' ?
            Inline->bind(
                qw| C |         => $cleaned_source,
                qw| name |      => $target_package,
                qw| directory | => $custom_inline_dir
            );
            use warnings;    # <-- 'redefine' ?
        };

        #######################################################

        if ( not defined &{$current_sub_name} ) {
            ## inherit parse_error [ $EVAL_ERROR ]
            warn_err( "<< compilation of '%s' not successful >>",
                0, $current_sub_name );
            if ( defined &{$fallback_ref} ) {
                warn_err(
                    "   : installing pure-perl alternative for '%s' ..,",
                    1, $current_sub_name );

                ## $fallback_ref ##

                eval "*${target_package}::${subroutine_name}= \$fallback_ref";
                warn_err(
                    "  : :. installation not successful [ %s ]",
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
            if ( $EVAL_ERROR
                or not defined &{"${target_package}::$current_sub_name"} ) {
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
    my $total_subroutine_count = scalar @subroutines;
    warn_err( "%d of %d subroutines compiled and installed",
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
    my $min_indent = List::Util::min map { m|^\s+| ? length($MATCH) : 0 }
        split( "\n", $source_code );
    $source_code =~ s|^\s{$min_indent}||mg;    ## indent to start of source ##

    return $source_code;    ## return cleaned source code version ##
}

##[ GENERATING INLINE DIRECTORY PATH ]########################################

sub gen_inline_path {
    my $user      = getpwuid($UID);
    my $code_name = shift;
    ( my $base_path = shift // qw| /var/tmp | ) =~ s|/$||;
    my $abs_path = sprintf( qw| %s/%s/.7/inline-code/%s |,
        $base_path, $user, $code_name );
    return $abs_path;
}

##[ SOURCECODE CHECKSUM ]#####################################################

sub encoded_elf_chksum {
    my $subroutine_source = shift // '';
    return warn_err( 'expected subroutine sourcecode', 0 )
        if not length $subroutine_source;
    my $elf_checksum = Digest::Elf::elf( encode_b32r($subroutine_source) );
    return encode_b32r( pack qw| V |, sprintf qw| %09d |, $elf_checksum );
}

return 1;  ###################################################################

#.............................................................................
#YSW5KOB2YABPDZTWRW6JICCLWQL4RR5ZMEKKXBYDTENHGGFR4K3QTVF4JGQJ3MNZMXTLUJ6WNBXHY
#::: WLZEVS37ASUYTXI2K35ZLLAABKIG2Z4PPUTBXQ4ELHVWZ34TQC5 :::: NAILARA AMOS :::
# :: KU7YIADB6FSBTUXW3LAULUBRFE6RTIJP7DYSYHOJOY4RYYIZY4DA :: CODE SIGNATURE ::
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
