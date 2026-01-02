
#define _GNU_SOURCE

#include <sys/socket.h>
#include <netdb.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <errno.h>
#include <time.h>
#include <string.h>
#include <netinet/in.h>

char *src_bmw_b32 = "[BMW_FILE_CHkSUM]";

/* Link-upgrade encryption state */
struct encryption_state {
    int enabled;
    char *key;
    unsigned int session_id;
    unsigned int read_counter;
    unsigned int write_counter;
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

    int socket_fd;
    struct addrinfo hints, *result, *rp;
    char * remote_host = NULL;
    char * remote_port = NULL;

    char * p7_unix_user = secure_getenv("PROTOCOL_7_BIN_P7R_USER");

    if ( p7_unix_user == NULL )
        p7_unix_user = secure_getenv("USER");  // use regular unix user

    if ( p7_unix_user == NULL )
        p7_unix_user = secure_getenv("LOGNAME"); // next LOGNAME

    if ( p7_unix_user == NULL )
        p7_unix_user = root_usr; // try unix user root as a fallback user

    if ( argc < 3 ) {
        fprintf( stderr, "\n < usage : %s <hostname> <port|command> [args] >\n", argv[0] );
        fprintf( stderr, "   examples:\n" );
        fprintf( stderr, "     %s relay.internal 42 list sessions\n", argv[0] );
        fprintf( stderr, "     %s compute-node.lan 171 v7.list zenki\n\n", argv[0] );
        exit(2);
    }

    remote_host = argv[1];
    remote_port = argv[2];

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

    /* prepare authentication - use auth-keypair for remote connections */
    asprintf( &auth_str, "select auth-keypair\nauth %s\n", p7_unix_user );

    /* prepare command string - skip hostname and port */
    int i;
    int arglen = 2;
    for ( i = 3; i < argc; ++i ) {
        arglen += strlen( argv[i] ) + 1;
    }
    char * cmd_str = (char *) malloc( sizeof(char) * arglen );
    if( cmd_str == NULL ) {
        fprintf( stderr, "< malloc [argv] > %s\n", strerror(errno) );
        exit(4);
    }

    strcpy( cmd_str, argv[3] );
    for ( i = 4; i < argc; ++i ) {
        strcat( cmd_str, " " );
        strcat( cmd_str, argv[i] );
    }
    strcat( cmd_str, "\n" );

    /* Connect to remote server via TCP */
    memset(&hints, 0, sizeof(struct addrinfo));
    hints.ai_family = AF_UNSPEC;      /* Allow IPv4 or IPv6 */
    hints.ai_socktype = SOCK_STREAM;  /* TCP */
    hints.ai_flags = 0;
    hints.ai_protocol = 0;            /* Any protocol */

    int gai_err = getaddrinfo(remote_host, remote_port, &hints, &result);
    if (gai_err != 0) {
        fprintf(stderr, "<< getaddrinfo error : %s >>\n", gai_strerror(gai_err));
        return 3;
    }

    /* Try each address until we successfully connect */
    for (rp = result; rp != NULL; rp = rp->ai_next) {
        socket_fd = socket(rp->ai_family, rp->ai_socktype, rp->ai_protocol);
        if (socket_fd == -1)
            continue;

        if (connect(socket_fd, rp->ai_addr, rp->ai_addrlen) != -1)
            break;  /* Success */

        close(socket_fd);
    }

    freeaddrinfo(result);

    if (rp == NULL) {
        fprintf(stderr, "<< connection not successful : %s:%s >>\n",
                remote_host, remote_port);
        return 3;
    }

    /* authenticate to remote protocol-7 server */
    write( socket_fd, auth_str, strlen(auth_str) );
    unsigned int line = 0;
    int result_code;
    char byte = ' ';
    while ( line <= 2 ) {   // 3 lines expected

        result_code = recv( socket_fd, &byte, 1, 0 );

        if ( result_code < 0 ) {
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
    char *link_upgrade_env = secure_getenv("PROTOCOL_7_LINK_UPGRADE");
    if (link_upgrade_env && strcmp(link_upgrade_env, "yes") == 0) {
        if (negotiate_link_upgrade(socket_fd, &enc_state) == 0) {
            fprintf(stderr, ":: link-upgrade encryption negotiated ::\n");
            enc_state.enabled = 1;
        } else {
            fprintf(stderr, ":: link-upgrade negotiation failed, continuing plaintext\n");
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
    long count_to_read = -1;    // Byte count (SIZE mode) or char count (CHRSIZE mode)
    int space_seen = 0;
    int utf8_char_count = 0;    // Track UTF-8 characters read (CHRSIZE mode only)
    int bytes_read = 0;         // Track raw bytes read
    while ( continue_read ) {
        result_code = recv( socket_fd, &byte, 1, MSG_WAITALL );
        if ( result_code < 1 ) {
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

                    int is_size_response = ( strcmp( reply_type, "SIZE" ) == 0 ||
                                             strcmp( reply_type, "CHRSIZE" ) == 0 );

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
                        write( STDOUT_FILENO, &byte, result_code );

                        // Handle both SIZE (byte-based) and CHRSIZE (character-based) modes
                        if ( count_to_read > -1 ) {
                            int is_chrsize = ( strcmp( reply_type, "CHRSIZE" ) == 0 );

                            if ( is_chrsize ) {
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

                        // Check if we've read enough based on response type
                        if ( is_chrsize ) {
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
