## [:< ##

# name  = task: smtpd zenka — P7-native mail receive, YAML conversion and routing
# descr = receive mail → parse → YAML + LLM summarize/classify → route to zenki.
#         raw email is forensics-only. zenki work exclusively with structured YAML.

## kimi memory

if in doubt about P7 patterns, coding style, or project context — read first:
```bash
cat data/ai-mem/kimi/MEMORY.md
cat data/ai-mem/kimi/coding-style.md
cat data/ai-mem/kimi/topic-zenki-creation-guide.md
```

## context

protocol-7 needs mail integration for:
- jobsite zenka: receive replies to sent applications, track status, trigger tasks
- future: all personal mail, temporary addresses, send capability, interview scheduling

this is NOT a classic MTA replacement. it is a P7-style adapter to mail:
- postfix remains as-is for delivery infrastructure
- smtpd zenka receives specific addresses via postfix pipe or local delivery
- mail is parsed into structured P7 data and routed to zenki via cube
- zenki gain authenticated mail access through P7 routing, not direct IMAP/SMTP

**first use case**: `jobs@<configured-domain>` → smtpd zenka → jobsite zenka
- incoming mail: application replies, status updates, interview requests
- jobsite zenka correlates by subject/thread-id with sent application records
- propagates notifications, triggers reply-required tasks

**postfix integration** (no postfix replacement needed):
```
# /etc/postfix/virtual or .forward equivalent
jobs@domain    |/path/to/p7-mail-inject
```
`p7-mail-inject`: thin script, reads mail from STDIN, sends to smtpd zenka via p7c.
postfix continues handling all other mail normally.

## signatures note

do not add signature stubs. do not run `bin/Protocol-7 sourcecode update-signatures`.
do not add or modify subroutine whitelists — these are managed separately.

---

## architecture

```
postfix → local delivery pipe → p7-mail-inject (thin script)
                                      ↓
                              smtpd.cmd.inject
                                  │
                                  ├─ Email::MIME parse → YAML struct
                                  ├─ LLM classify: intent/action/sentiment
                                  ├─ archive raw .eml (forensics only)
                                  └─ store .yaml (this is what zenki see)
                                      ↓
                              smtpd.route (matches To: → target zenka)
                                      ↓
                         routed to: jobsite.cmd.mail_received  (YAML)
                                    notify.message
                                    mail.store
```

raw email is never the working format. every zenka receives the YAML struct.
the `.eml` file exists at `raw_path` only — accessible for forensics, never
part of the normal processing flow.

## YAML message format

```yaml
## written to /var/protocol-7/mail/YYYY/MM/DD/<msg-id-hash>.yaml
message_id:      <abc123@domain>
from:            Stepstone GmbH <noreply@stepstone.de>
to:              jobs@yourdomain.com
subject:         Re: Your application for Senior Engineer
date:            2026-05-20T14:23:11Z
thread_id:       <original-msgid@yourdomain.com>   ## In-Reply-To or References
received_at:     2026-05-20T14:23:15Z              ## when smtpd zenka processed it

## LLM-generated classification (one small local model call at inject time)
summary:         Invitation to a 45-minute video interview next week
intent:          interview_request   ## reply|rejection|interview_request|offer
                                     ## document_request|information|spam|other
sentiment:       positive
action_required: true
action_type:     schedule_interview  ## schedule_interview|upload_cv|reply|
                                     ## none|review
urgency:         high                ## high|normal|low

## content (body_text kept for context; html omitted once summarized)
body_text:       |
  Dear applicant, we would like to invite you...

## attachments (never the raw bytes — just metadata + summary)
attachments:
  - filename:    Interview_Details.pdf
    content_type: application/pdf
    size:        18240
    summary:     Interview format overview and two technical questions

## forensics pointer — raw RFC 2822, never opened in normal flow
raw_path:        /var/protocol-7/mail/2026/05/20/abc123def456.eml
```

the three fields driving downstream behavior: `intent`, `action_required`,
`action_type`. jobsite zenka reads these directly — no body parsing needed.
```

---

## modules to implement

### smtpd.init_code

```
cfg.store_dir    = /var/protocol-7/mail/
cfg.archive_days = 90         ## keep mail for N days
cfg.route.*      = ...        ## address → zenka routing table (from startup config)
```

routing table example in zenka-startup.v7:
```
smtpd.route.jobs = jobsite
smtpd.route.*    = mail.store   ## default: archive only
```

### smtpd.cmd.inject

receives raw mail (RFC 2822) from `p7-mail-inject` script.
parses into structured hash and routes.

```perl
## parse raw mail
my $raw = $call->{'args'};   ## base32r-encoded to avoid framing issues

use Email::MIME;
my $email = Email::MIME->new( decode_b32r($raw) );

my $parsed = {
    'message_id' => $email->header('Message-ID'),
    'from'       => $email->header('From'),
    'to'         => $email->header('To'),
    'subject'    => $email->header('Subject'),
    'date'       => $email->header('Date'),
    'in_reply_to'=> $email->header('In-Reply-To'),
    'references' => $email->header('References'),
    'body_text'  => '',   ## plaintext body
    'body_html'  => '',   ## html body (if present)
    'attachments'=> [],   ## list of { filename, content_type, size }
    'raw_path'   => '',   ## path where raw mail is archived
};

## extract body parts
for my $part ( $email->subparts ) {
    my $ct = $part->content_type;
    if ( $ct =~ m|text/plain|i ) {
        $parsed->{'body_text'} = $part->body_str;
    } elsif ( $ct =~ m|text/html|i ) {
        $parsed->{'body_html'} = $part->body_str;
    } elsif ( $part->filename ) {
        push @{$parsed->{'attachments'}}, {
            'filename'     => $part->filename,
            'content_type' => $ct,
            'size'         => length( $part->body ),
        };
    }
}
```

### smtpd.route

matches the To: address against `cfg.route.*` table, dispatches to target zenka.

```perl
my $parsed  = shift;
my $to_addr = $parsed->{'to'};

## extract local part of address
( my $local = lc $to_addr ) =~ s|<([^>]+)>|$1|;
$local =~ s|@.*$||;

## match routing table
my $target_zenka = <smtpd.cfg.route>->{$local}
    // <smtpd.cfg.route>->{'*'}
    // 'mail.store';

## always archive
<[smtpd.archive]>->($parsed);

## route to target zenka
<[base.protocol-7.command.send.local]>->(
    $target_zenka,
    sprintf( "%s.mail_received %s\n",
        $target_zenka,
        encode_b32r( encode_json($parsed) )
    )
);
```

### smtpd.classify

calls a local LLM (via coding zenka tool or direct llm.service call) to
classify the parsed mail. runs after MIME parsing, before routing.

```perl
my $parsed  = shift;

## build classification prompt
my $prompt = sprintf(
    "classify this email. respond with YAML only, no explanation.\n\n"
  . "from: %s\nsubject: %s\nbody:\n%s\n\n"
  . "fields: summary (1 sentence), intent, sentiment, "
  . "action_required (true/false), action_type, urgency",
    $parsed->{'from'},
    $parsed->{'subject'},
    substr( $parsed->{'body_text'}, 0, 800 )  ## truncate for small model
);

## use coding zenka submit (async is fine — we wait for result here)
## or llm.service.call if direct access available
my $result = <[llm.service.classify]>->({ prompt => $prompt });

## parse YAML response, merge into $parsed
if ( defined $result ) {
    my $classification = YAML::Load($result);
    $parsed->{$_} = $classification->{$_}
        for qw| summary intent sentiment action_required action_type urgency |;
}

## defaults if LLM unavailable
$parsed->{'intent'}          //= 'information';
$parsed->{'action_required'} //= 0;
$parsed->{'action_type'}     //= 'none';
$parsed->{'urgency'}         //= 'normal';
$parsed->{'summary'}         //= $parsed->{'subject'};
```

note: LLM call is optional — if llm.service is offline, defaults apply and
mail is still routed. classification can be re-run later via `smtpd.cmd.reclassify`.

### smtpd.archive

stores raw mail and YAML struct to `cfg.store_dir`:
```
/var/protocol-7/mail/
  YYYY/MM/DD/
    <message-id-hash>.yaml         ## structured YAML — what zenki work with
    <message-id-hash>.eml.xz.enc  ## raw RFC 2822: xz compressed + twofish
                                   ## encrypted targeting cfg.archive_key
                                   ## forensics only — requires C25519 private key
```

the `.eml.xz.enc` is write-once, root-readable only. accessing raw content
requires the C25519 private key configured in `cfg.archive_key`.
the `.yaml` is the working copy — unencrypted, what all zenki use.

### raw mail encryption in smtpd.archive

```perl
use Compress::Raw::Lzma;
use AMOS7::Twofish;

## 1. xz compress
my ( $lzma ) = Compress::Raw::Lzma::EasyCompress->new;
my $compressed = '';
$lzma->code( $raw_mail, $compressed );
$lzma->flush($compressed);

## 2. twofish encrypt targeting configured C25519 public key
my $archive_key = <smtpd.cfg.archive_key>;   ## key name e.g. 'taeki'
my $encrypted   = <[crypt.C25519.encrypt_for_key]>->( \$compressed, $archive_key );

## 3. store encrypted blob — write-once, 0600
my $enc_path = "$store_path.eml.xz.enc";
<[file.write_bin]>->( $enc_path, $$encrypted );
chmod 0600, $enc_path;

## fallback: if key unavailable, store unencrypted with warning
## better to keep data than silently lose it
if ( not defined $encrypted ) {
    <[base.log]>->( 0, "archive key '$archive_key' unavailable — storing unencrypted" );
    <[file.write_bin]>->( "$store_path.eml.xz", $compressed );
}
```

### cfg for encryption

```
smtpd.cfg.archive_key       = taeki   ## C25519 key name for twofish encryption
smtpd.cfg.encrypt_raw       = yes     ## encrypt raw mail (default yes)
smtpd.cfg.compress_raw      = yes     ## xz compress before encrypt (default yes)
```

if `cfg.archive_key` points to an existing key in the keys zenka, all raw
mail is compressed + encrypted. hardware seizure reveals only YAML summaries,
not raw communication content.

### smtpd.cmd.list

lists recent mail with optional address/subject filter:
```bash
p7c smtpd.cmd.list 'jobs'       ## filter by local address part
p7c smtpd.cmd.list              ## recent 20 messages
```

### smtpd.cmd.get

retrieves full parsed mail by message-id or archive path:
```bash
p7c smtpd.cmd.get '<msgid@domain>'
```

### smtpd.cmd.set_route

runtime routing table update:
```bash
p7c smtpd.cmd.set_route 'jobs jobsite'
p7c smtpd.cmd.set_route 'noreply mail.store'
```

---

## jobsite zenka integration

### jobsite.cmd.mail_received

new module in the jobsite zenka. receives parsed mail from smtpd zenka.

```perl
my $call   = shift;
my $parsed = decode_json( decode_b32r( $call->{'args'} ) );

## correlate with sent applications via In-Reply-To / References headers
## or Subject: line pattern matching against known application subjects

my $thread_id  = $parsed->{'in_reply_to'} // $parsed->{'references'};
my $subject    = $parsed->{'subject'} // '';

## look up matching application task
## update task status based on content:
##   'interview' in subject → schedule interview task
##   'rejection' pattern    → mark application as rejected
##   'offer'     pattern    → high-priority notification
##   otherwise             → reply-required notification

## send notification via notify zenka
<[base.protocol-7.command.send.local]>->(
    'notify',
    sprintf( "notify.message job reply: %s\n",
        encode_b32r( $parsed->{'subject'} ) )
);
```

---

## bin/p7-mail-inject

thin script: reads raw mail from STDIN, sends to smtpd zenka via p7c.

```perl
#!/usr/bin/perl
use strict;
use Crypt::Misc qw| encode_b32r |;
use Encode qw| encode_utf8 |;

local $/;
my $raw = <STDIN>;
my $encoded = encode_b32r( encode_utf8($raw) );

exec "p7c smtpd.cmd.inject '$encoded'";
```

---

## configuration

```
## configuration/zenki/smtpd/zenka-startup.v7

start.on-demand       = 1
restart.disabled      = 1
heartbeat.disabled    = 1

smtpd.cfg.store_dir    = /var/protocol-7/mail/
smtpd.cfg.archive_days = 90

## routing: local-part of To: address → target zenka
smtpd.cfg.route.jobs   = jobsite
smtpd.cfg.route.*      = mail.store
```

## postfix configuration note

to pipe specific address to smtpd zenka, add to postfix virtual aliases or
use a `.forward` file for the system user that receives the mail:

```
# /etc/postfix/virtual
jobs@yourdomain.com    smtp-inject@localhost

# /etc/aliases or .forward for smtp-inject user
smtp-inject: "|/usr/local/bin/p7-mail-inject"
```

or simpler with postfix transport:
```
# /etc/postfix/transport
jobs@yourdomain.com    smtp-inject:
```

---

## perl dependencies

`Email::MIME` — parse RFC 2822 mail including multipart, attachments, encoding.
check if installed: `perl -e 'use Email::MIME; print "ok\n"'`
install if needed: add to dependencies script.

---

## test sequence

```bash
## inject a test mail directly
echo "From: test@example.com
To: jobs@yourdomain.com
Subject: Re: Application for Software Engineer
Message-ID: <test123@example.com>
In-Reply-To: <sent456@yourdomain.com>

Thank you for your application. We would like to invite you for an interview.
" | bin/p7-mail-inject

## verify: smtpd zenka received and archived
p7c smtpd.cmd.list jobs

## verify: jobsite zenka received notification
p7c p7-log.show-buffer jobsite
```

## success criteria

- [ ] smtpd zenka starts on-demand when mail is injected
- [ ] Email::MIME parses plaintext, HTML, and multipart mail correctly
- [ ] parsed mail struct contains message-id, from, to, subject, body, attachments
- [ ] routing table matches local address part → target zenka
- [ ] mail archived to /var/protocol-7/mail/YYYY/MM/DD/
- [ ] `smtpd.cmd.list` returns recent mail
- [ ] `smtpd.cmd.get` retrieves full parsed mail
- [ ] `bin/p7-mail-inject` script works from postfix pipe
- [ ] jobsite.cmd.mail_received receives and logs routed mail
- [ ] no signature stubs added, no subroutine whitelist changes made

#,,..,..,,.,.,...,,,.,.,,,...,..,,.,.,,.,,...,..,,...,...,..,,,,,,,.,,,,.,.,.,
#PB6ZVC6TRT4SLFGBSBAEOTWGYAGMCGOG6KQM2LZXOSV3ALRR2MJWPTINEX3FZYOZ5LS5KFRLEBABA
#\\\|MK2UYFTY4ZZSMRWBMKNKYWP2T5FTD6BC4D5PRIOYBBUC54LK6QD \ / AMOS7 \ YOURUM ::
#\[7]HTZI3WHTPP62LBRBLRZJB6LLACA4N3HBCOAVHPND4KDMOTRAJYBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
