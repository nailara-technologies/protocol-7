
#define _GNU_SOURCE

#include <sys/socket.h>
#include <sys/un.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <errno.h>

/* LLL: needs at least timeout, cut param at endlines, read line or RAW <n> */

char *src_bmw_b32 = "[BMW_FILE_CHkSUM]";
char *socket_path = "/var/run/.7/UNIX/NIW7OAQ"; // ENV{'PROTOCOL_7_UNIX_PATH'}

char* concat(const char *s1, const char *s2)
{
    const size_t len1 = strlen(s1);
    const size_t len2 = strlen(s2);
    int errno;
    char *result = malloc(len1 + len2 + 1); // +1 for the null-terminator
    if( result == NULL ) {
        fprintf( stderr, "< malloc > %s\n", strerror(errno) );
        exit(-2);
    }

    memcpy(result, s1, len1);
    memcpy(result + len1, s2, len2 + 1); // +1 to copy the null-terminator
    return result;
}

int main( int argc, char * argv[] ) {
    fd_set readset;
    char buf [1024];
    char * auth_str = '\0';
    char * root_usr = "root";
    struct sockaddr_un addr;
    int errno, socket_fd, result;

    char * p7_unix_user      = secure_getenv("PROTOCOL_7_P7C_USER");
    char * protocol_7_socket = secure_getenv("PROTOCOL_7_UNIX_PATH");

    if ( p7_unix_user == NULL )
        p7_unix_user = secure_getenv("USER");  // use regular unix user

    if ( p7_unix_user == NULL )
        p7_unix_user = secure_getenv("LOGNAME"); // next LOGNAME

    if ( p7_unix_user == NULL )
        p7_unix_user = root_usr; // try unix user root as a fallback user

    if ( protocol_7_socket != NULL )
        socket_path = protocol_7_socket;

    char * auth_P7C_USER = concat( "unix-", p7_unix_user );
    const char close_cmd [] = "close\n";

    if ( argc < 2 ) {
        fprintf( stderr, "\n < usage : %s <command> [args] >\n\n",
            argv[0] );
        exit(1);
    }

    for (int i = 1; i < argc; i++) {
        if (argv[i][0] == '-') {
           if (argv[i][1] == 'd')
           {
                if (argv[i][2] == 'q') // -dq == checksum only
                {
                    printf( "%s\n", src_bmw_b32 );
                } else {
                    printf( ":\n: %s.c :. %s .:\n:\n", argv[0], src_bmw_b32 );
                }
                return 0;
           }
           else
           {
                fprintf( stderr,
                  "\n  << option not valid >>  [ -d[q] for BMW checksum ]\n\n"
                );
                return 2;
           }
        }
    }

    /* prepare authentication */
    asprintf( &auth_str, "select unix\nauth %s\n", auth_P7C_USER );

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
        perror("<< socket error >>");
        exit(-1);
    }

    /* prepare unix socket path */
    memset( &addr, 0, sizeof(addr) );
    addr . sun_family = AF_UNIX;
    strncpy( addr.sun_path, socket_path, sizeof( addr.sun_path ) - 1 );

    /* connect to socket */
    if (connect(socket_fd, ( struct sockaddr * ) & addr, sizeof(addr)) == -1)
    {
        fprintf( stderr, "<< connection not successful : %s [unix:%s] >>\n",
                strerror(errno), socket_path );
        exit(-1);
    }

    /* authenticate to nailara core */
    write( socket_fd, auth_str, strlen(auth_str) );
    free(auth_P7C_USER);
    int match = 0;
    char byte = ' ';
    while ( match < 2 ) {
        result = recv( socket_fd, &byte, 1, 0 );
        if ( result < 0 ) {
            fprintf( stderr,
                "<< error during authentication sequence : %s >>\n",
                strerror(errno)
            );
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
                while ( ( result = read( socket_fd, buf, sizeof(buf) ) ) > 0 )
                {
                    if ( close_sent == 0 ) {
                        /* receiving output, send 'close' command */
                        write( socket_fd, close_cmd, strlen(close_cmd) );
                        close_sent = 1;
                        /* needs improvement */;
                    }
                    write( STDOUT_FILENO, buf, result );
                }
            }
        }
    } else if ( result < 0 ) {
        fprintf(stderr, "<< error on select() call : %s >>", strerror(errno));
    }
    return 0;
}
