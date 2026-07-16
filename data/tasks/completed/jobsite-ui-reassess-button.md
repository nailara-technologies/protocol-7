## task: prioritized re-assessment button via backchannel

### concept

a subtle re-assessment button on job cards that resets the job and
injects it at the FRONT of the assessment queue, bypassing the normal
scan cycle. uses the existing `pushChange` → `/jobs-sync` → `apply_reverse`
backchannel.

---

### backend: jobsite.sync.apply_reverse

add `action: reassess` handling after the existing `blacklist` block:

```perl
if ( $action eq 'reassess' ) {
    my $job = <[jobsite.job.read]>->($id);
    if ( ref $job ne 'HASH' ) {
        <[base.logs]>->( 0, 'jss.sync.apply: reassess %s — not found', $id );
        next;
    }

    ## clear assessment fields, reset to new ##
    for my $f (qw| score score_reason score_summary assertions stage
                   repair_attempted repair_failed repair_applied |) {
        delete $job->{$f};
    }
    $job->{'status'} = 'new';
    <[jobsite.job.write]>->( $id, $job );

    ## update in-memory task record ##
    my $rec = ( <jobsite.tasks> // {} )->{$id} // {};
    delete $rec->{$ARG} for qw| score score_reason score_summary assertions
                                stage repair_attempted repair_failed |;
    $rec->{'status'} = 'new';
    <jobsite.tasks>->{$id} = $rec;

    ## inject at front of assess queue (prioritized) ##
    my $profile_file = <jobsite.cfg.profile_file>
        // '/etc/protocol-7/jobsite/profile.txt';
    my $profile_text = <[file.read]>->($profile_file)
        // 'no profile configured';
    <[base.perlmod.autoload]>->('Encode');
    $profile_text = Encode::decode( 'UTF-8', $profile_text )
        unless utf8::is_utf8($profile_text);

    my $prompt = <[jobsite.util.build_prompt]>->($job);
    my $entry  = { 'job_id' => $id, 'desc' => $prompt };

    <jobsite.assess_queue> //= [];
    unshift @{ <jobsite.assess_queue> }, $entry;    ## front of queue ##

    ## if idle: start the cycle ##
    if ( ( <jobsite.cycle> // 'idle' ) eq 'idle' ) {
        <jobsite.cycle>         = 'assessing';
        <jobsite.pending_count> = 1 + scalar @{ <jobsite.assess_queue> };
        <[jobsite.dispatch.next]>;
    }

    <[base.logs]>->( 1, 'jss.sync.apply: reassess %s queued (front)', $id );
    next;
}
```

---

### frontend: button in card

add a small re-assess button to `.card-actions`. place it after the
apply badge, before the stage select. subtle styling — should not dominate:

```html
<button class="btn-reassess" data-id="${j.id}" title="re-assess">↺</button>
```

CSS:
```css
.btn-reassess {
    font-size: 0.78rem;
    padding: 1px 5px;
    color: #4a6a8a;
    background: rgba(8,20,38,0.5);
    border: 1px solid #1a3048;
    border-radius: 3px;
    cursor: pointer;
    opacity: 0.6;
    transition: opacity 0.15s, color 0.15s;
}
.btn-reassess:hover { opacity: 1.0; color: #80b4d8; }
```

event listener in renderCard (alongside the existing stage select listener):

```javascript
const btnReassess = el.querySelector('.btn-reassess');
if (btnReassess) {
    btnReassess.addEventListener('click', async () => {
        btnReassess.textContent = '…';
        btnReassess.disabled = true;
        await pushChange(j.id, { action: 'reassess' });
        btnReassess.textContent = '↺';
        btnReassess.disabled = false;
        notify('re-assessment queued');
    });
}
```

the `notify` function should already exist in the UI for showing brief
status messages. if not, a simple `console.log` fallback is acceptable.

---

### visibility rules

show the re-assess button on all cards EXCEPT:
- `applied`, `interviewed`, `responded` — user-decision stages, re-assessing
  would be confusing
- `archived` — hidden anyway

so: show on `review`, `to_apply`, `assessed` (alle tab), `rejected`, `error`.

in renderCard, conditional:
```javascript
const noReassess = ['applied','interviewed','responded','archived'];
${!noReassess.includes(j.stage) ? `<button class="btn-reassess" ...>↺</button>` : ''}
```

---

### profile text in apply_reverse

`jobsite.sync.apply_reverse` currently does not load the profile text.
for the reassess action, the profile is needed to build the prompt.
the profile is read from `<jobsite.cfg.profile_file>`. alternatively,
call `<[jobsite.dispatch.assessments]>` logic directly if building the
prompt in apply_reverse is too complex — but reading the file directly
is simpler and keeps the action self-contained.

---

### signatures note

do NOT manually write or edit signature lines. do not add stubs to new or
modified files.

## dispatch

#,,.,,...,.,.,,..,..,,,,,,.,,,.,,,..,,.,,,.,,,..,,...,...,...,..,,,,,,.,.,.,,,
#J4TIAVCBJ3FJLISGJFGMSDHQHGJ2JUBGIQIELN3ICQBWCW5KFMTUF64M5UMZWASTEXI6JGLYVPGXU
#\\\|W6WFTNNNUSSTJJJKIZEMXFNEKBHH4R54R4ZE3MFDDI4A3DGDOJ6 \ / AMOS7 \ YOURUM ::
#\[7]7CM2MUA7LUBENOVIBNKPDZKXUJYNQ7E2LAIZFIKD5D5ZSNJW7YDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
