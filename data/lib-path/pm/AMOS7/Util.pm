## [:< ##

package AMOS7::Util;   #######################################################

use v5.24;
use strict;
use English;
use warnings;
use Term::ReadKey;
use Time::HiRes qw| time sleep alarm |;

##[ global constants ]##
use constant TRUE  => 5;    ##  TRUE.  ##
use constant FALSE => 0;    ##  false  ##

use Event;

##[ AMOS MODULE ]#############################################################

use AMOS7;

use vars qw| $VERSION @EXPORT |;

use Exporter;
use base qw| Exporter |;

@EXPORT = qw| do_exit process_key_press $HOME $clear add_command |;

##[ INITIALIZATIONS ]#########################################################

my $verbose = TRUE;

our $HOME  = "\e[0H";
our $clear = "$HOME\e[2J\e[3J";

my $command_timeout = 1.7;
my $command_buffer  = '';

our %command_setup = (
    qr,^(clear|reset)$, => sub {
        print "\e[0J$HOME$C{b}\r$C{T}::\r";
        system qw| reset |;
        return '';
    },
    qr,^(x|q|exit)$, =>
        sub { $command_buffer = ' '; visualize_command(); do_exit() },

);

sub add_command {
    $command_setup{ $ARG[0] } = $ARG[1];
}

##[ UTILITY FUCTIONS ]########################################################

sub cmd_to_sequence {

    return join( ':',
        map { sprintf( '%03d', ord($ARG) ) }
            split '',
        $command_buffer );
}

sub do_exit { print "\b\b$C{R}"; ReadMode 0; exit(00000) }

sub clear_command_buffer {
    $command_buffer = '';
    visualize_command();
    return '';
}

sub check_command {
    $command_buffer //= '';
    my $cmd_seq_str = cmd_to_sequence($command_buffer);
    my $seq_cmd     = $cmd_seq_str =~ m|:|
        or $command_buffer =~ m|[^[:print:]]| ? TRUE : FALSE;

    state $clear_timer;
    if ( defined $clear_timer ) {
        $clear_timer->cancel if $clear_timer->is_active;
        $clear_timer = undef;
    }
    return '' if not length $command_buffer;
    my @params;
    my $callback;
    my $wait_param = 0;
    foreach my $cr ( reverse sort keys %command_setup ) {

        my $is_regex = index( $cr, '(?^u:', 0 ) == 0 ? TRUE : FALSE;

        if (
            (   $seq_cmd and ( $is_regex and $cmd_seq_str =~ $cr
                    or not $is_regex and $cmd_seq_str eq $cr )
            )
            or (not $seq_cmd
                and ( $is_regex and $command_buffer =~ $cr
                    or not $is_regex and $command_buffer eq $cr )
            )
        ) {
            $callback = $command_setup{$cr}
                if ref $command_setup{$cr} eq qw| CODE |;

            $callback = $command_setup{$cr}{'callback'}
                and @params = @{^CAPTURE}
                if ref( $command_setup{$cr} ) eq qw| HASH |
                and defined $command_setup{$cr}{'callback'}
                and defined $command_setup{$cr}{'param'}
                and $wait_param = TRUE
                and $command_buffer =~ qr|^$cr +$command_setup{$cr}{param}|;
        }

        last if defined $callback or $wait_param;
    }

    if (    not defined $callback
        and length $command_buffer
        and not $wait_param ) {

        ##  set command timeout  ##
        $clear_timer = Event->timer(
            'repeat' => FALSE,
            'cb'     => \&clear_command_buffer,
            'after'  => $command_timeout,
            'desc'   => '[ clear timer ]'
        );

    } elsif ( defined $callback ) {
        return error_exit('code reference expected as command callback')
            if ref($callback) ne qw| CODE |;
        ##  call command with params  ##
        $command_buffer = $callback->(@params) // '';
        visualize_command();
    } elsif ( not $wait_param ) {
        clear_command_buffer();
    }
}

sub read_single {
    state $check_timer;
    $command_buffer //= '';

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
    }

    return '' if not defined $key;

    check_command()        if length($command_buffer) and $key =~ m|[\r\n]|;
    clear_command_buffer() if $key                             =~ m|[\r\n]|;

    substr( $command_buffer, -1, 1, '' )    ## backspace ##
        and visualize_command()
        and return ''
        if length $command_buffer
        and $key eq chr(127);

    return '' if $key eq chr(127);

    while ( my $next_one = ReadKey(-1) ) {
        $key .= $next_one;
    }

    $command_buffer .= $key;

    $command_buffer =~ s|^\ +|| if not defined $command_setup{' '};

    check_command();

    ##  set check timeout  ##
    if ( defined $check_timer ) {
        $check_timer->cancel if $check_timer->is_active;
        $check_timer = undef;
    }

    state $set_count //= 0;

    ##  set command timeout  ##
    $check_timer = Event->timer(
        'repeat' => FALSE,
        'cb'     => \&check_command,
        'after'  => $command_timeout / 7,
        'desc'   => '[ check timer ]'
    );

    visualize_command();

    return $key if not length($command_buffer) and $key =~ m|[\ \n]|;
    return '';
}

sub visualize_command {
    return if not $verbose;
    return if cmd_to_sequence($command_buffer) ne $command_buffer;
    my $_pos = "\e[24H";
    printf( "$_pos\e[3J$_pos%s\r    ", ' ' x 42 ) and return TRUE
        if not length $command_buffer or $command_buffer eq ' ';
    printf "$C{R}$_pos $C{0} :. %s  ", $command_buffer;
    return TRUE;
}

sub process_key_press {
    my $wait_key      = shift // 0;
    my $show_sequence = $verbose;
    ReadMode 3;    ## no echo ##
    if ( $wait_key == -2 ) {
        my $read_delay = shift // -1;
        while ( read_single($read_delay) eq ' ' ) {
            ( shift // 0 );
        }
    } elsif ( $wait_key == -1 ) {
        read_single(0);
    } elsif ( $wait_key == 0 ) {
        read_single(-1);
    } else {
        read_single($wait_key);
    }
}

return TRUE ##################################################################

#,,,,,...,,,,,..,,,,.,,.,,...,..,,,,,,.,.,..,,..,,...,...,,..,,,.,,,.,,.,,,,,,
#HS6RH3HDU6IMQ24ZXYURJPMUEDMT4KKCQNXUGBY7FRZKUSK2ETYL3WKBHIYVPLFRC4BG2PR2AP5QO
#\\\|DIPX26FBWL3ASOACF5G2GQKLSJ6K4HSOHZEP4NFM7H5XZN4XBYA \ / AMOS7 \ YOURUM ::
#\[7]W5EQICXAAAN43KQU5CECBYVZBMYMMFVHDXI4CV6ZVCZ7VOIWLKCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
