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
use AMOS7::TERM::Frame qw|
    frame_border_line frame_rule_line frame_colorize_content frame_bar |;

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

our $VERSION = qw| AMOS7::TERM-VERSION.325Q2VQ |;

@EXPORT_OK = qw[
    terminal_title has_tty history_init history_add history_up
    history_down history_page_up history_page_down editor_init
    editor_process_key editor_get_buffer editor_submit editor_reset
    editor_load cursor_render cursor_clear_old cursor_set_color
    cursor_set_animation cursor_enable cursor_disable
    frame_border_line frame_rule_line frame_colorize_content frame_bar
    scroll_region_set scroll_region_clear content_area_clear pinned_row_print
    ask confirm_key diff_page wipe_secret
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

## defined in AMOS7::TERM::Frame [ core-only ] : the very same hash via ##
## glob alias, not a copy -- mutating one side is visible on the other  ##
our %p7_colors;
*p7_colors = \%AMOS7::TERM::Frame::p7_colors;

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

sub ask {

    ## generic console question, usable from zenki AND standalone scripts.
    ##
    ## AMOS7::TERM::ask( { question => 'proceed?' } )              yes-no
    ## AMOS7::TERM::ask( { question => 'name', type => 'text' } )
    ## AMOS7::TERM::ask( { question => 'key',  type => 'masked' } )
    ##
    ## 'masked' delegates to read_password_single below, so secret entry keeps
    ## its single implementation rather than growing a second one.
    ##
    ## two properties make this safe to call from anywhere :
    ##
    ## 'given'  when defined it is returned immediately and nothing is printed
    ## -- crypt.C25519.load_keypair's own  parameter-or-prompt shape.  lets a
    ## caller expose a  :tag: or command parameter that turns an interactive
    ## step into a scripted one with no second code path.
    ##
    ## no tty   returns 'default' WITHOUT reading.  a blocking read on a
    ## detached STDIN is how an event-driven zenka wedges itself, so this
    ## refuses rather than risk it.
    ##
    ## BLOCKING : reads STDIN.  call before an event loop is entered, or where
    ## nothing else needs servicing -- the same constraint that makes the
    ## passphrase prompts acceptable during zenka init but not inside a
    ## running form.

    my $params = shift // {};

    return undef if ref $params ne qw| HASH |;

    my $question = $params->{'question'} // return undef;
    my $type     = $params->{'type'}     // qw| yes-no |;
    my $default  = $params->{'default'};
    my $prefix   = $params->{'prefix'} // qw| :. |;

    ## [1] answered programmatically : no prompt, no output ##
    return $params->{'given'} if defined $params->{'given'};

    ## [2] no terminal : never block, hand back the default ##
    return $default if not AMOS7::TERM::has_tty();

    return AMOS7::TERM::read_password_single($question)
        if $type eq qw| masked |;

    ## hint shows which answer 'enter' selects ##
    my $hint = '';
    if ( $type eq qw| yes-no | ) {
        ## parentheses are REQUIRED : 'not' binds looser than ?: , so 'not
        ## defined $default ? A : B' negates the whole ternary chain and
        ## always yields '' -- the hint silently disappeared
        if ( not defined $default ) {
            $hint = ' [y/n]';
        } else {
            $hint = $default ? ' [Y/n]' : ' [y/N]';
        }
    } elsif ( defined $default and length $default ) {
        $hint = sprintf( ' [%s]', $default );
    }

    printf "\n %s %s%s : ", $prefix, $question, $hint;
    STDOUT->flush();

    my $answer = <STDIN>;
    print "\n";

    return $default if not defined $answer;    ## EOF [ ctrl-d ] ##

    chomp $answer;
    $answer =~ s|^\s+||;
    $answer =~ s|\s+$||;

    return $default if not length $answer;
    return $answer  if $type ne qw| yes-no |;

    return TRUE  if $answer =~ m|^y|i;
    return FALSE if $answer =~ m|^n|i;

    return $default;                           ## unparsable : do not guess ##
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

        ## a retry : the previous entries wiped, not just replaced
        wipe_secret( \$password_0 );
        wipe_secret( \$password_1 );

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
                    wipe_secret( \$password_0 );
                    wipe_secret( \$password_1 );
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
                wipe_secret( \$password_0 );
                wipe_secret( \$password_1 );
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
    wipe_secret( \$password_1 );    ## the same value : one copy goes back ##
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

    my $XORchars_count     = 0;
    my $XOR_buffer_pos     = 0;
    my $XOR_stars_slowdown = 1;

    ## the typed bytes live in ONE buffer, edited in place with vec [ no regex
    ## and no substr copies : a substitution that matches moves the string and
    ## leaves the old copy behind, about two per backspace ] -- its first $n
    ## bytes are the value, the rest stays zero. the editing rules are the
    ## previous regexes, in their order : the returned bytes decrypt existing
    ## keys [ bin/test-scripts/test-term-password.pl ]
    my $buf_size = 4 * $tty_read_size;
    my $buf      = "\0" x $buf_size;
    my $n        = 0;

    my $find = sub {    ## first position of a byte value, or -1 ##
        my $byte = shift;
        foreach my $i ( 0 .. $n - 1 ) {
            return $i if vec( $buf, $i, 8 ) == $byte;
        }
        return -1;
    };
    my $delete = sub {    ## $count bytes at $at : the rest moved up ##
        my ( $at, $count ) = @ARG;
        vec( $buf, $ARG, 8 ) = vec( $buf, $ARG + $count, 8 )
            foreach $at .. $n - $count - 1;
        vec( $buf, $ARG, 8 ) = 0 foreach $n - $count .. $n - 1;
        $n -= $count;
    };
    my $clear = sub {
        vec( $buf, $ARG, 8 ) = 0 foreach 0 .. $n - 1;
        $n = 0;
    };
    my $sequence_at = sub {    ## the bytes of $sequence at $at ##
        my ( $at, $sequence ) = @ARG;
        my @bytes = unpack 'C*', $sequence;
        return FALSE if $at + @bytes > $n;
        foreach my $k ( 0 .. $#bytes ) {
            return FALSE if vec( $buf, $at + $k, 8 ) != $bytes[$k];
        }
        return TRUE;
    };
    my $sequence_to_backspace = sub {    ## s|\Q$sequence\E|\b|g ##
        my $sequence = shift;
        my $found    = FALSE;
        foreach my $i ( 0 .. $buf_size ) {
            last if $i >= $n;
            next if not $sequence_at->( $i, $sequence );
            vec( $buf, $i, 8 ) = 8;
            $delete->( $i + 1, length($sequence) - 1 );
            $found = TRUE;
        }
        return $found;
    };

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

        ## read straight into the buffer at $n [ its size stays : sysread
        ## shortens the string, the zeros are put back in place ]
        error_exit('TTY_IN handle not opened')
            if not defined $TTY_IN
            or not length fileno $TTY_IN;
        my $room = $buf_size - $n;
        $room = $tty_read_size if $room > $tty_read_size;
        my $read_chrs = sysread $TTY_IN, $buf, $room, $n;
        $n += $read_chrs if $read_chrs;
        $buf .= "\0" x ( $buf_size - length $buf );

        ##  XOR passwd mode  ##
        $extended_processing_mode = FALSE
            if $extended_processing_mode
            and $n >= $passwd_mlen;

        if ($extended_processing_mode) {

            ##  ignoring return on empty buffer  ##
            $clear->()
                if $n == 1
                and ( vec( $buf, 0, 8 ) == 10 or vec( $buf, 0, 8 ) == 13 );

            ## DEL [ or backspace ] ##
            ##
            ##  make backspace  ##
            $show_stars = FALSE
                if $sequence_to_backspace->("\e[3~");
            $show_stars = FALSE    ##[ left cursor key also ]##
                if $sequence_to_backspace->("\e[D");
            foreach my $i ( 0 .. $n - 1 ) {    ## DEL ##
                next if vec( $buf, $i, 8 ) != 127;
                vec( $buf, $i, 8 ) = 8;
                $show_stars = FALSE;
            }
            if ( $n and vec( $buf, 0, 8 ) == 8 ) {    ##[ silent : one ]##
                $delete->( 0, 1 );
                $show_stars = FALSE;
            }
            ## process backspace                           ##
            ## [ the leftmost 'any byte but LF, then BS' ] ##
            while (TRUE) {
                my $at = -1;
                foreach my $i ( 0 .. $n - 2 ) {
                    next if vec( $buf, $i,     8 ) == 10;
                    next if vec( $buf, $i + 1, 8 ) != 8;
                    $at = $i;
                    last;
                }
                last if $at < 0;
                $delete->( $at, 2 );
                $show_stars = FALSE;
                ## one at a time ##
                ##
                ## remove * chars ##
                AMOS7::TERM::del_rnd_stars();
            }

            ##  delete other sequences [ esc, '[', a byte but LF, '~'? ]  ##
            my $i = 0;
            while ( $i < $n ) {
                if (    $i + 2 < $n
                    and vec( $buf, $i,     8 ) == 27
                    and vec( $buf, $i + 1, 8 ) == 91
                    and vec( $buf, $i + 2, 8 ) != 10 ) {
                    my $length
                        = ( $i + 3 < $n and vec( $buf, $i + 3, 8 ) == 126 )
                        ? 4
                        : 3;
                    $delete->( $i, $length );
                    $show_stars = FALSE;
                    next;
                }
                $i++;
            }

            ## CTRL+U [NAK] [erase read]  [ up to the last ctrl-u : what    ##
            ## came after it in the same read stays -- clearing it too lost ##
            ## the keys typed right after, and a pasted value after a       ##
            ## ctrl-u ]                                                     ##
            if ( $extended_processing_mode and $find->(21) >= 0 ) {
                ##  erase characters read so far  ##
                AMOS7::TERM::rewind_stars();
                my $last = $n - 1;
                $last-- while vec( $buf, $last, 8 ) != 21;
                $delete->( 0, $last + 1 );
            }

            $show_stars = FALSE if not $n;

        } elsif ($continue_reading) {    ##  XOR passwd mode  ##

            $XOR_buffer //= chr(127) x 64;    ##  initializing XOR buffer  ##

            my $used = 0;
            while ( $used < $n ) {
                my $code = vec( $buf, $used++, 8 );

                if ( $code == 10 or $code == 13 ) {    ## end processing ##
                    $clear->();
                    vec( $buf, 0, 8 ) = 10;
                    $n                = 1;
                    $used             = 0;
                    $continue_reading = FALSE;
                    $show_stars       = FALSE;
                    last;
                }

                vec( $XOR_buffer, $XOR_buffer_pos++, 8 ) ^= $code;

                $XORchars_count++;
                $XOR_buffer_pos = 0 if $XOR_buffer_pos == 64;
                last                if $XORchars_count == $max_XOR_chars;

                if ( $show_stars
                    and ( $XORchars_count * $XOR_stars_slowdown ) % 3 == 0 ) {
                    AMOS7::TERM::show_rnd_stars($mprompt_length);
                }
                $XOR_stars_slowdown *= 0.97 if $XOR_stars_slowdown > 0.13;
            }
            $delete->( 0, $used ) if $used;    ## the folded bytes are gone ##
        }

        $pwd_cur_len = $n;

        $continue_reading = FALSE              ##[  read end conditions  ]##
            if defined $read_chrs
            and $read_chrs == 0
            and $abort_mode = qw| timeout |    ##[ timeout ]##
            or $n >= $passwd_mlen              ##[ maxlen ]##
            or $n and (

            $find->(10) >= 0                   ##[ LF ]##
            or $find->(13) >= 0                ##[ CR ]##
            or $n >= $tty_read_size            ##[ read_len ]##

            );

        if ( $abort_mode eq qw| timeout | ) {
            AMOS7::TERM::timeout_stars();
            $show_stars = FALSE;
        } elsif (
            $continue_reading
            and $extended_processing_mode
            and $n >= $passwd_mlen             ##[ maxlen ]##
            or $find->(27) >= 0                ## escape ##
            or $find->(4) >= 0                 ## CTRL-D ##
            or $find->(3) >= 0                 ## CTRL-C ##
        ) {
            $abort_mode = qw| user-interrupt |;
            AMOS7::TERM::reset_stars();
            $continue_reading = FALSE;
            $show_stars       = FALSE;
        }

        if ($continue_reading) {    ##  deleting all chars < asc 10  ##
            my $kept = 0;
            foreach my $i ( 0 .. $n - 1 ) {
                my $byte = vec( $buf, $i, 8 );
                if ( $byte <= 9 ) {
                    $show_stars = FALSE;
                    next;
                }
                vec( $buf, $kept++, 8 ) = $byte;
            }
            vec( $buf, $ARG, 8 ) = 0 foreach $kept .. $n - 1;
            $n = $kept;
        }

        $show_stars = FALSE if $show_stars and not $continue_reading;
        $show_stars = FALSE if $show_stars and not $extended_processing_mode;

        AMOS7::TERM::show_rnd_stars($mprompt_length) if $show_stars;
    }

    my $LF_found = FALSE;
    foreach my $LF_byte ( 13, 10 ) {
        my $LF_match_pos = $find->($LF_byte);
        next if $LF_match_pos < 0;
        ## truncating pwd buffer to linefeed pos ##
        $LF_found = TRUE;
        vec( $buf, $ARG, 8 ) = 0 foreach $LF_match_pos .. $n - 1;
        $n = $LF_match_pos;
    }

    ##  XOR passwd mode  ##
    ##
    if ( $n >= $passwd_mlen ) {
        $extended_processing_mode = FALSE;
    }

    reset_stars() if not $LF_found and $extended_processing_mode;

    if ( [ caller(1) ]->[3] ne qw| AMOS7::TERM::read_password_repeated | ) {
        AMOS7::TERM::close_TTY_no_echo(TRUE);
    } else {
        say {$TTY_OUTPUT} '';
    }

    ## the value : a copy of exactly its bytes [ or the xor fold ], the buffer
    ## zeroed for a re-read
    if ( not $extended_processing_mode ) {
        $read_chars_buffer = $XOR_buffer;
        wipe_secret( \$XOR_buffer );    ## shared : only its own share ##
        undef $XOR_buffer;    ## a re-read initializes it again [ //= ] ##
    } else {
        $read_chars_buffer = "\0" x $n;
        vec( $read_chars_buffer, $ARG, 8 ) = vec( $buf, $ARG, 8 )
            foreach 0 .. $n - 1;
    }
    $clear->();

    if ( $abort_mode ne FALSE ) {
        wipe_secret( \$read_chars_buffer );
        $read_chars_buffer = undef;
    }

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
        wipe_secret( \$read_chars_buffer );    ##  reset password entered  ##
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
    ## guarding against undefined term_width
    ## [ should not happen with new defaults ]
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

    if ( not defined $TTY_IN or not length fileno $TTY_IN ) {
        warn_err('TTY_IN handle not opened <{C1}>');
        return undef;
    }
    if ( index( [ caller(1) ]->[3], qw| AMOS7::TERM:: |, 0 ) != 0 ) {
        ##[ only flush it ]##
        $TERM_ios->setattr( $TTY_fd_restore, TCSAFLUSH );
        return 0;    ## input discarded \ no abort ##
    } else {
        my $restore_time = AMOS7::TERM::get_input_timeout() // 13;
        AMOS7::TERM::set_input_timeout($input_timeout);

        ## check for interrupt ##
        my $check_buffer = '';
        AMOS7::TERM::read_to_buffer_TTY( \$check_buffer );
        AMOS7::TERM::set_input_timeout($restore_time);

        ## typed-ahead keys may be a password
        ## [ the second of a repeated entry ] : checked byte by byte with vec,
        ## no regex copies, then wiped. sequence encoded keys [ esc
        ## '[' a byte but LF, '~'? ] are skipped, then esc \ ctrl-c \ ctrl-d
        ## interrupt, CR \ LF continue
        my ( $interrupt, $continue ) = ( FALSE, FALSE );
        my $length = length $check_buffer;
        my $i      = 0;
        while ( $i < $length ) {
            my $byte = vec( $check_buffer, $i, 8 );
            if (    $byte == 27
                and $i + 2 < $length
                and vec( $check_buffer, $i + 1, 8 ) == 91
                and vec( $check_buffer, $i + 2, 8 ) != 10 ) {
                $i += ( $i + 3 < $length
                        and vec( $check_buffer, $i + 3, 8 ) == 126 ) ? 4 : 3;
                next;
            }
            $interrupt = TRUE if $byte == 3  or $byte == 4 or $byte == 27;
            $continue  = TRUE if $byte == 10 or $byte == 13;
            $i++;
        }
        wipe_secret( \$check_buffer );
        return 2 if $interrupt;
        return 1 if $continue;
    }
    return 0;    ## regular continuation \ no abort ##
}

## single key confirmation [ the bin/ncode user_confirmed prompt ] : reads AND
## writes /dev/tty itself, so no buffered or redirected stdout \ stderr can
## hide the question. typed-ahead input is flushed first -- only a key pressed
## after the prompt shows counts. 'y' -> TRUE, 'n' esc ctrl-c ctrl-d -> FALSE,
## any other key asks again [ bold from the second round ].  undef without a
## terminal [ the caller decides, nothing blocks ].  reason => 1 : a denial
## then asks for a reason line -- list context returns ( FALSE, reason | undef
## ). diff => <code ref returning ( unified diff text, diff_page options )> :
## 'd' pages it and asks again
##
## AMOS7::TERM::confirm_key( { question => 'sign these 3 files ?' } )
sub confirm_key {
    my $params   = shift                 // {};
    my $question = $params->{'question'} // return undef;

    open( my $tty_in,  '<', qw| /dev/tty | ) or return undef;
    open( my $tty_out, '>', qw| /dev/tty | ) or return undef;
    $tty_out->autoflush(1);

    my $fd      = fileno $tty_in;
    my $termios = POSIX::Termios->new;
    return undef if not $termios->getattr($fd);
    my $lflag_saved = $termios->getlflag;
    my ( $vmin_saved, $vtime_saved )
        = ( $termios->getcc(VMIN), $termios->getcc(VTIME) );
    $termios->setlflag( $lflag_saved & ~( ICANON | ECHO ) );
    $termios->setcc( VMIN,  1 );
    $termios->setcc( VTIME, 0 );
    $termios->setattr( $fd, TCSAFLUSH );    ## typed-ahead input dropped ##

    ## the bin/ncode palette ##
    my %c = (
        qw| T | => "\e[38;2;6;71;195m",
        qw| 0 | => "\e[38;2;68;39;172m",
        qw| 2 | => "\e[38;2;170;94;2m",
        qw| B | => "\e[1m",
        qw| K | => "\e[5m",
        qw| R | => "\e[0m",
    );
    ( my $question_str = $question ) =~ s|\?$|$c{'K'}?$c{'R'}$c{'T'}|;

    my $diff_code
        = ref $params->{'diff'} eq qw| CODE | ? $params->{'diff'} : undef;
    my @keys = ( qw| y n |, $diff_code ? qw| d | : () );

    my ( $answer, $bold ) = ( undef, '' );
    while ( not defined $answer ) {
        print {$tty_out} $c{'T'}
            . "\r :: $question_str :: "
            . $bold
            . $c{'0'} . '['
            . join(
            $c{'0'} . '|',
            map { $c{'K'} . $bold . $c{'T'} . $ARG . $c{'R'} } @keys
            )
            . $c{'0'} . ']'
            . $c{'T'} . ' :. '
            . $c{'R'};
        my $key;
        if ( not sysread( $tty_in, $key, 1 ) ) {
            $answer = FALSE;    ## eof \ read error : deny ##
        } elsif ( $key eq qw| y | ) {
            $answer = TRUE;
        } elsif ( $key eq qw| n | or $key =~ m|^[\x03\x04\x1b]$| ) {
            $answer = FALSE;
        } elsif ( $key eq qw| d | and $diff_code ) {
            print {$tty_out} "\n";
            $termios->setlflag($lflag_saved);    ## the pager runs cooked ##
            $termios->setattr( $fd, TCSANOW );
            ## ( text, options ) ##
            AMOS7::TERM::diff_page( $diff_code->() );
            $termios->setlflag( $lflag_saved & ~( ICANON | ECHO ) );
            $termios->setattr( $fd, TCSAFLUSH );
            next;                                ## same round, no bold ##
        }
        $bold = $c{'B'};
    }
    print {$tty_out} $c{'2'}
        . ( $answer ? qw| y | : qw| n | )
        . $c{'R'} . "\n";

    $termios->setlflag($lflag_saved);
    $termios->setcc( VMIN,  $vmin_saved );
    $termios->setcc( VTIME, $vtime_saved );
    $termios->setattr( $fd, TCSANOW );

    ## a denial may carry a reason                                        ##
    ## [ the bin/admin/vc_commit length gate, no truth check ] : 13 .. 76 ##
    ## chars, an empty line skips it                                      ##
    my $reason;
    if ( not $answer and $params->{'reason'} ) {
        my ( $min_len, $max_len ) = ( 13, 76 );
        while (TRUE) {
            print {$tty_out} $c{'T'}
                . ' :: reason [ enter skips ] :. '
                . $c{'R'};
            my $line = <$tty_in>;
            last if not defined $line;
            $line =~ s|[\r\n]+$||;
            $line =~ s|[^[:print:]]||g;
            $line =~ s|^\s+||;
            $line =~ s|\s+$||;
            last if not length $line;
            my $line_length = length $line;

            if ( $line_length < $min_len or $line_length > $max_len ) {
                print {$tty_out} $c{'2'}
                    . " :.   .:[ len :. $line_length "
                    . ".: $min_len .:. $max_len ]:.\n"
                    . $c{'R'};
                next;
            }
            $reason = $line;
            last;
        }
    }

    close $tty_in;
    close $tty_out;
    return wantarray ? ( $answer, $reason ) : $answer;
}

## a unified diff in the bin/ncode preview colors [ removed lines on the dark
## blue, added on the dark green background, headers dimmed, file names bold ]
## through 'less -R' on /dev/tty. no pager : printed to the tty
##
## options { pager => <command> } : the text goes as it is to that command
## [ sh -c, like git's core.pager -- e.g. 'diff-modified | less -RFX' ]
sub diff_page {
    my $diff_text = shift // '';
    my $options   = shift // {};

    my %c = (
        qw|  T  | => "\e[38;2;6;71;195m",
        qw|  0  | => "\e[38;2;68;39;172m",
        qw|  1  | => "\e[38;2;38;46;153m",
        qw|  2  | => "\e[38;2;170;94;2m",
        qw| B01 | => "\e[48;2;9;5;24m",
        qw| B02 | => "\e[48;2;9;5;42m",
        qw|  B  | => "\e[1m",
        qw|  D  | => "\e[2m",
        qw|  R  | => "\e[0m",
    );

    $diff_text = sprintf "%s :. no changes to show .:%s\n", $c{'2'}, $c{'R'}
        if not length $diff_text;

    my $pager_cmd = $options->{'pager'};
    my $colored   = '';
    $colored = $diff_text if defined $pager_cmd and length $pager_cmd;
    foreach my $line ( length $colored ? () : split m|(?<=\n)|, $diff_text ) {
        my $eol = $line =~ s|\n$|| ? "\n" : '';
        if ( $line =~ m{^(diff |\+\+\+|---|@@|index |new file|deleted file)} )
        {
            $line =~ s|([^/\s]+)\s*$|$c{'R'}$c{'B02'}$c{'B'}$c{'T'}$1|
                if $line =~ m|^diff |;
            $colored .= $c{'D'} . $c{'1'} . $line . $c{'R'} . $eol;
        } elsif ( $line =~ s|^-|| ) {
            $colored
                .= $c{'D'}
                . $c{'0'} . '-'
                . $c{'R'}
                . $c{'B01'}
                . $c{'1'}
                . $line
                . $c{'R'}
                . $eol;
        } elsif ( $line =~ s|^\+|| ) {
            $colored
                .= $c{'D'}
                . $c{'T'} . '+'
                . $c{'R'}
                . $c{'B02'}
                . $c{'1'}
                . $line
                . $c{'R'}
                . $eol;
        } else {
            $colored .= $c{'1'} . $line . $c{'R'} . $eol;
        }
    }

    open( my $tty_out, '>', qw| /dev/tty | ) or return FALSE;
    ## the pager writes to the tty, whatever stdout is ##
    open( my $stdout_saved, '>&', \*STDOUT ) or return FALSE;
    open( STDOUT,           '>&', $tty_out ) or return FALSE;
    my $paged = FALSE;
    my @pager
        = length $pager_cmd // ''
        ? ( qw| sh -c |, $pager_cmd )
        : qw| less -R |;
    if ( open( my $pager, '|-', @pager ) ) {
        binmode $pager, ':raw';
        print {$pager} $colored;
        close $pager;
        $paged = TRUE;
    }
    open( STDOUT, '>&', $stdout_saved );
    print {$tty_out} $colored if not $paged;
    close $tty_out;
    return TRUE;
}

## overwrite a secret in place twice with random bytes, then truncate
## [ base.buffer.erase_secure, AMOS7::Vault ] -- the same length keeps the
## same buffer. a copy sharing it [ copy on write ] keeps its own share
sub wipe_secret {
    my $sref = shift;
    return FALSE if ref $sref ne qw| SCALAR |;
    my $len = length( ${$sref} // '' );
    return FALSE if not $len;
    my $prng = Crypt::PRNG::Fortuna->new();
    substr( ${$sref}, 0, $len, $prng->bytes($len) ) for 1 .. 2;
    ${$sref} = '';
    return TRUE;
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

    ## Ctrl-W - kill word backward
    ## [ delete previous word, save to kill buffer ]
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
            ## scan back over utf-8 continuation bytes
            ## [ 10xxxxxx = 0x80-0xBF ]
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
            ## scan back over utf-8 continuation bytes
            ## [ 10xxxxxx = 0x80-0xBF ]
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

sub editor_get_cursor {
    my $editor = shift;
    return undef if !defined $editor;
    return $editor->{cursor_pos};
}

sub editor_set_cursor {
    my ( $editor, $pos ) = @ARG;
    return if !defined $editor;
    $editor->{cursor_pos} = $pos;
    return TRUE;
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
        ## on a character : show with underline attribute
        ## [preserves character] apply color and underline, reset underline
        ## only [NOT all attributes]
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

## frame_border_line, frame_rule_line, frame_colorize_content and frame_bar ##
## live in AMOS7::TERM::Frame [ core-only ] -- imported above and kept in   ##
## this package's @EXPORT_OK, so every existing caller keeps working        ##
## unchanged                                                                ##

## split-screen : reserve the bottom N rows as a fixed area                 ##
## [ e.g. an input line ], confine scrolling to the rows above via DECSTBM. ##
## once set, ordinary print()/"\n" into the content area scroll correctly   ##
## within that region with NO per-print bookkeeping -- the only code that   ##
## needs care is whatever draws into the reserved rows                      ##
## [ see pinned_row_print below ], since the terminal's resting cursor      ##
## lives inside the scroll region between content prints. caller MUST call  ##
## scroll_region_clear before the process exits or detaches from the tty,   ##
## or the terminal is left with a partial scroll region afterward.  returns ##
## the last content row [ 1-indexed ] on success, undef if the terminal is  ##
## too small for the requested reservation.                                 ##
sub scroll_region_set {
    my $reserved_rows = shift // 1;

    my ( undef, $rows ) = terminal_size();
    $rows //= 24;

    my $content_bottom = $rows - $reserved_rows;
    return undef if $content_bottom < 1;

    ## DECSTBM : confine scroll to rows 1..content_bottom [ 1-indexed ] ##
    print "\e[1;${content_bottom}r";
    ## DECSTBM moves the cursor to (1,1) as a side effect [ vt100 spec ] -- ##
    ## park it at the bottom of the new region instead, ready to print      ##
    print "\e[${content_bottom};1H";
    STDOUT->flush();

    return $content_bottom;
}

## clear rows 1..content_bottom [ the actual streaming content area, as     ##
## opposed to scroll_region_clear's reserved-rows-only scope ] and park the ##
## cursor at the bottom, ready for a caller to print/replay into it.        ##
## neither scroll_region_set nor scroll_region_clear ever erases the        ##
## content rows themselves -- set only moves the DECSTBM boundary and parks ##
## the cursor, clear only wipes the reserved strip below it -- so           ##
## re-entering a mode and replaying a buffer shorter than the content area  ##
## left whatever was already on screen sitting there, making the replay     ##
## look like it doubled the content instead of replacing it. call this      ##
## right after scroll_region_set, before printing/replaying.                ##
sub content_area_clear {
    my $content_bottom = shift;
    return unless defined $content_bottom and $content_bottom > 0;

    for my $row ( 1 .. $content_bottom ) {
        print "\e[${row};1H\e[2K";
    }
    print "\e[${content_bottom};1H";
    STDOUT->flush();

    return;
}

## restore full-screen scrolling [ always pair with scroll_region_set ].    ##
## pass the SAME reserved_rows given to scroll_region_set to also clear     ##
## whatever was drawn into those rows and park the cursor at the bottom --  ##
## otherwise the old content just sits there as static screen debris, since ##
## resetting the scroll boundary alone never erases anything.               ##
sub scroll_region_clear {
    my $reserved_rows = shift // 0;

    my ( undef, $rows ) = terminal_size();
    $rows //= 24;

    print "\e[1;${rows}r";    ## DECSTBM : full-screen scroll region ##

    if ( $reserved_rows > 0 ) {
        my $first_reserved = $rows - $reserved_rows + 1;
        $first_reserved = 1 if $first_reserved < 1;
        for my $row ( $first_reserved .. $rows ) {
            print "\e[${row};1H\e[2K";
        }
        print "\e[${rows};1H";    ## park cursor at the bottom row ##
    }

    STDOUT->flush();

    return;
}

## draw into one of the fixed rows reserved by scroll_region_set without     ##
## disturbing the content area's resting cursor position : save cursor [     ##
## DECSC, not the legacy ANSI.SYS \e[s/\e[u pair -- DECSC/DECRC also         ##
## preserves attributes and is the xterm-safe choice ], jump to the target   ##
## row, clear it, print, restore. caller passes an ABSOLUTE 1-indexed row    ##
## number                                                                    ##
## [ e.g. scroll_region_set's return value + 1 for the first reserved row ], ##
## never a relative "\r"-style redraw -- the cursor is not reliably sitting  ##
## on that row when this is called.                                          ##
sub pinned_row_print {
    my ( $row, $text ) = @_;
    return unless defined $row and defined $text;

    print "\e7";                  ## DECSC : save cursor pos + attrs
    print "\e[${row};1H\e[2K";    ## jump to target row, clear it
    print $text;
    print "\e8";    ## DECRC : restore [ back inside scroll region ]
    STDOUT->flush();

    return;
}

return TRUE ##################################################################

#,,.,,.,,,..,,..,,.,.,...,...,,,,,...,,,,,...,..,,...,...,,.,,,,,,.,,,,,.,,.,,
#PQHS7RKKVXPDU6WYF6HFXG2CM3W6HSVTMODEFF4FMTK7JOPU5WXIQGSU3KDMDD764KPBMDMYXIH3Q
#\\\|55GKEBL2SQHDDMMKA2O4452JQK625IKZ7U5L44SZAIL7WP7XFHW \ / AMOS7 \ YOURUM ::
#\[7]R32RACK56BHY4XW5OSA6VGEOPHJ5GCGEXIDKJ7ID7RHQQSGMBCAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
