# task: sourcecode.recently-modified — commit history with duration column

## context

the sourcecode zenka manages module signatures and file tracking. adding a
`recently-modified` command gives models and humans a fast way to see what
has changed recently, filtered by path or pattern. the duration column uses
`base.parser.duration` for human-readable output. registered as a coding
zenka tool so local models can call it during task execution for context.

## signatures note

do not add signature stubs. run `bin/Protocol-7 sourcecode update-signatures` when done.

---

## what to implement

### sourcecode.recently-modified

```
args: {
  filter  => 'src/coding',   ## optional path prefix or glob pattern
  limit   => 26,                 ## number of files to show (default 26)
  since   => undef,              ## optional: only files changed since ntime/date
}

output (two-column, left-aligned):

  2h ago          src/coding.callback.http_error
  2h ago          src/coding.sanitize.jinja_messages
  4h ago          data/yaml/reasoning-templates/arrived-by-being.yaml
  4h ago          data/yaml/reasoning-templates/semantic-triangle.yaml
  1 day ago       src/coding.async.send_request
  3 days ago      cfg/zenki/coding/start
  ...

implementation:
  1. run: git log --name-only --pretty=format:"%H %at" -- <filter>
     or:   git log --diff-filter=M --name-only --pretty=format:"%H %at"
  2. parse: for each commit, extract timestamp + file list
  3. deduplicate: keep only first (most recent) occurrence of each file
  4. compute duration: now - commit_timestamp → <[base.parser.duration]>->($delta)
  5. format: sprintf "  %-16s  %s", $duration, $filepath
  6. sort by most recent first (git log is already in this order)
  7. apply limit

base.parser.duration output examples:
  "just now"    (< 1 minute)
  "3 min ago"   (< 1 hour)
  "2h ago"      (< 1 day)
  "3 days ago"  (< 1 week)
  "2 weeks ago" (< 1 month)
  "4 months ago"

return format:
  { 'mode' => 'size', 'data' => $formatted_output }
  (standard list-command return format)
```

### tool registration for coding zenka

register `recently_modified` as a coding zenka tool so local models can
call it during task execution:

tool definition (add to coding zenka's tool registry):

```yaml
name: recently_modified
description: >
  list recently modified files from git commit history, sorted by modification
  time with human-readable duration. use to understand what changed recently
  before starting work on a related area. returns two columns: duration ago
  and file path.
parameters:
  filter:
    type: string
    description: optional path prefix or glob to filter results (e.g. 'src/coding', 'data/yaml')
    required: false
  limit:
    type: integer
    description: maximum number of files to return (default 26)
    required: false
```

tool dispatch:
  the tool calls: `p7 sourcecode.recently-modified '{"filter":"...", "limit":N}'`
  returns the formatted two-column output as the tool result

---

## where to add the tool registration

check src/coding.tools.* or the tool registry initialization for where
existing tools are defined. add `recently_modified` following the same pattern.
the tool name uses underscore (recently_modified) matching the existing
convention (read_file, search_code, list_modules etc.)

---

## p7 command interface

```bash
## show all recently modified files
p7 sourcecode.recently-modified

## filter to coding modules only
p7 sourcecode.recently-modified '{"filter":"src/coding"}'

## show last 13 changes in reasoning templates
p7 sourcecode.recently-modified '{"filter":"data/yaml/reasoning-templates","limit":13}'

## all changes in last session (filter by ntime window — optional enhancement)
p7 sourcecode.recently-modified '{"since":"ZDY6JCVRHY"}'
```

---

## success criteria

- [ ] command returns two-column output: duration + filepath
- [ ] duration column uses base.parser.duration (human-readable)
- [ ] most recently modified file appears first
- [ ] each file appears only once (most recent commit wins)
- [ ] filter arg correctly limits to path prefix/pattern
- [ ] limit arg respected (default 26)
- [ ] return format: { mode => 'size', data => $formatted_string }
- [ ] tool registered in coding zenka tool registry
- [ ] tool callable as recently_modified from within a coding task
- [ ] tool result is the formatted two-column string

#,,.,,,,.,,.,,,..,.,.,.,.,,..,,,.,,.,,,.,,.,.,..,,...,...,..,,..,,..,,...,..,,
#WJU4HNFPFYVT35HBNTQXXY5JHOA4ARGZWX5LVYVCJDRYEWUNJTSCLRFSSJV6Y3XZPP5GGHHUVPS3I
#\\\|NAWEP4KD264RI2MLU5V4OGCNVSBQ6YKM64UEC6QGNDQ7LZVNR5A \ / AMOS7 \ YOURUM ::
#\[7]T5DQQK23MQ6EPPOITCVHDQ24IYM5YTU3L74I6DM2V3I4GRN3EGAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
