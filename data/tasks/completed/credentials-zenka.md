## [:< ##

# name  = task: credentials zenka — secure site credential storage and selective zenka authorization
# descr = encrypted credential store with per-zenka authorization tokens;
#         first use case: jobsite zenka gets authorized stepstone session

## kimi memory

if in doubt about P7 patterns, coding style, or project context — read first:
```bash
cat data/ai-mem/kimi/MEMORY.md
cat data/ai-mem/kimi/coding-style.md
cat data/ai-mem/kimi/topic-zenki-creation-guide.md
```

## context

zenki need authenticated access to external services:
- jobsite zenka: stepstone/xing/linkedin login sessions
- smtp zenka: mail account credentials
- future: any web service requiring login

the pattern is NOT "give zenka the password". it is:
- credentials zenka holds all secrets encrypted at rest
- requesting zenka presents identity (cube-authenticated session)
- credentials zenka decides whether to authorize that zenka for that credential
- authorization grants a session token or live session, not the raw credential
- full audit trail: which zenka accessed which credential and when

this is analogous to OAuth from a P7 perspective: credentials zenka is the
authorization server, other zenki are clients, cube authentication is the
identity layer.

## signatures note

do not add signature stubs. do not run `bin/Protocol-7 sourcecode update-signatures`.
do not add or modify subroutine whitelists — these are managed separately.

---

## architecture

```
jobsite zenka → credentials.cmd.request_session 'stepstone'
                        ↓ (cube injects zenka identity via source_zenka)
credentials zenka checks: is 'jobsite' authorized for 'stepstone'?
                        ↓ yes
              spawns headless browser session with stepstone login
                        ↓
              returns: session_token OR live_session_handle
                        ↓
jobsite zenka uses session to: search jobs, apply, check status
```

---

## credential storage

### encryption

credentials stored encrypted at rest using the existing C25519/Twofish stack.
each credential entry encrypted with the system key + a per-entry nonce.

storage: `/var/protocol-7/credentials/` (root-only readable directory)

```yaml
## /var/protocol-7/credentials/stepstone.yaml (encrypted)
name:     stepstone
url:      https://www.stepstone.de
username: jobs@yourdomain.com
password: <encrypted>
type:     web-session         ## web-session | api-key | smtp | imap
notes:    job application portal
authorized_zenki:
  - jobsite
  - smtp
```

### credential types

| type | storage | access method |
|---|---|---|
| `web-session` | username+password | headless browser session spawn |
| `api-key` | key string | direct key provision to authorized zenka |
| `smtp` | host+user+password | SMTP client session |
| `imap` | host+user+password | IMAP client session |
| `ssh-key` | key path | key forwarding to authorized zenka |

---

## modules to implement

### credentials.init_code

```perl
<credentials.cfg.store_dir>   //= '/var/protocol-7/credentials/';
<credentials.cfg.session_ttl> //= 3600;   ## session token TTL in seconds
<credentials.cfg.audit_log>   //= '/var/protocol-7/credentials/audit.log';
```

### credentials.cmd.request_session

**add to cube command_aliases source_zenka list** — cube injects requesting
zenka's name so credentials zenka knows who is asking.

```perl
my $call         = shift;
my $cred_name    = $call->{'args'};
my $zenka_name   = $call->{'zenka_name'};   ## injected by cube via source_zenka

## load credential entry
my $cred = <[credentials.load]>->($cred_name);
return { 'mode' => 'false', 'data' => "unknown credential '$cred_name'" }
    unless defined $cred;

## check authorization
my @authorized = @{ $cred->{'authorized_zenki'} // [] };
unless ( grep { $ARG eq $zenka_name } @authorized ) {
    <[credentials.audit]>->( $zenka_name, $cred_name, 'DENIED' );
    return { 'mode' => 'false', 'data' => 'not authorized' };
}

<[credentials.audit]>->( $zenka_name, $cred_name, 'GRANTED' );

## provision access based on type
if ( $cred->{'type'} eq 'web-session' ) {
    return <[credentials.spawn_web_session]>->( $cred, $zenka_name );
} elsif ( $cred->{'type'} eq 'api-key' ) {
    return { 'mode' => 'true', 'data' => $cred->{'key'} };
} elsif ( $cred->{'type'} =~ m|^(smtp|imap)$| ) {
    return { 'mode' => 'true', 'data' => {
        'host' => $cred->{'host'},
        'user' => $cred->{'username'},
        'pass' => $cred->{'password'},   ## decrypted in-memory only
    }};
}
```

### credentials.spawn_web_session

for `web-session` type: spawns a headless web-browser session pre-authenticated
with the credential. returns a session handle (either a session token or a
reference to a running browser zenka instance).

two modes:
1. **token mode**: logs in, extracts session cookie/token, returns it
   requesting zenka uses token directly in HTTP calls
2. **proxy mode**: keeps browser session alive, requesting zenka routes
   navigation commands through it

start with token mode — simpler, sufficient for jobsite automation.

```perl
## spawn a temporary web-browser instance for login
## use the existing web-browser zenka with on-demand mode
## load login URL → fill credentials → extract session cookie

my $cred    = shift;
my $for     = shift;

## use site-yaml or a login-specific module to handle the login flow
## each site may need a custom login handler
my $handler = <[credentials.login_handler]>->( $cred->{'url'} );

my $session_token = $handler->( $cred->{'username'}, $cred->{'password'} );

## store session with TTL
my $token_id = <[base.gen_id]>->({});
<credentials.session>->{$token_id} = {
    'cred'    => $cred->{'name'},
    'zenka'   => $for,
    'token'   => $session_token,
    'expires' => time + <credentials.cfg.session_ttl>,
};

return { 'mode' => 'true', 'data' => $token_id };
```

### credentials.cmd.add

interactive command to add a new credential (prompts for password, never logged):

```bash
p7c credentials.cmd.add 'stepstone https://stepstone.de jobs@example.com web-session jobsite'
## prompts for password via nshell, encrypts, stores
```

### credentials.cmd.list

lists credential names and their authorized zenki (never shows passwords):

```bash
p7c credentials.cmd.list
## stepstone  [web-session]  → jobsite, smtp
## protonmail [imap]         → smtp
```

### credentials.cmd.authorize

adds a zenka to a credential's authorized list:

```bash
p7c credentials.cmd.authorize 'stepstone jobsite'
```

### credentials.audit

appends to audit log with timestamp, zenka, credential, decision:
```
2026-05-20T14:23:11  jobsite  stepstone  GRANTED
2026-05-20T14:23:45  kimi     stepstone  DENIED
```

---

## cube command_aliases addition

file: `configuration/zenki/cube/command_aliases`

add to `source_zenka` list:
```
credentials.cmd.request_session
credentials.cmd.authorize
```

cube injects the requesting zenka's name — credentials zenka gets cube-verified
identity of who is asking, cannot be spoofed by the requesting zenka.

---

## jobsite integration

### jobsite.cmd.apply_to_job (updated)

when jobsite zenka needs to apply to a job requiring login:

```perl
## request stepstone session from credentials zenka
my $reply = <[base.X-11.wait_for_window]>;   ## wrong - use route-send pattern
## correct:
my $session = <[base.protocol-7.command.send.local]>->(
    'credentials', "credentials.cmd.request_session stepstone\n"
);

## use session token in subsequent HTTP calls to stepstone
```

---

## temporary address management

mail addresses can be generated per-account and stored as credentials:

```yaml
name:     stepstone-mail
type:     address-alias
address:  stepstone-7kx9@mail.yourdomain.com
maps_to:  jobs@yourdomain.com
notes:    temporary address for stepstone registration
```

smtp zenka routing table maps `stepstone-7kx9` → jobsite zenka automatically.
when an account is closed, the alias is removed — mail to it is silently dropped.

---

## test sequence

```bash
## add stepstone credential (interactive)
p7c credentials.cmd.add 'stepstone https://stepstone.de jobs@example.com web-session jobsite'

## list credentials
p7c credentials.cmd.list

## jobsite zenka requests session (should succeed — authorized)
p7c jobsite.cmd.test_credentials stepstone

## attempt from unauthorized zenka (should be denied and logged)
p7c kimi.test_credentials stepstone   ## if such a test command exists

## check audit log
tail /var/protocol-7/credentials/audit.log
```

## success criteria

- [ ] credentials stored encrypted at rest in cfg.store_dir
- [ ] `credentials.cmd.add` stores credential without logging password
- [ ] `credentials.cmd.request_session` checks authorized_zenki via cube identity
- [ ] unauthorized request returns 'not authorized' and logs DENIED
- [ ] authorized request for api-key returns key directly
- [ ] authorized request for web-session spawns login, returns session token
- [ ] audit log records every access attempt with zenka identity and decision
- [ ] `credentials.cmd.list` shows names and authorized zenki, never passwords
- [ ] cube command_aliases updated so source_zenka injects caller identity
- [ ] no signature stubs added, no subroutine whitelist changes made

#,,..,,,.,,..,.,.,...,.,,,,..,...,,,,,,,,,,..,..,,...,...,..,,,,.,..,,,.,,...,
#4EQ4C3X7MZFALDQ3I3ZVU7AVYOAIL4UTJOJ75QHM5BZCMWOR57ZRNVKOBYNPBTDPPLO2QFSA4UJ5K
#\\\|WMMC43IC2NNK5MLT65Q3Q4ZWCW7RZHAHVRWKMRWUQN6CA662WWS \ / AMOS7 \ YOURUM ::
#\[7]SWSYFJUR2JQ3EYH2CGEBDPUEDJYK7HEMAUN2OWIWCADNY26UQ4BA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
