## [:< ##

package AMOS7::TERM; #########################################################

use v5.24;
use utf8;
use strict;
use English;
use warnings;

##[ global constants ]##
use constant TRUE  => 5;    ##  TRUE.  ##
use constant FALSE => 0;    ##  false  ##

use AMOS7;

use Event;
use Term::ReadLine;
use Time::HiRes qw| sleep |;
use Crypt::PRNG::Fortuna qw| rand |;

use Exporter;
use base qw| Exporter |;
use vars qw| $VERSION @EXPORT @EXPORT_OK |;

my $VERSION = qw| AMOS7::TERM-VERSION.7OT2XVQ |;

@EXPORT_OK = qw| terminal_title |;

@EXPORT = qw| terminal_size read_password_single read_password_repeated |;

use POSIX qw| :termios_h |;

our %CC_FIELDS = (
    VEOF   => VEOF,
    VEOL   => VEOL,
    VERASE => VERASE,
    VINTR  => VINTR,
    VKILL  => VKILL,
    VQUIT  => VQUIT,
    VSUSP  => VSUSP,
    VSTART => VSTART,
    VSTOP  => VSTOP,
    VMIN   => VMIN,
    VTIME  => VTIME,
);
our %CC_backup;

our $pwd_cur_len           //= 0;
our $pwd_min_len           //= 13;
our $PASSWD_READ_TIMEOUT   //= 13;
our $pwd_read_aborted      //= FALSE;
our $term_read_key_support //= FALSE;
our $TTY_read_size         //= 2048;

our $TTY_IN;
our $TERM_ios;
our $TTY_OUTPUT;
our $READ_BUFFER;
our $TTY_fd_restore;
our $original_flags;
our $currrent_pass_prompt;

our @rnd_count;

##[ TERMINAL [ TTY ] ]########################################################

sub terminal_size {

    my $handle = shift // *STDIN;    ## use *STDOUT for pipe detection ##

    return undef if not -t $handle;
    state $size       = "\0" x 8;
    state $TIOCGWINSZ = 21523;

    ioctl( $handle, $TIOCGWINSZ, $size ) or return undef;
    my $size_aref = [ unpack qw| S!S!S!S! |, $size ];

    return ( $size_aref->[1], $size_aref->[0] );
}

sub read_to_buffer_TTY {
    my $buffer_sref     = shift // \$READ_BUFFER;
    my $input_timeout   = shift // $PASSWD_READ_TIMEOUT;
    my $tty_read_size   = shift // $TTY_read_size;
    my $autoinc_timeout = shift // TRUE;

    my $buffered_bytes = length( $buffer_sref->$* // '' );

    if ($autoinc_timeout) {
        my $new_timeout = $input_timeout + 0.7 * $buffered_bytes;
        $TERM_ios->setcc( VTIME, sprintf qw| %u |, 10 * $new_timeout );
    }

    my $bytes_read_count = sysread $TTY_IN, $buffer_sref->$*, $tty_read_size,
        $buffered_bytes;

    return ( $bytes_read_count, \$READ_BUFFER ) if wantarray;
    return $bytes_read_count;
}

sub init_TTY_no_echo {    ##  adaptation from Term::ReadPassword  ##

    my $prompt       = shift;                            ## optional ##
    my $read_timeout = shift // $PASSWD_READ_TIMEOUT;    ##[ in seconds ]##
    undef @rnd_count;    ## displayed * characters buffer ##
    $pwd_cur_len = 0;

    my ( $in, $out ) = Term::ReadLine->findConsole;
    if ( not $in ) {
        warn_err('found no available console <{C1}>');
        return undef;
    }
    if ( not open $TTY_IN, qw| +< |, $in ) {
        if ( not open $TTY_IN, qw| <& |, *STDIN{IO} ) {
            warn_err( 'cannot [re-] open STDIN [ %s ]',
                1, lcfirst($OS_ERROR) );
            return undef;
        } else {
            warn_err( 'cannot open %s [rw] [ %s ]',
                1, $in, lcfirst($OS_ERROR) );
            return undef;
        }
    }

    if ( not open $TTY_OUTPUT, qw| >> |, $out ) {
        if ( not open $TTY_OUTPUT, qw| >>& |, *STDOUT{IO} ) {
            warn_err( 'cannot [re-] open STDOUT [ %s ]',
                1, lcfirst($OS_ERROR) );
            return undef;
        } else {
            warn_err( 'cannot open %s [writing] [ %s ]',
                1, $out, lcfirst($OS_ERROR) );
            return undef;
        }
    }

    select( ( select($TTY_OUTPUT), $OUTPUT_AUTOFLUSH = TRUE )[0] );
    print $TTY_OUTPUT $prompt if defined $prompt;

    $TTY_fd_restore = fileno($TTY_IN);
    $TERM_ios       = POSIX::Termios->new();

    $TERM_ios->getattr($TTY_fd_restore);
    $original_flags = $TERM_ios->getlflag();
    foreach my $field ( keys %CC_FIELDS ) {
        $CC_backup{$field} = $TERM_ios->getcc( $CC_FIELDS{$field} );
    }

    my $flags = $original_flags & ~( ISIG | ECHO | ICANON );

    $TERM_ios->setlflag($flags);

    if ($read_timeout) {
        $TERM_ios->setcc( VTIME, 10 * $read_timeout );
        $TERM_ios->setcc( VMIN,  0 );
    } else {
        $TERM_ios->setcc( VTIME, 0 );
        $TERM_ios->setcc( VMIN,  1 );
    }

    $TERM_ios->setattr( $TTY_fd_restore, TCSAFLUSH );

    return TRUE;
}

sub close_TTY_no_echo {
    my $send_newline = shift // TRUE;
    $pwd_cur_len = 0 if $pwd_cur_len;
    if ( defined $READ_BUFFER and length $READ_BUFFER ) {
        substr(    ##  clear buffer content  ##
            $READ_BUFFER, 0,
            length $READ_BUFFER,
            chr(127) x length $READ_BUFFER
        );
        $READ_BUFFER = undef;
    }

    undef @rnd_count;    ## displayed * characters buffer ##

    print {$TTY_OUTPUT} chr(10) if $send_newline and defined $TTY_OUTPUT;
    return undef                if not defined $TERM_ios;

    $TERM_ios->setlflag($original_flags);

    while ( my ( $field, $_val ) = each %CC_backup ) {
        $TERM_ios->setcc( $CC_FIELDS{$field}, $_val );
    }
    $TERM_ios->setattr( $TTY_fd_restore, TCSAFLUSH );
    close($TTY_IN);
    close($TTY_OUTPUT);

    $TTY_OUTPUT = $TTY_IN = undef;

    return TRUE;
}

##[ USER-INTERACTION ]########################################################

sub read_password_repeated {

    my $password_type_msg = shift // qw| password |;
    my $term_title        = shift // '';
    my $output_lines      = shift // 1;
    $output_lines = 0 if $output_lines !~ m|^\d+$|;

    ( my $password_0, my $password_1 );

    while (not defined $password_0
        or not defined $password_1
        or $password_0 ne $password_1 ) {

        ( $password_0, my $abort_mode )
            = read_password_single( sprintf( 'enter %s', $password_type_msg ),
            $term_title );

        if ( not defined $password_0 and $abort_mode ne FALSE ) {
            return undef if defined $main::PROTOCOL_SEVEN;    ##  zenka  ##
            ##[ had already exited otherwise ]##
        } else {

            ( $password_1, my $abort_mode )
                = read_password_single(
                sprintf( 're-enter %s', $password_type_msg ) );

            if (    defined $password_0
                and defined $password_1
                and $password_0 ne $password_1 ) {
                if ( $password_0 ne $password_1 ) {
                    undef $password_0;
                    undef $password_1;
                    if ( defined $main::PROTOCOL_SEVEN ) {
                        $main::code{'base.log'}
                            ->( 0, '<<  paswords differ  >>' );
                    } else {
                        warn_err(' <<  paswords differ  >> <{NC}>');
                    }
                }
                sleep 1.2;
            }
            if ( $abort_mode ne FALSE ) {
                undef $password_0;
                undef $password_1;
                print $C{'R'};
                return undef;
            }
        }
    }

    print sprintf( "%s:\n", $C{'0'} ) x $output_lines;

    return $password_0;
}

sub read_password_single {

    my $message_prompt = shift // 'enter password';
    my $term_title     = shift // '';
    my $output_lines   = shift // 1;
    my $input_timeout  = shift // $PASSWD_READ_TIMEOUT;
    $output_lines = 0 if $output_lines !~ m|^\d+$|;

    $currrent_pass_prompt = $message_prompt;
    my $mprompt_length = 8 + length $message_prompt;

    my $read_chars_buffer;
    $pwd_cur_len = 0;
    my $passwd_mlen     = 64;
    my $tty_read_size   = 1026;
    my $max_XOR_chars   = 1024;
    my $autoinc_timeout = TRUE;

    my $colored_prompt = sprintf "%s:\n%s: %s%s %s %s%s :. %s", $C{'0'},
        $C{'0'}, $C{'T'}, $C{'B'},
        $message_prompt,
        $C{'R'}, $C{'0'}, $C{'T'};

    my $XOR_buffer;    ##  >= 64 bytes mode  ##
    my $chr_remove    = join '', map {chr} ( 0 .. 9 );
    my $sequ_left     = join '', map {chr} qw| 27 91 68 |;
    my $sequ_begin    = join '', map {chr} qw| 27 91 |;
    my $del_sequence  = join '', map {chr} qw| 27 91 51 126 |;
    my $seq_END       = chr 126;
    my $DEL           = chr 127;
    my $backspace_chr = chr 8;
    my $NAK           = chr 21;

    my $XORchars_count     = 0;
    my $XOR_buffer_pos     = 0;
    my $XOR_stars_slowdown = 1;

REREAD_PASSWORD:

    terminal_title($term_title) if length $term_title;

    AMOS7::TERM::init_TTY_no_echo( $colored_prompt, $input_timeout );

    my $abort_mode               = FALSE;
    my $continue_reading         = TRUE;
    my $extended_processing_mode = TRUE;

    while ($continue_reading) {

        my $show_stars = TRUE;

        my $read_chrs
            = AMOS7::TERM::read_to_buffer_TTY( \$read_chars_buffer, undef,
            $tty_read_size, $autoinc_timeout );

        ##  XOR passwd mode  ##
        $extended_processing_mode = FALSE
            if $extended_processing_mode
            and length($read_chars_buffer) >= $passwd_mlen;

        if ($extended_processing_mode) {

            ##  ignoring return on empty buffer  ##
            $read_chars_buffer = ''
                if $read_chars_buffer eq chr 10
                or $read_chars_buffer eq chr 13;

            ## DEL [ or backspace ] ##
            ##
            ##  make backspace  ##
            $show_stars = FALSE
                if $read_chars_buffer =~ s|\Q$del_sequence\E|$backspace_chr|g;
            $show_stars = FALSE    ##[ left cursor key also ]##
                if $read_chars_buffer =~ s|\Q$sequ_left\E|$backspace_chr|g;
            $show_stars = FALSE
                if $read_chars_buffer =~ s|$DEL|$backspace_chr|g;
            $show_stars = FALSE
                if $read_chars_buffer =~ s|^$backspace_chr||g;  ##[ silent ]##
            ## process backspace ##
            while ( $read_chars_buffer =~ s|.$backspace_chr|| ) {
                $show_stars = FALSE;
                ## one at a time ##
                ##
                ## remove * chars ##
                AMOS7::TERM::del_rnd_stars();
            }

            $show_stars = FALSE    ##  delete other sequences  ##
                if $read_chars_buffer =~ s|\Q$sequ_begin\E.$seq_END?||g;

            ## CTRL+U [NAK] [erase read] ##
            ##
            if ( $extended_processing_mode
                and rindex( $read_chars_buffer, $NAK ) >= 0 ) {
                ##  erase characters read so far  ##
                AMOS7::TERM::rewind_stars();
                $read_chars_buffer = '';
                $show_stars        = FALSE;
            }

            $show_stars = FALSE if not length $read_chars_buffer;

        } elsif ($continue_reading) {    ##  XOR passwd mode  ##

            $XOR_buffer //= chr(127) x 64;    ##  initializing XOR buffer  ##

            while ( length $read_chars_buffer ) {
                my $XOR_char = substr $read_chars_buffer, 0, 1, '';
                my $code     = ord $XOR_char;

                if ( $code == 10 or $code == 13 ) { ## end processing ##
                    $read_chars_buffer = chr 10;
                    $continue_reading  = FALSE;
                    $show_stars        = FALSE;
                    last;
                }

                my $XORBUF_char = substr $XOR_buffer, $XOR_buffer_pos, 1;

                substr $XOR_buffer, $XOR_buffer_pos++, 1,
                    $XORBUF_char ^ $XOR_char;

                $XORchars_count++;
                $XOR_buffer_pos = 0 if $XOR_buffer_pos == 64;
                last                if $XORchars_count == $max_XOR_chars;

                if ( $show_stars
                    and ( $XORchars_count * $XOR_stars_slowdown ) % 3 == 0 ) {
                    AMOS7::TERM::show_rnd_stars($mprompt_length);
                }
                $XOR_stars_slowdown *= 0.97 if $XOR_stars_slowdown > 0.13;
            }
        }

        $pwd_cur_len = length $read_chars_buffer;

        $continue_reading = FALSE    ##[  read end conditions  ]##
            if defined $read_chrs
            and $read_chrs == 0
            and $abort_mode = qw| timeout |                  ##[ timeout ]##
            or length($read_chars_buffer) >= $passwd_mlen    ##[ maxlen ]##
            or length($read_chars_buffer) and (

            rindex( $read_chars_buffer, chr 10 ) >= 0         ##[ LF ]##
            or rindex( $read_chars_buffer, chr 13 ) >= 0      ##[ CR ]##
            or length($read_chars_buffer) >= $tty_read_size   ##[ read_len ]##

            );

        if ( $abort_mode eq qw| timeout | ) {
            AMOS7::TERM::timeout_stars();
            $show_stars = FALSE;
        } elsif (
            $continue_reading
            and $extended_processing_mode
            and length($read_chars_buffer) >= $passwd_mlen    ##[ maxlen ]##
            or rindex( $read_chars_buffer, chr 27 ) >= 0      ## escape ##
            or rindex( $read_chars_buffer, chr 4 ) >= 0       ## CTRL-D ##
            or rindex( $read_chars_buffer, chr 3 ) >= 0       ## CTRL-C ##
        ) {
            $abort_mode = qw| user-interrupt |;
            AMOS7::TERM::reset_stars();
            $continue_reading = FALSE;
            $show_stars       = FALSE;
        }

        $show_stars = FALSE    ##  deleting all chars < asc 10  ##
            if $continue_reading
            and $read_chars_buffer =~ s|[$chr_remove]+||g;

        $show_stars = FALSE if $show_stars and not $continue_reading;
        $show_stars = FALSE if $show_stars and not $extended_processing_mode;

        AMOS7::TERM::show_rnd_stars($mprompt_length) if $show_stars;
    }

    my $LF_found = FALSE;
    foreach my $LF_chr ( chr 13, chr 10 ) {
        my $LF_match_pos = index $read_chars_buffer, $LF_chr;
        ## truncating pwd buffer to linefeed pos ##
        $LF_found = TRUE and substr $read_chars_buffer, $LF_match_pos,
            length($read_chars_buffer) - $LF_match_pos, ''
            if $LF_match_pos >= 0;
    }

    ##  XOR passwd mode  ##
    ##
    if ( length($read_chars_buffer) >= $passwd_mlen ) {
        $extended_processing_mode = FALSE;
    }

    reset_stars() if not $LF_found and $extended_processing_mode;

    AMOS7::TERM::close_TTY_no_echo();

    $read_chars_buffer = $XOR_buffer if not $extended_processing_mode;

    $read_chars_buffer = undef if $abort_mode ne FALSE;

    ##  checking min pwd length  ##
    ###
    if ( defined $read_chars_buffer
        and length($read_chars_buffer) < $pwd_min_len ) {
        if ( defined $main::PROTOCOL_SEVEN ) {
            printf "\n%s:\n", $C{'0'};
            $main::code{'base.logs'}
                ->( 0, '<<  pasword min len is %d  >>', $pwd_min_len );
        } else {
            warn_err( ' <<  pasword min len is %d  >> <{NC}>',
                -1, $pwd_min_len );
        }
        $read_chars_buffer = '';    ##  reset password entered  ##
        Time::HiRes::sleep 1.2;
        goto REREAD_PASSWORD;

        ##  display abort reason messages  ##
        ##
    } elsif ( $abort_mode eq qw| user-interrupt | ) {  ##[  abort by user  ]##

        if ( defined $main::PROTOCOL_SEVEN ) {
            printf "%s:\n", $C{'0'};
            $main::code{'base.log'}->( 0, ' [ password read aborted ]' );
            printf "%s:\n", $C{'0'};
        } else {
            error_exit(' [ password read aborted ]');
        }
    } elsif ( $abort_mode eq qw| timeout | ) {         ##[ timeout ]##

        if ( defined $main::PROTOCOL_SEVEN ) {         ##  zenka  ##
            printf "%s:\n", $C{'0'};
            $main::code{'base.log'}->( 0, '[ password input timeout ]' );
            printf "%s:\n", $C{'0'};
            for ( 0 .. 6 ) {
                Time::HiRes::sleep(0.1);
                Event::loop(0.007);
            }
        } else {
            error_exit(' [ password input timeout ]');
        }
    }

    print sprintf( "%s:\n", $C{'0'} ) x $output_lines;

    return ( $read_chars_buffer, $abort_mode ) if wantarray;
    return $read_chars_buffer;
}

sub terminal_title {

    my $term_title = shift // '';
    return FALSE if not length $term_title;

    my $clear_console
        = ( defined $main::PROTOCOL_SEVEN
            and $main::data{'system'}{'verbosity'}{'console'} )
        ? ''    ##  do not clear screen with -v option  ##
        : "\e[H\e[2J\e[3J";

    ( my $term_width, undef ) = AMOS7::TERM::terminal_size();
    my $colon_line = qw| : | x abs( $term_width - length($term_title) - 11 );

    printf { $TTY_OUTPUT // *STDOUT{IO} }
        "%s\n%s.:::.[%s%s %s %s%s].:%s\n%s%s:%s\n",
        $clear_console,
        $C{'0'}, $C{'T'}, $C{'B'}, $term_title, $C{'R'}, $C{'0'},
        $colon_line, $C{'R'}, $C{'0'}, $C{'R'};

    return TRUE;    ## true ##
}

sub term_rewind {
    my $mprompt_length = shift // 0;
    my $stars_count    = shift // scalar @rnd_count;
    return if not $mprompt_length;

    state $last_color //= $C{'T'};
    $mprompt_length = 17 + $mprompt_length;

    my $term_width = [AMOS7::TERM::terminal_size]->[0];

    if ( ( $mprompt_length + $stars_count ) >= $term_width ) {
        if ( $last_color eq $C{'T'} ) {
            $last_color = $C{'g'};
        } else {
            $last_color = $C{'T'};
        }
        printf {$TTY_OUTPUT} "\r%s%s: %s%s %s %s%s :. %s",
            $C{'R'}, $C{'0'}, $C{'T'}, $C{'B'},
            $currrent_pass_prompt,
            $C{'R'}, $C{'0'}, $C{'R'} . $last_color;
        return TRUE;
    } else {
        return FALSE;
    }

}

sub show_rnd_stars {
    my $mprompt_length = shift // 0;
    my $add_more_count = ( 10 - $pwd_cur_len ) / 5;
    $add_more_count = 0 if $add_more_count < 0;
    my $rnd_keys = sprintf qw| %u |, 1.2 + rand( 1 + $add_more_count );
    my $stars_total_count = scalar @rnd_count;
    my $add_count         = 0;
    for ( 1 .. $rnd_keys ) {    ## masking length ##
        if ( term_rewind( $mprompt_length, ++$stars_total_count ) ) {
            $stars_total_count = $add_count = 0;
            @rnd_count         = ();               ##  to be improved  ##
        }
        ++$add_count and print {$TTY_OUTPUT} qw| * |;
        Time::HiRes::sleep rand( 0.13 / $rnd_keys );
    }
    push @rnd_count, $add_count;
}

sub del_rnd_stars {
    if (@rnd_count) {
        for ( 1 .. pop @rnd_count ) {
            print {$TTY_OUTPUT} "\b \b";
            Time::HiRes::sleep( rand(0.13) );
        }
    }
}

sub timeout_stars {
    my $rewind_delay = 0.777;
    while (@rnd_count) {
        for ( 1 .. pop @rnd_count ) {
            print {$TTY_OUTPUT} "\b \b";
            Time::HiRes::sleep( $rewind_delay *= 0.84 );
            Event::loop(0.07);
        }
    }
}

sub rewind_stars {
    my $rewind_delay = 0.007;
    while (@rnd_count) {
        for ( 1 .. pop @rnd_count ) {
            print {$TTY_OUTPUT} "\b \b";
            Time::HiRes::sleep( $rewind_delay *= 1.042 );
            Event::loop(0.07);
        }
    }
}

sub reset_stars {
    while (@rnd_count) {
        for ( 1 .. pop @rnd_count ) {
            print {$TTY_OUTPUT} "\b \b";
            Time::HiRes::sleep 0.007;
        }
    }
}

return TRUE ##################################################################

#,,,,,.,.,,.,,..,,.,,,..,,,,.,,.,,..,,.,.,,.,,..,,...,...,...,,,,,,,.,.,.,,..,
#2Y3ZVGT2PKKYTWPZMJRXLKCDHH472F2VRPQK3X7YSSPGLF7MVMDKPLQE6XJYD6CWTEP36IY5JGCG4
#\\\|MYNOB5WC65HRPMLBYJZSZNTR2IMY5F7ZXVAVHRKUGEVJ7JYIHHR \ / AMOS7 \ YOURUM ::
#\[7]F3QVWUIJKS6EXBIUVF2V65UQUD3SVSLK3JZWH4HSIC3F2EFDFOBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
