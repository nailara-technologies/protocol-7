## task: jobsite UI card refinements — assertions display, error tab, NaN fix

### context

the jobs UI at `data/web-root/vhosts/jobs.vhost/index.html` receives rich
assessment data that is not yet displayed. the assessment model returns:
- `job.assertions.suggest.apply` — 'true'/'false' recommendation
- `job.assertions.suggest.archive` — 'true'/'false'
- `job.assertions.dimensions.<name>.score` — per-dimension 0-10 scores
- `job.assertions.dimensions.<name>.reason` — per-dimension prose reason

dimension keys:
`location`, `work-profile`, `company-culture`, `compensation`,
`remote-flexibility`, `career-growth`, `tech-stack`, `team-structure`

---

### change 1: NaN score filter bypass fix

file: `index.html` line ~795

current:
```javascript
if (norm < minScore) return false;
```

fix:
```javascript
if (!isFinite(norm) || norm < minScore) return false;
```

jobs with empty score (NaN) currently slip through the filter and show as
title-only cards. this makes them correctly hidden when below threshold.

---

### change 2: assertions.suggest.apply badge on card

show a small badge on each assessed/review card indicating the model's
apply recommendation. placed in `.card-actions` row, left of the stage select.

```html
<!-- when job.assertions?.suggest?.apply === 'true' -->
<span class="badge-apply badge-yes">✓ apply</span>

<!-- when job.assertions?.suggest?.apply === 'false' -->
<span class="badge-apply badge-no">✗ skip</span>
```

CSS:
```css
.badge-apply { font-size: 0.72rem; padding: 1px 6px; border-radius: 3px;
               margin-right: 6px; font-weight: 600; }
.badge-yes   { color: #50c050; background: rgba(20,80,20,0.35);
               border: 1px solid #204820; }
.badge-no    { color: #808080; background: rgba(20,20,20,0.3);
               border: 1px solid #303030; }
```

only show badge when `job.assertions?.suggest?.apply` is defined.

---

### change 3: dimensions score row on card

below `.card-reason`, add a compact dimension score row shown when
`job.assertions?.dimensions` exists and has entries.

abbreviated dim names (map in JS):
```javascript
const dimAbbr = {
    'location':           'loc',
    'work-profile':       'work',
    'company-culture':    'cult',
    'compensation':       'comp',
    'remote-flexibility': 'remote',
    'career-growth':      'growth',
    'tech-stack':         'tech',
    'team-structure':     'team',
};
```

render as: `loc:3 | work:2 | cult:2 | comp:5 | remote:3 | growth:3 | tech:4 | team:2`

score coloring (inline style or class):
- score >= 7: `color: #50c050` (green)
- score >= 5: `color: #c0a030` (amber)
- score <  5: `color: #804040` (muted red)

HTML structure:
```html
<div class="card-dims">
  <span class="dim-score dim-low">loc:3</span> |
  <span class="dim-score dim-low">work:2</span> | ...
</div>
```

CSS:
```css
.card-dims   { font-size: 0.70rem; color: #506070; margin-top: 3px;
               letter-spacing: 0.02em; }
.dim-high    { color: #50c050; }
.dim-mid     { color: #c0a030; }
.dim-low     { color: #804040; }
```

on card hover, dim scores lift slightly (same transition as card-reason).

make the row collapsible — clicking it opens a detailed tooltip/panel showing
each dimension's reason text. use a `<details>` element or a simple toggle:

```html
<div class="card-dims" title="click for details">...</div>
<div class="card-dims-detail hidden">
  <div><b>loc</b>: Düsseldorf ist nicht in den bevorzugten Regionen...</div>
  ...
</div>
```

---

### change 4: error tab for repair_failed jobs

currently the UI has an unused "error" tab/filter. wire it to show jobs
where `job.repair_failed === 5` or `job.repair_failed === true`.

the `repair_failed` field is present in the JSON from `plugin.web.jobs.data`
(it passes through the assertions block). check: add it to the passthrough
fields in `plugin.web.jobs.data` if not already present.

```javascript
// in render filter logic, alongside stage filter:
if (filterMode === 'error') {
    return job.repair_failed == 5 || job.repair_failed === true;
}
```

the error tab badge should show the count of repair_failed jobs.
use a muted red color: `color: #c05050`.

also add error count to `updateStats`:
```javascript
document.getElementById('stat-error').textContent =
    all.filter(j => j.repair_failed == 5).length + ' err';
```

add stat badge in controls row:
```html
<span id="stat-error" class="stat" style="color:#c05050;background:rgba(80,20,20,0.3)">0 err</span>
```

---

### change 5: archive suggestion visual cue

when `job.assertions?.suggest?.archive === 'true'`, dim the card slightly
to indicate the model recommends archiving:

```css
.job-card.suggest-archive { opacity: 0.65; }
.job-card.suggest-archive:hover { opacity: 1.0; }
```

add class in renderCard when archive suggestion is true.

---

### change 6: repair_failed field passthrough in plugin.web.jobs.data

`plugin.web.jobs.data` may not be passing `repair_failed` through to the
browser. check lines around the field remapping (score_reason → reason) and
add:

```perl
$j->{'repair_failed'} = $j->{'repair_failed'} // 0;
```

or ensure it's not being deleted. `repair_failed` is a YAML field at the
top level of the job record.

---

### implementation order

1. NaN fix (trivial, do first)
2. repair_failed passthrough in plugin.web.jobs.data
3. error tab + stat badge
4. apply badge
5. dims score row (with detail toggle)
6. archive dimming

---

### signatures note

the HTML file does NOT have AMOS7 signatures — edit freely.
for any Perl modules touched (plugin.web.jobs.data), do NOT add signature
stubs to modified files.

## dispatch

#,,.,,,.,,,..,,..,...,..,,,,,,,.,,.,.,,,.,,..,..,,...,...,,..,...,.,.,,..,...,
#G44ZP3ODCNW4ZAY4VKJLG5JQVJKECPWN32UQPDBU42XXMCQJ7VLOVF6LYTXT2FM2F5IQ3PBBJSCLI
#\\\|6K22G2UDVFGCXZ7ILRV74WIFP7MMC5S5CSWOTEIZT6L35RQ5IY5 \ / AMOS7 \ YOURUM ::
#\[7]BF7VLB42HJQHK7PCDA2FVD6H7B7OEFMX26T74WYVXTXRIOPMSECQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
