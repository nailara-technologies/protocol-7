sub p7_assert__harmony {    ##  rename and overload in base module  ##  [LLL]

    my $input_string = shift // '';
    my $check_elf    = shift // TRUE;    ## true ##

    return TRUE if not length $input_string;    ##  '' is true  ##

    my $visualize ## create separate visualization routine in AMOS7::Assert ##
        = defined $data{'base'}{'harmony'}{'visualize'}
        ? $data{'base'}{'harmony'}{'visualize'}
        : {};     ## hashref with visualization settings ##

    if ( defined &AMOS7::Assert::Truth::is_true
        and not $visualize->{'enabled'} ) {
        ##  redirect to is_true  ##
        return AMOS7::Assert::Truth::is_true( \$input_string, 1, $check_elf );
    }

    my $visualize_zulum      = $visualize->{'zulum'}      // FALSE;
    my $visualize_harmony    = $visualize->{'harmony'}    // FALSE;
    my $visualize_disharmony = $visualize->{'disharmony'} // FALSE;

    state %a;
    if (   $visualize_zulum
        or $visualize_harmony
        or $visualize_disharmony ) {
        if ( not keys %a ) {

            #  reset          "\c[[m"
            my $reset       = "\e[0m";
            my $nailara_bg  = "\e[48;2;9;5;42m";
            my $blacklight  = "\e[38;2;68;39;172m";
            my $nailara_fg  = "\e[38;2;38;46;153m";
            my $error_color = "\e[38;2;197;141;7m";
            my $neon_green  = "\e[38;2;71;195;6m";
            %a = (
                'str'     => "\c[[1m",
                'bg'      => $nailara_bg,
                'bl'      => $blacklight,
                'reset'   => $reset,
                'ZL-B'    => $nailara_fg,
                'ZULUM'   => $blacklight,
                'Z-REST'  => "\c[[2m" . $reset . $nailara_bg . $nailara_fg,
                'D-REST'  => $reset . $nailara_bg . $neon_green,
                'NG'      => $neon_green . "\c[[1m",
                'UNKNOWN' => $neon_green . "\c[[5m",
                'color_y' => "\c[[6m" . $blacklight,
                'color_n' => $error_color . "\c[[1m",
                'clear'   => "\c[[H\c[[2J"
            );
        }
    }

    ## [ load modules first, if not present ] ##
    my @modules_to_load = qw| Math::BigFloat |;
    
    # Add AMOS7::CHKSUM::ELF to the list of modules to load if we're checking ELF
    push @modules_to_load, qw| AMOS7::CHKSUM::ELF | if $check_elf;
    
    map {
        if ( not defined $data{'base'}{'perlmod'}{'loaded'}->{$ARG}
            or $data{'base'}{'perlmod'}{'loaded'}->{$ARG} == 0 ) {

            return TRUE
                if defined $data{'base'}{'perlmod'}{'loading-failed'}
                and exists $data{'base'}{'perlmod'}{'loading-failed'}->{$ARG};

            ( my $pm_name = "$ARG.pm" ) =~ s|::|/|g;

            eval { require $pm_name };    ## load _before_ logging ., ##

            if ($EVAL_ERROR) {
                $code{'log.error'}->(": loading not successful [ $ARG ]");
                ## give up assertions to not cause infinite loops ##
                $data{'base'}{'perlmod'}{'loading-failed'}->{$ARG} = 1;
                return 1;
            } else {
                $data{'base'}{'perlmod'}{'loaded'}->{$ARG} = 1;
                $code{'log.devmod'}->(": loaded perl module '$ARG'.,");
                
                # Import functions if this is AMOS7::CHKSUM::ELF
                if ($ARG eq 'AMOS7::CHKSUM::ELF') {
                    eval { AMOS7::CHKSUM::ELF->import('elf_chksum') };
                    if ($EVAL_ERROR) {
                        $code{'log.error'}->(": import failed for [ $ARG ]");
                        $data{'base'}{'perlmod'}{'loading-failed'}->{$ARG} = 1;
                        return 1;
                    }
                }
            }
        }
    } @modules_to_load;
    ##

    ##                                   ##
    ## visualizing asserted numbers only ##
    ##                                   ##

    Math::BigFloat->round_mode(qw| trunc |);

    my $calc_str;
    ## check as number ##
    if ( $input_string =~ m|^\d+(\.\d+)?$| ) {
        ( my $input_num = $input_string ) =~ s|\.||;

        my $accuracy = 13;

        ( $calc_str
                = Math::BigFloat->new($input_num)
                ->bdiv( 13, $accuracy + length($input_num) ) ) =~ s|\.||;

        my $seperator_str = ' : ';

        if ( index( $calc_str, qw| 230769 | ) >= 0 ) {    ## FALSE ##

            my $min_len = $accuracy + 5;
            my $num_len = length($input_num);
            my $z_len   = abs( $min_len - $num_len );

            if (    $visualize_harmony
                and $visualize_disharmony
                and $num_len < $min_len ) {

                $input_num .= '0' x $z_len;
            }
            ### ..340769.., [E] ##
            $calc_str
                =~ s{(\d+?)((((((3)?0)?7)?6)?9)?230769([230769]+)*)(\d*)$}
                {$a{'D-REST'}${1}$a{'NG'}${2}$a{'D-REST'}${9}  $a{'reset'}}
                and say "$a{bg}$a{bl}: $input_num$seperator_str$calc_str "
                if $visualize_disharmony;

            return 0;
        } elsif ( $visualize_harmony
            and index( $calc_str, qw| 846153 | ) >= 0 ) {
            ### ..846153.., [T=5] ##
            $calc_str
                =~ s{(\d+?)((((((4)?6)?1)?5)?3)?846153([846153]+)*)(\d*)$}
                {$a{'ZULUM'}${1}$a{'ZL-B'}${2}$a{'Z-REST'}${9} $a{'reset'}};
            say "$a{bg}$a{bl}: $input_num$seperator_str$calc_str";

        } elsif ( $visualize_zulum
            and index( $calc_str, qw| 0000000 | ) >= 0 ) {
            $calc_str =~ s{(\d+?)?(0000000*)$}
                {$a{'ZULUM'}${1}$a{'ZL-B'}${2} $a{'reset'}};
            say "$a{bg}$a{bl}: $input_num$seperator_str$calc_str";

        } elsif ( $visualize_harmony and $visualize_disharmony ) {
            say "$a{bg}$a{bl}: $input_num$seperator_str$a{'UNKNOWN'}"
                . "$calc_str $a{'reset'}";
        }
    }

    return TRUE if not $check_elf;    ## true ##

    ##                                ##
    ##  checking for true elf chksum  ##
    ##                                ##

    state $load_already_attempted = FALSE;
    if (    not defined &AMOS7::Assert::Truth::is_true
        and not $load_already_attempted ) {    ## try only once ##
        eval { use AMOS7::Assert::Truth };
        $data{'base'}{'perlmod'}{'loaded'}->{'AMOS7::Assert::Truth'} = TRUE
            if not length $EVAL_ERROR
            and defined &AMOS7::Assert::Truth::is_true;
        $load_already_attempted = TRUE;        ## true ##
    }

    ## as string ##
    if ( defined &AMOS7::Assert::Truth::is_true ) {
        return &AMOS7::Assert::Truth::is_true( $input_string, 0, 1 );
    }

    ## Use the elf_chksum function from AMOS7::CHKSUM::ELF module
    my $elf_checksum;
    
    if ( defined $code{'chk-sum.elf'} ) {
        $elf_checksum = $code{'chk-sum.elf'}->( \$input_string );
    } elsif ( defined &elf_chksum ) {
        # Use the imported function from AMOS7::CHKSUM::ELF
        $elf_checksum = elf_chksum( \$input_string );
    } else {
        # Neither option is available - log an error
        $code{'log.error'}->(": no ELF checksum implementation available");
        return TRUE; # Default to TRUE when we can't calculate checksum
    }

    if ( defined &AMOS7::Assert::Truth::true_int ) {
        return TRUE
            if AMOS7::Assert::Truth::true_int($elf_checksum);    ## true ##
        return FALSE;                                            ##  false  ##
    } else {    ## use modulo 13 ## [LLL]
        $calc_str = Math::BigFloat->new($elf_checksum)
            ->bdiv( 13, 13 + length $elf_checksum );

        return FALSE if index( $calc_str, qw| 230769 | ) >= 0;   ##  false  ##

        ## assertion complete : harmony detected ## [ no 230769.., ]
        return TRUE;
    }
    ##
}
