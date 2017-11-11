#include <sys/socket.h>
#include <sys/types.h>
#include <sys/un.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <errno.h>

/* XXX: needs a least a timeout, cut param at endlines, read line or RAW <n> */

char * socket_path = "/tmp/.n/s/53BNMpXBtETx_5xqiZcwlQ";

char auth_str[64] = "select unix\nauth photon\n";
char close_cmd[6] = "close\n";

int main( int argc, char * argv[] ) {
    struct sockaddr_un addr;
    char buf [1024];
    int errno, socket_fd, result;
    fd_set readset;

    /* print usage message */
    if ( argc < 2 ) {
        printf( "\n usage: %s <nailara_command> [command_args]\n\n", argv[0] );
        exit(1);
    }

    /* prepare command string */
    int i;
    int arglen = 2;
    for ( i = 1; i < argc; ++i ) {
        arglen += strlen( argv[i] ) + 1;
    }
    char * cmd_str = (char *) malloc( sizeof(char) * arglen );
    strcpy( cmd_str, argv[1] );
    for ( i = 2; i < argc; ++i ) {
        strcat( cmd_str, " " );
        strcat( cmd_str, argv[i] );
    }
    strcat( cmd_str, "\n" );

    /* prepare socket */
    if ( ( socket_fd = socket( AF_UNIX, SOCK_STREAM, 0 ) ) == -1 ) {
        perror("[!] socket error");
        exit(-1);
    }

    /* prepare unix socket path */
    memset( &addr, 0, sizeof(addr) );
    addr . sun_family = AF_UNIX;
    strncpy( addr . sun_path, socket_path, sizeof( addr . sun_path ) - 1 );

    /* connect to socket */
    if (connect( socket_fd, ( struct sockaddr * ) & addr, sizeof(addr) ) == -1){
        printf( "< connect error > '%s': %s!", socket_path, strerror(errno) );
        exit(-1);
    }

    /* authenticate to nailara core */
    write( socket_fd, auth_str, strlen(auth_str) );
    int match = 0;
    char byte = ' ';
    while ( match < 2 ) {
        result = recv( socket_fd, &byte, 1, 0 );
        if ( result < 0 ) {
            printf( "[!] error during authentication: %s\n", strerror(errno) );
            exit(-1);
        }
        if ( byte == '\n' ) { match++; }
    }

    /* preparing select [read] filehandle set */
    do {
        FD_ZERO(&readset);
        FD_SET( socket_fd, &readset );
        result = select( socket_fd + 1, &readset, NULL, NULL, NULL );
    } while ( result == -1 && errno == EINTR );

    int close_sent = 0;
    if ( result > 0 ) {
        if ( FD_ISSET( socket_fd, &readset ) ) {
            result = recv( socket_fd, buf, sizeof(buf), 0 );
            if ( result == 0 ) {
                close(socket_fd);
            } else {

                /* send nailara command string to socket */
                write( socket_fd, cmd_str, strlen(cmd_str) );
                free(cmd_str);

                /* read and print output until connection is closed */
                while ( ( result = read( socket_fd, buf, sizeof(buf) ) ) > 0 ) {
                    if ( close_sent == 0 ) {
                        /* receiving output, send 'close' command */
                        write( socket_fd, close_cmd, strlen(close_cmd) );
                        close_sent = 1;
                        /* needs improvement! */;
                    }
                    write( STDOUT_FILENO, buf, result );
                }
            }
        }
    } else if ( result < 0 ) {
        printf( "Error on select(): %s", strerror(errno) );
    }
    return 0;
}
