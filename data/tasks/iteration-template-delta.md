# task: implement iteration.template.delta

## objective
create `modules/iteration.template.delta` — given a score record with
issues, produce a precise template patch that would prevent the most
significant issue on the next attempt.

## read first
- `modules/iteration.score_result` — understand score record structure:
  { score, passed, total, verdict, issues => [ { criterion, status,
    gap, fixable_by } ], attempt_n }
- `modules/iteration.loop` — shows how delta is stored in state

## what to implement

params (hashref via shift):
  score_record  — the score record from iteration.score_result
  template_name — name of the template that was used [ string ]
  attempt_n     — which attempt produced this score record

logic:
1. find the highest-impact unfixed issue:
   - filter issues where status ne 'pass' and fixable_by eq 'template'
   - if none: return undef [ nothing a template can fix ]
   - pick the one with most specific gap description [ longest gap str ]

2. classify the issue type and map to a patch:
   - syntax error      → add concrete example of correct syntax
   - missing step      → add explicit instruction for that step
   - wrong tool usage  → add tool parameter example [ see feature-impl ]
   - format violation  → add format reminder with correct example
   - write not done    → strengthen write-to-disk instruction

3. produce a delta hashref:
   {
     issue_id      => criterion string of the issue addressed,
     change_type   => 'add_example' | 'add_instruction' | 'strengthen',
     location      => 'after:<label>' | 'prepend' | 'append',
     content       => the exact text to insert [ one short paragraph max ]
     template_name => $template_name,
     attempt_n     => $attempt_n,
   }

4. log the delta at level 1 and return it

## style
- $ARG not $_ in map/grep/foreach
- <[base.logs]>->( N, fmt, args ) for logging
- lowercase comments, [ word ] bracket annotations
- no use statements, no pragmas

#,,,,,,,,,..,,,,.,,,,,...,,,.,,.,,.,.,.,.,..,,..,,...,...,...,...,..,,..,,,.,,
#LU675THXXZGG76WYUPBLUIGN5AIRCJFH6QPPPGVHGSWMY7CVJSIPCUICKYCNTWMF2WYKR7AP73TAU
#\\\|B67EWHHCTT263BOFWZ62ILOHMC6DNQKIW5ZS7553XAKDB4V53AV \ / AMOS7 \ YOURUM ::
#\[7]3KKWI56D7RPX7BRPDRBHH5R52AY5FQ4GA7ODASGHP726CV7WZOBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
