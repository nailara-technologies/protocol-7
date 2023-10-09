
#define _GNU_SOURCE

#include <sys/socket.h>
#include <sys/un.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <errno.h>

char *src_bmw_b32 = "[BMW_FILE_CHkSUM]";
char *socket_path = "/var/run/.7/UNIX/NIW7OAQ"; // ENV{'PROTOCOL_7_UNIX_PATH'}

char* concat(const char *s1, const char *s2)
{
    const size_t len1 = strlen(s1);
    const size_t len2 = strlen(s2);
    int errno;
    char *result = malloc(len1 + len2 + 1 ); // +1 for '\0'
    if( result == NULL ) {
        fprintf( stderr, "< malloc [concat] > %s\n", strerror(errno) );
        exit(4);
    }

    memcpy(result, s1, len1);
    memcpy(result + len1, s2, len2 + 1); // +1 for '\0'
    return result;
}

int main( int argc, char * argv[] ) {

    char * auth_str  = '\0';
    char * root_usr  = "root";    // fallback user

    int errno, socket_fd;
    struct sockaddr_un addr;

    char * p7_unix_user      = secure_getenv("PROTOCOL_7_BIN_P7_USER");
    char * protocol_7_socket = secure_getenv("PROTOCOL_7_UNIX_PATH");

    if ( p7_unix_user == NULL )
        p7_unix_user = secure_getenv("USER");  // use regular unix user

    if ( p7_unix_user == NULL )
        p7_unix_user = secure_getenv("LOGNAME"); // next LOGNAME

    if ( p7_unix_user == NULL )
        p7_unix_user = root_usr; // try unix user root as a fallback user

    if ( protocol_7_socket != NULL )
        socket_path = protocol_7_socket;

    char * auth_BIN_P7_USER = concat( "unix-", p7_unix_user );

    if ( argc < 2 ) {
        fprintf( stderr, "\n < usage : %s <command> [args] >\n\n",
            argv[0] );
        exit(2);
    }

    for (int i = 1; i < argc; i++) {
        if (argv[i][0] == '-') {
           if (argv[i][1] == 'd')
           {
                if (argv[i][2] == 'q') // -dq == checksum only
                    printf( "%s\n", src_bmw_b32 );
                else
                    printf( ":\n: %s.c :. %s .:\n:\n", argv[0], src_bmw_b32 );
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
    asprintf( &auth_str, "select unix\nauth %s\n", auth_BIN_P7_USER );

    /* prepare command string */
    int i;
    int arglen = 2;
    for ( i = 1; i < argc; ++i ) {
        arglen += strlen( argv[i] ) + 1;
    }
    char * cmd_str = (char *) malloc( sizeof(char) * arglen );
    if( cmd_str == NULL ) {
        fprintf( stderr, "< malloc [argv] > %s\n", strerror(errno) );
        exit(4);
    }

    strcpy( cmd_str, argv[1] );
    for ( i = 2; i < argc; ++i ) {
        strcat( cmd_str, " " );
        strcat( cmd_str, argv[i] );
    }
    strcat( cmd_str, "\n" );

    /* prepare socket */
    if ( ( socket_fd = socket( AF_UNIX, SOCK_STREAM, 0 ) ) == -1 ) {
        perror("<< socket error >>");
        return 3;
    }

    /* prepare unix socket path */
    memset( &addr, 0, sizeof(addr) );
    addr.sun_family = AF_UNIX;
    strncpy( addr.sun_path, socket_path, sizeof( addr.sun_path ) - 1 );

    /* connect to socket */
    if (connect(socket_fd, ( struct sockaddr * ) & addr, sizeof(addr)) == -1)
    {
        fprintf( stderr, "<< connection not successful : %s [unix:%s] >>\n",
                strerror(errno), socket_path );
        return 3;
    }

    /* authenticate to protocol-7 cube */
    write( socket_fd, auth_str, strlen(auth_str) );
    free(auth_BIN_P7_USER);
    unsigned int line = 0;
    int result;
    char byte = ' ';
    while ( line <= 2 ) {   // 3 lines expected

        result = recv( socket_fd, &byte, 1, 0 );

        if ( result < 0 ) {
            fprintf( stderr,
                "<< error during authentication sequence : %s >>\n",
                strerror(errno)
            );
            return 4;
        } else if ( byte == '\n' ) {
            line++;
        }

        if ( line == 2 && byte == 'O' ) {  // AUTH_ERR[O]R in third reply line
            fprintf( stderr,
                "<< authentication not successful [ user '%s' ] >>\n",
                p7_unix_user );
            return 3;
        }
    }

    /* send protocol-7 command string to socket */
    write( socket_fd, cmd_str, strlen(cmd_str) );
    free(cmd_str);

    char reply_type[13]   = "\0";
    char size_str_buf[24] = "\0";

    int output_bytes  = 0;
    int skip_this_one = 0;
    int continue_read = 1;
    int close_at_lf   = 1;
    int reading_size  = 0;
    long bytes_to_read = -1;
    int space_seen = 0;
    while ( continue_read ) {
        result = recv( socket_fd, &byte, 1, MSG_WAITALL );
        if ( result < 1 ) {
            continue_read = 0;
        } else {
            if( space_seen == 0 && strlen(reply_type) < 9 ) {
                size_t rtype_len = strlen( reply_type );
                if ( byte == ' ' ) {
                    space_seen = 1;
                    reply_type[rtype_len] = '\0';
                }
                else
                    reply_type[rtype_len] = byte;

            } else if ( space_seen ) {

                if ( output_bytes == 0 ) {
                    if ( strcmp( reply_type, "TRUE" ) == 0 ||
                         strcmp( reply_type, "FALSE" ) == 0 )
                        output_bytes = 1;

                    if ( reading_size ||
                         strcmp( reply_type, "SIZE" ) == 0 ) {
                        size_t sizes_len = strlen(size_str_buf);

                        if ( sizes_len > 20 ) {
                            fprintf( stderr,
                                "<< SIZE reply error : numeric overflow >>\n"
                            );
                            return 20;
                        }

                        if ( reading_size == 0 )
                             reading_size = 1;

                        if( byte == '\n' ) {
                            size_str_buf[sizes_len] = '\0';
                            bytes_to_read = atoi(size_str_buf);
                            close_at_lf  = 0;
                            reading_size = 0;
                            // SIZE 00000
                            if( bytes_to_read == 0 )
                                continue_read = 0;
                            else {
                                output_bytes = 1;
                                skip_this_one = 1; // endline from SIZE reply
                            }
                        }
                        else {
                            size_str_buf[sizes_len] = byte;
                        }
                    }
                }

                if ( continue_read && output_bytes ) {

                    if ( skip_this_one )
                        skip_this_one = 0;
                    else
                        /*  writing payload-data to stdout  */
                        write( STDOUT_FILENO, &byte, result );

                    if ( close_at_lf && byte == '\n' ) // TRUE || FALSE line
                        continue_read = 0;

                    else if ( bytes_to_read > -1 ) {
                        bytes_to_read--;

                        //  'SIZE <bytes>'-reply completed
                        if ( bytes_to_read < 0 )
                            continue_read = 0;
                    }
                }
            }
        }
    }

    if ( strcmp( reply_type, "FALSE" ) <= 0 )
        return 1;
    else
        return 0; // TRUE || SIZE-reply
}
