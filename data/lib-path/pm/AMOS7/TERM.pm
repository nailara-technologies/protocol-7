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
use POSIX;
use POSIX::SigSet;
use POSIX::SigAction;
use Term::ReadLine;
use Time::HiRes          qw| sleep |;
use Crypt::PRNG::Fortuna qw| rand |;

use Exporter;
use base qw| Exporter |;
use vars qw| $VERSION @EXPORT @EXPORT_OK |;

my $VERSION = qw| AMOS7::TERM-VERSION.7OT2XVQ |;

@EXPORT_OK = qw[
    terminal_title has_tty history_init history_add history_up
    history_down history_page_up history_page_down editor_init
    editor_process_key editor_get_buffer editor_submit editor_reset
    editor_load cursor_render cursor_clear_old cursor_set_color
    cursor_set_animation cursor_enable cursor_disable
    frame_border_line frame_rule_line frame_colorize_content frame_bar
];

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
our %before_readline_signals;
our @override_signal_nums = ( SIGINT, SIGTERM, SIGQUIT, SIGABRT, SIGHUP );

our $pwd_cur_len           //= 0;
our $pwd_min_len           //= 13;
our $PASSWD_READ_TIMEOUT   //= 13;
our $pwd_read_aborted      //= FALSE;
our $term_read_key_support //= FALSE;
our $TTY_read_size         //= 2048;

our $term;
our $TTY_IN;
our $TERM_ios;
our $TTY_OUTPUT;
our $READ_BUFFER;
our $TTY_fd_restore;
our $original_flags;
our $username_regex;
our $currrent_pass_prompt;
our $currrent_uname_prompt;
our $prompt_prefix_string //= qw| : |;
our $title_prefix         //= qw| . |;

our @rnd_count;

##[ CURSOR RENDERING ]########################################################

our %cursor_state = (
    enabled    => TRUE,          ##  display custom cursor  ##
    color_code => '',            ##  current color code [ phosphor green ]  ##
    animation  => qw| static |,  ##  animation mode for future use  ##
);

##[ PROTOCOL-7 COLOR PALETTE ]################################################

our %p7_colors = (
    'p7_fg_0000' => "\e[38;2;68;39;172m",    ##  purple  ##
    'p7_fg_0001' => "\e[38;2;38;46;153m",    ##    blue  ##
    'p7_fg_0002' => "\e[38;2;170;94;2m",     ##   brown  ##
    'p7_fg_0003' => "\e[38;2;9;170;94m",     ##  phosphor green [ cursor ]  ##
    'p7_fg_0004' => "\e[38;2;6;71;195m",     ##  TRUE blue       [ text ]   ##
    ##  neon amber  [ brighter 0002 ]  ##
    'p7_fg_0005' => "\e[38;2;197;141;7m",
    ##  neon green  [ brighter 0003 ]  ##
    'p7_fg_0006' => "\e[38;2;71;195;6m",
);

##[ HISTORY MANAGEMENT ]######################################################

our @history_entries;
### current position in history [ scalar @history_entries = new ] ##
our $history_current_index = 0;

our $history_filename    = 'nshell.history';
our $history_max_size    = 1000;    ##   maximum history entries to keep  ##
our $history_session_gap = 300;     ##  session gap in seconds [ 5 min ]  ##

sub history_init {

    my $filename    = shift // $history_filename;
    my $max_size    = shift // $history_max_size;
    my $session_gap = shift // $history_session_gap;

    $history_filename    = $filename;
    $history_max_size    = $max_size;
    $history_session_gap = $session_gap;

    ## try to load existing history
    if ( eval { require AMOS7::FILE } ) {
        my @entries = AMOS7::FILE::read_all_timestamped_multiline($filename);
        if (@entries) {
            @history_entries = @entries;
            ## new command position
            $history_current_index = $#history_entries + 1;

            return scalar @history_entries;
        }
    }

    $history_current_index = 0;
    return 0;
}

sub history_add {

    my @lines = @ARG;
    return undef if not @lines;

    if ( eval { require AMOS7::FILE } ) {
        my $timestamp
            = AMOS7::FILE::append_timestamped_multiline( $history_filename,
            @lines );
        if ( defined $timestamp ) {
            push @history_entries, [ $timestamp, \@lines ];

            ## trim history if exceeds max size
            if ( @history_entries > $history_max_size ) {
                shift @history_entries;
            }
            ## reset to 'new' position
            $history_current_index = $#history_entries + 1;

            return $timestamp;
        }
    }

    return undef;
}

sub history_up {

    return undef if not @history_entries;

    ## moving up in history [ towards older entries ]
    if ( $history_current_index > $#history_entries ) {
        ## first time from new position: jump to last entry
        $history_current_index = $#history_entries;
    } elsif ( $history_current_index > 0 ) {
        ## continue going back
        $history_current_index--;
    }

    if (    $history_current_index >= 0
        and $history_current_index <= $#history_entries ) {
        return $history_entries[$history_current_index]->[1];
    }

    return undef;
}

sub history_down {
    return undef if not @history_entries;
    ## already at new position
    return undef if $history_current_index > $#history_entries;

    ## moving down in history [ towards newer entries ]
    if ( $history_current_index < $#history_entries ) {
        $history_current_index++;
        if ( $history_current_index <= $#history_entries ) {
            return $history_entries[$history_current_index]->[1];
        }
    }

    ## reached the end, return to 'new command' position
    $history_current_index = $#history_entries + 1;
    return undef;
}

sub history_page_up {
    return undef if not @history_entries;
    ## already at new position
    return undef if $history_current_index > $#history_entries;

    ## page up : jump to previous session boundary
    my $current_ts = $history_entries[$history_current_index]->[0];
    my $target_idx = $history_current_index;

    ## convert current timestamp to numeric seconds
    my $current_delta = _timestamp_to_delta($current_ts);
    return undef if not defined $current_delta;

    ## search backwards for session boundary
    for ( my $i = $history_current_index - 1; $i >= 0; $i-- ) {
        my $prev_ts    = $history_entries[$i]->[0];
        my $prev_delta = _timestamp_to_delta($prev_ts);
        next if not defined $prev_delta;

        my $gap = $current_delta - $prev_delta;
        if ( $gap > $history_session_gap ) {
            $target_idx = $i;
            last;
        }
    }

    $history_current_index = $target_idx;
    return $history_entries[$history_current_index]->[1]
        if $history_current_index >= 0;

    return undef;
}

sub history_page_down {
    return undef if not @history_entries;
    ## already at new position
    return undef if $history_current_index > $#history_entries;

    ## page down : jump to next session boundary
    my $current_ts = $history_entries[$history_current_index]->[0];
    my $target_idx = $history_current_index;

    ## convert current timestamp to numeric seconds
    my $current_delta = _timestamp_to_delta($current_ts);
    return undef if not defined $current_delta;

    ## search forwards for session boundary
    for ( my $i = $history_current_index + 1; $i <= $#history_entries; $i++ )
    {
        my $next_ts    = $history_entries[$i]->[0];
        my $next_delta = _timestamp_to_delta($next_ts);
        next if not defined $next_delta;

        my $gap = $next_delta - $current_delta;
        if ( $gap > $history_session_gap ) {
            $target_idx = $i;
            last;
        }
    }

    if ( $target_idx > $history_current_index ) {
        $history_current_index = $target_idx;
        return $history_entries[$history_current_index]->[1];
    }

    ## reached the end, return to 'new command' position
    $history_current_index = -1;
    return undef;
}

## helper function : convert base32 network timestamp to delta seconds
sub _timestamp_to_delta {

    my $timestamp = shift // return undef;

    ## trying to use Protocol-7 conversion if available
    if ( defined $main::code{'base.ntime.delta_seconds'} ) {
        return $main::code{'base.ntime.delta_seconds'}->($timestamp);
    }

    ## fallback : Base32 alphabet for manual conversion  Protocol-7 uses: 0-9,
    ## A-V [ 22 chars total ]  using qw with grouped formatting to preserve
    ## alignment
    my %base32_map = (
        qw|
            0 0   1 1   2 2   3 3   4 4
            5 5   6 6   7 7   8 8   9 9
            A 10  B 11  C 12  D 13  E 14
            F 15  G 16  H 17  I 18  J 19
            K 20  L 21  M 22  N 23  O 24
            P 25  Q 26  R 27  S 28  T 29
            U 30  V 31
            |
    );

    ## convert base32 string to numeric value
    my $numeric_ts = 0;
    my @chars      = split //, uc($timestamp);

    foreach my $char (@chars) {
        return undef if not defined $base32_map{$char};
        $numeric_ts = $numeric_ts * 32 + $base32_map{$char};
    }

    ## calculating delta from current time [ rough approximation ] in seconds
    ## from some epoch
    my $now = time();
    return $numeric_ts;    ## returning the converted value for comparison
}

##[ USER-INTERACTION ]########################################################

sub user_and_passwd {
    my $term_title = shift // '';
    my $repeat_pwd = shift // FALSE;

    my $username;
    my $read_passwd;

    $currrent_uname_prompt = sprintf '%s name :. ', $prompt_prefix_string;

    $term = Term::ReadLine->new('user-and-pwd');
    $term->ornaments('');
    $term->enableUTF8();
    $term->MinLine(undef);
    Term::ReadLine->clear_history();

REREAD_NAME:

    terminal_title($term_title) if length $term_title;
    printf "%s%s\n", $C{'0'}, $prompt_prefix_string;

    override_signals();
    $username = $term->readline($currrent_uname_prompt);
    restore_signals();

    $username =~ s,(^[\t ]+|[\t ]+$),,g if defined $username;

    if (    defined $username_regex
        and defined $username
        and length $username
        and $username !~ $username_regex ) {
        my $err_reason_str = '<< username contains not valid characters >>';
        if ( defined $main::PROTOCOL_SEVEN ) {
            printf "%s:\n", $C{'0'};
            $main::code{'base.logs'}->( 0, $err_reason_str, $pwd_min_len );
        } else {
            warn_err( ' %s <{NC}>', -1, $err_reason_str );
        }
        Time::HiRes::sleep(1.24);
        goto REREAD_NAME;
    }

    return undef if not defined $username or not length $username;

    if ( not $repeat_pwd ) {
        $read_passwd = AMOS7::TERM::read_password_single( undef, undef, 0 );
    } else {
        $read_passwd = AMOS7::TERM::read_password_repeated( undef, undef, 0 );
    }

    return undef if not defined $read_passwd;

    return ( $username, $read_passwd );
}

sub has_tty {
    ## check if a TTY is available for interactive I/O  returns TRUE if any of
    ## STDIN, STDOUT, STDERR is connected to a TTY or if Term::ReadLine can
    ## find a console

    ## first try Term::ReadLine->findConsole [ finds /dev/tty or similar ]
    my ( $in, $out ) = Term::ReadLine->findConsole;
    return TRUE if $in && -t $in;

    ## fall back to checking if any standard stream is a TTY
    return TRUE if -t *STDIN;
    return TRUE if -t *STDOUT;
    return TRUE if -t *STDERR;

    return FALSE;
}

sub read_password_repeated {

    my $password_type_msg = shift // qw| password |;
    my $term_title        = shift // '';
    my $output_lines      = shift // 1;
    my $input_timeout     = shift // $PASSWD_READ_TIMEOUT;
    $output_lines = 0 if $output_lines !~ m|^\d+$|;

    ## remaining args are options [ e.g. fallback_on_no_tty => 'read_stdin' ]
    my %options       = @ARG;
    my $fallback_mode = $options{fallback_on_no_tty} // qw| read_stdin |;

    ## only initialize TTY if we have a TTY available
    if ( AMOS7::TERM::has_tty() ) {
        AMOS7::TERM::init_TTY_no_echo( undef, $input_timeout );
    } elsif ( $fallback_mode eq qw| raise_exception | ) {
        error_exit('no tty available for password input');
    } elsif ( $fallback_mode eq qw| return_undef | ) {
        return undef;
    }
    ## else: 'read_stdin' mode - continue without TTY

    ( my $password_0, my $password_1 );

    while (not defined $password_0
        or not defined $password_1
        or $password_0 ne $password_1 ) {

        ( $password_0, my $abort_mode )
            = read_password_single( sprintf( 'enter %s', $password_type_msg ),
            $term_title, $output_lines, $input_timeout, %options );

        if ( not defined $password_0 and $abort_mode ne FALSE ) {
            AMOS7::TERM::close_TTY_no_echo(FALSE);
            return undef if defined $main::PROTOCOL_SEVEN;    ##  zenka  ##
            ##[ had already exited otherwise ]##
        } else {
            ( $password_1, my $abort_mode )
                = read_password_single(
                sprintf( 're-enter %s', $password_type_msg ),
                '', $output_lines, $input_timeout, %options );

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
                if ( AMOS7::TERM::wait_or_abort(1.24) )    ##  1.24s delay  ##
                {    ##[  abort by user  ]##
                    say '';
                    if ( defined $main::PROTOCOL_SEVEN ) {
                        printf "%s%s\n", $C{'0'}, $prompt_prefix_string;
                        $main::code{'base.log'}
                            ->( 0, ' [ password read aborted ]' );
                        printf "%s%s\n", $C{'0'}, $prompt_prefix_string;
                    } else {
                        AMOS7::TERM::close_TTY_no_echo(FALSE);
                        error_exit(' [ password read aborted ]');
                    }
                }
            }
            if ( $abort_mode ne FALSE ) {
                undef $password_0;
                undef $password_1;
                print $C{'R'};

                AMOS7::TERM::close_TTY_no_echo(FALSE);
                return undef;
            }
        }
    }

    print sprintf( "%s%s\n", $C{'0'}, $prompt_prefix_string ) x $output_lines;

    AMOS7::TERM::close_TTY_no_echo(FALSE);
    return $password_0;
}

sub read_password_single {
    ## prefix with ':no-enter:' to avoid 'enter ' prefix
    my $message_prompt = sprintf( 'enter %s', shift // qw| password | );
    $message_prompt =~ s|enter ((re\-)?)enter|$1enter|;    ## allows re-enter
    $message_prompt =~ s|^enter :no-enter: ||;             ## special case
    my $term_title    = shift // '';
    my $output_lines  = shift // 1;
    my $input_timeout = shift // $PASSWD_READ_TIMEOUT;
    $output_lines = 0 if $output_lines !~ m|^\d+$|;

    ## remaining args are options [ e.g. fallback_on_no_tty => 'read_stdin' ]
    my %options       = @ARG;
    my $fallback_mode = $options{fallback_on_no_tty} // 'read_stdin';

    ## check if we have a TTY available
    if ( not AMOS7::TERM::has_tty() ) {
        ## no TTY available - handle fallback
        if ( $fallback_mode eq 'raise_exception' ) {
            error_exit('no tty available for password input');
        } elsif ( $fallback_mode eq 'return_undef' ) {
            return ( undef, FALSE );
        } elsif ( $fallback_mode eq 'read_stdin' ) {
            ## read password directly from STDIN [ no masking, no TTY ]
            print $message_prompt . " " if length $message_prompt;
            STDOUT->flush();
            my $password = <STDIN>;
            print "\n";

            ## EOF on stdin ($password undef) must abort, not retry -- ##
            ## otherwise a closed/exhausted stdin re-reads instantly   ##
            ## forever (no blocking wait on true EOF), spinning the    ##
            ## caller's retry loop at full CPU with no way out         ##
            return ( undef, TRUE ) if not defined $password;

            chomp($password);
            return ( $password, FALSE );
        }
    }

    $currrent_pass_prompt = $message_prompt;
    my $mprompt_length = 8 + length $message_prompt;

    my $read_chars_buffer;
    $pwd_cur_len = 0;
    my $passwd_mlen     = 64;
    my $tty_read_size   = 1026;
    my $max_XOR_chars   = 1024;
    my $autoinc_timeout = TRUE;

    my $colored_prompt = sprintf "%s%s\n%s%s %s%s %s %s%s :. %s", $C{'0'},
        $prompt_prefix_string,
        $C{'0'}, $prompt_prefix_string, $C{'T'}, $C{'B'},
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

    if ( [ caller(1) ]->[3] ne qw| AMOS7::TERM::read_password_repeated | ) {
        AMOS7::TERM::init_TTY_no_echo( $colored_prompt, $input_timeout );
    } else {
        ##[ flushing input again ]##
        AMOS7::TERM::discard_buffered_input();
        AMOS7::TERM::reset_read_password_buffer();
        AMOS7::TERM::set_input_timeout($input_timeout);
        print {$TTY_OUTPUT} $colored_prompt;
    }
    my $abort_mode               = FALSE;
    my $continue_reading         = TRUE;
    my $extended_processing_mode = TRUE;

    while ($continue_reading) {

        my $show_stars = TRUE;

        my $read_chrs
            = AMOS7::TERM::read_to_buffer_TTY( \$read_chars_buffer,
            $tty_read_size );

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

                if ( $code == 10 or $code == 13 ) {    ## end processing ##
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

    if ( [ caller(1) ]->[3] ne qw| AMOS7::TERM::read_password_repeated | ) {
        AMOS7::TERM::close_TTY_no_echo(TRUE);
    } else {
        say {$TTY_OUTPUT} '';
    }

    $read_chars_buffer = $XOR_buffer if not $extended_processing_mode;

    $read_chars_buffer = undef if $abort_mode ne FALSE;

    ##  checking min pwd length  ##
    ###
    if ( defined $read_chars_buffer
        and length($read_chars_buffer) < $pwd_min_len ) {
        if ( defined $main::PROTOCOL_SEVEN ) {
            printf "%s:\n", $C{'0'};
            $main::code{'base.logs'}
                ->( 0, '<<  pasword min len is %d  >>', $pwd_min_len );
        } else {
            warn_err( ' <<  pasword min len is %d  >> <{NC}>',
                -1, $pwd_min_len );
        }
        $read_chars_buffer = '';    ##  reset password entered  ##
        if ( AMOS7::TERM::wait_or_abort(1.24) )    ##  1.24s delay  ##
        {                                          ##[  abort by user  ]##
            if ( defined $main::PROTOCOL_SEVEN ) {
                printf "%s%s\n", $C{'0'}, $prompt_prefix_string;
                $main::code{'base.log'}->( 0, ' [ password read aborted ]' );
                printf "%s%s\n", $C{'0'}, $prompt_prefix_string;
                return undef;
            } else {
                AMOS7::TERM::close_TTY_no_echo(FALSE);
                error_exit(' [ password read aborted ]');
            }
        } else {
            goto REREAD_PASSWORD;
        }

        ##  display abort reason messages  ##
        ##
    } elsif ( $abort_mode eq qw| user-interrupt | ) {  ##[  abort by user  ]##
        if ( defined $main::PROTOCOL_SEVEN ) {
            printf "%s%s\n", $C{'0'}, $prompt_prefix_string;
            $main::code{'base.log'}->( 0, ' [ password read aborted ]' );
            printf "%s%s\n", $C{'0'}, $prompt_prefix_string;
        } else {
            AMOS7::TERM::close_TTY_no_echo(FALSE);
            error_exit(' [ password read aborted ]');
        }
    } elsif ( $abort_mode eq qw| timeout | ) {         ##[ timeout ]##
        if ( defined $main::PROTOCOL_SEVEN ) {         ##  zenka  ##
            printf "%s%s\n", $C{'0'}, $prompt_prefix_string;
            $main::code{'base.log'}->( 0, '[ password input timeout ]' );
            printf "%s%s\n", $C{'0'}, $prompt_prefix_string;
            for ( 0 .. 6 ) {
                Time::HiRes::sleep(0.1);
                Event::loop(0.007);
            }
        } else {
            AMOS7::TERM::close_TTY_no_echo(FALSE);
            error_exit(' [ password input timeout ]');
        }
    }

    print sprintf( "%s%s\n", $C{'0'}, $prompt_prefix_string ) x $output_lines;

    return ( $read_chars_buffer, $abort_mode ) if wantarray;
    return $read_chars_buffer;
}

sub terminal_title {

    my $term_title = shift // '';
    return FALSE if not length $term_title;

    my $clear_console
        = ( defined $main::PROTOCOL_SEVEN
            and $main::data{'system'}{'zenka'}{'verbosity'}{'console'} )
        ? ''    ##  do not clear screen with -v option  ##
        : "\e[H\e[2J\e[3J";

    ( my $term_width, undef ) = AMOS7::TERM::terminal_size();
    ## guarding against undefined term_width  [ should not happen with new
    ## defaults ]
    $term_width //= 80;

    my $colon_line
        = qw| : | x
        abs(
        $term_width - length($term_title) - ( 10 + length $title_prefix ) );

    printf { $TTY_OUTPUT // *STDOUT{IO} }
        "%s\n%s%s%s:::.[%s%s %s %s%s].:%s\n%s%s%s%s\n",
        $clear_console,
        $C{'0'}, $title_prefix, $C{'0'}, $C{'T'}, $C{'B'}, $term_title,
        $C{'R'}, $C{'0'},
        $colon_line, $C{'R'}, $C{'0'}, $prompt_prefix_string, $C{'R'};

    return TRUE;    ## true ##
}

sub term_rewind {
    my $mprompt_length = shift // 0;
    my $stars_count    = shift // scalar @rnd_count;
    return if not $mprompt_length;

    state $last_color //= $C{'T'};
    $mprompt_length = 17 + $mprompt_length;

    my $term_width = [ AMOS7::TERM::terminal_size() ]->[0];
    return FALSE if not defined $term_width;  ## return early : i.e. a pipe ##

    if ( ( $mprompt_length + $stars_count ) >= $term_width ) {
        if ( $last_color eq $C{'T'} ) {
            $last_color = $C{'g'};
        } else {
            $last_color = $C{'T'};
        }
        printf {$TTY_OUTPUT} "\r%s%s%s %s%s %s %s%s :. %s",
            $C{'R'}, $C{'0'}, $prompt_prefix_string, $C{'T'}, $C{'B'},
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

##[ TERMINAL [ TTY ] ]########################################################

sub terminal_size {

    my $handle = shift // *STDIN;    ## use *STDOUT for pipe detection ##

    ## return safe defaults if not a TTY
    return ( 80, 24 ) if not -t $handle;

    state $size       = "\0" x 8;
    state $TIOCGWINSZ = 21523;

    ## if ioctl fails, return defaults instead of undef
    ioctl( $handle, $TIOCGWINSZ, $size ) or return ( 80, 24 );
    my $size_aref = [ unpack qw| S!S!S!S! |, $size ];

    return ( $size_aref->[1], $size_aref->[0] );
}

sub set_input_timeout {
    my $input_timeout = shift // $PASSWD_READ_TIMEOUT;
    if ( $input_timeout == 0 ) {
        $TERM_ios->setcc( VTIME, 0 );
    } else {
        $TERM_ios->setcc( VTIME, sprintf qw| %u |, 10 * $input_timeout );
    }
    $TERM_ios->setattr( $TTY_fd_restore, TCSAFLUSH );    ## discards input ##
}

sub get_input_timeout {
    return $TERM_ios->getcc(VTIME);
}

sub read_to_buffer_TTY {

    my $buffer_sref   = shift // \$READ_BUFFER;
    my $tty_read_size = shift // $TTY_read_size;

    error_exit('TTY_IN handle not opened')
        if not defined $TTY_IN
        or not length fileno $TTY_IN;

    my $buffered_bytes = length( $buffer_sref->$* // '' );

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
            warn_err( 'terminal input unavailable [cannot access STDIN]: %s',
                1, lcfirst($OS_ERROR) );
            return undef;
        } else {
            warn_err( 'terminal input unavailable [%s]: %s',
                1, $in, lcfirst($OS_ERROR) );
            return undef;
        }
    }

    if ( not open $TTY_OUTPUT, qw| >> |, $out ) {
        if ( not open $TTY_OUTPUT, qw| >>& |, *STDOUT{IO} ) {
            warn_err(
                'terminal output unavailable [cannot access STDOUT]: %s',
                1, lcfirst($OS_ERROR) );
            return undef;
        } else {
            warn_err( 'terminal output unavailable [%s]: %s',
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
        $TERM_ios->setcc( VMIN,  1 );    ##[ minimum characters read ]##
    }

    $TERM_ios->setattr( $TTY_fd_restore, TCSAFLUSH );

    return TRUE;
}

sub wait_or_abort {

    my $wait_delay      = shift // 1.24;
    my $time_start      = sprintf qw|%.5f|, Time::HiRes::time;
    my $delay_remaining = $wait_delay;
    my $was_closed      = FALSE;

    if ( not defined $TTY_IN or not length fileno $TTY_IN ) {
        AMOS7::TERM::init_TTY_no_echo();    ##  reopen TTY  ##
        $was_closed = TRUE;
    }

    while ( $delay_remaining > 0 ) {
        my $status = AMOS7::TERM::discard_buffered_input($delay_remaining);
        if ($status) {
            AMOS7::TERM::close_TTY_no_echo() if $was_closed;
            return TRUE  if $status == 2;    ## abort condition ##
            return FALSE if $status == 1;    ## waiting skipped ##
        }
        $delay_remaining = $wait_delay       ##[ updating delay ]##
            - ( sprintf( qw|%.5f|, Time::HiRes::time ) - $time_start );
    }

    AMOS7::TERM::close_TTY_no_echo(FALSE) if $was_closed;  ## closing again ##

    return FALSE;    ##  not aborting  ##
}

sub discard_buffered_input {

    my $input_timeout = shift // 0;    ## optional value for delays ##

    ## return codes  0 : input discarded  1 : continue  2 : interrupt ##

    state $interrupt_re;
    state $continue_regex;
    state $seq_END //= chr 126;
    state $sequ_begin //= join '', map {chr} qw| 27 91 |;
    if ( not defined $TTY_IN or not length fileno $TTY_IN ) {
        warn_err('TTY_IN handle not opened <{C1}>');
        return undef;
    } elsif ( not defined $interrupt_re or not defined $continue_regex ) {
        my @continue_code      = qw| 10 13 |;
        my @interrupt_asc_code = qw| 3 4 27 |;
        $interrupt_re   = join '', map {chr} @interrupt_asc_code;
        $continue_regex = join '', map {chr} @continue_code;
        $interrupt_re   = qr|[$interrupt_re]|;
        $continue_regex = qr|[$continue_regex]|;
    }
    if ( index( [ caller(1) ]->[3], qw| AMOS7::TERM:: |, 0 ) != 0 ) {
        ##[ only flush it ]##
        $TERM_ios->setattr( $TTY_fd_restore, TCSAFLUSH );
        return 0;    ## input discarded \ no abort ##
    } else {
        my $restore_time = AMOS7::TERM::get_input_timeout() // 13;
        AMOS7::TERM::set_input_timeout($input_timeout);

        ## check for interrupt ##
        AMOS7::TERM::read_to_buffer_TTY( \my $check_buffer );
        AMOS7::TERM::set_input_timeout($restore_time);

        ## rem. sequence encoded keys ##
        $check_buffer =~ s|\Q$sequ_begin\E.$seq_END?||g;
        ## check for interrupts and continuation key ##
        return 2 if $check_buffer =~ $interrupt_re;
        return 1 if $check_buffer =~ $continue_regex;
    }
    return 0;    ## regular continuation \ no abort ##
}

sub reset_read_password_buffer {

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
    return TRUE;
}

sub close_TTY_no_echo {

    my $send_newline = shift // TRUE;

    AMOS7::TERM::reset_read_password_buffer();

    print {$TTY_OUTPUT} chr(10) if $send_newline and defined $TTY_OUTPUT;
    return undef                if not defined $TERM_ios;

    $TERM_ios->setlflag($original_flags);

    while ( my ( $field, $_val ) = each %CC_backup ) {
        $TERM_ios->setcc( $CC_FIELDS{$field}, $_val );
    }
    $TERM_ios->setattr( $TTY_fd_restore, TCSAFLUSH );

    close($TTY_IN)     if defined $TTY_IN     and length fileno($TTY_IN);
    close($TTY_OUTPUT) if defined $TTY_OUTPUT and length fileno($TTY_OUTPUT);

    $TTY_OUTPUT = $TTY_IN = undef;

    return TRUE;
}

## readline ##

sub override_signals {

    my $sigset     = POSIX::SigSet->new(@override_signal_nums);
    my $action_sig = POSIX::SigAction->new( \&readline_signals, $sigset );

    foreach my $posix_signal (@override_signal_nums) {
        my $old_action = {};
        POSIX::sigaction( $posix_signal, $action_sig, $old_action );

        $action_sig = POSIX::SigAction->new( $old_action->{'HANDLER'},
            $old_action->{'MASK'}, $old_action->{'FLAGS'} );

        $before_readline_signals{$posix_signal} = $action_sig;
    }

    return TRUE;
}

sub restore_signals {

    my $sigset = POSIX::SigSet->new(@override_signal_nums);

    foreach my $posix_signal (@override_signal_nums) {
        my $action_sig = $before_readline_signals{$posix_signal};
        POSIX::sigaction( $posix_signal, $action_sig );
    }

    return TRUE;
}

sub readline_signals {
    my $SIG_name = shift;

    $OUTPUT_AUTOFLUSH = TRUE;
    if ( $SIG_name eq qw| HUP | ) {
        print "\e[H\e[2J\e[3J"; ## 'clear screen' [remote trigger] : SIGHUP ##
    } else {
        clear_name_line();
        say '';
    }

    $term->free_line_state;
    $term->cleanup_after_signal;

    my $reason_str
        = $SIG_name ne qw| INT |
        ? sprintf qw| SIG%s |, $SIG_name
        : undef;

    exit_user_passwd($reason_str);
}

sub clear_name_line {

    my $line_width = [ terminal_size() ]->[1];
    my $line_space = ' ' x abs( $line_width - length $currrent_uname_prompt );
    print sprintf "\r%s%s%s%s%s%s\r", $C{b}, $C{0}, $currrent_uname_prompt,
        $C{R},
        $line_space, $C{'R'};
}

sub exit_user_passwd {
    my $abort_reason        = shift;
    my $exit_message_string = 'user details input aborted';
    $exit_message_string .= sprintf ' [ %s ]', $abort_reason
        if defined $abort_reason;
    error_exit($exit_message_string);
}

##[ COMMAND LINE EDITOR ]#####################################################

sub editor_init {
    ## initializing and return editor state reference
    return {
        buffer      => '',
        cursor_pos  => 0,
        kill_buffer => '',
        color_set   => FALSE,
    };
}

sub editor_process_key {
    my ( $editor, $key, %colors ) = @ARG;

    return undef if !defined $editor or !defined $key;

    my $result = {
        action        => 'none',
        output        => '',
        complete      => FALSE,
        should_signal => undef,
    };

    ## newline - command complete
    if ( $key eq "\n" or $key eq "\r" ) {
        $result->{action}   = 'newline';
        $result->{complete} = TRUE;
        $result->{output}   = "\n";
        return $result;
    }

    ## Ctrl-C - send SIGINT
    if ( $key eq "\x03" ) {
        $result->{action}        = 'signal';
        $result->{should_signal} = 'INT';
        return $result;
    }

    ## Ctrl-D - Delete char at cursor [ or EOF if buffer empty ]
    if ( $key eq "\x04" ) {
        if ( $editor->{cursor_pos} < length $editor->{buffer} ) {
            ## determine byte length of the utf-8 char at cursor position
            my $first_b = ord(
                substr( $editor->{buffer}, $editor->{cursor_pos}, 1 ) );
            my $del_len_d
                = ( $first_b & 0xF8 ) == 0xF0 ? 4
                : ( $first_b & 0xF0 ) == 0xE0 ? 3
                : ( $first_b & 0xE0 ) == 0xC0 ? 2
                :                               1;
            ## delete character at cursor position
            substr( $editor->{buffer}, $editor->{cursor_pos}, $del_len_d,
                '' );
            $result->{action} = 'delete';

            ## output : rest of line + clear to end + reposition
            my $rest = substr( $editor->{buffer}, $editor->{cursor_pos} );
            $result->{output}
                = $rest . ' ' . ( "\x08" x ( length($rest) + 1 ) );
        }
        return $result;
    }

    ## Ctrl-A - move cursor to start of line
    if ( $key eq "\x01" ) {
        my $steps = $editor->{cursor_pos};
        if ( $steps > 0 ) {
            $editor->{cursor_pos} = 0;
            $result->{action}     = 'cursor_left';
            $result->{output}     = "\x08" x $steps;    ## backspace N times
        }
        return $result;
    }

    ## Ctrl-E - move cursor to end of line
    if ( $key eq "\x05" ) {
        my $end_pos = length $editor->{buffer};
        my $steps   = $end_pos - $editor->{cursor_pos};
        if ( $steps > 0 ) {
            $editor->{cursor_pos} = $end_pos;
            $result->{action}     = 'cursor_right';
            $result->{output}
                = substr( $editor->{buffer}, $editor->{cursor_pos} - $steps,
                $steps );
        }
        return $result;
    }

    ### Ctrl-K - kill to end of line
    ##         [ deleting from cursor to end, save to kill buffer ]
    if ( $key eq "\x0b" ) {
        my $rest_len = length( $editor->{buffer} ) - $editor->{cursor_pos};
        if ( $rest_len > 0 ) {
            $editor->{kill_buffer}
                = substr( $editor->{buffer}, $editor->{cursor_pos},
                $rest_len, '' );
            $result->{action} = 'kill_to_end';
            $result->{output}
                = ' ' x $rest_len . ( "\x08" x $rest_len );    ## clear to end
        }
        return $result;
    }

    ### Ctrl-U - kill from start of line to cursor
    ##         [ deleting and save to kill buffer ]
    if ( $key eq "\x15" ) {
        if ( $editor->{cursor_pos} > 0 ) {
            my $deleted_len = $editor->{cursor_pos};
            $editor->{kill_buffer}
                = substr( $editor->{buffer}, 0, $editor->{cursor_pos}, '' );
            $editor->{cursor_pos} = 0;
            $result->{action}     = 'kill_from_start';

            ## output : backspace to start  + remaining text + clear rest +
            ## reposition
            my $rest                = substr( $editor->{buffer}, 0 );
            my $deleted_display_len = $deleted_len;
            $result->{output}
                = ( "\x08" x $deleted_len )
                . $rest
                . ( ' ' x $deleted_display_len )
                . ( "\x08" x ( $deleted_display_len + length($rest) ) );
        }
        return $result;
    }

    ## Ctrl-W - kill word backward [ delete previous word, save to kill buffer
    ## ]
    if ( $key eq "\x17" ) {
        if ( $editor->{cursor_pos} > 0 ) {
            my $start_pos = $editor->{cursor_pos};

            ## skip trailing whitespace
            while ( $start_pos > 0
                && substr( $editor->{buffer}, $start_pos - 1, 1 ) =~ m|\s| ) {
                $start_pos--;
            }

            ## skip word characters [ non-whitespace ]
            while ( $start_pos > 0
                && substr( $editor->{buffer}, $start_pos - 1, 1 ) !~ m|\s| ) {
                $start_pos--;
            }

            if ( $start_pos < $editor->{cursor_pos} ) {
                $editor->{kill_buffer}
                    = substr( $editor->{buffer}, $start_pos,
                    $editor->{cursor_pos} - $start_pos, '' );
                my $deleted_len = $editor->{cursor_pos} - $start_pos;
                $editor->{cursor_pos} = $start_pos;
                $result->{action}     = 'kill_word';
                $result->{output}     = "\x08" x $deleted_len;
            }
        }
        return $result;
    }

    ## Ctrl-Y - yank [ paste kill buffer at cursor position ]
    if ( $key eq "\x19" ) {
        if ( length $editor->{kill_buffer} ) {
            substr( $editor->{buffer}, $editor->{cursor_pos}, 0,
                $editor->{kill_buffer} );
            $result->{action} = 'yank';

            ## output : yanked text + rest of buffer + reposition cursor
            my $rest = substr( $editor->{buffer},
                $editor->{cursor_pos} + length( $editor->{kill_buffer} ) );
            $result->{output} = $editor->{kill_buffer} . $rest;
            if ( length $rest > 0 ) {
                ## noving cursor back to original position
                $result->{output} .= "\x08" x length($rest);
            }
            $editor->{cursor_pos} += length $editor->{kill_buffer};
        }
        return $result;
    }

    ## left arrow key - move cursor left [ ANSI: \e[D ]
    if ( $key eq "\e[D" or $key eq "\x1b[D" ) {
        if ( $editor->{cursor_pos} > 0 ) {
            ## scan back over utf-8 continuation bytes [ 10xxxxxx = 0x80-0xBF
            ## ]
            my $step = 1;
            while (
                $editor->{cursor_pos} - $step > 0
                && (ord(substr(
                            $editor->{buffer},
                            $editor->{cursor_pos} - $step, 1
                        )
                    ) & 0xC0
                ) == 0x80
            ) {
                $step++;
            }
            $editor->{cursor_pos} -= $step;
            $result->{action} = 'cursor_left';
            $result->{output} = "\x08" x $step;
        }
        return $result;
    }

    ## right arrow key - move cursor right [ ANSI: \e[C ]
    if ( $key eq "\e[C" or $key eq "\x1b[C" ) {
        if ( $editor->{cursor_pos} < length $editor->{buffer} ) {
            ## determine byte length of the utf-8 char at cursor position
            my $first = ord(
                substr( $editor->{buffer}, $editor->{cursor_pos}, 1 ) );
            my $step
                = ( $first & 0xF8 ) == 0xF0 ? 4
                : ( $first & 0xF0 ) == 0xE0 ? 3
                : ( $first & 0xE0 ) == 0xC0 ? 2
                :                             1;
            my $char
                = substr( $editor->{buffer}, $editor->{cursor_pos}, $step );
            $editor->{cursor_pos} += $step;
            $result->{action} = 'cursor_right';
            $result->{output} = $char;    ## echo the character under cursor
        }
        return $result;
    }

    ## delete key escape sequence [ ANSI: \e[3~ ] - delete character at cursor
    if ( $key eq "\e[3~" or $key eq "\x1b[3~" ) {
        if ( $editor->{cursor_pos} < length $editor->{buffer} ) {
            ## determine byte length of the utf-8 char at cursor position
            my $first = ord(
                substr( $editor->{buffer}, $editor->{cursor_pos}, 1 ) );
            my $del_len
                = ( $first & 0xF8 ) == 0xF0 ? 4
                : ( $first & 0xF0 ) == 0xE0 ? 3
                : ( $first & 0xE0 ) == 0xC0 ? 2
                :                             1;
            substr( $editor->{buffer}, $editor->{cursor_pos}, $del_len, '' );
            $result->{action} = 'delete';

            ## output : rest of line + clear to end + reposition
            my $rest = substr( $editor->{buffer}, $editor->{cursor_pos} );
            $result->{output}
                = $rest . ' ' . ( "\x08" x ( length($rest) + 1 ) );
        }
        return $result;
    }

    ## backspace - delete character before cursor  both \x08 [Ctrl+H] and \x7f
    ## [DEL] are treated as backspace since many terminals send backspace as
    ## DEL
    if ( $key eq "\x08" or $key eq "\x7f" ) {
        if ( $editor->{cursor_pos} > 0 ) {
            ## scan back over utf-8 continuation bytes [ 10xxxxxx = 0x80-0xBF
            ## ]
            my $del_len = 1;
            while (
                $editor->{cursor_pos} - $del_len > 0
                && (ord(substr(
                            $editor->{buffer},
                            $editor->{cursor_pos} - $del_len, 1
                        )
                    ) & 0xC0
                ) == 0x80
            ) {
                $del_len++;
            }
            $editor->{cursor_pos} -= $del_len;
            substr( $editor->{buffer}, $editor->{cursor_pos}, $del_len, '' );
            $result->{action} = 'backspace';

            ## output : rest of line + clear + reposition
            my $rest = substr( $editor->{buffer}, $editor->{cursor_pos} );
            $result->{output}
                = "\x08" x $del_len
                . $rest . ' '
                . ( "\x08" x ( length($rest) + 1 ) );
        }
        return $result;
    }

    ## printable character [ check first byte of multi-byte UTF-8 ]
    if ( length $key and ord( substr( $key, 0, 1 ) ) >= 32 ) {
        ## set color on first character
        if ( !length $editor->{buffer} ) {
            $editor->{color_set} = TRUE;
            $result->{output}    = ( $colors{p7_fg_0004} // '' );
        }

        ## insert character at cursor position
        substr( $editor->{buffer}, $editor->{cursor_pos}, 0, $key );
        $editor->{cursor_pos} += length($key);   ## byte-accurate for utf-8 ##
        $result->{action} = 'echo';

        ## output : character + rest of line + reposition cursor
        my $rest = substr( $editor->{buffer}, $editor->{cursor_pos} );
        $result->{output} .= $key . $rest;
        if ( length $rest > 0 ) {
            ## moving cursor back to new position
            $result->{output} .= "\x08" x length($rest);
        }

        return $result;
    }

    return $result;
}

sub editor_get_buffer {
    my $editor = shift;
    return undef if !defined $editor;
    return $editor->{buffer};
}

sub editor_submit {
    my $editor = shift;
    return undef if !defined $editor;

    my $result = $editor->{buffer};
    editor_reset($editor);
    return $result;
}

sub editor_reset {
    my $editor = shift;
    return if !defined $editor;

    $editor->{buffer}      = '';
    $editor->{cursor_pos}  = 0;
    $editor->{kill_buffer} = '';
    $editor->{color_set}   = FALSE;

    return TRUE;
}

sub editor_load {
    my ( $editor, $text ) = @ARG;
    return if !defined $editor;

    $editor->{buffer}      = $text // '';
    $editor->{cursor_pos}  = length $editor->{buffer};
    $editor->{kill_buffer} = '';
    $editor->{color_set}   = ( length $editor->{buffer} ) ? TRUE : FALSE;

    return TRUE;
}

##[ CURSOR RENDERING ]########################################################

sub cursor_render {
    ## render custom cursor at current position in editor buffer returns ANSI
    ## codes to display cursor with color and optional underline important:
    ## does NOT reset at end [ color persists for next operation ]
    my ( $buffer, $cursor_pos ) = @ARG;

    return '' if not $cursor_state{'enabled'};

    my $char_at_cursor = substr( $buffer, $cursor_pos, 1 ) // '';
    my $color          = $cursor_state{color_code};

    if ( $char_at_cursor eq '' or $char_at_cursor eq ' ' ) {
        ## at end of buffer or on space: show colored underscore no reset at
        ## end [ preserve color for next render ]
        return $color . '_' . "\x08";    ## colored underscore then backspace
    } else {
        ## on a character : show with underline attribute [preserves
        ## character] apply color and underline, reset underline only [NOT all
        ## attributes]
        return $color . "\e[4m" . $char_at_cursor . "\e[24m\x08";
    }
}

sub cursor_clear_old {
    ## clear old cursor position by restoring the character at that position
    ## returns ANSI codes to clear and restore
    my ( $buffer, $old_pos ) = @ARG;

    return '' if !$cursor_state{'enabled'};

    ## bounds check : old position might be beyond buffer after deletions
    return '' if $old_pos >= length($buffer);

    my $char_at_old = substr( $buffer, $old_pos, 1 ) // '';
    my $color       = $cursor_state{'color_code'};

    if ( $char_at_old eq '' or $char_at_old eq ' ' ) {
        ## was showing underscore : clear with space
        return ' ' . "\x08";
    } else {
        ## was showing underlined character : restore it without underline
        return $color . $char_at_old . "\e[0m\x08";
    }
}

sub cursor_set_color {
    ## set cursor color code [ e.g. from loaded color palette ]
    my ($color_code) = @ARG;
    $cursor_state{'color_code'} = $color_code // '';
    return TRUE;
}

sub cursor_set_animation {
    ## setting cursor animation mode for timer-based updates  modes: 'static',
    ## 'pulse', 'blink', etc [ implementation later ]
    my ($animation_mode) = @ARG;
    $cursor_state{'animation'} = $animation_mode // qw| static |;
    return TRUE;
}

sub cursor_enable {
    ## enable custom cursor rendering
    $cursor_state{'enabled'} = TRUE;
    return TRUE;
}

sub cursor_disable {
    ## disable custom cursor rendering
    $cursor_state{'enabled'} = FALSE;
    return TRUE;
}

##[ ASCII FRAME HELPERS ]#####################################################

## render a border line via anchor/fill/slot elasticity model  parameters:
## elements => [{type=>'anchor',value=>..,color=>..},
## {type=>'fill',char=>..,min=>..,color=>..},
## {type=>'slot',name=>..,color=>..}]  values => {name=>string} for slots
## width => target column count reset => ansi reset sequence [ used after
## every colored segment ]
sub frame_border_line {
    my $params = shift // {};

    my $elements = $params->{'elements'} // [];
    my $values   = $params->{'values'}   // {};
    my $width    = $params->{'width'}    // 0;
    my $reset    = $params->{'reset'}    // '';

    return '' if not @{$elements};

    ## sum fixed-width parts and locate fill slots ##
    my $fixed_width = 0;
    my @fill_idx;
    for my $i ( 0 .. $#{$elements} ) {
        my $el = $elements->[$i];
        if ( $el->{'type'} eq qw| anchor | ) {
            $fixed_width += length( $el->{'value'} // '' );
        } elsif ( $el->{'type'} eq qw| slot | ) {
            $fixed_width += length( $values->{ $el->{'name'} } // '' );
        } elsif ( $el->{'type'} eq qw| fill | ) {
            push @fill_idx, $i;
        }
    }

    my $available = $width - $fixed_width;
    $available = 0 if $available < 0;

    ## distribute available column budget across fill elements ##
    my %alloc;
    if (@fill_idx) {
        if ( @fill_idx == 1 ) {
            $alloc{ $fill_idx[0] } = $available;
        } else {
            my $sum_min = 0;
            $sum_min += ( $elements->[$_]->{'min'} // 1 ) for @fill_idx;
            my $used = 0;
            for my $idx (@fill_idx) {
                my $min = $elements->[$idx]->{'min'} // 1;
                my $a   = int( $available * $min / $sum_min );
                $a = 0 if $a < 0;
                $alloc{$idx} = $a;
                $used += $a;
            }
            my $rem = $available - $used;
            $alloc{ $fill_idx[-1] } += $rem if $rem != 0;
        }
    }

    ## assemble line with per-element color wrap ##
    my $line = '';
    for my $i ( 0 .. $#{$elements} ) {
        my $el    = $elements->[$i];
        my $color = $el->{'color'} // '';
        my $r     = length($color) ? $reset : '';
        if ( $el->{'type'} eq qw| anchor | ) {
            my $v = $el->{'value'} // '';
            $line .= $color . $v . $r if length $v;
        } elsif ( $el->{'type'} eq qw| slot | ) {
            my $v = $values->{ $el->{'name'} } // '';
            $line .= $color . $v . $r if length $v;
        } elsif ( $el->{'type'} eq qw| fill | ) {
            my $n = $alloc{$i} // 0;
            $line .= $color . ( $el->{'char'} x $n ) . $r if $n > 0;
        }
    }

    return $line;
}

## convenience wrapper : title on the left, fill dashes to the right  colors
## hash uses keys 'title', 'fill', 'reset' [ any missing = no color ]
sub frame_rule_line {
    my $title = shift // '';
    my $width = shift // 0;
    my $C     = shift // {};

    return frame_border_line(
        {   width    => $width,
            reset    => $C->{'reset'} // '',
            elements => [
                {   type  => qw| anchor |,
                    value => $title,
                    color => $C->{'title'} // '',
                },
                {   type  => qw| fill |,
                    char  => $C->{'char'} // '-',
                    min   => 1,
                    color => $C->{'fill'} // '',
                },
            ],
        }
    );
}

## colorize a content line  splits label:/value with leading/trailing pad also
## handles a separator row [ colon-border + = fill + colon-border ] color-hash
## keys used : fill_colon fill_eq label value
sub frame_colorize_content {
    my $line  = shift // '';
    my $A     = shift // {};
    my $reset = shift // '';
    return $line if not length $line;

    ## separator row : left border + run of = + right border ##
    if ( $line =~ m{^([:.])(\s*=+\s*)([:.])$} ) {
        my ( $lb, $mid, $rb ) = ( $1, $2, $3 );
        return
              ( $A->{'fill_colon'} // '' )
            . $lb
            . $reset
            . ( $A->{'fill_eq'} // '' )
            . $mid
            . $reset
            . ( $A->{'fill_colon'} // '' )
            . $rb
            . $reset;
    }

    my $first = substr( $line, 0, 1 );
    my $last  = length($line) > 1 ? substr( $line, -1, 1 ) : '';
    my $body
        = length($line) > 1
        ? substr( $line, 1, length($line) - 2 )
        : '';

    my $left
        = ( $first eq qw| : | )
        ? ( ( $A->{'fill_colon'} // '' ) . $first . $reset )
        : $first;
    my $right
        = ( $last eq qw| : | )
        ? ( ( $A->{'fill_colon'} // '' ) . $last . $reset )
        : $last;

    my $body_colored;
    if ( $body =~ m{^(\s*)([\w][\w\-\.]*:)(\s+)(.*?)(\s*)$} ) {
        my ( $lpad, $lbl, $sp, $val, $rpad ) = ( $1, $2, $3, $4, $5 );
        $body_colored
            = $lpad
            . ( $A->{'label'} // '' )
            . $lbl
            . $reset
            . $sp
            . ( length($val) ? ( $A->{'value'} // '' ) . $val . $reset : '' )
            . $rpad;
    } elsif ( length $body and $body =~ m{\S} ) {
        if ( $body =~ m{^(\s*)(.*?)(\s*)$} ) {
            my ( $lpad, $mid, $rpad ) = ( $1, $2, $3 );
            $body_colored = $lpad
                . (
                length($mid)
                ? ( $A->{'value'} // '' ) . $mid . $reset
                : ''
                ) . $rpad;
        } else {
            $body_colored = $body;
        }
    } else {
        $body_colored = $body;
    }

    return $left . $body_colored . $right;
}

## render fraction [ 0..1 ] as a left-justified space-padded fill bar
sub frame_bar {
    my $frac  = shift // 0;
    my $width = shift // 0;
    my $char  = shift // ':';

    $frac  = 0 if $frac < 0;
    $frac  = 1 if $frac > 1;
    $width = 0 if $width < 0;

    my $fill = int( $width * $frac );
    $fill = $width if $fill > $width;

    return sprintf( '%-*s', $width, $char x $fill );
}

return TRUE ##################################################################

#,,,.,.,,,.,.,,,,,,,.,...,,,,,,,,,...,,,.,..,,..,,...,...,..,,,,.,,,,,,..,..,,
#3AJ7UGRGPYOJMZZ7IHN2UMDDSADDQZMV5R4GSIUUA7V67L4YU4JWCXIQJ3AOI6CTMR4TDREEOAZAK
#\\\|WVKCRYRZN3ZD7VPK7D3MSOPCDLZSBKDLPULU54NC3XYTXMCBKGD \ / AMOS7 \ YOURUM ::
#\[7]6K3T5VZMBIIB3NNBEDP5D55F4M6K6ZWHJF6HYE36ZKF6M2DXRGBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
