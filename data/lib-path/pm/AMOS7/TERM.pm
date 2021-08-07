## >:] ##

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
use Term::ReadKey;
use Time::HiRes qw| sleep |;
use Crypt::PRNG::Fortuna qw| rand |;

use Exporter;
use base qw| Exporter |;
use vars qw| $VERSION @EXPORT @EXPORT_OK |;

my $VERSION = qw| AMOS7::TERM-VERSION.7OT2XVQ |;

@EXPORT_OK = qw| terminal_title |;

@EXPORT = qw| terminal_size read_password_single read_password_repeated |;

our $pwd_min_len      //= 13;
our $pwd_read_aborted //= 0;

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

##[ USER-INTERACTION ]########################################################

sub read_password_repeated {

    my $password_type_msg = shift // qw| password |;
    my $term_title        = shift // '';
    my $output_lines      = shift // 1;
    $output_lines = 0 if $output_lines !~ m|^\d+$|;

    $OUTPUT_AUTOFLUSH = TRUE;

    ( my $password_0, my $password_1 );

    while (not defined $password_0
        or not defined $password_1
        or $password_0 ne $password_1 ) {

        terminal_title($term_title) if length $term_title;

        ( $password_0, my $password_status )
            = read_password_single(
            sprintf( 'enter %s', $password_type_msg ) );

        if (not defined $password_0
            and (  $password_status == 0
                or $password_status == 1 )
        ) {
            return undef if defined $main::PROTOCOL_SEVEN;    ##  zenka  ##

        } elsif (
            $password_status == 0    ##  checking min pwd length  ##
            and length($password_0) < $pwd_min_len
        ) {

            undef $password_0;
            if ( defined $main::PROTOCOL_SEVEN ) {
                $main::code{'base.logs'}
                    ->( 0, '<<  pasword min len is %d  >>', $pwd_min_len );
            } else {
                warn_err( ' <<  pasword min len is %d  >> <{NC}>',
                    -1, $pwd_min_len );
            }
            sleep 1.2;

        } elsif ( $password_status != 1 ) {

            ( $password_1, my $password_status )
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

            if ( $password_status > 0 ) {
                undef $password_0;
                undef $password_1;
                say $C{'R'};
                if ( defined $main::PROTOCOL_SEVEN ) {
                    printf "%s:\n", $C{'0'};
                    $main::code{'base.log'}
                        ->( 0, ' [ password read aborted ]' );
                    printf "%s:\n", $C{'0'};
                } else {
                    error_exit(' [ password read aborted ]');
                }
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
    my $output_lines   = shift // 0;
    $output_lines = 0 if $output_lines !~ m|^\d+$|;

    my $sig_int          = $SIG{'INT'};
    my $password_status  = 0;
    my $pwd_read_aborted = 0;
    my $autoflush        = $OUTPUT_AUTOFLUSH;

    $OUTPUT_AUTOFLUSH = TRUE;

    terminal_title($term_title) if length $term_title;

    printf "%s:\n%s: %s%s %s %s%s :. %s", $C{'0'}, $C{'0'}, $C{'T'}, $C{'B'},
        $message_prompt,
        $C{'R'}, $C{'0'}, $C{'T'};

    ReadMode 4;

    my $read_pwd;

    my $key  = '';
    my $code = 0;
    my @rnd_count;
    while ( defined $key and $key !~ m|[\r\n]|
        or $code ) {
        $code = 0;
        my $read_timeout = 13 + 0.7 * length( $read_pwd // '' );
        $key  = read_single_key_press($read_timeout);
        $code = ord($key) if defined $key;

        $code = 0 if defined $read_pwd and $read_pwd =~ s|^\*+$||;

        $code = 10 if $code == 13;

        last if $code == 0 or $code == 255 or $code == 27;

        if ( $code == 10 and length $read_pwd ) {    ##  read complete  ##
            ReadMode 0;
            say sprintf "\n%s:%s", $C{'0'}, $C{'R'};
            return ( $read_pwd, $password_status ) if wantarray;

            print sprintf( "%s:\n", $C{'0'} ) x $output_lines;

            return $read_pwd;    ## return entered password ##

        } elsif ( $code == 127 ) {    ##  backspace  ##
            my $pwd_len = length($read_pwd);
            if ($pwd_len) {
                substr( $read_pwd, $pwd_len - 1, 1, qw| * | );
                substr( $read_pwd, $pwd_len - 1, 1, '' );
                if (@rnd_count) {
                    for ( 1 .. pop @rnd_count ) {
                        print "\b \b";
                        sleep( rand(0.13) );
                    }
                }
            }
        } elsif ( defined $key
            and $code != 10
            and $code != 255
            and $code != 27 ) {    ## adding one key to the password ##

            $read_pwd .= $key;
            $password_status = 0;    ##  resetting pwd status  ##

            my $rnd_keys = sprintf qw| %u |, 1.2 + rand(1);
            for ( 1 .. $rnd_keys ) {    ## masking length ##
                print qw| * |;
                sleep( rand(0.13) );
            }
            push @rnd_count, $rnd_keys;

        } else {    ##[  read abort  ]##
            $read_pwd = '*' x    ##  erasing password from memory  ##
                sprintf( qw| %u |,
                1.3 * length( $read_pwd // '' ) + rand(7) );
            $read_pwd        = '';
            $password_status = 2;
        }
    }

    ReadMode 0;

    if ( $code == 255 ) {    ##[  input timeout  ]##

        $password_status = 1;

        my $rewind_delay = 0.777;
        while (@rnd_count) {
            for ( 1 .. pop @rnd_count ) {
                print "\b \b";
                sleep( $rewind_delay *= 0.84 );
                Event::loop(0.07);
            }
        }
        say $C{'R'};
        if ( defined $main::PROTOCOL_SEVEN ) {    ##  zenka  ##
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

        return ( undef, $password_status ) if wantarray;
        return undef;

    } elsif ( not length( $key // '' ) ) {
        while (@rnd_count) {
            for ( 1 .. pop @rnd_count ) {
                print "\b \b";
                sleep 0.007;
            }
        }
        say $C{'R'};

        if ( defined $main::PROTOCOL_SEVEN ) {
            printf "%s:\n", $C{'0'};
            $main::code{'base.log'}->( 0, ' [ password read aborted ]' );
            printf "%s:\n", $C{'0'};
        } else {
            error_exit(' [ password read aborted ]');
        }
        return ( undef, $password_status ) if wantarray;
        return undef;
    }

    $SIG{'INT'} = $sig_int;
    $OUTPUT_AUTOFLUSH = $autoflush;
}

sub terminal_title {
    my $term_title = shift // '';
    return 0 if not length $term_title;

    $OUTPUT_AUTOFLUSH = TRUE;

    my $clear_console
        = ( defined $main::PROTOCOL_SEVEN
            and $main::data{'system'}{'verbosity'}{'console'} )
        ? ''    ##  do not clear screen with -v option  ##
        : "\e[H\e[2J\e[3J";

    ( my $term_width, undef ) = AMOS7::TERM::terminal_size();
    my $colon_line = qw| : | x abs( $term_width - length($term_title) - 11 );

    printf "%s\n%s.:::.[%s%s %s %s%s].:%s\n%s%s:%s\n",
        $clear_console,
        $C{'0'}, $C{'T'}, $C{'B'}, $term_title, $C{'R'}, $C{'0'},
        $colon_line, $C{'R'}, $C{'0'}, $C{'R'};

    return TRUE;    ## true ##
}

sub read_single_key_press {

    my $read_timeout = shift;

    my $key;
    if ( $read_timeout == 0 ) {
        while ( not defined $key ) {
            $key = ReadKey(0.07);
            Event::loop(0.07);
        }
    } else {
        my @wait_secs;
        my $timeout_remain = ( ( $read_timeout * 100 ) % 7 ) / 100;
        my $count          = $read_timeout / 0.07;
        @wait_secs = ( (0.07) x $count, $timeout_remain );

        foreach my $delay (@wait_secs) {
            $key = ReadKey($delay);
            last if defined $key;
            Event::loop(0.007);
        }
        $key //= chr(255);
    }

    return '' if not defined $key;

    return $key if $key =~ m|[\r\n]|;

    my $code = ord($key);

    return undef if $code == 3 or $code == 27;

    while ( my $next_one = ReadKey(-1) ) {
        $key .= $next_one;
    }

    return $key;
}

return TRUE ##################################################################

#,,,.,.,.,.,,,,,,,...,..,,.,,,,.,,,.,,,,.,,.,,..,,...,...,..,,..,,.,,,,..,.,,,
#6XRRIVBLDZWBGXCPLF2EA5PNW7BOTO7JD4NSTP7UATF2LK4L2SY6UZE46EXWESNMITSBIIEHFHZWG
#\\\|B4CJDDPPKOG6FXZ5ONLGZFNC5EBHZ6YUCWYOJ527356L36DNC6Z \ / AMOS7 \ YOURUM ::
#\[7]A5QSBZRVEE5GVRYV65QNNCTTJSRCUOPGXJFZBZHWTQUQBW3NXYBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
