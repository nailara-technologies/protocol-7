
#define _GNU_SOURCE

#include <sys/socket.h>
#include <sys/types.h>
#include <sys/un.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <errno.h>

/* LLL: needs at least a timeout, cut param at endlines, read line or RAW <n> */

char * socket_path = "/tmp/.n/s/W7WHIAQ"; /* ::todo:: calculate or look up.. */

int main( int argc, char * argv[] ) {
    fd_set readset;
    char buf [1024];
    char * auth_str = '\0';
    struct sockaddr_un addr;
    int errno, socket_fd, result;

    char * auth_usr = secure_getenv("USER");
    const char close_cmd [] = "close\n";

    if ( argc < 2 ) {
        fprintf( stderr, "\n usage: %s <nailara_command> [command_args]\n\n",
            argv[0] );
        exit(1);
    }

    if ( auth_usr == NULL ) {
        fprintf( stderr, "{!} %s!",
            "expected environment variable USER is not set\n" );
        exit(1);
    }

    // debug:
    // printf( " account user [%s]\n", auth_usr );

    /* prepare authentication */
    asprintf(&auth_str, "select unix\nauth %s\n", auth_usr);
    // asprintf(&auth_str, "select unix\nauth %s\n", auth_usr);

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
        printf( "< connection failed > socket path '%s': %s!\n",
                socket_path, strerror(errno) );
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
