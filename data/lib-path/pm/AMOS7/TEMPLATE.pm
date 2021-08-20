## [:< ##

package AMOS7::TEMPLATE;    #################################################

use v5.24;
use strict;
use English;
use warnings;

##[ global constants ]##
use constant TRUE  => 5;    ##  TRUE.  ##
use constant FALSE => 0;    ##  false  ##

use Safe;
use Encode;
use Time::HiRes;
use Module::Load qw| autoload |;

use Exporter;
use base qw| Exporter |;
use vars qw| @EXPORT $VERSION |;

@EXPORT = qw| template_is_true is_valid_tempate $VERSION |;

our $VERSION = qw| AMOS7::TEMPLATE-VERSION.VY7PD5Q |;

##[ AMOS MODULE ]#############################################################

use AMOS7;    ##  error handler  ##

autoload AMOS7::Assert::Truth    ## is_true ##
    if not defined &AMOS7::Assert::Truth::is_true
    and [ caller(0) ]->[0] ne qw| AMOS7::Assert::Truth |;

##[ SET-UP \ INIT ]###########################################################

our $regex_str //= {};
our $ELF_7_modes = [];
our $truth_templates     //= [];
our $default_timeout     //= 3;    ##  overall truth template time limit  ##
our $templ_valid_timeout //= $default_timeout;
our $split_template_regex = qr{(*nlb:\\)[,\|]};

our $callback_setup //= {};

##[ TEMPLATE VALIDATION CODE ]###########################################

sub template_is_true {
    my $checksum_encoded = shift @ARG;
    my @elf_modes        = @ARG;

    return error_exit('no defined truth template <{C1}>')
        if not defined $truth_templates or not template_count();
    return error_exit('expected defined encoded chksum parameter <{C1}>')
        if not defined $checksum_encoded;
    return error_exit('expected elf truth mode parameter list <{C1}>')
        if not @elf_modes;

    my $TRUE = TRUE;    ## true ##

    foreach my $template ( $truth_templates->@* ) {
        my $ref_type = ref $template;

        if ( length $ref_type == 4
            and index( $ref_type, qw| CODE |, 0 ) == 0 ) {    ## CODE ref ##

            $TRUE = FALSE if not $template->( $checksum_encoded, @ARG );

        } elsif ( rindex( $ref_type, qw| Regex | ) != -1 ) {    ## regex ##

            $TRUE = FALSE if $checksum_encoded !~ $template;

        } else {

            $TRUE = FALSE
                if not AMOS7::Assert::Truth::is_true(
                sprintf( $template, $checksum_encoded ),
                0, 1, $AMOS7::TEMPLATE::ELF_7_modes->@* );
        }

        last if not $TRUE;                                      ##  false  ##
    }

    return $TRUE;
}

sub reset_truth_templates {
    $AMOS7::TEMPLATE::regex_str       = {};
    $AMOS7::TEMPLATE::ELF_7_modes     = [];
    $AMOS7::TEMPLATE::truth_templates = [];

    ##  reset timeout here too ? [ amos chksum errors ]  ##   [ LLL ]
}

sub reset_temp_valid_timeout {
    return $AMOS7::TEMPLATE::templ_valid_timeout = $default_timeout;
}

sub template_timeout {
    my $timeout = shift;

    return $AMOS7::TEMPLATE::templ_valid_timeout if not defined $timeout;

    return error_exit('expected timeout parameter in seconds')
        if $timeout !~ m|^\d+(\.\d+)?$|;
    return error_exit('timeout 0 is not valid') if $timeout == 0;

    $AMOS7::TEMPLATE::templ_valid_timeout = $timeout;
    return TRUE;    ## true ##
}

sub set_ELF7_modes {
    my @elf_modes = @ARG;
    foreach my $ELFmode (@elf_modes) {
        return error_exit( 'elf mode [%s] not valid', $ELFmode )
            if $ELFmode !~ m|^1?\d+$|;
    }
    $AMOS7::TEMPLATE::ELF_7_modes = \@elf_modes;
}

sub assign_truth_templates {

    my $template_param = shift;

    reset_truth_templates();

    ( my $template_valid, my $template_errstr )
        = AMOS7::TEMPLATE::is_valid_template($template_param);

    if ( not $template_valid ) {
        warn_err(
            sprintf( '%s [ %%s ]', $template_errstr ),
            2,
            length ref $template_param
            ? ref $template_param
            : $template_param // qw| [UNDEF] |
        );
        return undef;
    }

    if ( ref $template_param eq qw| ARRAY | ) {
        $AMOS7::TEMPLATE::truth_templates = $template_param;

    } elsif ( length ref $template_param ) {
        $AMOS7::TEMPLATE::truth_templates = [$template_param];

    } else {
        $AMOS7::TEMPLATE::truth_templates
            = split_truth_templates($template_param);
    }

}

sub regex_src_string {
    my $regex_source_string;
    my $compiled_regex = shift;

    if ( defined $AMOS7::TEMPLATE::regex_str->{$compiled_regex} ) {
        $regex_source_string = $AMOS7::TEMPLATE::regex_str->{$compiled_regex};

    } else {    ##  when templates are reset already  ##

        ( $regex_source_string = $compiled_regex ) =~ s{^\(\?\^:|\)$}{}g;
    }
    return $regex_source_string;
}

sub compile_regex {
    my $regex_str = shift // '';
    return error_exit('expected regex string') if not length $regex_str;

    my $parse = new Safe;
    $parse->permit_only(qw| :base_core :base_orig |);
    my $perlcode_qr_str = sprintf 'qr\'%s\'', $regex_str;
    my $result          = $parse->reval( $perlcode_qr_str, 1 );

    if ( rindex( ref $result, qw| Regexp | ) == -1 or length $EVAL_ERROR ) {
        return error_exit('error in regular expression');
    }

    return $result;    ##  return compiled regex  ##
}

sub template_count {
    $truth_templates //= [];
    return scalar $truth_templates->@*;
}

sub split_truth_templates {

    my $template        = shift;
    my $truth_templates = [];

    return error_exit('template not defined') if not defined $template;

    $truth_templates = [ split $split_template_regex, $template ];

    foreach my $template ( $truth_templates->@* ) {
        $template =~ s.\\([,\|]).$1.g;

        if ( index( $template, qw|regex:|, 0 ) == 0 ) {
            substr( $template, 0, 6, '' );

            $template =~ s|regex\\:|regex:|g;    ##  restoring escaped  ##

            my $_re = $template;

            ##  replacing template with compiled regex  ##
            ##
            $template = compile_regex($_re);

            ## storing source ##
            ##
            $AMOS7::TEMPLATE::regex_str->{$template} = $_re;
        }

    }

    return $truth_templates;
}

sub is_valid_template {

    my $template        = shift;
    my $truth_templates = [];

    my $template_errstr;
    my $template_valid = TRUE;            ## true ##
    my $ref_type       = ref $template;

    if ( not defined $template ) {
        $template_valid  = FALSE;                    ##  false  ##
        $template_errstr = 'template not defined';

    } elsif ( not length $ref_type ) {    ##  single template param  ##
        $truth_templates = split_truth_templates($template);

    } elsif ( $ref_type eq qw| CODE | ) {
        $truth_templates = [$template];    ##  single CODE reference  ##

    } elsif ( $ref_type eq qw| ARRAY | ) {
        $truth_templates = $template;      ##  template ARRAY reference  ##

    } elsif ( rindex( $ref_type, qw| Regexp | ) != -1 ) {
        $truth_templates = [$template];    ##  regex param [ single ]  ##

    } else {
        $template_valid = FALSE;           ##  false  ##
        $template_errstr
            = sprintf 'template has unsuppored reference type %s',
            $ref_type;
    }

    if ( not $template_valid ) {
        return ( $template_valid, $template_errstr ) if wantarray;
        return $template_valid;            ##  false  ##
    }

    foreach my $template ( $truth_templates->@* ) {
        if ( not defined $template ) {
            $template_valid  = FALSE;                    ##  false  ##
            $template_errstr = 'template not defined';
        } elsif ($template_valid) {
            my $ref_type = ref $template;

            ##  CODE ref template  ##
            next if $ref_type eq qw| CODE |;

            ##  compiled regular expression template  ##
            next if rindex( $ref_type, qw| Regexp | ) != -1;

            ##  sprintf template [ contains %s ]  ##
            my @match_count = $template =~ m|(*nlb:\%)%s|sg;
            if ( @match_count != 1 ) {
                $template_valid = 0;    ##  false  ##
                $template_errstr
                    = sprintf "sprintf template '%s' not valid"
                    . " [ expecting single %%s ]",
                    $template;
            }
        }
        if ( not $template_valid ) {
            return ( $template_valid, $template_errstr ) if wantarray;
            return $template_valid;    ##  false  ##
        }
    }

    ##  no errors encountered  ##
    return ( $template_valid, undef ) if wantarray;
    return $template_valid;    ## true ##
}

##[ TEMPLATE VALIDATION CALLBACKS ]###########################################

sub reset_all_callbacks {
    $AMOS7::TEMPLATE::callback_setup = {};  ##  erasing all values [reset]  ##
}

sub configure_exclusive_type_callback {    ##  example template %%s:%s  ##
    my $selected_types_list_ref = shift;
    my $type_list_aref          = shift;
    my $sprintf_templates_aref  = shift;

    ##  validate template logic  ##   [ LLL ]

    return error_exit('expected selected types list array ref')
        if ref $selected_types_list_ref ne qw| ARRAY |;
    return error_exit('expected type list array reference')
        if ref $type_list_aref ne qw| ARRAY |;
    return error_exit('expected sprintf templates array ref param')
        if ref $sprintf_templates_aref ne qw| ARRAY |;
    return error_exit('type list contains no elements')
        if not scalar $type_list_aref->@*;
    return error_exit('template list contains no elements')
        if not scalar $sprintf_templates_aref->@*;

    foreach my $template ( $sprintf_templates_aref->@* ) {
        foreach my $match_type (qw| %%s %s |) {
            my @match_count = $template =~ m|(*nlb:\%)$match_type|sg;
            if ( @match_count != 1 ) {
                my $err_reason_str
                    = @match_count == 0 ? qw| missing | : qw| redundant |;
                warn_err( "sprintf template '%s' not valid [ %s '%s' ]",
                    4, $template, $err_reason_str, $match_type );
                return undef;    ##  aborting template set-up  ##
            }
        }
    }

    my %types_selected = map { $ARG => TRUE } $selected_types_list_ref->@*;
    my @excl_types_list    ##  remove selected types from list  ##
        = grep { not exists $types_selected{$ARG} } $type_list_aref->@*;

    $AMOS7::TEMPLATE::callback_setup->{'exclusive-type'} = {
        qw|  excl-type-list   |       => \@excl_types_list,
        qw| sprintf-truth-templates | => $sprintf_templates_aref,
    };  ##  truth templates are inverted, returning false if they are true  ##

    return $AMOS7::TEMPLATE::callback_setup->{'exclusive-type'};
}

sub CALLBACK_exclusive_type { ##  calling excl. types callback with params  ##
    my $cb_params = $AMOS7::TEMPLATE::callback_setup->{'exclusive-type'};
    my $check_string_param = shift;

    my $check_string_param_sref
        = ref $check_string_param eq qw| SCALAR |
        ? $check_string_param
        : \$check_string_param;

    return TEMPLATE_exclusive_type(
        $cb_params->{'excl-type-list'},
        $cb_params->{'sprintf-truth-templates'},
        $check_string_param_sref
    );
}

sub TEMPLATE_exclusive_type {
    my $excl_list_ref          = shift;
    my $sprintf_templates_aref = shift;
    my $check_string_param     = shift;

    my $TRUE = TRUE;    ## true ##

    return error_exit('expected exculsion type list array reference')
        if ref $excl_list_ref ne qw| ARRAY |;
    return error_exit('expected sprintf templates array ref param')
        if ref $sprintf_templates_aref ne qw| ARRAY |;
    return error_exit('expected check string scalar ref param')
        if ref $check_string_param ne qw| SCALAR |;

    use warnings qw| FATAL |;    ## catch sprintf errors ##

    foreach my $template ( $sprintf_templates_aref->@* ) {
        foreach my $type ( $excl_list_ref->@* ) {
            my $template_filled = eval { sprintf $template, $type };

            return error_exit( format_sprintf( $EVAL_ERROR, 4 ) )
                if not defined $template_filled or length $EVAL_ERROR;

            my $valid_str
                = eval { sprintf $template_filled, $check_string_param->$* };

            return error_exit( format_sprintf( $EVAL_ERROR, 4 ) )
                if not defined $valid_str or length $EVAL_ERROR;

            $TRUE = FALSE
                if AMOS7::Assert::Truth::is_true( $valid_str, 0, 1 );

            return $TRUE if not $TRUE;    ##  false  ##
        }
    }
    return $TRUE;                         ##  true  ##
}

return TRUE ##################################################################

#,,..,,,.,,..,...,..,,,.,,,..,,,.,,,,,,,.,,,.,..,,...,...,...,.,.,,,,,..,,,,,,
#7OB5FX4SZSKQD3FTW2AHS6CKDTW37OXXON4GWWESE4FEVBN6FCA44GV4KN4MN35CI6LVFM77T5UVA
#\\\|TQRH75RTMGSQLTOOTAN3ASUOPYJJYLTONUM2FWJFKZDEOPPF5Y6 \ / AMOS7 \ YOURUM ::
#\[7]EXGL2QVIVGQ56T6Z7M73TV4NFEYM5BRALOKRRUWE7PLQR3AJL4AI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
