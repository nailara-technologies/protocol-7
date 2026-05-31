## task: add 'interviewed' tab to jobs web UI

### context

`data/web-root/vhosts/jobs.vhost/index.html` — the application tracker UI.
`interviewed` is a new job status added in the status-dir restructure
(session 67). it represents jobs where the candidate got an interview, sitting
between `applied` and terminal states. add it as a UI column/tab.

### placement in the pipeline

status priority (highest first for merge):
`applied > interviewed > apply > review > assessed > new > rejected > blocked`

wait — `interviewed` comes AFTER `applied` logically (you applied, then got
interviewed). the full flow:

```
new → assessed → review → apply → applied → interviewed → [outcome]
```

so `interviewed` should appear as a tab AFTER `applied` in the UI.

### changes to index.html

#### 1. add tab button

in the tab navigation strip, add `interviewed` after `applied`:

```html
<button class="tab-btn" data-tab="interviewed">interviewed</button>
```

use the same styling as other terminal-status tabs (`applied`, `rejected`).
a distinct color would help — suggest a warm amber/gold to distinguish from
the blue pipeline tabs: `color: #c8a84b` (or check harmony).

#### 2. filter function

the tab filter already works by matching `job.status === tab`. since `status`
field on pushed records will be `interviewed` for jobs in that dir, no filter
logic change needed — just ensure the tab name matches exactly.

#### 3. card action button

on cards in the `interviewed` tab (and in `applied`), show a status-change
button to move back to `review` if needed (interview declined / rescheduled):

```html
<button class="btn-status" data-action="review">← review</button>
```

this button should call the existing status-update API endpoint with
`status=review`.

#### 4. count badge

if the UI shows per-tab counts in the tab bar, add `interviewed` to the
count aggregation.

#### 5. progress bar right section

the `jobsite.cmd.progress` right bracket could show `int:N` for interviewed
count alongside the other stats.

### harmony check

before finalizing the button label: `p7c harmony interviewed` — if FALSE,
suggest alternatives. likely TRUE given it's a standard English word.

### signatures note

the HTML file does NOT have AMOS7 signatures. edit freely.
for any Perl modules touched, do NOT add signature stubs.

## dispatch

#,,,,,,,,,...,.,.,,,.,.,,,...,.,,,..,,,.,,..,,..,,...,.,,,,.,,..,,,,,,,..,,,,,
#CM6R3QIZNMOSGVEB2KNVZLYSSTAC66USVAZGTFOMJRJI7YMMICU67FB3FP2JXF7VBCQEGYRK6EXRK
#\\\|HI2LMDM766EHFSRD4HYUO7Z4V2UFDIC55O2EY4XFWRILWYUIY7L \ / AMOS7 \ YOURUM ::
#\[7]27YT5ZYVIFW4TFB7VRSYSXO4CCRTGUHTQ2P3TCE4B54V3BCZWECY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
