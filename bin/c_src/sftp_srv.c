
/* sftp_srv.c  [ SFTP to protocol 7 unix domain socket relay ] */

#define _GNU_SOURCE

#include <sys/socket.h>
#include <sys/select.h>
#include <sys/un.h>
#include <string.h>
#include <signal.h>
#include <stdlib.h>
#include <unistd.h>
#include <errno.h>
#include <stdio.h>
#include <stdio_ext.h>

/* fd_max() macro */

#undef  fd_max
#define fd_max(x,y) ((x) > (y) ? (x) : (y))

/* read \ write buffer size */

#define BUF_SIZE 114688

/* peer shutdown \ fd close macro */

#define SHUTDOWN_SFD do {                                       \
                          if ( stdout_fd >= 0 ) {               \
                              _flushlbf();                      \
                              close(stdin_fd);                  \
                              stdin_fd = -1;                    \
                              close(stdout_fd);                 \
                              stdout_fd = -1;                   \
                          }                                     \
                      } while (0)

#define SHUTDOWN_U_FD do {                                      \
                          if (unix_fd >= 0) {                   \
                              _flushlbf();                      \
                              shutdown(unix_fd, SHUT_RDWR);     \
                              close(unix_fd);                   \
                              unix_fd = -1;                     \
                          }                                     \
                      } while (0)

/* expected */

char *src_bmw_b32   = "[BMW_FILE_CHkSUM]";
char *banner_string = "AMOS7-SFTP \\\\ protocol version 3\n"; //  expected
char *socket_path   = "/var/run/.7/UNIX/RFVQUQA"; // ENV{'UNIX_SFTP_PATH'}

/* concat() function */

char* concat(const char *s1, const char *s2)
{
    const size_t len1 = strlen(s1);
    const size_t len2 = strlen(s2);
    int errno;
    char *result = malloc(len1 + len2 + 1 ); // +1 for '\0'
    if( result == NULL ) {
        fprintf( stderr, "< malloc [concat] > %s\n", strerror(errno) );
        exit(EXIT_FAILURE);
    }
    memcpy(result, s1, len1);
    memcpy(result + len1, s2, len2 + 1); // +1 for '\0'
    return result;
}

/* main code */

int main( int argc, char * argv[] ) {

    int errno, unix_fd;
    struct sockaddr_un addr;

    /* override default path with UNIX_SFTP_PATH */

    char * protocol_7_socket = secure_getenv("UNIX_SFTP_PATH");
    if ( protocol_7_socket != NULL )
        socket_path = protocol_7_socket;

    /* code chksum option [ not further documented ] */

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

    if ( argc > 1 ) {
        fprintf( stderr, "\n  << no arguments expected [ env vars ] >>\n\n" );
        return 2;
    }

    signal(SIGPIPE, SIG_IGN);

    /* prepare socket */
    if ( ( unix_fd = socket( AF_UNIX, SOCK_STREAM, 0 ) ) == -1 ) {
        perror("<< socket error >>");
        exit(EXIT_FAILURE);
    }

    /* prepare unix socket path */
    memset( &addr, 0, sizeof(addr) );
    addr.sun_family = AF_UNIX;
    strncpy( addr.sun_path, socket_path, sizeof( addr.sun_path ) - 1 );

    /* connect to socket */
    if (connect(unix_fd, ( struct sockaddr * ) & addr, sizeof(addr)) == -1)
    {
        fprintf( stderr, "<< connection not successful : %s [unix:%s] >>\n",
                strerror(errno), socket_path );
        exit(EXIT_FAILURE);
    }

    /* sending SSH environment variables [ proto init state ] */

    char * SSH_CLIENT     = secure_getenv("SSH_CLIENT");
    char * SSH_CONNECTION = secure_getenv("SSH_CONNECTION");

    /* SSH_CLIENT */

    if ( SSH_CLIENT == NULL )
        write( unix_fd, "set-ENV SSH_CLIENT undefined\n", 29 );
    else {
        char * set_env_cmd;
        asprintf( &set_env_cmd, "set-ENV SSH_CLIENT '%s'\n", SSH_CLIENT );
        write( unix_fd, set_env_cmd, strlen(set_env_cmd) );
        free( set_env_cmd );
    }

    /* SSH_CONNECTION */

    if ( SSH_CONNECTION == NULL )
        write( unix_fd, "set-ENV SSH_CONNECTION undefined\n", 33 );
    else {
        char * set_env_cmd;
        asprintf( &set_env_cmd,
            "set-ENV SSH_CONNECTION '%s'\n", SSH_CONNECTION );
        write( unix_fd, set_env_cmd, strlen(set_env_cmd) );
        free( set_env_cmd );
    }

    /*  environment sent, change state  */
    write( unix_fd, "done-init\n", 10 );

    /* reply checks are done later below */

    int proto_state = 0;

    /*  prepare relay  */

    int stdin_fd  = STDIN_FILENO;
    int stdout_fd = STDOUT_FILENO;

    char buf_stdin[BUF_SIZE], buf_unix[BUF_SIZE];
    int buf_stdin_avail = 0, buf_stdin_written = 0;
    int buf_unix_avail = 0, buf_unix_written = 0;

    /* select relay code is adapted from man SELECT_TUT example */

    while ( stdin_fd >= 0 || stdout_fd > 0 || unix_fd >= 0 ) {

        int ready, nfds = 0;
        ssize_t nbytes;
        fd_set readfds, writefds, exceptfds;

        /* clearing FD list */

        FD_ZERO(&readfds);
        FD_ZERO(&writefds);
        FD_ZERO(&exceptfds);

        /* read-FDs */

        if (stdin_fd > -1 && buf_stdin_avail < BUF_SIZE) {
            FD_SET(stdin_fd, &readfds);
            nfds = fd_max(nfds, stdin_fd);
        }
        if (unix_fd > 0 && buf_unix_avail < BUF_SIZE) {
            FD_SET(unix_fd, &readfds);
            nfds = fd_max(nfds, unix_fd);
        }

        /* write-FDs */

        if (stdout_fd > 0 && buf_unix_avail - buf_unix_written > 0) {
            FD_SET(stdout_fd, &writefds);
            nfds = fd_max(nfds, stdout_fd);
        }
        if (unix_fd > 0 && buf_stdin_avail - buf_stdin_written > 0) {
            FD_SET(unix_fd, &writefds);
            nfds = fd_max(nfds, unix_fd);
        }

        /* exception-FD */

        if (stdin_fd > -1) {
            FD_SET(stdin_fd, &exceptfds);
            nfds = fd_max(nfds, stdin_fd);
        }
        if (stdout_fd > 0) {
            FD_SET(stdout_fd, &exceptfds);
            nfds = fd_max(nfds, stdout_fd);
        }
        if (unix_fd > 0) {
            FD_SET(unix_fd, &exceptfds);
            nfds = fd_max(nfds, unix_fd);
        }

        /*  waiting for data or exceptions  */

        ready = select(nfds + 1, &readfds, &writefds, &exceptfds, NULL);

        /* check for interrupts and select errors */

        if (ready == -1 && errno == EINTR)
            continue;

        if (ready == -1) {
            perror("select call error");
            exit(EXIT_FAILURE);
        }

        /* out-of-band data transfer [ for completeness ] */

        if ( unix_fd > 0 && FD_ISSET(unix_fd, &exceptfds)) {
            char c;
            nbytes = recv(unix_fd, &c, 1, MSG_OOB);
            if (nbytes < 1) {
                SHUTDOWN_U_FD;
            }
            else
                send(stdout_fd, &c, 1, MSG_OOB);
        }
        if (stdin_fd > -1 && FD_ISSET(stdin_fd, &exceptfds)) {
            char c;
            nbytes = recv(stdin_fd, &c, 1, MSG_OOB);
            if (nbytes < 1)
                SHUTDOWN_SFD;
            else
                send(unix_fd, &c, 1, MSG_OOB);
        }

        /*  read from stdin into buffer  */

        if (stdin_fd > -1 && FD_ISSET(stdin_fd, &readfds)) {

            nbytes = read(stdin_fd, buf_stdin + buf_stdin_avail,
                      BUF_SIZE - buf_stdin_avail);

            if (nbytes < 1)
                SHUTDOWN_SFD;
            else
                buf_stdin_avail += nbytes;
        }

        /*  read from unix socket  */

        if (unix_fd > 0 && FD_ISSET(unix_fd, &readfds)) {

            nbytes = read(unix_fd, buf_unix + buf_unix_avail,
                      BUF_SIZE - buf_unix_avail);

            if (nbytes < 1)
               SHUTDOWN_U_FD;
            else
                buf_unix_avail += nbytes;
        }

        if ( stdout_fd > 0 && FD_ISSET(stdout_fd, &writefds) &&
                buf_unix_avail > 0 ) {

            if ( proto_state == 2 ) {  /* relay is active */

                nbytes = write( stdout_fd, buf_unix + buf_unix_written,
                    buf_unix_avail - buf_unix_written );

                if (nbytes < 1)
                    SHUTDOWN_SFD;
                else
                    buf_unix_written += nbytes;

            } else if ( proto_state == 0 &&
                strncmp( buf_unix, banner_string,
                    strlen(banner_string) ) == 0 ) {

                /* banner received */

                buf_unix_written = buf_unix_avail = 0; // reset buffer
                proto_state++; // advance to 'init' protocol state

            } else if ( proto_state == 0 ) {
                fprintf( stderr,
                    "<<  protocol error : expected banner string  >>\n"
                );
                fprintf( stderr, "     : buffer .: %s\n", buf_unix );
                return 3;

            } else if ( proto_state == 1 ) {
                /*  protocol [ ssh-env ] init phase  */
                if ( strncmp( buf_unix, "TRUE init complete\n", 19 ) == 0 ) {

                    buf_unix_written = buf_unix_avail = 0; // reset buffer

                    proto_state++;       // start relaying

                } else if ( strcmp( buf_unix,
                    "FALSE connection source unauthorized\n" ) == 0 ) {
                    fprintf( stderr,
                        "<< connection source not authorized >>\n"
                    );
                    return 1;
                } else {
                    fprintf( stderr,
                      "<<  protocol error : protocol init not sucessful  >>\n"
                    );
                    fprintf( stderr, "     : buffer .: %s\n", buf_unix );
                    return 3;
                }
            }
        }

        /*  writing to unix domain socket  */

        if ( unix_fd > 0 && FD_ISSET(unix_fd, &writefds) &&
                buf_stdin_avail > 0 ) {
            nbytes = write(unix_fd, buf_stdin + buf_stdin_written,
                       buf_stdin_avail - buf_stdin_written);
            if (nbytes < 1)
                SHUTDOWN_U_FD;
            else
                buf_stdin_written += nbytes;
        }

        /* write data caught up with read data ? */
        if (buf_stdin_written == buf_stdin_avail)
            buf_stdin_written = buf_stdin_avail = 0;
        if (buf_unix_written == buf_unix_avail)
            buf_unix_written = buf_unix_avail = 0;

        /* async close */
        if ( buf_stdin_avail - buf_stdin_written == 0 &&
            ( stdout_fd < 0 || stdin_fd < 0 ) )
            SHUTDOWN_U_FD;
        if (unix_fd < 0 && buf_unix_avail - buf_unix_written == 0)
            SHUTDOWN_SFD;
    }

    /* session closed */
    exit(EXIT_SUCCESS);
}
