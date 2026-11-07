# render loop : live templates instead of a frozen queue

2026-11-07. a gap analysis, not a new concept. the loop itself is already
designed ; this note names the one piece missing between it and the invoke
queue of today, and the smallest way to get there.

## the trigger [ owner, 2026-11-07 ]

an invoke.ai render queue of 800+ items had to be deleted whole : invoke
offers no way to edit queued items. what was needed instead :

- BATCH EDIT queued items -- swap a reference image for a better version,
  apply newly found parameters, update SEGMENTS of their prompts
- better still : DYNAMIC PROMPT TEMPLATES, already part of the elfdb plans --
  the owner calls them the more durable and generic approach
- templates are STREAM EDITING : a direction of change is judged desirable
  once, then applies to future, still unknown input, with an expectable
  quality and style range
- the linear queue as such is the problem : a self-refining feedback system
  over the reference image channels, without manual work becoming an
  obsession, and without overfocusing one category until the queue is
  stacked with too much work

## what the plans already cover [ build on, do not restate ]

| need | where it is designed |
|------|----------------------|
| the self-refining loop, quality gate, anti-entropic reset | `CONCEPT-HARMONIC-VISUAL-INTELLIGENCE.md` |
| category templates as the unit of tuning [ "evaluate the CATEGORIES and their templates, ignore the input state" ] | `data/tasks/images-elfdb-feature-collection.md`, drift detection |
| fixed default prompt parts [ "optimum age", "perfect anatomy" ] that cannot be forgotten | same, default prompt attributes |
| slotted prompts : `[domain] elf, [expression], ..`, `<subject>`, a generic form | `network-elf-avatar-pipeline.md` base prompt template ; `data/yaml/prompts/image/psytrance-network-kitten.yaml` |
| optional elements and variants, switchable per render | `psytrance-network-kitten.yaml`, optional_elements |
| reference CHANNELS with roles as prompt text [ qwen-image 2.1 ] | feature collection, qwen-image 2.1 |
| best-5 per narrow column, ratchet, diversity | `VISUAL-INPUT-PIPELINE-AND-LIVING-TEMPLATES.md` |
| swap a key image -> re-render exactly its descendants | same, REFERENCE HISTORY TREE |
| saturation : rendering time goes to zero for full categories | same, SATURATION |
| scheduling by curves and thresholds, edited visually, part of the state machine | feature collection, scheduling by curves |
| render control [ order, interactive, parked, drain, requeue ] | invoke-web [ exists ] |

so templates, channels, the tree and the scheduler are all designed. what is
missing is where they meet the queue.

## the gap : the queue freezes the prompt

an invoke queue item holds a fully RESOLVED prompt, reference list and
settings. resolved at enqueue time, the item cannot follow a template
improvement, a better reference version or a new parameter finding : 800
items carried 800 frozen copies of yesterday's best knowledge.

the fix is one rule :

**a queued item holds a BINDING, not a prompt. it is resolved at dispatch,
the moment a render slot frees, against the current template version.**

```
item     = { template, template_version_policy, bindings, column, priority }
bindings = { subject : kitten, eyes : nebula-faint, ref.identity : <addr> .. }
resolve  = template [ current or pinned version ] + bindings
           -> prompt text, reference images, settings
           -> recorded on the result : template version + resolved form
```

consequences, each free once this holds :

- BATCH EDIT = edit the template [ every item using it follows ] or rebind
  [ change one binding across the items that share it ]. no edit pass over
  queued items ; nothing to delete
- REFERENCE SWAP = a binding names a reference by content address. a better
  version is a new address and a rebinding ; the reference history tree
  then marks the already rendered descendants to redo
- STREAM EDITING = a template version is the "direction judged desirable" ;
  future input meets it at dispatch, never a stale copy
- TRACEABILITY = every result records the template version and the
  resolved form, so versions compare side by side and a bad change rolls
  back as one unit [ the predecessor stays, cf. the reversible choices of
  the re-rendering section ]
- a template version can PIN [ an A \ B comparison with a fixed seed needs
  the old form ] or FLOAT [ the default : always the current one ]

## the queue becomes short by design

resolve-at-dispatch makes it possible to stop pre-filling at all : instead
of 800 pending items, each column holds a small DEMAND [ "column X wants
N more renders" ], and the scheduler fills a free slot from the column whose
curve wins [ scheduling by curves ] :

- a column's weight FALLS with its own backlog and with its saturation
  [ best-5 all above the threshold ] -- the brake against overfocusing one
  category, built into the curve, not into discipline
- a new or customized column starts with weight [ the SATURATION exception ]
- the pending list never grows beyond a few items per column, so there is
  nothing to clean up by hand, and a template improvement reaches the very
  next render

## storage : one reference, many holders

reference images, templates and results as N7FS nodes [ format 3,
`N7FS-FORMAT-3.md` ] : one content-addressed copy, any number of holders
[ references ], garbage only when no holder is left. that is the scaling the
gallery lacked without redundancy, and the content addresses the reference
history tree already assumes [ rename.bmw \ amos checksums ].
signed template versions on the same store give the traceability above a
signature for free.

## smallest first steps [ interim, invoke stays the engine ]

1. TEMPLATE FILE FORM : extend `data/yaml/prompts/image/*.yaml` [ already
   templates with slots, variants and optional elements ] by an explicit
   version and named slots, so a renderer can resolve one mechanically
2. RESOLVE AT DISPATCH in invoke-web : our side keeps the pending bindings
   and submits to invoke.ai one or two items ahead only -- invoke's own
   queue becomes a short buffer, never the store of intent. to verify
   first : how invoke-web enqueues today and what its requeue path keeps
3. RESULT RECORD : template version + resolved form + reference addresses
   per result, beside the image
4. COLUMN DEMAND : a per-column count with a simple backlog-damped weight ;
   the full curve editor of the feature collection later

steps 1-3 already end the frozen queue and give batch edits through
templates ; step 4 starts the self-refining scheduling. the native engine
replaces invoke.ai later without changing the binding model : the queue is
VIRTUAL [ owner, 2026-11-07 ] -- intent lives on our side, the engine only
ever sees the next resolved item. the native path exists in principle :
pytorch was loaded successfully from perl through Inline::Python, so a render
zenka can resolve and render in one process, with no queue of its own.

## open questions [ for the owner ]

- version policy default : float [ always current ] for everything, or pin
  per column while it is being compared ?
- the unit of demand : per narrow column [ best-5 group ] or per category
  until the columns exist ?
- where the pending bindings live : invoke-web state, a task zenka queue,
  or N7FS records from the start ?

#,,,.,,.,,,.,,,,.,.,.,...,,,,,,,,,.,,,,..,.,,,..,,...,..,,,,,,,,.,,..,.,,,.,,,
#GDVYZUGCN7BYLTFSD3Y7RATMZ7VIDTDD4Q6BSVN5DPTM7QT2T7JCM4NTUSPEOXA4NXFELYE7TMGQ4
#\\\|ITTYTZK4TUYW3AXADZOU2AEFFVFSLFZYEBZLKXVQKWQGWY4SJ77 \ / AMOS7 \ YOURUM ::
#\[7]WXUFICL3JZ64CTHTCWMA43ONU5KMGNECNU5XVZITPJLZOUG7QGBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
