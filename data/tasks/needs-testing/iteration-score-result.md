# task: implement iteration.score_result

## signatures note
do NOT add the single-line `#,,.,,,...` stub. leave files clean.

## data key syntax reminder
`<iteration.results>->{$id}` not `$data{'iteration.results'}{$id}`.
dotted %data keys use `<key.sub>->{}` — parsed to nested form.
`<[module.name]>->($arg)` to call a module with args.
write the module to disk using write_new_file tool — do not return
code in the response.

## objective
create `src/iteration.score_result` — evaluate a task result
against its acceptance criteria. returns a structured score record
used by the iteration loop to decide retry / advance / escalate.

## params (hashref via shift)
  result     — string: the produced output / code / text
  criteria   — arrayref of strings: acceptance criteria from task
  attempt_n  — integer: which attempt this is [ 1-based ]
  context    — optional string: task description for reference

## logic
1. for each criterion string in criteria:
   - check whether result satisfies it [ simple heuristic sufficient:
     does the result contain evidence of meeting the criterion? ]
   - assign status: 'pass' | 'partial' | 'fail'
   - if not pass: note what is specifically missing (one sentence)
   - classify fixable_by: 'template' | 'model' | 'user'
     template = a reminder or example in the prompt would fix it
     model    = needs a more capable model
     user     = requires a human decision or domain knowledge

2. compute overall score:
   pass=1.0, partial=0.5, fail=0.0 per criterion
   score = sum / count  [ float 0.0–1.0 ]

3. determine verdict:
   score >= 0.85              → 'advance'
   score <  0.85, fixable     → 'retry'   [ all issues fixable_by template ]
   any issue fixable_by user  → 'escalate'
   any issue fixable_by model → 'retry' unless attempt_n >= 3, then 'escalate'

4. return hashref:
   {
     score        => float,
     passed       => N,
     total        => M,
     verdict      => 'advance' | 'retry' | 'escalate',
     issues       => [ { criterion, status, gap, fixable_by }, ... ],
     attempt_n    => N,
   }

## style
- `$ARG` not `$_` in map/grep/foreach
- `<[base.logs]>->( N, fmt, args )` for logging
- lowercase comments, `[ word ]` bracket annotations
- no use statements, no pragmas — P7 modules load clean

#,,.,,,,,,,..,.,.,,.,,,,,,.,.,.,.,..,,..,,,,,,..,,...,...,...,...,...,...,..,,
#HJRRK3LYUHDSBY4Y3XMKNBBSSNJNWC3C43PDPTI7GTJWCEARGUB2THI5NQLPW233AEPDVTAR5VEDM
#\\\|VKPFJEF5U7IU2BS5HE3L2MU7RKA4USK2ODKAMEXPEV34ACSFRYY \ / AMOS7 \ YOURUM ::
#\[7]XWNFGW6XGPHQBWBBZLHEZQ6X35BF4AMDMQYK5J5K2NHZ3Y75O4CQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
