## [:< ##

# name  = task: X-11 — protocol error reconnect with exponential backoff
# descr = resolve the LLL in X-11.post_init: wire the planned reconnect handler
#         so transient X11 errors trigger backoff retry instead of zenka death

## kimi memory

if in doubt about P7 patterns, coding style, or project context — read first:
```bash
cat data/ai-mem/kimi/MEMORY.md
cat data/ai-mem/kimi/coding-style.md
cat data/ai-mem/kimi/topic-zenki-creation-guide.md
```

## context

`modules/X-11.post_init` lines ~135-148 registers a custom X11 error handler
but the reconnect call is commented out with an LLL marker:

```perl
## reconnect here, if not successful call: ## [ LLL ]
#  <[X-11.error_handler]>->($err_str);
```

on X11 protocol error the handler logs and returns — the next X11 call then
dies, causing the zenka to exit. v7 restarts the zenka, which restarts the X
server, disrupting all running X11 applications.

`modules/X-11.connect_X11` already retries indefinitely on initial connection —
the retry infrastructure exists and needs to be extracted into a shared module.

design reference: `data/md/development/X11-RELIABILITY-AND-WINDOW-REGISTRY.md`
section 1 (protocol reconnect).

## signatures note

do not add signature stubs. do not run `bin/Protocol-7 sourcecode update-signatures`.
do not add or modify subroutine whitelists — these are managed separately.

---

## what to read first

```bash
cat modules/X-11.post_init           ## find the LLL error handler (lines ~135-148)
cat modules/X-11.connect_X11         ## existing retry loop to extract from
cat modules/X-11.init_code           ## cfg defaults pattern
cat configuration/zenki/X-11/start   ## where to add new cfg keys
```

---

## fix 1: add cfg defaults in init_code or start

file: `modules/X-11.init_code` or `configuration/zenki/X-11/start`

add reconnect configuration defaults:
```perl
<X-11.reconnect.enabled>       //= TRUE;
<X-11.reconnect.max_attempts>  //= 7;
<X-11.reconnect.initial_delay> //= 1;    ## seconds
<X-11.reconnect.max_delay>     //= 60;   ## seconds cap
```

check where other X-11 cfg defaults live and add there consistently.

## fix 2: new module X-11.reconnect

new file: `modules/X-11.reconnect`

extract and generalise the retry loop from `X-11.connect_X11`:

```perl
## [:< ##

# name  = X-11.reconnect
# descr = attempt display reconnect with exponential backoff after protocol error

return if not <[base.cfg_bool]>->(<X-11.reconnect.enabled>);
return if defined <X-11.reconnect.in_progress>;

<X-11.reconnect.in_progress> = TRUE;

my $max_attempts   = <X-11.reconnect.max_attempts>  // 7;
my $initial_delay  = <X-11.reconnect.initial_delay> // 1;
my $max_delay      = <X-11.reconnect.max_delay>     // 60;

my $delay    = $initial_delay;
my $attempts = 0;

<[base.log]>->( 0, 'x11 connection lost — attempting reconnect.,' );

while ( $attempts < $max_attempts ) {
    $attempts++;
    <[base.log]>->( 1, "reconnect attempt $attempts / $max_attempts .," );

    ## attempt to reconnect to display
    my $connected = eval {
        <X-11.obj>->init( <X-11.display>->{ <X-11.mode> } );
        1;
    };

    if ( $connected ) {
        <[base.log]>->( 1, ': reconnected to X display =)' );
        delete <X-11.reconnect.in_progress>;

        ## re-initialise display state
        <[X-11.init_display_states]>;
        return TRUE;
    }

    <[base.logs]>->(
        0, ': reconnect failed [ attempt %d ] — retrying in %ds .,',
        $attempts, $delay
    );

    ## exponential backoff with cap
    sleep $delay;
    $delay = $delay * 2;
    $delay = $max_delay if $delay > $max_delay;
}

<[base.log]>->( 0, 'reconnect exhausted — giving up.,' );
delete <X-11.reconnect.in_progress>;
<[base.exit]>->( 'x11 reconnect failed', 1, qw| 0110 | );
```

note: `sleep` is blocking — check whether `X-11.post_init` uses an async event
loop (Event.pm) and if so use a timer-based approach instead of `sleep`. look
at how `X-11.connect_X11` handles the wait between retries and match the pattern.

## fix 3: wire the error handler in post_init

file: `modules/X-11.post_init`

find the error handler block (~line 135-148). replace:
```perl
## reconnect here, if not successful call: ## [ LLL ]
#  <[X-11.error_handler]>->($err_str);
```

with:
```perl
<[X-11.reconnect]>;
```

the LLL comment and commented-out line should both be removed.

## verification

```bash
## check LLL is gone:
grep -n 'LLL\|reconnect here' modules/X-11.post_init
## expected: no matches

## check new module exists:
ls modules/X-11.reconnect

## check error handler calls reconnect:
grep -n 'reconnect\|error_handler' modules/X-11.post_init
```

## success criteria

- [ ] `X-11.reconnect` module exists with exponential backoff loop
- [ ] `X-11.post_init` error handler calls `<[X-11.reconnect]>` (LLL resolved)
- [ ] reconnect cfg defaults added (`max_attempts`, `initial_delay`, `max_delay`)
- [ ] backoff delay doubles each attempt, capped at `max_delay`
- [ ] exhausted reconnect calls `base.exit` cleanly (allows v7 restart)
- [ ] `in_progress` flag prevents concurrent reconnect attempts
- [ ] sleep/timer approach matches existing event loop pattern
- [ ] no signature stubs added, no subroutine whitelist changes made

#,,..,,,.,.,,,,.,,.,.,...,..,,...,,..,..,,..,,..,,...,...,,,.,,.,,,.,,,,,,.,,,
#64F7TVKBH3NKM7Y266IKMXJWOE5VQOR4SNFHD53MKDIFEVIQ6YX7KENF5YWPRCHJFKT6FOCCNJRN2
#\\\|NKJHPMFKXABKZBWULJHKA3KNBEXXG4HEWIWNMMPHO4CDYASSTAR \ / AMOS7 \ YOURUM ::
#\[7]IKGXATDGNI3WF6DAZBE5P4U45YDWWOXYVFVL7V634ZBOYAW77ICY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
