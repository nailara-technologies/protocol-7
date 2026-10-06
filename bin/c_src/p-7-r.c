
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
#include <sys/wait.h>
#include <fcntl.h>
#include <signal.h>

char *src_bmw_b32 = "[BMW_FILE_CHkSUM]";

#define P7_AUTH_HELPER "/data/projects/protocol-7/bin/p7-auth-keypair-helper.pl"
#define P7_LU_HELPER   "/data/projects/protocol-7/bin/p7-link-upgrade-helper.pl"

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

/* --- link-upgrade encrypted frame I/O ------------------------------------- */

/* read exactly n bytes [ blocking ] ; 0 ok, -1 error/closed */
static int read_full(int fd, void *buf, size_t n)
{
    size_t got = 0;
    while (got < n) {
        ssize_t r = recv(fd, (char *)buf + got, n - got, MSG_WAITALL);
        if (r < 1)
            return -1;
        got += (size_t)r;
    }
    return 0;
}

/* run a helper WITHOUT a shell [ fork + execv ] : argv holds public values
   only, secrets go in via the stdin pipe [ never argv, env or a file name ].
   stdout is collected into *out [ malloc'd, always non-NULL on success,
   caller frees ] ; returns the helper exit status, -1 when it could not
   run, was killed, or a pipe failed. the raw output is wiped on failure */
static int helper_exec(char *const argv[], const unsigned char *in,
                       size_t in_len, unsigned char **out, size_t *out_len)
{
    int to_child[2], from_child[2];
    *out = NULL;
    *out_len = 0;

    if (pipe2(to_child, O_CLOEXEC) < 0)
        return -1;
    if (pipe2(from_child, O_CLOEXEC) < 0) {
        close(to_child[0]);
        close(to_child[1]);
        return -1;
    }

    pid_t pid = fork();
    if (pid < 0) {
        close(to_child[0]);
        close(to_child[1]);
        close(from_child[0]);
        close(from_child[1]);
        return -1;
    }
    if (pid == 0) {
        /* child : stdin <- pipe, stdout -> pipe, stderr -> /dev/null ;
           dup2 clears O_CLOEXEC on 0 \ 1 \ 2, the rest closes on exec */
        int devnull = open("/dev/null", O_WRONLY | O_CLOEXEC);
        if (dup2(to_child[0], STDIN_FILENO) < 0 ||
            dup2(from_child[1], STDOUT_FILENO) < 0)
            _exit(127);
        if (devnull >= 0)
            dup2(devnull, STDERR_FILENO);
        signal(SIGPIPE, SIG_DFL);
        execv(argv[0], argv);
        _exit(127);
    }

    close(to_child[0]);
    close(from_child[1]);

    int ok = 1;
    size_t off = 0;
    while (off < in_len) {
        ssize_t w = write(to_child[1], in + off, in_len - off);
        if (w < 0 && errno == EINTR)
            continue;
        if (w < 1) {
            ok = 0;
            break;
        }
        off += (size_t)w;
    }
    close(to_child[1]);

    size_t cap = 4096, len = 0;
    unsigned char *buf = (unsigned char *)malloc(cap);
    if (buf == NULL)
        ok = 0;
    while (buf != NULL) {
        if (cap - len < 1024) {
            /* grow without leaving a stale copy behind [ no realloc ] */
            unsigned char *nb = (unsigned char *)malloc(cap * 2);
            if (nb == NULL) {
                ok = 0;
                break;
            }
            memcpy(nb, buf, len);
            explicit_bzero(buf, cap);
            free(buf);
            buf = nb;
            cap *= 2;
        }
        ssize_t r = read(from_child[0], buf + len, cap - len);
        if (r < 0 && errno == EINTR)
            continue;
        if (r < 0)
            ok = 0;
        if (r < 1)
            break;
        len += (size_t)r;
    }
    close(from_child[0]);

    int status = 0;
    while (waitpid(pid, &status, 0) < 0) {
        if (errno != EINTR) {
            ok = 0;
            break;
        }
    }
    if (!ok || !WIFEXITED(status)) {
        if (buf != NULL) {
            explicit_bzero(buf, cap);
            free(buf);
        }
        return -1;
    }
    *out = buf;
    *out_len = len;
    return WEXITSTATUS(status);
}

/* run p7-link-upgrade-helper.pl encrypt|decrypt on a buffer : stdin is
   "<key b32>\n" + data [ no temp file, the key never on argv ] ;
   returns malloc'd output */
static unsigned char *lu_crypt(const char *op, struct encryption_state *st,
                               const unsigned char *in, size_t in_len,
                               unsigned int counter, size_t *out_len)
{
    char sid[16], ctr[16];
    snprintf(sid, sizeof(sid), "%u", st->session_id);
    snprintf(ctr, sizeof(ctr), "%u", counter);
    /* nonce direction : this client encrypts client -> server [ 1 ],
       decrypts server -> client [ 2 ] - never the same nonce twice */
    char *dir = strcmp(op, "encrypt") == 0 ? "1" : "2";
    char *av[] = { P7_LU_HELPER, (char *)op, sid, ctr, dir, NULL };

    size_t klen = strlen(st->key);
    size_t stdin_len = klen + 1 + in_len;
    unsigned char *stdin_buf = (unsigned char *)malloc(stdin_len);
    if (stdin_buf == NULL)
        return NULL;
    memcpy(stdin_buf, st->key, klen);
    stdin_buf[klen] = '\n';
    memcpy(stdin_buf + klen + 1, in, in_len);

    unsigned char *out = NULL;
    size_t len = 0;
    int rc = helper_exec(av, stdin_buf, stdin_len, &out, &len);
    explicit_bzero(stdin_buf, stdin_len);
    free(stdin_buf);
    if (rc != 0) {          /* helper died [ e.g. auth tag mismatch ] */
        if (out != NULL) {
            explicit_bzero(out, len);
            free(out);
        }
        return NULL;
    }
    *out_len = len;
    return out;
}

/* encrypt one frame and send : pack('N',len) . ciphertext . tag */
static int lu_send_frame(int fd, struct encryption_state *st,
                         const unsigned char *data, size_t len)
{
    size_t ct_len = 0;
    unsigned char *ct = lu_crypt("encrypt", st, data, len,
                                 st->write_counter, &ct_len);
    if (!ct) {
        fprintf(stderr, "<< link-upgrade encrypt failed >>\n");
        return -1;
    }
    unsigned char hdr[4];
    hdr[0] = (unsigned char)((ct_len >> 24) & 0xFF);
    hdr[1] = (unsigned char)((ct_len >> 16) & 0xFF);
    hdr[2] = (unsigned char)((ct_len >> 8) & 0xFF);
    hdr[3] = (unsigned char)(ct_len & 0xFF);

    int ok = (write(fd, hdr, 4) == 4) &&
             (write(fd, ct, ct_len) == (ssize_t)ct_len);
    free(ct);
    if (!ok)
        return -1;
    st->write_counter++;
    return 0;
}

/* decrypted receive buffer [ frames are fed to the parser byte-wise ] */
static unsigned char *dec_buf = NULL;
static size_t dec_len = 0;
static size_t dec_pos = 0;

/* next plaintext byte from the encrypted link ; 1 byte, 0 closed, -1 error */
static ssize_t lu_read_byte(int fd, struct encryption_state *st, char *byte)
{
    while (dec_pos >= dec_len) {
        free(dec_buf);
        dec_buf = NULL;
        dec_len = dec_pos = 0;

        unsigned char hdr[4];
        if (read_full(fd, hdr, 4) < 0)
            return 0;   /* connection closed */

        unsigned int flen = ((unsigned int)hdr[0] << 24) |
                            ((unsigned int)hdr[1] << 16) |
                            ((unsigned int)hdr[2] << 8) |
                            (unsigned int)hdr[3];
        if (flen < 16 || flen > 16U * 1024U * 1024U) {
            fprintf(stderr, "<< invalid encrypted frame length %u >>\n", flen);
            return -1;
        }

        unsigned char *frame = (unsigned char *)malloc(flen);
        if (!frame)
            return -1;
        if (read_full(fd, frame, flen) < 0) {
            free(frame);
            return 0;
        }

        size_t plen = 0;
        dec_buf = lu_crypt("decrypt", st, frame, flen,
                           st->read_counter, &plen);
        free(frame);
        if (!dec_buf) {
            fprintf(stderr, "<< link-upgrade decrypt failed [ auth tag ] >>\n");
            return -1;
        }
        dec_len = plen;
        dec_pos = 0;
        st->read_counter++;
        /* empty frame [ keepalive ] : loop and read the next one */
    }
    *byte = (char)dec_buf[dec_pos++];
    return 1;
}

/* read one decrypted line [ used for post-upgrade textual replies ] */
static int lu_read_line(int fd, struct encryption_state *st,
                        char *buffer, size_t max_size)
{
    int pos = 0;
    char byte;
    while (pos < (int)max_size - 1) {
        if (lu_read_byte(fd, st, &byte) != 1)
            return -1;
        buffer[pos++] = byte;
        if (byte == '\n')
            break;
    }
    buffer[pos] = '\0';
    return pos;
}

/* --- wire v2 : auth-keypair + link-upgrade mutual binding ------------------
   [ data/md/design/AUTH-LINK-BINDING.md ] ; every helper argv value below
   is PUBLIC [ username, nonce, S_pub, ephemeral pubkeys, nonce_sid,
   encoding, host, port, signatures ] -- the client key is loaded by the
   helper itself */

#define B32_32_LEN  52   /* b32 [ no padding ] of 32 bytes */
#define B32_64_LEN 103   /* b32 [ no padding ] of 64 bytes */

/* binding context : what the select reply announced + who we are */
struct bind_ctx {
    const char *username;
    char s_pub[B32_32_LEN + 1];          /* pinned server identity key */
    char server_nonce[B32_32_LEN + 1];
};

/* strict b32 : RFC 4648 alphabet, exact length -- server supplied values
   end up on helper argv / the wire, nothing else may pass */
static int is_b32(const char *s, size_t len)
{
    if (s == NULL || strlen(s) != len)
        return 0;
    for (size_t i = 0; i < len; i++) {
        if (!((s[i] >= 'A' && s[i] <= 'Z') || (s[i] >= '2' && s[i] <= '7')))
            return 0;
    }
    return 1;
}

/* [A-Za-z0-9] plus the characters in extra, 1 .. max chars */
static int is_safe_token(const char *s, size_t max, const char *extra)
{
    size_t len = s ? strlen(s) : 0;
    if (len == 0 || len > max)
        return 0;
    for (size_t i = 0; i < len; i++) {
        char c = s[i];
        if (!((c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') ||
              (c >= '0' && c <= '9') || strchr(extra, c) != NULL))
            return 0;
    }
    return 1;
}

/* copy output line n [ 0 based ] of buf into line, without the newline */
static void helper_line(const unsigned char *buf, size_t len, int n,
                        char *line, size_t max)
{
    size_t pos = 0;
    line[0] = '\0';
    while (n > 0 && pos < len) {
        if (buf[pos++] == '\n')
            n--;
    }
    if (n > 0)
        return;
    size_t k = 0;
    while (pos < len && buf[pos] != '\n' && k + 1 < max)
        line[k++] = (char)buf[pos++];
    line[k] = '\0';
}

/* run a helper [ no shell ] with an optional secret on stdin, keep its
   first two output lines ; returns the helper exit status, -1 when it
   could not run or died. the raw output is wiped */
static int run_helper(char *const argv[], const char *secret_stdin,
                      char *line1, size_t n1, char *line2, size_t n2)
{
    unsigned char *out = NULL;
    size_t len = 0;
    int rc = helper_exec(argv, (const unsigned char *)secret_stdin,
                         secret_stdin ? strlen(secret_stdin) : 0,
                         &out, &len);
    if (line1 && n1)
        line1[0] = '\0';
    if (line2 && n2)
        line2[0] = '\0';
    if (out == NULL)
        return -1;
    if (line1 && n1)
        helper_line(out, len, 0, line1, n1);
    if (line2 && n2)
        helper_line(out, len, 1, line2, n2);
    explicit_bzero(out, len);
    free(out);
    return rc;
}

/* server key pin [ TOFU ] : ~/.n/remote-keys/servers/<host>_<port>.public
   0 ok [ matched or pinned now ], 5 strict + not pinned, 6 mismatch,
   -1 any other failure [ incl. unreadable pin file ] -- fail closed */
int check_server_pin(const char *remote_host, const char *remote_port,
                     const char *s_pub_b32, int verbose, int strict)
{
    char result_line[256];
    char *av[] = { P7_AUTH_HELPER, "check-pin", (char *)remote_host,
                   (char *)remote_port, (char *)s_pub_b32,
                   strict ? "strict" : NULL, NULL };
    int rc = run_helper(av, NULL, result_line, sizeof(result_line), NULL, 0);

    if (rc == 0 && strcmp(result_line, "PIN_VALID") == 0) {
        if (verbose)
            fprintf(stderr, ":: server key matches pin ::\n");
        return 0;
    }
    if (rc == 0 && strncmp(result_line, "PIN_NEW ", 8) == 0 &&
        is_b32(result_line + 8, B32_32_LEN)) {
        fprintf(stderr, ": pinned server key %s [ %s:%s ]\n",
                result_line + 8, remote_host, remote_port);
        return 0;
    }
    if (rc == 5 && strcmp(result_line, "PIN_UNPINNED") == 0) {
        fprintf(stderr, ":\n");
        fprintf(stderr, ": strict mode: server key not yet pinned\n");
        fprintf(stderr, ": connect once without -strict to pin: p-7-r %s:%s <command>\n",
                remote_host, remote_port);
        fprintf(stderr, ":\n");
        return 5;
    }
    if (rc == 6 && strcmp(result_line, "PIN_MISMATCH") == 0) {
        /* Always print MITM warning - security is more important than silence */
        fprintf(stderr, ":\n");
        fprintf(stderr, ": << SECURITY WARNING >> server key pin mismatch\n");
        fprintf(stderr, ": possible MITM attack - server pubkey does not match pinned key\n");
        fprintf(stderr, ": connection rejected [ pin is never replaced automatically ]\n");
        fprintf(stderr, ":\n");
        return 6;
    }
    fprintf(stderr, "<< server key pin check failed [ pin file unreadable or invalid ? ] >>\n");
    return -1;
}

/* Link-upgrade negotiation + mutual binding [ mandatory : an auth-keypair
   session is binding-pending until link-complete-ok verifies ] */
int negotiate_link_upgrade(int socket_fd, struct encryption_state *state,
                           const struct bind_ctx *ctx)
{
    static const char lu_ok[]   = "TRUE link-upgrade OK ";
    static const char lc_ok[]   = "link-complete-ok ";
    static const char encoding[] = "none";
    char cmd[1024];
    char server_pubkey[B32_32_LEN + 1] = {0};
    char client_pubkey[256] = {0};
    char client_secret[256] = {0};
    char shared_secret[256] = {0};
    char client_bind_sig[256] = {0};
    char verdict[64] = {0};
    char sid[16] = {0};
    char secret_in[256 + 2] = {0};   /* "<secret b32>\n" */
    char response_line[512] = {0};
    char confirm[512] = {0};
    int rc = -1;

    /* 1. Send link-upgrade init */
    if (write(socket_fd, "link-upgrade\n", 13) != 13) {
        fprintf(stderr, "<< link-upgrade : send failed >>\n");
        return -1;
    }

    /* 2. Read server response: "TRUE link-upgrade OK <server_eph b32>" */
    if (read_line(socket_fd, response_line, sizeof(response_line)) < 0) {
        fprintf(stderr, "<< link-upgrade : no reply >>\n");
        return -1;
    }
    strip_newline(response_line);
    if (strncmp(response_line, lu_ok, sizeof(lu_ok) - 1) != 0 ||
        !is_b32(response_line + sizeof(lu_ok) - 1, B32_32_LEN)) {
        fprintf(stderr, "<< link-upgrade : invalid server reply >>\n");
        return -1;
    }
    memcpy(server_pubkey, response_line + sizeof(lu_ok) - 1, B32_32_LEN);

    /* 3. Generate client ephemeral keypair via helper */
    char *av_eph[] = { P7_LU_HELPER, "gen-ephemeral", NULL };
    if (run_helper(av_eph, NULL, client_pubkey, sizeof(client_pubkey),
                   client_secret, sizeof(client_secret)) != 0 ||
        !is_b32(client_pubkey, B32_32_LEN) ||
        !is_b32(client_secret, B32_32_LEN)) {
        fprintf(stderr, "<< link-upgrade : ephemeral key generation failed >>\n");
        goto out;
    }

    /* 4. Send client pubkey */
    snprintf(cmd, sizeof(cmd), "link-pub-key %s\n", client_pubkey);
    if (write(socket_fd, cmd, strlen(cmd)) != (ssize_t)strlen(cmd)) {
        fprintf(stderr, "<< link-upgrade : send failed >>\n");
        goto out;
    }

    /* 5. Read readiness confirmation : exactly "SIZE 0" */
    if (read_line(socket_fd, confirm, sizeof(confirm)) < 0) {
        fprintf(stderr, "<< link-upgrade : no reply to link-pub-key >>\n");
        goto out;
    }
    strip_newline(confirm);
    if (strcmp(confirm, "SIZE 0") != 0) {
        fprintf(stderr, "<< link-upgrade : link-pub-key refused >>\n");
        goto out;
    }

    /* 6. Compute DH shared secret via helper [ secret on stdin ] */
    char *av_dh[] = { P7_LU_HELPER, "compute-dh", server_pubkey, NULL };
    snprintf(secret_in, sizeof(secret_in), "%s\n", client_secret);
    int dh_rc = run_helper(av_dh, secret_in, shared_secret,
                           sizeof(shared_secret), NULL, 0);
    explicit_bzero(secret_in, sizeof(secret_in));
    explicit_bzero(client_secret, sizeof(client_secret));
    if (dh_rc != 0 ||
        !is_b32(shared_secret, B32_32_LEN)) {
        fprintf(stderr, "<< link-upgrade : shared secret computation failed >>\n");
        goto out;
    }

    /* 7. Derive encryption key via helper ; nonce_sid 1 .. 2**32-1 */
    state->session_id = (unsigned int)time(NULL);
    if (state->session_id == 0)
        state->session_id = 1;
    snprintf(sid, sizeof(sid), "%u", state->session_id);
    char *av_kdf[] = { P7_LU_HELPER, "derive-key", sid, NULL };
    snprintf(secret_in, sizeof(secret_in), "%s\n", shared_secret);
    state->key = (char *)calloc(1, 256);
    int kdf_rc = state->key == NULL ? -1
        : run_helper(av_kdf, secret_in, state->key, 256, NULL, 0);
    explicit_bzero(secret_in, sizeof(secret_in));
    explicit_bzero(shared_secret, sizeof(shared_secret));
    if (kdf_rc != 0 || !is_b32(state->key, B32_32_LEN)) {
        fprintf(stderr, "<< link-upgrade : key derivation failed >>\n");
        goto out;
    }

    /* 8. Send encoding confirmation [ the transcript signs this string ] */
    snprintf(cmd, sizeof(cmd), "link-confirm-encoding %s\n", encoding);
    if (write(socket_fd, cmd, strlen(cmd)) != (ssize_t)strlen(cmd)) {
        fprintf(stderr, "<< link-upgrade : send failed >>\n");
        goto out;
    }
    if (read_line(socket_fd, confirm, sizeof(confirm)) < 0) {
        fprintf(stderr, "<< link-upgrade : no reply to link-confirm-encoding >>\n");
        goto out;
    }
    strip_newline(confirm);
    if (strcmp(confirm, "encoding-confirmed") != 0) {
        fprintf(stderr, "<< link-upgrade : encoding not confirmed >>\n");
        goto out;
    }

    /* 9. client_bind_sig over the binding transcript [ public fields only ] */
    char *av_bind[] = { P7_AUTH_HELPER, "gen-bind", (char *)ctx->username,
                        (char *)ctx->server_nonce, (char *)ctx->s_pub,
                        server_pubkey, client_pubkey, sid,
                        (char *)encoding, NULL };
    if (run_helper(av_bind, NULL, client_bind_sig, sizeof(client_bind_sig),
                   NULL, 0) != 0 ||
        !is_b32(client_bind_sig, B32_64_LEN)) {
        fprintf(stderr, "<< link-upgrade : client bind signature failed >>\n");
        goto out;
    }

    /* 10. link-complete <nonce_sid> <client_bind_sig> : the server derives
           the same key + nonces from nonce_sid, both ends must match */
    snprintf(cmd, sizeof(cmd), "link-complete %u %s\n",
             state->session_id, client_bind_sig);
    if (write(socket_fd, cmd, strlen(cmd)) != (ssize_t)strlen(cmd)) {
        fprintf(stderr, "<< link-upgrade : send failed >>\n");
        goto out;
    }

    /* 11. link-complete-ok <server_bind_sig> : verified against the PINNED
           S_pub before anything else is sent */
    if (read_line(socket_fd, confirm, sizeof(confirm)) < 0) {
        fprintf(stderr, "<< link-upgrade : no reply to link-complete >>\n");
        goto out;
    }
    strip_newline(confirm);
    if (strncmp(confirm, lc_ok, sizeof(lc_ok) - 1) != 0 ||
        !is_b32(confirm + sizeof(lc_ok) - 1, B32_64_LEN)) {
        fprintf(stderr, "<< link-upgrade : link-complete refused or malformed >>\n");
        goto out;
    }
    char *av_verify[] = { P7_AUTH_HELPER, "verify-bind",
                          confirm + sizeof(lc_ok) - 1, (char *)ctx->username,
                          (char *)ctx->server_nonce, (char *)ctx->s_pub,
                          server_pubkey, client_pubkey, sid,
                          (char *)encoding, NULL };
    if (run_helper(av_verify, NULL, verdict, sizeof(verdict), NULL, 0) != 0 ||
        strcmp(verdict, "BIND_OK") != 0) {
        fprintf(stderr, ":\n");
        fprintf(stderr, ": << SECURITY WARNING >> server bind signature invalid\n");
        fprintf(stderr, ": the peer did not prove the pinned server key for this link\n");
        fprintf(stderr, ": connection aborted\n");
        fprintf(stderr, ":\n");
        goto out;
    }

    state->read_counter = 0;
    state->write_counter = 0;
    rc = 0;

out:
    explicit_bzero(client_secret, sizeof(client_secret));
    explicit_bzero(shared_secret, sizeof(shared_secret));
    explicit_bzero(secret_in, sizeof(secret_in));
    if (rc != 0 && state->key != NULL) {
        explicit_bzero(state->key, 256);
        free(state->key);
        state->key = NULL;
    }
    return rc;
}

int main( int argc, char * argv[] ) {

    char * auth_str  = '\0';
    char * root_usr  = "root";    // fallback user
    int verbose = 0;  // verbose flag for debug output
    int strict = 0;   // strict mode: abort if key not already pinned

    int socket_fd;
    struct addrinfo hints, *result, *rp;
    char * remote_host = NULL;
    char * remote_port = NULL;

    /* a helper that exits early must not kill us via SIGPIPE on its
       stdin pipe : write() then fails and the caller fails closed */
    signal(SIGPIPE, SIG_IGN);

    char * p7_unix_user = secure_getenv("PROTOCOL_7_BIN_P7R_USER");

    if ( p7_unix_user == NULL )
        p7_unix_user = secure_getenv("USER");  // use regular unix user

    if ( p7_unix_user == NULL )
        p7_unix_user = secure_getenv("LOGNAME"); // next LOGNAME

    if ( p7_unix_user == NULL )
        p7_unix_user = root_usr; // try unix user root as a fallback user

    if ( argc < 3 ) {
        fprintf( stderr, "\n < usage : %s <hostname[:port]> <command> [args] >\n", argv[0] );
        fprintf( stderr, "   examples:\n" );
        fprintf( stderr, "     %s relay.internal list sessions\n", argv[0] );
        fprintf( stderr, "     %s compute-node.lan:47 v7-zenki.list zenki\n\n", argv[0] );
        exit(2);
    }

    for (int i = 1; i < argc; i++) {
        if (argv[i][0] == '-') {
           if (argv[i][1] == 'v' && argv[i][2] == '\0') {
                verbose = 1;
                /* Remove -v from argv by shifting */
                for (int j = i; j < argc - 1; j++)
                    argv[j] = argv[j + 1];
                argc--;
                i--;  // Recheck this position
           } else if (strncmp(argv[i], "-strict", 7) == 0 && argv[i][7] == '\0') {
                strict = 1;
                /* Remove -strict from argv by shifting */
                for (int j = i; j < argc - 1; j++)
                    argv[j] = argv[j + 1];
                argc--;
                i--;  // Recheck this position
           } else if (argv[i][1] == 'd') {
                if (argv[i][2] == 'q') // -dq == checksum only
                    printf( "%s\n", src_bmw_b32 );
                else
                    printf( ":\n: %s.c :. %s .:\n:\n", argv[0], src_bmw_b32 );
                return 0;
           } else {
                fprintf( stderr,
                  "\n  << option not valid >>  [ -v for verbose, -strict for strict mode, -d[q] for BMW checksum ]\n\n"
                );
                return 2;
           }
        }
    }

    /* options removed : hostname[:port] is argv[1] now */
    if ( argc < 3 ) {
        fprintf( stderr, "\n < usage : %s [-v] [-strict] <hostname[:port]> <command> [args] >\n\n", argv[0] );
        exit(2);
    }

    /* Parse hostname[:port] format */
    char * hostname_arg = argv[1];
    char * port_sep = strchr(hostname_arg, ':');

    if ( port_sep != NULL ) {
        /* Port specified in hostname:port format */
        remote_port = port_sep + 1;
        remote_host = (char *)malloc(port_sep - hostname_arg + 1);
        if ( remote_host == NULL ) {
            fprintf(stderr, "< malloc [hostname] > out of memory\n");
            exit(4);
        }
        strncpy(remote_host, hostname_arg, port_sep - hostname_arg);
        remote_host[port_sep - hostname_arg] = '\0';
    } else {
        /* No port specified, use default (from config or 42) */
        remote_host = hostname_arg;
        remote_port = "42";  /* Default port - would use config in full implementation */
    }

    /* these reach helper command lines : refuse anything but plain names */
    if ( ! is_safe_token(remote_host, 253, ".-") || remote_host[0] == '-' ||
         ! is_safe_token(remote_port, 5, "") || atoi(remote_port) < 1 ||
         atoi(remote_port) > 65535 ) {
        fprintf(stderr, "<< invalid hostname or port >>\n");
        exit(2);
    }
    if ( ! is_safe_token(p7_unix_user, 64, "._-") ||
         p7_unix_user[0] == '.' || p7_unix_user[0] == '-' ) {
        fprintf(stderr, "<< unix user name not usable for auth-keypair >>\n");
        exit(2);
    }

    /* auth-keypair credentials are built after the select reply : the
       v2 auth_sig covers the server nonce + the pinned server key */
    char c25519_pubkey[256] = {0};
    char ed25519_sig[256] = {0};

    /* prepare command string - skip hostname[:port] */
    int i;
    int arglen = 2;
    for ( i = 2; i < argc; ++i ) {
        arglen += strlen( argv[i] ) + 1;
    }
    char * cmd_str = (char *) malloc( sizeof(char) * arglen );
    if( cmd_str == NULL ) {
        fprintf( stderr, "< malloc [argv] > %s\n", strerror(errno) );
        exit(4);
    }

    strcpy( cmd_str, argv[2] );
    for ( i = 3; i < argc; ++i ) {
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
        /* close-on-exec : helper processes never inherit the link */
        socket_fd = socket(rp->ai_family, rp->ai_socktype | SOCK_CLOEXEC,
                           rp->ai_protocol);
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

    /* Read protocol banner first */
    char protocol_banner[512] = {0};
    if (read_line(socket_fd, protocol_banner, sizeof(protocol_banner)) < 0) {
        fprintf(stderr, "<< error reading protocol banner >>\n");
        return 4;
    }
    strip_newline(protocol_banner);

    /* Verify protocol banner matches expected format: \\PROTOCOL-7-VERSION\\<VERSION>\\ */
    if (strncmp(protocol_banner, "\\\\PROTOCOL-7-VERSION\\\\", 22) != 0) {
        fprintf(stderr, "<< protocol mismatch: %s >>\n", protocol_banner);
        return 4;
    }

    /* Two-stage authentication: select auth method, then TOFU validation, then credentials */

    /* Stage 1: Send auth method selection */
    if (write(socket_fd, "select auth-keypair\n", 20) < 0) {
        fprintf(stderr, "<< error sending auth method selection >>\n");
        return 4;
    }

    /* Stage 2: Read server response with pubkey announcement */
    char select_response[512] = {0};
    if (read_line(socket_fd, select_response, sizeof(select_response)) < 0) {
        fprintf(stderr, "<< error reading auth method response ::\n");
        return 4;
    }
    strip_newline(select_response);

    /* select reply v2 : exactly "TRUE <S_pub b32> <server_nonce b32>" ;
       anything else [ incl. a v1 reply without the nonce ] is refused */
    struct bind_ctx bctx;
    memset(&bctx, 0, sizeof(bctx));
    bctx.username = p7_unix_user;
    if (strncmp(select_response, "TRUE ", 5) != 0 ||
        strlen(select_response) != 5 + B32_32_LEN + 1 + B32_32_LEN ||
        select_response[5 + B32_32_LEN] != ' ') {
        fprintf(stderr, "<< select reply refused [ expected TRUE <server key> <nonce> ] >>\n");
        close(socket_fd);
        return 4;
    }
    memcpy(bctx.s_pub, select_response + 5, B32_32_LEN);
    memcpy(bctx.server_nonce, select_response + 6 + B32_32_LEN, B32_32_LEN);
    if (!is_b32(bctx.s_pub, B32_32_LEN) ||
        !is_b32(bctx.server_nonce, B32_32_LEN)) {
        fprintf(stderr, "<< select reply refused [ invalid server key or nonce ] >>\n");
        close(socket_fd);
        return 4;
    }

    /* Stage 3: server key pin check BEFORE the auth line is sent */
    if (verbose)
        fprintf(stderr, ":: checking server key pin ::\n");
    int tofu_result = check_server_pin(remote_host, remote_port, bctx.s_pub,
                                       verbose, strict);
    if (tofu_result != 0) {
        close(socket_fd);
        if (tofu_result == 5) {
            return 5;  /* Strict mode: key not yet pinned (recoverable) */
        } else if (tofu_result == 6) {
            return 6;  /* MITM/hijacking detected (serious) */
        } else {
            return 4;  /* pin check error */
        }
    }

    /* v2 auth credentials : C25519 session pubkey + auth_sig over
       [ label, server_nonce, S_pub, session_pub, username ] */
    char *av_auth[] = { P7_AUTH_HELPER, "gen-auth", p7_unix_user,
                        bctx.server_nonce, bctx.s_pub, NULL };
    if (run_helper(av_auth, NULL, c25519_pubkey, sizeof(c25519_pubkey),
                   ed25519_sig, sizeof(ed25519_sig)) != 0 ||
        !is_b32(c25519_pubkey, B32_32_LEN) ||
        !is_b32(ed25519_sig, B32_64_LEN)) {
        fprintf(stderr, "<< failed to build auth credentials [ user '%s' ] >>\n",
                p7_unix_user);
        close(socket_fd);
        return 4;
    }

    /* Stage 4: Send auth credentials after TOFU success */
    asprintf( &auth_str, "auth %s %s %s\n",
              p7_unix_user, c25519_pubkey, ed25519_sig );

    if (write(socket_fd, auth_str, strlen(auth_str)) < 0) {
        fprintf(stderr, "<< error sending auth credentials >>\n");
        return 4;
    }
    free(auth_str);

    /* Stage 5: Read auth response (expecting AUTH_TRUE or AUTH_ERROR) */
    char auth_response[256] = {0};
    if (read_line(socket_fd, auth_response, sizeof(auth_response)) < 0) {
        fprintf(stderr, "<< error reading auth response >>\n");
        return 4;
    }
    strip_newline(auth_response);

    if (strncmp(auth_response, "AUTH_TRUE", 9) != 0) {
        fprintf(stderr, "<< authentication not successful [ user '%s' ] >>\n", p7_unix_user);
        return 3;
    }

    /* Pre-declare byte and result_code for command response reading */
    char byte = ' ';
    int result_code = 0;

    /* Link-upgrade encryption + binding [ mandatory ] */
    struct encryption_state enc_state = {0, NULL, 0, 0, 0};

    /* Stream-locking state initialization */
    struct stream_state stream = {0, 0, 0, 0};
    stream.locking_enabled = 1;  /* p-7-r always uses locked mode for STRM safety */

    /* the session stays binding-pending [ unusable ] until the server
       proves the pinned key for THIS link : no plaintext fallback */
    if (negotiate_link_upgrade(socket_fd, &enc_state, &bctx) != 0) {
        fprintf(stderr, "<< link-upgrade binding failed : connection aborted >>\n");
        close(socket_fd);
        return 4;
    }
    if (verbose)
        fprintf(stderr, ":: link-upgrade encryption negotiated, server binding verified ::\n");
    enc_state.enabled = 1;

    /* Send select-strm-mode first and read its response */
    if ( enc_state.enabled ) {
        if ( lu_send_frame( socket_fd, &enc_state,
                            (unsigned char *)"select-strm-mode locked\n",
                            24 ) < 0 ) {
            fprintf(stderr, "error sending encrypted strm-mode request\n");
            close(socket_fd);
            return 4;
        }
    } else {
        write( socket_fd, "select-strm-mode locked\n", 24 );
    }

    /* Read select-strm-mode response - should be TRUE */
    char strm_response_line[256] = {0};
    int strm_read_ok = enc_state.enabled
        ? ( lu_read_line( socket_fd, &enc_state, strm_response_line,
                          sizeof(strm_response_line) ) > 0 )
        : ( read_line( socket_fd, strm_response_line,
                       sizeof(strm_response_line) ) > 0 );
    if ( ! strm_read_ok ) {
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

    /* send protocol-7 command string to socket [ encrypted when upgraded ] */
    if ( enc_state.enabled ) {
        if ( lu_send_frame( socket_fd, &enc_state, (unsigned char *)cmd_str,
                            strlen(cmd_str) ) < 0 ) {
            fprintf(stderr, "error sending encrypted command\n");
            free(cmd_str);
            close(socket_fd);
            return 4;
        }
    } else {
        write( socket_fd, cmd_str, strlen(cmd_str) );
    }
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
        /* byte source : decrypted frames when link-upgrade is active */
        if ( enc_state.enabled )
            result_code = lu_read_byte( socket_fd, &enc_state, &byte );
        else
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

                    int is_strm_response = ( strcmp( reply_type, "STRM" ) == 0 );

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

                    /* STRM protocol handling */
                    if ( is_strm_response && stream.locking_enabled ) {
                        size_t arg_len = strlen(strm_arg_buf);

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
                                /* Reset state to parse next STRM header fresh */
                                memset(reply_type, 0, sizeof(reply_type));
                                space_seen = 0;
                            } else if ( strcmp(strm_arg_buf, "open") == 0 ) {
                                /* Unbounded stream: no declared total */
                                stream.expected_bytes = -1;
                                stream.streaming = 1;
                                stream.received_bytes = 0;
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
                                continue_read = 0;
                            } else {
                                /* chunk_size for data packet */
                                count_to_read = atol(strm_arg_buf);
                                bytes_read = 0;
                                output_bytes = 1;
                                skip_this_one = 1;
                            }

                            reading_strm_arg = 0;
                            memset(strm_arg_buf, 0, sizeof(strm_arg_buf));
                        } else {
                            strm_arg_buf[arg_len] = byte;
                        }
                    }
                }

                if ( continue_read && output_bytes ) {

                    if ( skip_this_one )
                        skip_this_one = 0;
                    else {
                        /*  writing payload-data to stdout  */
                        write( STDOUT_FILENO, &byte, result_code );

                        // Handle SIZE (byte-based), CHRSIZE (character-based), and STRM (byte-based) modes
                        if ( count_to_read > -1 ) {
                            int is_chrsize = ( strcmp( reply_type, "CHRSIZE" ) == 0 );
                            int is_strm = ( strcmp( reply_type, "STRM" ) == 0 );

                            if ( is_chrsize ) {
                                // CHRSIZE mode: count UTF-8 characters
                                // Start of character is 0xxxxxxx (ASCII) or 11xxxxxx (multi-byte)
                                // Continuation bytes are 10xxxxxx
                                unsigned char ubyte = (unsigned char)byte;
                                if ( (ubyte & 0xC0) != 0x80 ) {
                                    utf8_char_count++;
                                }
                            } else {
                                // SIZE mode and STRM mode: count raw bytes
                                bytes_read++;
                                if ( is_strm ) {
                                    // STRM mode: also track in stream state
                                    stream.received_bytes++;
                                }
                            }
                        }
                    }

                    if ( close_at_lf && byte == '\n' ) // TRUE || FALSE line
                        continue_read = 0;

                    else if ( count_to_read > -1 ) {
                        int is_chrsize = ( strcmp( reply_type, "CHRSIZE" ) == 0 );
                        int is_strm = ( strcmp( reply_type, "STRM" ) == 0 );

                        // Check if we've read enough based on response type
                        if ( is_chrsize ) {
                            // CHRSIZE mode: stop when UTF-8 char_count >= count_to_read
                            if ( utf8_char_count >= count_to_read )
                                continue_read = 0;
                        } else {
                            // SIZE mode and STRM mode: stop when bytes_read >= count_to_read
                            if ( bytes_read >= count_to_read ) {
                                if ( is_strm ) {
                                    // STRM mode: reset parsing state for next STRM header
                                    count_to_read = -1;
                                    bytes_read = 0;
                                    output_bytes = 0;
                                    memset(reply_type, 0, sizeof(reply_type));
                                    space_seen = 0;
                                } else {
                                    // SIZE mode: normal completion
                                    continue_read = 0;
                                }
                            }
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
