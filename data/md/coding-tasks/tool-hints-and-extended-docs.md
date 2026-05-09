# tool-hints — contextualized error hints + extended tool documentation

**Priority:** Medium
**Type:** Feature — Tool System Self-Improvement
**Component:** coding.tools.dispatch, coding.tools.handler.*, coding.tools.definitions

## Overview

Extend the tool system with three capabilities:

1. **Extended tool descriptions** — `tool_help` tool returns full docs,
   examples, and known pitfalls for any tool. Separate from the short
   OpenAI schema description (token-budget constrained). Lives in a
   YAML registry file, fetched on demand.

2. **Contextualized error hints** — when a tool call fails or returns a
   suspicious result, `coding.tools.dispatch` checks a hint registry and
   appends a relevant hint to the tool result. Pattern-matched against
   both the tool arguments and the error/result string.

3. **Model-extensible hint registry** — `register_hint` tool lets models
   add new patterns after discovering them during task execution. New
   hints are staged (not immediately live) and reviewed before becoming
   permanent — same self-improvement loop as context templates.

## Architecture

```
tool call → dispatch → execute → result
                ↓                  ↓
          hint registry        match patterns
          (YAML/tree)    →     append hint if matched
                ↓
        model sees result + hint inline
```

## Layer 1: Hint Registry

**File:** `data/yaml/tool-hints/registry.yaml`

Structure:
```yaml
hints:
  - name: search_code_backslash_spiral
    match_on: args          ## check args or result
    tool: search_code       ## empty = any tool
    pattern: '\\[QqsS*+?]'  ## regex matched against args JSON
    hint: |
      backslash-heavy regex patterns corrupt over multiple rounds via
      Jinja template processing. use simple literal strings instead:
        good: search_code(pattern: "while (1)")
        good: search_code(pattern: "event.once")
        bad:  search_code(pattern: "while\s*\(\s*1\s*\)")
      prefer reading modules directly with read_module when searching
      for patterns that require complex regex.
    added_by: system
    rationale: model repeatedly used \Q and \s* patterns causing spirals

  - name: search_code_empty_result_hint
    match_on: result
    tool: search_code
    pattern: 'no matches for m\{'
    hint: |
      if your pattern returned no results, consider:
      - simplify the pattern (remove backslashes, use literal text)
      - use read_module on the specific module you expect to find it in
      - use list_modules to discover which namespace to search
    added_by: system
    rationale: empty search results often mean pattern corruption, not absence

  - name: path_required_replace_in_file
    match_on: result
    tool: replace_in_file
    pattern: 'path required'
    hint: |
      'path required' often means JSON arg corruption from backslashes in
      old_string or new_string content. if your replacement strings contain
      backslashes, use edit_file instead — it handles backslash content
      more robustly.
    added_by: system
    rationale: replace_in_file path arg corrupted by complex content strings

  - name: write_new_file_staged
    match_on: result
    tool: write_new_file
    pattern: 'staged new file'
    hint: |
      file was staged rather than written directly. this happens when the
      directory is not writable by the coding zenka user. the file is at
      the staged path shown. to apply: the user runs bin/apply-staged, or
      you can use coding.cmd.apply-staged if you have permission.
      check: does the target directory exist? use list_files to verify.
    added_by: system
    rationale: models don't always notice staging and assume the write succeeded
```

## Layer 2: Hint Injection in coding.tools.dispatch

**File:** `modules/coding.tools.dispatch` — add after result is obtained,
before returning to the state machine.

New module: `modules/coding.tools.hints.check` — called from dispatch.

```perl
# name  = coding.tools.hints.check
# descr = check hint registry against tool args and result, return hint text

my ( $tool_name, $args_json, $result_str ) = @ARG;

my $registry_path = <system.root_path>
    . '/data/yaml/tool-hints/registry.yaml';
return '' unless -f $registry_path;

my $registry = <[format.yaml.load_file]>->($registry_path) // {};
my @hints    = @{ $registry->{'hints'} // [] };

my @matched;
for my $hint (@hints) {
    ## tool filter — empty matches any ##
    next if length( $hint->{'tool'} // '' )
        and $hint->{'tool'} ne $tool_name;

    my $target
        = ( $hint->{'match_on'} // 'result' ) eq 'args'
        ? $args_json
        : $result_str;

    my $pattern = $hint->{'pattern'} // next;
    if ( eval { $target =~ m{$pattern} } ) {
        push @matched, $hint->{'hint'};
    }
}

return '' unless @matched;
return "\n\n## tool hint ##\n" . join "\n\n", @matched;
```

**In coding.tools.dispatch** — after `$raw_result` is obtained:
```perl
## check hint registry for contextual guidance ##
my $hint = <[coding.tools.hints.check]>->(
    $name, JSON::PP->new->encode($args), "$raw_result"
);
$raw_result .= $hint if length $hint;
```

## Layer 3: tool_help Tool

**File:** `modules/coding.tools.handler.tool_help`

```perl
# name  = coding.tools.handler.tool_help
# descr = return extended documentation for a named tool

my $args      = shift // {};
my $tool_name = $args->{'tool'} // return 'tool name required';

my $registry_path = <system.root_path>
    . '/data/yaml/tool-hints/registry.yaml';
my $registry = <[format.yaml.load_file]>->($registry_path) // {};

## find all hints for this tool ##
my @hints = grep {
    !length( $_->{'tool'} // '' ) or $_->{'tool'} eq $tool_name
} @{ $registry->{'hints'} // [] };

my $output = "## tool: $tool_name ##\n\n";

## extended description from registry ##
my $desc = $registry->{'descriptions'}{$tool_name} // '';
$output .= "### description ###\n$desc\n\n" if length $desc;

## known hints / pitfalls ##
if (@hints) {
    $output .= "### known pitfalls ###\n";
    for my $h (@hints) {
        $output .= "**$h->{'name'}**: $h->{'hint'}\n\n";
    }
}

return $output || "no extended documentation for '$tool_name'";
```

**Tool definition** — add to coding.tools.definitions:
```perl
## tool_help — extended tool documentation and known pitfalls ##
{
    name        => 'tool_help',
    description =>
        'get extended documentation, examples, and known pitfalls for '
        . 'any tool. use when a tool behaves unexpectedly or you want '
        . 'to understand its full capabilities before calling it.',
    parameters => {
        tool => { type => 'string', description => 'tool name to look up' },
    },
    required => ['tool'],
}
```

## Layer 4: register_hint Tool

**File:** `modules/coding.tools.handler.register_hint`

```perl
# name  = coding.tools.handler.register_hint
# descr = stage a new hint for the tool hint registry

my $args     = shift // {};
my $name     = $args->{'name'}     // return 'name required';
my $match_on = $args->{'match_on'} // 'result';
my $tool     = $args->{'tool'}     // '';
my $pattern  = $args->{'pattern'}  // return 'pattern required';
my $hint     = $args->{'hint'}     // return 'hint text required';
my $rationale = $args->{'rationale'} // '';

## validate pattern compiles ##
eval { '' =~ m{$pattern} };
return "error: pattern does not compile: $@" if $@;

## stage to a review file rather than writing directly to registry ##
my $stage_dir  = <system.root_path> . '/data/yaml/tool-hints/staged/';
my $stage_file = $stage_dir . $name . '.yaml';

## ensure staged dir exists ##
<[file.mkdir]>->($stage_dir) unless -d $stage_dir;

my $entry = {
    name      => $name,
    match_on  => $match_on,
    tool      => $tool,
    pattern   => $pattern,
    hint      => $hint,
    rationale => $rationale,
    added_by  => 'model',
    staged_at => <[base.ntime.b32]>,
};

<[format.yaml.dump_file]>->( $stage_file, $entry );

return "hint '$name' staged at data/yaml/tool-hints/staged/$name.yaml\n"
    . "a human or review task will merge it into the registry after verification.";
```

**Tool definition:**
```perl
## register_hint — stage a new tool hint for review ##
{
    name        => 'register_hint',
    description =>
        'stage a new hint for the tool hint registry. use when you discover '
        . 'a pattern that causes tool failures or unexpected behavior. '
        . 'the hint will be reviewed before becoming permanent. '
        . 'pattern is a regex matched against tool args (match_on=args) '
        . 'or the tool result string (match_on=result).',
    parameters => {
        name      => { type => 'string',  description => 'unique hint name (snake_case)' },
        match_on  => { type => 'string',  description => 'args or result [ default result ]' },
        tool      => { type => 'string',  description => 'tool to match (empty = any tool)' },
        pattern   => { type => 'string',  description => 'regex pattern to match against target' },
        hint      => { type => 'string',  description => 'hint text shown to model' },
        rationale => { type => 'string',  description => 'why this hint is needed' },
    },
    required => ['name', 'pattern', 'hint'],
}
```

## Acceptance Criteria

- `data/yaml/tool-hints/registry.yaml` exists with 4 default hints
- `coding.tools.hints.check` called from dispatch, result appended when matched
- `p7c coding.call-tool tool_help '{"tool":"search_code"}'` returns pitfalls
- `p7c coding.call-tool register_hint '{"name":"test","pattern":"x","hint":"y"}'`
  creates staged file, not writing directly to registry
- hint injection tested: call search_code with a `\s*` pattern, verify hint appears
- `ptd -c` passes on all new modules

## Notes

- signatures_note: leave signing to the system, no stub lines
- hint registry YAML: no `## [:< ##` P7 header — YAML::XS chokes on them
- staged hints directory: created on first register_hint call if absent
- pattern validation: always eval-test the regex before staging to catch compile errors
- the `descriptions` key in registry.yaml is a hash of tool_name → extended text,
  separate from hints — add at least search_code and replace_in_file entries
- hint injection adds minimal overhead: only loads registry file once (cache after first load
  via `state $registry` in the hints.check module if performance matters)

#,,,,,..,,,,,,...,,,.,.,,,,..,..,,..,,...,,,,,..,,...,..,,..,,.,.,,,.,,.,,.,,,
#ML4RT3ATZKBHT6SVMSS2DYZP5MDYJ7EKAW35UNS43RHKEC7EOFLXEOQ3EG6ZPAKEJOY3QYQU3Y76A
#\\\|4EPZ7Z2J3F3TZUVBNFBGZ2MTOBCVZFS5PGJTQVIWWDUKHSSVPSX \ / AMOS7 \ YOURUM ::
#\[7]VFJLYWF3KAJKQF2DGE45IMKTT57OCK3LIXVUM7VANJ3VFAGHEKCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
