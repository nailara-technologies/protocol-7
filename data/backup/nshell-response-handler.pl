sub shell_loop {
    my $sock   = shift;
    my $prompt = shift;

    if ( not $stdout_pid = fork() ) {
        $SIG{'TERM'} = $SIG{'INT'} = $SIG{'HUP'} = qw| IGNORE |;
        $SIG{'PIPE'} = sub { kill( 9, $parent_pid ); exit(2) };
        stdout_fork();
        exit;
    }
    if ( defined $stored_cmd ) {
        sleep(0.2);
        undef $stored_cmd;
    }

    map {
        $SIG{$ARG} = sub { parent_exit( shift, $stdout_pid ) }
    } qw| TERM INT HUP |;

    $term->add_history('');

    $connect = FALSE;
    my $last_line = '';
    override_signals();

    my $waiting_for_response = 0;
    my $size_bytes_remaining = 0;

    while ( -S $sock ) {
        my $line;

        if ($waiting_for_response) {
            my $response;
            my $bytes_read;

            if ($size_bytes_remaining > 0) {
                # Read remaining SIZE response bytes
                $bytes_read = sysread($sock, $response, $size_bytes_remaining);
                if ($bytes_read > 0) {
                    print "$response";
                    $size_bytes_remaining -= $bytes_read;
                    if ($size_bytes_remaining == 0) {
                        $waiting_for_response = 0;
                    }
                }
                next;
            }

            # Read response line
            $response = <$sock>;
            if (defined $response) {
                chomp($response);

                if ($response =~ /^SIZE (\d+)$/) {
                    $size_bytes_remaining = $1;
                    next;
                }

                if ($response =~ /^(TRUE|FALSE) /) {
                    print "$response\n";
                    $waiting_for_response = 0;
                }
            }

            next if $waiting_for_response;
        }

        # Get input when not waiting for response
        $line = $term->readline($prompt);

        if (not defined $line) {
            last if not -S $sock;
            next;
        }

        $WARNED  = FALSE;
        $connect = TRUE;
        print $C{'T'};

        if ( $line ne '' ) {
            $term->add_history($line) if $line ne $last_line;
            $last_line = $line;

            if ( $line =~ m|^\. cd (.+)| ) {
                my $cd_path = $LAST_PAREN_MATCH;
                if ( not chdir($cd_path) ) {
                    warn_err( 'cd [ %s ] %s <{NC}>',
                        -1, $cd_path, scalar format_error( $OS_ERROR, -1 ) );
                }
            } elsif ( $line =~ m|^\. (.+)$| ) {
                $lines_up = 1;
                no warnings;
                if ( my $err = system($LAST_PAREN_MATCH) ) {
                    my $error   = '';
                    my $err_msg = "exit code : $err";
                    if ( $err == -1 ) {
                        $err_msg = format_error( $OS_ERROR, -1 );
                        $error   = ' << error >>';
                    }
                    warn_err( '- ! -%s [ %s ] <{NC}>', -1, $error, $err_msg );
                }
                use warnings;
            } else {
                if ( $line eq qw| [reset] | ) {
                    system(qw| reset |);
                    $line = '';
                    say '';
                }
                if ( length($line) and $line ne '[quit]' ) {
                    say '' if $PRINT_SEPERATOR_NEWLINE;
                    if ( !s_write( $sock, sprintf( "%s\n", $line ) ) ) {
                        sleep(0.1);
                        $stored_cmd = $line;
                    } else {
                        $waiting_for_response = 1;
                    }
                }
                sleep(0.2);
                if (   $line eq '[quit]'
                    or defined $stored_cmd and $stored_cmd eq 'exit'
                    or $line =~ "TRUE session closed\n" ) {
                    print {$sock} "exit user quit shell session\n"
                        if $line eq '[quit]';
                    close($sock);
                    exit;
                } elsif ( defined $stored_cmd
                    or not -S $sock
                    or not $sock->connected ) {
                    my $r_msg = ' :: reconnecting..,';
                    if ( not defined $stored_cmd ) {
                        printf "\e[2H\e[2J%s\n", $r_msg;
                    } else {
                        my $l_cmd = length $stored_cmd;
                        printf "\033[1A\r%-*s\n\033[2A\r", $l_cmd, $r_msg;
                    }
                    last;
                }
            }
        }
    }

    if ( not $connect ) {
        if ( -S $shell_sock ) {
            s_write( $shell_sock, "\nexit ==\\ lost terminal \\==\n" );
            close($shell_sock);
        }
        kill( 9, $parent_pid );
        exit(qw| 0110 |);
    }
}
