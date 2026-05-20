## [:< ##

# name  = task: bin/todo — self-contained todo list CLI
# descr = standalone perl script, YAML backend, no P7 dependency.
#         consistent with P7 style. foundation for bin/task (P7-connected).

## kimi memory

if in doubt about P7 patterns, coding style, or project context — read first:
```bash
cat data/ai-mem/kimi/MEMORY.md
cat data/ai-mem/kimi/coding-style.md
```

## context

a self-contained todo list tool usable without a running P7 system.
useful for coordinating parallel kimi sessions, tracking session work,
and as a foundation for the later P7-connected `bin/task` script.

style reference: look at `bin/is-true` or `bin/amos-chksum` for the
standalone script pattern (BEGIN block for lib path, clean output).

## signatures note

do not add signature stubs. do not run `bin/Protocol-7 sourcecode update-signatures`.
do not add or modify subroutine whitelists — these are managed separately.

---

## storage

YAML file at `~/.p7/todo.yaml` (created on first use).
one file, simple structure:

```yaml
## ~/.p7/todo.yaml
items:
  - id:       1
    text:     dispatch ncode-doc to kimi
    status:   done
    priority: normal
    tags:     [ kimi, ncode ]
    added:    2026-05-20T14:23:11
    done_at:  2026-05-20T15:01:44

  - id:       2
    text:     write smtp zenka task file
    status:   open
    priority: high
    tags:     [ smtp, zenka ]
    added:    2026-05-20T14:45:00
    done_at:  ~

next_id: 3
```

---

## commands

```
todo                        ## list open items (default)
todo list                   ## same
todo list all               ## open + done
todo list done              ## done items only
todo list <tag>             ## filter by tag

todo add <text>             ## add item, normal priority
todo add -h <text>          ## high priority
todo add -l <text>          ## low priority
todo add -t tag1,tag2 <text>  ## with tags

todo done <id>              ## mark done
todo done <id> <id> ...     ## mark multiple done

todo rm <id>                ## remove item
todo edit <id> <new text>   ## edit text

todo tag <id> <tag>         ## add tag to item
todo untag <id> <tag>       ## remove tag

todo clear                  ## remove all done items
todo reset                  ## remove everything (asks for confirmation)
```

---

## output format

ascii art framed, P7 lowercase narrative style, loved by users:

```
 .: todo :.──────────────────────────────────────────────────────────

  ▲  1 ·  dispatch ncode-doc to kimi              [ kimi · ncode ]
  ▲  2 ·  write smtp zenka task file              [ smtp · zenka ]
     3 ·  resume window-placement kimi task
  ▽  4 ·  update memory after session

 ──────────────────────────────────── 4 open  ·  2 done  ·  0 high ─
```

done items with dim checkmark when listed with `all`:

```
  ✓  5 ·  ncode-doc dispatched
  ✓  6 ·  ticker reread-config fixed
```

high priority: `▲` marker + amber color (when TTY)
low priority:  `▽` marker + dim
normal:        no marker

the framing rule at top and bottom uses `─` to terminal width (or 72 cols
if width unknown). header shows `: todo :.` in P7 style. footer shows counts.
look at how `bin/ncode` or `bin/amos-chksum` format their output headers for
style reference — consistent with the rest of the toolchain.

---

## implementation notes

- use `YAML::PP` or `YAML::XS` if available, fall back to `YAML` — check what
  is available: `perl -e 'use YAML::PP; print "ok\n"' 2>/dev/null || echo "no"`
- ids are integers, monotonically increasing, never reused
- `~/.p7/` directory created if absent
- no locking needed — single-user local tool
- ANSI color: high priority in amber, done items dimmed — but check if stdout
  is a TTY first, skip color when piped
- status values: `open` | `done` | `cancelled`
- priority values: `high` | `normal` | `low`

---

## test sequence

```bash
## basic workflow
todo add -h 'dispatch ncode-doc to kimi'
todo add 'resume window-placement after smtp'
todo add -l 'update memory'
todo list
## expected: 3 items, first one marked high

todo done 1
todo list
## expected: 2 open items

todo list all
## expected: 2 open + 1 done

todo tag 2 kimi
todo list kimi
## expected: 1 item with kimi tag

todo clear
todo list all
## expected: done items removed, open items remain
```

## success criteria

- [ ] `bin/todo` is executable and self-contained (no p7c dependency)
- [ ] YAML stored at `~/.p7/todo.yaml`, created on first use
- [ ] add/done/rm/list/edit/tag/untag/clear commands work
- [ ] priority flags -h/-l work on add
- [ ] list filters by tag, status, or all
- [ ] output format: id + priority + text + tags, clean columns
- [ ] ANSI color when TTY, plain when piped
- [ ] high priority items visually distinct
- [ ] done items show checkmark when listed with `all`
- [ ] `~/.p7/` directory auto-created if absent
- [ ] no signature stubs, no whitelist changes

#,,..,.,.,..,,..,,,..,,,,,,..,...,,,,,,,,,...,..,,...,...,.,.,.,,,,.,,..,,,,.,
#YRH2N4EZA5UIPKTH5JV4CP62IGSXEZISLYVRUCVCOIKATCHDEAWPJWXF42E3BPTRUB4VYNE4T6LP2
#\\\|JHMLIQPWSK4ZQDIJDWMMKX6Z4VTKKFF2TIB3UC2OLBDJ52VOOEY \ / AMOS7 \ YOURUM ::
#\[7]DHURHYILWSNKKB2Z3OA2LYOD5EBI3OUAF76UPHXCVNLGJTSRJ6DY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
