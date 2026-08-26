## task: extract Stepstone's own salary estimate into site-yaml job records

### read first

- `data/ai-mem/kimi/coding-style.md` and `data/ai-mem/kimi/MEMORY.md` — P7
  module conventions (this is a small task but the pitfalls below still
  apply: `base.logs` not `base.log`, no fake signature stubs, TRUE=5/FALSE=0)
- `src/site-yaml.stepstone.job` — current JSON-LD extractor, the file
  you will extend
- `src/site-yaml.http.get` — existing fetch helper, use it, don't add
  a second HTTP client
- `src/jobsite.util.build_prompt` — assessment prompt builder, the
  second file you will extend

---

### motivation

Stepstone shows its own estimated salary range on many (not all) job
postings — a number the site itself computed, separate from any
employer-stated salary. Right now the jobsite assessment prompt asks a
local LLM to *guess* the `compensation` dimension score from company size
and industry alone, e.g. (real assessment output on file today):

> "Mittelstandsbetrieb mit 170+ Mitarbeitern – wahrscheinlich solide
> Vergütung, aber ohne genaue Zahlen schwer einschätzbar."

That's a proxy for a number Stepstone already published on the same page.
Extracting it grounds the compensation scoring in reality instead of a
guess, and gives the candidate (via jobs.vhost review UI, unrelated to
this task) an actual anchor for a salary ask.

---

### step 1 : find the real markup

`src/site-yaml.stepstone.job` currently only parses the JSON-LD
`<script type="application/ld+json">` block. Stepstone's salary *estimate*
widget is a site feature, not part of the JobPosting JSON-LD schema — it
is very unlikely to be in that block. You need to fetch a live page and
find where it actually lives in the HTML.

Use `<[site-yaml.http.get]>->($url)` (or curl from a shell, whichever is
faster for exploration) against these two known-good URLs — both show a
visible Stepstone salary estimate range as of 2026-07-14:

- `https://www.stepstone.de/stellenangebote--AI-Engineer-Data-Scientist-mwd-Machine-Learning-Generative-AI-Deutschland-Berlin-Duesseldorf-Heidelberg-Ulm-HMS-Analytical-Software-GmbH--14275750-inline.html`
  (estimate was €53,000–77,000)
- `https://www.stepstone.de/stellenangebote--DevOps-Engineer-Backend-Entwickler-in-m-w-d-Berlin-marbis-GmbH--13760935-inline.html`
  (estimate was €42,000–64,000)

Look for German label text near the number — likely something like
"Geschätztes Gehalt", "Gehaltsschätzung", "Durchschnittsgehalt", or a
`data-` attribute / embedded JSON blob (Stepstone often ships a second
`<script type="application/json">` or inline Next.js `__NEXT_DATA__` /
similar state blob alongside the JSON-LD one — check for that first,
it's more stable than scraping rendered text).

If a job page has no visible estimate (some postings show an
employer-stated salary instead, or nothing), that's a normal, expected
case — do not treat it as a parse failure.

---

### step 2 : extend `site-yaml.stepstone.job`

Add two new keys to the returned hash:

```perl
'salary_estimate_min' => ...,   ## integer, no currency symbol/thousands sep ##
'salary_estimate_max' => ...,
```

**Critical: absence must be a clean, unambiguous state.** When no estimate
is found on the page, do **NOT** set these keys to `0`, `''`, or `undef`
inside the hash — omit both keys entirely from the returned hashref. A
future task will layer in other salary sources (market-average APIs,
trend data) and they all need to distinguish "no data" from "value is
literally zero" the same way. Downstream code should use
`exists $job->{'salary_estimate_min'}`, never `$job->{'salary_estimate_min'} // 0`
followed by a truthiness check.

Parse the number as a plain integer (strip `.`/`,` thousands separators,
`€`/`EUR` symbols, "Brutto"/"pro Jahr" suffixes — Stepstone's estimate is
always an annual gross range in the examples above).

---

### step 3 : wire into the assessment prompt

In `src/jobsite.util.build_prompt`, when `$job->{'salary_estimate_min'}`
and `$job->{'salary_estimate_max'}` both exist, add a line to the prompt
telling the model the real range instead of leaving it to guess, e.g.
something like:

```
Stepstone-Gehaltsschätzung für diese Stelle: €<min>–<max> (jährlich brutto)
```

placed near the `"## Stellenanzeige : ..."` block. When the fields are
absent, the prompt should look exactly as it does today (no "no data"
placeholder line — just omit it). This does not require changing the
YAML output schema, `jobsite.validate.assessment`, or
`jobsite.handler.assess-done` — the compensation `reason` text should
just naturally reference the real number now that the model has it,
same free-text field as before.

No changes needed in `jobsite.cmd.job-upsert` or the store schema — it
already copies the full fetched hash (`my $job = { %{$job_in} };`), so
any new keys from `site-yaml.stepstone.job` flow through to
`store.yaml`/per-job files automatically.

---

### testing

Run the extractor against both URLs above (or whichever still resolve)
and confirm:
- both known-estimate pages produce `salary_estimate_min`/`_max` matching
  the ranges quoted above (±rounding)
- a page with no visible estimate produces a hash with neither key present
  (test against any older/expired listing, or one with an employer-stated
  salary instead — those should also come back with no estimate keys,
  since employer-stated salary is a different signal, not in scope here)
- existing JSON-LD fields (title, company, description, ...) are
  unaffected

---

## signatures note

do NOT manually write or edit signature lines. existing signatures on
modified files will be regenerated by the signing system. do not add
fake/stub signatures to new files.

## dispatch

#,,,,,...,.,,,,..,,,,,...,.,,,.,,,.,,,,.,,.,,,..,,...,...,.,,,,.,,.,,,.,.,...,
#HBZWWEBWGMDD5KS6DQ6H7J35NFPSGCJXMSODSXI4BUXMWUJADPWYECGYECB4THNCF3TOQI3Z2CK2E
#\\\|2A7PJONMLGZOOB2Z4R3DQJXWBV2GRS6JTZQBHTRPIOWMOF3YWGQ \ / AMOS7 \ YOURUM ::
#\[7]WONRRRU7VDVGOCEULNLUCRBQFZVSYJFQEMDGO2IZ5MZNM7ZHFADQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
