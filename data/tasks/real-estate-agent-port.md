# real-estate agent port — task

## context

existing: jobsite framework — src/jobsite.*, src/site-yaml.job.*,
src/plugin.web.jobs.*, data/web-root/vhosts/jobs.vhost/index.html
(categorized status tabs UI, scoring, bulk actions, export/report tables)
memory: data/ai-mem/kimi/jobs-pipeline-2026-06-28.md,
data/ai-mem/kimi/topic-jobsite-scan-refactor.md
source: duck.ai design conversation 2026-07-29 (prompts 40–43)

port the job-offer scanning/categorization framework to real-estate
listings. the dependency chain is explicit: income first, then housing —
this task is QUEUED behind application communication automation, not
cancelled. doing the search manually while the framework sits installed
would be stalling momentum; the final bottleneck (in-person visits) is
serialized anyway and only benefits from better-ranked candidates.

the port is also the second instance proving the framework is generic —
the moment two domains run on it, the "abstract the matrix away"
generalization (reusable agent-group framework from concrete job
machinery) has its test case.

## phase 1 — domain abstraction

### task 1.1 — extract the generic pipeline
```
## dispatch + prompt
survey src/jobsite.* + plugin.web.jobs.* and factor the domain-
specific parts (job boards, scoring keys, status names, export formats)
from the generic machinery (scan → store → score → categorize → UI tabs
→ export). propose the minimal abstraction: a domain config (yaml) per
site-type that the generic engine consumes. write the abstraction plan
as a comment block BEFORE refactoring — small steps, jobsite must keep
working throughout.
```

### task 1.2 — real-estate domain config
```
## dispatch + prompt
create the immobilien domain config: sources (immobilienscout24,
wg-gesucht, immonet, ebay-kleinanzeigen scrapers), scoring profile
(safety/quiet, cat-friendly, price range, transit, commute to
karlsruhe center), status tabs mirroring the jobs pipeline
(new → review → contact → visit → offer → rejected), alert queue
for fresh matches. reuses the generic engine from task 1.1.
```

## phase 2 — operation

### task 2.1 — scanner agents live
```
## dispatch + prompt
run the real-estate scanners on a schedule; verify dedup against
already-seen listings, scoring sanity on a hand-checked sample of 20,
and alert delivery. hundreds of listings scored in parallel against
true requirements is the expected steady state.
```

### task 2.2 — visit serialization support
```
## dispatch + prompt
add a visit-planning view: ranked candidates grouped by area for
batched in-person visits (the irreducible serial bottleneck), with
contact/appointment state tracked per listing in the existing tab UI.
```

## notes

- personal context (budgets, timeline, reasons) lives in
  /data/interview/relocation-and-baseline.md — OUTSIDE the repo.
  this task file stays technical.
- communication automation around job offers (follow-ups, scheduling)
  precedes this in priority — but both ride the same abstraction from
  task 1.1, so doing 1.1 first serves both.

#,,.,,,.,,.,,,,..,,,.,,,.,...,.,.,,,.,,,.,,,.,..,,...,...,,.,,,,,,.,,,,,,,,,.,
#QGLAU2FS6D3YSVJAQVEGK2SDH7WRKUUCUQ33L3ZCYTWCMMUHPN4J5MPGTPITZRAGLIU7GTDEY2IUK
#\\\|QHKSA5D6OJZ54L4WYYYIEBLYMCD5GSSDG3YVBNK7AASKXDOS47A \ / AMOS7 \ YOURUM ::
#\[7]MHNF6AFNMSEOQPFWG7OX5Z6FR74ZY3PYTKZ7QBIRY3UDHRQDF4CI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
