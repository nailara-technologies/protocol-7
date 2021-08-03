
package AMOS7::TERM; #########################################################

use v5.24;
use utf8;
use strict;
use English;
use warnings;

use AMOS7;

use Event;
use Term::ReadKey;
use Time::HiRes qw| sleep |;
use Crypt::PRNG::Fortuna qw| rand |;

use Exporter;
use base qw| Exporter |;
use vars qw| $VERSION @EXPORT @EXPORT_OK |;

my $VERSION = qw| AMOS7::TERM-VERSION.7OT2XVQ |;

@EXPORT_OK = qw| read_password_line |;

@EXPORT = qw| terminal_size read_password |;

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

sub read_password {

    my $password_type_msg = shift // qw| password |;
    my $term_title        = shift // '';

    $OUTPUT_AUTOFLUSH = 1;
    my $clear_console
        = ( defined $main::PROTOCOL_SEVEN
            and $main::data{'system'}{'verbosity'}{'console'} )
        ? ''    ##  do not clear screen with -v option  ##
        : "\e[H\e[2J\e[3J";

    ( my $password_0, my $password_1 );

    while (not defined $password_0
        or not defined $password_1
        or $password_0 ne $password_1 ) {

        print $clear_console;
        ( my $term_width, undef ) = AMOS7::TERM::terminal_size();
        my $colon_line
            = qw| : | x abs( $term_width - length($term_title) - 11 );

        if ( length $term_title ) {
            printf "%s\n%s.:::.[%s%s %s %s%s].:%s\n%s%s:%s\n",
                $clear_console,
                $C{'0'}, $C{'T'}, $C{'B'}, $term_title, $C{'R'}, $C{'0'},
                $colon_line, $C{'R'}, $C{'0'}, $C{'R'};
        }

        $password_0
            = read_password_line( sprintf( 'enter %s', $password_type_msg ) );

        if ( not defined $password_0 ) {
            return undef if defined $main::PROTOCOL_SEVEN;    ##  zenka  ##

        } elsif (
            $password_0 ne qw| 1 |    ##  checking min pwd length  ##
            and length($password_0) < $pwd_min_len
        ) {
            undef $password_0;
            if ( defined $main::PROTOCOL_SEVEN ) {
                printf "%s:\n", $C{'0'};
                $main::code{'base.logs'}
                    ->( 0, '<<  pasword min len is %d  >>', $pwd_min_len );
            } else {
                warn_err( ' <<  pasword min len is %d  >> <{NC}>',
                    -1, $pwd_min_len );
            }
            sleep 1.2;

        } elsif ( defined $password_0 and $password_0 ne qw| 1 | ) {

            $password_1 = read_password_line(
                sprintf( 're-enter %s', $password_type_msg ) );

            if (    defined $password_0
                and defined $password_1
                and $password_0 ne $password_1 ) {
                if ( $password_0 ne $password_1 ) {
                    undef $password_0;
                    undef $password_1;
                    if ( defined $main::PROTOCOL_SEVEN ) {
                        printf "%s:\n", $C{'0'};
                        $main::code{'base.log'}
                            ->( 0, '<<  paswords differ  >>' );
                    } else {
                        warn_err(' <<  paswords differ  >> <{NC}>');
                    }
                }
                sleep 1.2;
            }
            if ( defined $password_1 and $password_1 eq qw| 1 | ) {
                undef $password_0;
                undef $password_1;
                say $C{'R'};
                if ( defined $main::PROTOCOL_SEVEN ) {
                    printf "%s:\n", $C{'0'};
                    $main::code{'base.log'}
                        ->( 0, '[ password read aborted ]' );
                    printf "%s:\n", $C{'0'};
                } else {
                    error_exit(' [ password read aborted ]');
                }
                return undef;
            }
        }
    }
    printf "%s:\n", $C{'0'} for ( 0 .. 1 );

    return $password_0;
}

sub read_password_line {
    my $message_prompt   = shift // 'enter password';
    my $sig_int          = $SIG{'INT'};
    my $pwd_read_aborted = 0;
    my $autoflush        = $OUTPUT_AUTOFLUSH;

    $OUTPUT_AUTOFLUSH = 1;

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
            say $C{'R'};
            return $read_pwd;

        } elsif ( $code == 127 ) {                   ##  backspace  ##
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
            and $code != 27 ) {

            $read_pwd .= $key;

            my $rnd_keys = sprintf qw| %u |, 1.2 + rand(1);
            for ( 1 .. $rnd_keys ) {
                print qw| * |;
                sleep( rand(0.13) );
            }
            push @rnd_count, $rnd_keys;

        } else {
            $read_pwd = qw| * | x    ##  erasing password from memory  ##
                sprintf( qw| %u |,
                1.3 * length( $read_pwd // '' ) + rand(7) );
        }
    }

    ReadMode 0;

    if ( $code == 255 ) {
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
            $main::code{'base.log'}->( 0, '[ password read aborted ]' );
            printf "%s:\n", $C{'0'};
        } else {
            error_exit(' [ password read aborted ]');
        }

        return undef;
    }

    $SIG{'INT'} = $sig_int;
    $OUTPUT_AUTOFLUSH = $autoflush;
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

return 5;  ###################################################################

#,,.,,,..,.,.,,.,,...,..,,...,,.,,,,,,.,,,,..,..,,...,...,...,...,,,,,.,.,,,,,
#REMS6CRVA6O7GAEETAJA4BIXNNWVL7E5M6HRVCQOFATYT3LWQRJ6S4S2Q5P2D5EHJ4LO7U7ZSGN4E
#\\\|OWZAFAWMILNAFFQS6WDKDMUDFXORXOPROCEDK4CN7JSSJ77BBDW \ / AMOS7 \ YOURUM ::
#\[7]56FHY25B7XHC6MRIVUKWJ664GQ74MHZUNYCRTAHLY2EW7UGOV4CY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
