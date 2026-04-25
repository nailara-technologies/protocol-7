
#define _GNU_SOURCE

#include <sys/socket.h>
#include <sys/un.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <errno.h>
#include <time.h>
#include <string.h>

char *src_bmw_b32 = "[BMW_FILE_CHkSUM]";
char *socket_path = "/var/run/.7/UNIX/NIW7OAQ"; // ENV{'PROTOCOL_7_UNIX_PATH'}

/* Link-upgrade encryption state */
struct encryption_state {
    int enabled;
    char *key;
    unsigned int session_id;
    unsigned int read_counter;
    unsigned int write_counter;
};

/* Stream-locking state for STRM protocol handling */
struct stream_state {
    int locking_enabled;     /* 1 if stream-locking true sent */
    int streaming;           /* 1 if in active STRM stream */
    long expected_bytes;     /* From STRM open <N> */
    long received_bytes;     /* Cumulative from STRM chunks */
};

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

/* Helper: Read a line from socket until newline */
int read_line(int socket_fd, char *buffer, size_t max_size)
{
    int pos = 0;
    char byte;
    while (pos < max_size - 1) {
        if (recv(socket_fd, &byte, 1, 0) < 1)
            return -1;
        buffer[pos++] = byte;
        if (byte == '\n')
            break;
    }
    buffer[pos] = '\0';
    return pos;
}

/* Helper: Strip trailing newline */
void strip_newline(char *str)
{
    int len = strlen(str);
    if (len > 0 && str[len - 1] == '\n')
        str[len - 1] = '\0';
}

/* Link-upgrade negotiation */
int negotiate_link_upgrade(int socket_fd, struct encryption_state *state)
{
    FILE *f;
    char cmd[1024];
    char server_pubkey[256] = {0};
    char client_pubkey[256] = {0};
    char client_secret[256] = {0};
    char shared_secret[256] = {0};

    /* 1. Send link-upgrade init */
    if (write(socket_fd, "link-upgrade\n", 13) < 0)
        return -1;

    /* 2. Read server response: "TRUE link-upgrade OK <pubkey_base32>" */
    char response_line[512] = {0};
    if (read_line(socket_fd, response_line, sizeof(response_line)) < 0)
        return -1;
    strip_newline(response_line);

    /* Extract pubkey from "TRUE link-upgrade OK <pubkey>" */
    char *pubkey_start = strstr(response_line, "OK ");
    if (!pubkey_start) {
        fprintf(stderr, ":: invalid server response during link-upgrade ::\n");
        return -1;
    }
    pubkey_start += 3;  /* Skip "OK " */
    strncpy(server_pubkey, pubkey_start, sizeof(server_pubkey) - 1);

    /* 3. Generate client ephemeral keypair via helper */
    f = popen("/data/projects/protocol-7/bin/p7-link-upgrade-helper.pl gen-ephemeral 2>/dev/null", "r");
    if (!f) {
        fprintf(stderr, ":: failed to spawn crypto helper ::\n");
        return -1;
    }

    if (fgets(client_pubkey, sizeof(client_pubkey), f) == NULL ||
        fgets(client_secret, sizeof(client_secret), f) == NULL) {
        pclose(f);
        return -1;
    }
    pclose(f);
    strip_newline(client_pubkey);
    strip_newline(client_secret);

    /* 4. Send client pubkey */
    snprintf(cmd, sizeof(cmd), "link-pub-key %s\n", client_pubkey);
    if (write(socket_fd, cmd, strlen(cmd)) < 0)
        return -1;

    /* 5. Read readiness confirmation */
    char confirm[256] = {0};
    if (read_line(socket_fd, confirm, sizeof(confirm)) < 0)
        return -1;

    /* 6. Compute DH shared secret via helper */
    snprintf(cmd, sizeof(cmd),
             "/data/projects/protocol-7/bin/p7-link-upgrade-helper.pl compute-dh %s %s 2>/dev/null",
             client_secret, server_pubkey);
    f = popen(cmd, "r");
    if (!f) {
        fprintf(stderr, ":: failed to compute shared secret ::\n");
        return -1;
    }

    if (fgets(shared_secret, sizeof(shared_secret), f) == NULL) {
        pclose(f);
        return -1;
    }
    pclose(f);
    strip_newline(shared_secret);

    /* 7. Derive encryption key via helper */
    state->session_id = (unsigned int)time(NULL);
    snprintf(cmd, sizeof(cmd),
             "/data/projects/protocol-7/bin/p7-link-upgrade-helper.pl derive-key %s %u 2>/dev/null",
             shared_secret, state->session_id);
    f = popen(cmd, "r");
    if (!f) {
        fprintf(stderr, ":: failed to derive encryption key ::\n");
        return -1;
    }

    state->key = (char *)malloc(256);
    if (state->key == NULL || fgets(state->key, 256, f) == NULL) {
        pclose(f);
        return -1;
    }
    pclose(f);
    strip_newline(state->key);

    /* 8. Send encoding confirmation (none = no transport encoding) */
    char enc_cmd[256] = {0};
    snprintf(enc_cmd, sizeof(enc_cmd), "link-confirm-encoding none\n");
    if (write(socket_fd, enc_cmd, strlen(enc_cmd)) < 0)
        return -1;

    if (read_line(socket_fd, confirm, sizeof(confirm)) < 0)
        return -1;
    strip_newline(confirm);
    /* Expect: "encoding-confirmed" or similar success response */

    if (write(socket_fd, "link-complete\n", 14) < 0)
        return -1;

    if (read_line(socket_fd, confirm, sizeof(confirm)) < 0)
        return -1;

    state->read_counter = 0;
    state->write_counter = 0;
    return 0;
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

    /* Link-upgrade encryption negotiation (optional) */
    struct encryption_state enc_state = {0, NULL, 0, 0, 0};

    /* Stream-locking state initialization */
    struct stream_state stream = {0, 0, 0, 0};
    stream.locking_enabled = 1;  /* p7c always uses locked mode for STRM safety */

    char *link_upgrade_env = secure_getenv("PROTOCOL_7_LINK_UPGRADE");
    if (link_upgrade_env && strcmp(link_upgrade_env, "yes") == 0) {
        if (negotiate_link_upgrade(socket_fd, &enc_state) == 0) {
            fprintf(stderr, ":: link-upgrade encryption negotiated ::\n");
            enc_state.enabled = 1;
        } else {
            fprintf(stderr, ":: link-upgrade negotiation failed, continuing plaintext\n");
        }
    }

    /* Send select-strm-mode first and read its response */
    write( socket_fd, "select-strm-mode locked\n", 24 );

    /* Read select-strm-mode response - should be TRUE */
    char strm_response_line[256] = {0};
    if (read_line(socket_fd, strm_response_line, sizeof(strm_response_line)) < 0) {
        fprintf(stderr, "error reading strm-mode response\n");
        close(socket_fd);
        return 4;
    }
    if (strncmp(strm_response_line, "TRUE", 4) != 0) {
        fprintf(stderr, "strm-mode not accepted: %s\n", strm_response_line);
        /* Continue anyway - not fatal */
    }
    if (getenv("DEBUG"))
        fprintf(stderr, "[select-strm-mode locked] accepted\n");

    /* send protocol-7 command string to socket */
    write( socket_fd, cmd_str, strlen(cmd_str) );
    free(cmd_str);

    char reply_type[13]   = "\0";
    char size_str_buf[24] = "\0";
    char strm_arg_buf[64] = "\0";  /* For STRM open/close args */

    int output_bytes  = 0;
    int skip_this_one = 0;
    int continue_read = 1;
    int close_at_lf   = 1;
    int reading_size  = 0;
    int reading_strm_arg = 0;  /* 1 if parsing STRM argument */
    long count_to_read = -1;    // Byte count (SIZE mode) or char count (CHRSIZE mode)
    int space_seen = 0;
    int utf8_char_count = 0;    // Track UTF-8 characters read (CHRSIZE mode only)
    int bytes_read = 0;         // Track raw bytes read
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
                else {
                    reply_type[rtype_len] = byte;
                }

            } else if ( space_seen ) {

                if ( output_bytes == 0 ) {
                    if ( strcmp( reply_type, "TRUE" ) == 0 ||
                         strcmp( reply_type, "FALSE" ) == 0 )
                        output_bytes = 1;

                    int is_strm_response = ( strcmp( reply_type, "STRM" ) == 0 );
                    int is_size_response = ( strcmp( reply_type, "SIZE" ) == 0 ||
                                             strcmp( reply_type, "CHRSIZE" ) == 0 );

                    /* STRM protocol handling */
                    if ( is_strm_response && stream.locking_enabled ) {
                        size_t arg_len = strlen(strm_arg_buf);

                        if ( arg_len > 60 ) {
                            fprintf( stderr,
                                "<< STRM reply error : argument overflow >>\n"
                            );
                            return 20;
                        }

                        if ( reading_strm_arg == 0 )
                            reading_strm_arg = 1;

                        if ( byte == '\n' ) {
                            strm_arg_buf[arg_len] = '\0';

                            /* Parse STRM argument: "open <bytes>", "open" (unbounded),
                               "<chunk_size>", or "close" */
                            if ( strncmp(strm_arg_buf, "open ", 5) == 0 ) {
                                stream.expected_bytes = atol(strm_arg_buf + 5);
                                stream.streaming = 1;
                                stream.received_bytes = 0;
                                close_at_lf = 0;
                                /* Reset state to parse next STRM header fresh */
                                memset(reply_type, 0, sizeof(reply_type));
                                space_seen = 0;
                            } else if ( strcmp(strm_arg_buf, "open") == 0 ) {
                                /* Unbounded stream: no declared total */
                                stream.expected_bytes = -1;
                                stream.streaming = 1;
                                stream.received_bytes = 0;
                                close_at_lf = 0;
                                memset(reply_type, 0, sizeof(reply_type));
                                space_seen = 0;
                            } else if ( strcmp(strm_arg_buf, "close") == 0 ) {
                                /* Validate and exit (skip check for unbounded streams) */
                                if ( stream.expected_bytes != -1 &&
                                     stream.received_bytes != stream.expected_bytes ) {
                                    fprintf(stderr, "[STRM] ERROR: incomplete stream %ld/%ld bytes\n",
                                        stream.received_bytes, stream.expected_bytes);
                                    return 1;
                                }
                                if (getenv("DEBUG"))
                                    fprintf(stderr, "[STRM] stream closed: %ld bytes received\n",
                                        stream.received_bytes);
                                continue_read = 0;
                            } else {
                                /* chunk_size for data packet */
                                count_to_read = atol(strm_arg_buf);
                                bytes_read = 0;
                                output_bytes = 1;
                                skip_this_one = 1;  /* Skip the newline after size */
                            }

                            reading_strm_arg = 0;
                            memset(strm_arg_buf, 0, sizeof(strm_arg_buf));
                        } else {
                            strm_arg_buf[arg_len] = byte;
                        }
                    }

                    if ( reading_size || is_size_response ) {
                        size_t sizes_len = strlen(size_str_buf);

                        if ( sizes_len > 20 ) {
                            fprintf( stderr,
                                "<< SIZE/CHRSIZE reply error : numeric overflow >>\n"
                            );
                            return 20;
                        }

                        if ( reading_size == 0 )
                             reading_size = 1;

                        if( byte == '\n' ) {
                            size_str_buf[sizes_len] = '\0';
                            count_to_read = atoi(size_str_buf);
                            close_at_lf  = 0;
                            reading_size = 0;
                            utf8_char_count = 0;  // Reset counters
                            bytes_read = 0;
                            // SIZE/OCTETS 00000
                            if( count_to_read == 0 )
                                continue_read = 0;
                            else {
                                output_bytes = 1;
                                skip_this_one = 1; // endline from SIZE/OCTETS reply
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
                    else {
                        /*  writing payload-data to stdout  */
                        write( STDOUT_FILENO, &byte, result );

                        // Handle STRM, SIZE (byte-based) and CHRSIZE (character-based) modes
                        if ( count_to_read > -1 ) {
                            int is_chrsize = ( strcmp( reply_type, "CHRSIZE" ) == 0 );
                            int is_strm = ( strcmp( reply_type, "STRM" ) == 0 );

                            if ( is_strm ) {
                                // STRM mode: count raw bytes and track to stream state
                                bytes_read++;
                                stream.received_bytes++;
                            } else if ( is_chrsize ) {
                                // CHRSIZE mode: count UTF-8 characters
                                // Start of character is 0xxxxxxx (ASCII) or 11xxxxxx (multi-byte)
                                // Continuation bytes are 10xxxxxx
                                unsigned char ubyte = (unsigned char)byte;
                                if ( (ubyte & 0xC0) != 0x80 ) {
                                    utf8_char_count++;
                                }
                            } else {
                                // SIZE mode: count raw bytes
                                bytes_read++;
                            }
                        }
                    }

                    if ( close_at_lf && byte == '\n' ) // TRUE || FALSE line
                        continue_read = 0;

                    else if ( count_to_read > -1 ) {
                        int is_chrsize = ( strcmp( reply_type, "CHRSIZE" ) == 0 );
                        int is_strm = ( strcmp( reply_type, "STRM" ) == 0 );

                        // Check if we've read enough based on response type
                        if ( is_strm ) {
                            // STRM mode: reset when bytes_read >= count_to_read (chunk complete)
                            // Continue reading for next STRM header
                            if ( bytes_read >= count_to_read ) {
                                count_to_read = -1;  /* Reset to header parsing mode */
                                bytes_read = 0;
                                output_bytes = 0;   /* Reset to parse next STRM header */
                                memset(reply_type, 0, sizeof(reply_type));
                                space_seen = 0;
                            }
                        } else if ( is_chrsize ) {
                            // CHRSIZE mode: stop when UTF-8 char_count >= count_to_read
                            if ( utf8_char_count >= count_to_read )
                                continue_read = 0;
                        } else {
                            // SIZE mode: stop when bytes_read >= count_to_read
                            if ( bytes_read >= count_to_read )
                                continue_read = 0;
                        }
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
