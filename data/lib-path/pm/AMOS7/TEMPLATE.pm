
package AMOS7::TEMPLATE;    #################################################

use v5.24;
use strict;
use English;
use warnings;

use Safe;
use Encode;
use Time::HiRes;

use Exporter;
use base qw| Exporter |;
use vars qw| @EXPORT $VERSION |;

@EXPORT = qw| is_true is_valid_tempate $VERSION |;

our $VERSION = qw| AMOS7::TEMPLATE-VERSION.VY7PD5Q |;

##[ AMOS MODULE ]#############################################################

use AMOS7;    ##  error handler  ##

use AMOS7::Assert::Truth;    ## is_true ##

##[ SET-UP \ INIT ]###########################################################

our $regex_str       //= {};
our $truth_templates //= [];
our $templ_valid_timeout  = 3;    ##  overall truth template time limit  ##
our $split_template_regex = qr{(*nlb:\\)[,\|]};

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

    my $TRUE = 5;    ## true ##

    foreach my $template ( $truth_templates->@* ) {

        if ( rindex( ref $template, qw| Regex | ) != -1 ) {

            $TRUE = 0 if $checksum_encoded !~ $template;    ## regex ##

        } else {

            $TRUE = 0
                if not is_true( sprintf( $template, $checksum_encoded ),
                0, 1, @elf_modes );
        }

        last if not $TRUE;    ##  false  ##
    }

    return $TRUE;
}

sub reset_truth_templates {
    $AMOS7::TEMPLATE::truth_templates = [];
    $AMOS7::TEMPLATE::regex_str       = {};
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

    $AMOS7::TEMPLATE::truth_templates
        = split_truth_templates($template_param);

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
    my $template_valid = 5;    ## true ##

    if ( not defined $template ) {
        $template_valid  = 0;                        ##  false  ##
        $template_errstr = 'template not defined';

    } elsif ( not length ref $template ) {    ##  single template param  ##
        $truth_templates = split_truth_templates($template);

    } elsif ( ref $template eq qw| ARRAY | ) {
        $truth_templates = $template;         ##  template ARRAY reference  ##

    } else {
        $template_valid = 0;                  ##  false  ##
        $template_errstr
            = sprintf 'template has unsuppored reference type %s',
            ref $template;
    }

    if ( not $template_valid ) {
        return ( $template_valid, $template_errstr ) if wantarray;
        return $template_valid;               ##  false  ##
    }

    foreach my $template ( $truth_templates->@* ) {
        if ( not defined $template ) {
            $template_valid  = 0;                        ##  false  ##
            $template_errstr = 'template not defined';
        } elsif ($template_valid) {

            ##  compiled regular expression template  ##
            next if rindex( ref $template, qw| Regexp | ) != -1;

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

return 5;  ###################################################################

#,,,,,,,,,...,...,.,,,,..,.,.,..,,,,.,,..,,..,..,,...,...,.,.,..,,..,,..,,...,
#77TF2JIPJSUOCD7GNYMJ3HC2UEYATSYPLW5ZLMN6TZM2PCFCWIKO4KYOKDVS5SW42B2NSC63JLZPK
#\\\|O3SKU7IHTBZHC3EHS3DKLWKHLBX7DEI5D2EEJ26SIAYYXOXOO34 \ / AMOS7 \ YOURUM ::
#\[7]3HFZTXZ323BUNZLWXEFXOZJO5PAKA7NGB2T74HPXMXVR7GEGMEDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
