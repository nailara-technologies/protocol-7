
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

our $VERSION = qw| AMOS7::TERM-VERSION.7OT2XVQ |;

@EXPORT_OK = qw| read_password_line |;

@EXPORT = qw| terminal_size read_password |;

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

    $OUTPUT_AUTOFLUSH = 1;
    my $clear_console = "\e[H\e[2J\e[3J";

    ( my $password_0, my $password_1 );

    while ( not defined $password_0 or $password_0 ne $password_1 ) {

        print $clear_console;
        ( my $term_width, undef ) = AMOS7::TERM::terminal_size();
        my $colon_line = qw| : | x abs( $term_width - 30 );

        printf "%s\n\n%s.:::.[%s%s seed file encryption %s%s].:%s\r%s",
            $clear_console,
            $C{'0'}, $C{'T'}, $C{'B'}, $C{'R'}, $C{'0'}, $colon_line, $C{'R'};

        $password_0
            = read_password_line( sprintf( 'enter %s', $password_type_msg ) );

        if ( $password_0 ne qw| 1 | ) {
            $password_1 = read_password_line(
                sprintf( 're-enter %s', $password_type_msg ) );

            if (    defined $password_0
                and defined $password_1
                and $password_0 ne $password_1 ) {
                warn_err(' <<  paswords differ  >> <{NC}>')
                    if $password_0 ne $password_1;
                sleep 0.7;
            }
            if ( $password_1 eq qw| 1 | ) {
                say $C{'R'};
                error_exit(' [ password read aborted ]');
            }
        }
    }

    ## say ':';
    ## say ':: password was : ', $password_0;
    ## say '';

    return $password_0;

}

sub read_password_line {
    my $message_prompt   = shift // 'enter password';
    my $sig_int          = $SIG{'INT'};
    my $pwd_read_aborted = 0;
    my $autoflush        = $OUTPUT_AUTOFLUSH;

    $OUTPUT_AUTOFLUSH = 1;

    my $prefix = $message_prompt =~ m|re.?enter| ? '' : "\n:\n";

    printf "%s%s%s:\n%s: %s%s %s %s%s :. %s",, $C{'0'}, $prefix, $C{'0'},
        $C{'0'}, $C{'T'}, $C{'B'},
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
            return $read_pwd;    ##  check minimum length  ##  [ LLL ]

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
        error_exit(' [ password input timeout ]');
        return undef;
    } elsif ( not length( $key // '' ) ) {
        while (@rnd_count) {
            for ( 1 .. pop @rnd_count ) {
                print "\b \b";
                sleep 0.007;
            }
        }
        say $C{'R'};
        error_exit(' [ password read aborted ]');
        return undef;
    }

    $SIG{'INT'} = $sig_int;
    $OUTPUT_AUTOFLUSH = $autoflush;
}

sub read_single_key_press {

    my $read_mode = shift;

    my $key;
    if ( $read_mode == 0 ) {
        while ( not defined $key ) {
            $key = ReadKey(0.07);
            Event::loop(0.07);
        }
    } else {
        $key = ReadKey($read_mode);
        Event::loop(0.007);
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

#,,,.,,,,,,.,,...,..,,.,.,,,,,,.,,,.,,.,.,...,..,,...,...,...,,,.,.,.,...,,.,,
#6BZOL47RK4333AONFZCES24VSDACZEXTEBREE3C5SUB2Q244CD5CHM3IXIVQVHC7SEMGLBINE3VQQ
#\\\|KDKMOX6YY2SS3OTVEEQEQ3O35BDPSQKN2SRKBHA72WJXIFJXY3Z \ / AMOS7 \ YOURUM ::
#\[7]CNC2AS4UEOJD5PJKYYLN5EVUV7A35SL77E3ZDP7GSN76VXW6FEAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
