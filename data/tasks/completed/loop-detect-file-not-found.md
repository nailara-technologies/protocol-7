# task: add file-not-found loop detection pattern

## objective
add a new pattern to `src/coding.tool.detect_loop` that fires when
`read_file` repeatedly returns "file not found" — even across different
paths. this catches the case where a model searches for core subs as
module files and keeps trying variants (base.ntime, base.ntime.b32,
base.time, etc.) without finding anything.

## read first
- `src/coding.tool.detect_loop` — understand existing pattern
  format (lines 62-221) and tool_history structure (lines 228-270)
- existing patterns: stuck_retry (line 119), research_spiral (line 158)
  — follow the same { name, priority, min_hits, check, confidence } format

## what to add

### 1. track file-not-found hits in ld_state

in the `## Update history ##` section (around line 270), after pushing
to tool_history, also check tool_results if available in the state:

add to ld_state initialization (around line 228):
  'file_not_found_count' => 0,

in the suspicion phase history update: scan current tool_calls batch
for read_file calls, check if $task->{'execution'}->{'last_tool_results'}
contains "file not found" for those calls, and increment the counter.

actually simpler: scan $tool_calls names — if the same tool_key contains
'read_file' and appears in tool_history more than N times without any
non-read_file calls in between, trigger.

### 2. add the pattern

add after the existing `stuck_retry` pattern (after line ~136):

```perl
{   'name'     => 'file_not_found_spiral',
    'priority' => 2,    ## higher priority than stuck_retry ##
    'min_hits' => 4,
    'check'    => sub {
        my ( $history, $weights ) = @ARG;
        return 0 unless @$history >= 4;

        ## count read_file calls in last 8 entries ##
        my @last8 = @$history[ -8 .. -1 ];
        my $read_file_count = grep { m{^read_file} } @last8;

        ## if 4+ of last 8 tool calls were read_file, likely searching ##
        ## for something that doesn't exist as a module file ##
        return 1 if $read_file_count >= 4;
        return 0;
    },
    'confidence'    => 0.80,
    'allow_polling' => 0,
    'warning' => 'repeated read_file calls suggest searching for a file'
        . ' that does not exist as a module — check if it is a core sub'
        . ' (base.ntime.b32, base.time etc. live in bin/Protocol-7)',
},
```

## important
- read the full module before editing — find the exact line numbers
- use replace_in_file to insert after the stuck_retry pattern closing },
- do NOT change any existing patterns
- the warning message will be shown to the model when triggered

## style
- $ARG not $_ in map/grep/foreach
- lowercase comments, [ word ] bracket annotations
- no use statements, no pragmas

#,,.,,,,.,,..,,,,,,..,.,,,,..,,,.,..,,,.,,...,..,,...,...,.,,,..,,,,,,,.,,,,,,
#VAQ6WI5Y5E4L5QKELB3FN25ZX5YP456FIYKPBNJXN36YW2AKGNMKFQFU3VSSGWFQZYYRTAHDVZUAE
#\\\|XPFUMVYP2H2IQXIJFLA6VKGZUEF4ACBCPY77EF25FXAFSXZTDHL \ / AMOS7 \ YOURUM ::
#\[7]T2LXXLXWPSDI7CDK6F45IUSQ7JUNOK2UR724HYKBSB67G2XSUOBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
