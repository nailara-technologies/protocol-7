
package AMOS7::TEMPLATE;    #################################################

use v5.24;
use strict;
use English;
use warnings;

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
        $TRUE = 0
            if not is_true( sprintf( $template, $checksum_encoded ),
            0, 1, @elf_modes );

        last if not $TRUE;    ##  false  ##
    }

    return $TRUE;
}

sub reset_truth_templates {
    $AMOS7::TEMPLATE::truth_templates = [];
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
            my @match_count = $template =~ m|(*nlb:\%)%s|sg;
            if ( @match_count != 1 ) {
                $template_valid = 0;                     ##  false  ##
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

#,,,.,,,,,.,.,.,.,,,.,..,,,.,,.,.,..,,...,,,.,..,,...,..,,...,,..,,,,,.,.,..,,
#J7EBTS2YNFDMR3OMPGDW2QEJHGVLCVRCIACMCV5KTZZYHMD7765PRO7R2VFFJUKSEFVYHPPHIV4SS
#\\\|2FNPKIFGAJYVEZYGZHUXVXCOASTKGPMSPUDZVFRC3RFQZ6PWYG2 \ / AMOS7 \ YOURUM ::
#\[7]4LIB57JHBMLZGPVK46RLHXWM36D6AXZPLVJY5EQCIA7DBPCWIGDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
