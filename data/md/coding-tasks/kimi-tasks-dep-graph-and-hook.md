## kimi tasks: dependency graph + pre-commit length check ##

two self-contained tasks for kimi to implement.
mark checklist items as completed alongside the corresponding commits.

---

## task 1: pre-commit descr/param length check ##

quick task — add a staged-file check to the existing pre-commit hook.

### context

all command modules in modules/ follow this header format:
```
# name  = module.cmd.name
# param = <args>
# descr = one-line description
```
the command table in nshell/list output has fixed width — lines over ~55
chars cause wrapping or truncation. a manual pass just fixed ~52 files;
this prevents regression.

### find the hook first

- [x] locate pre-commit hook — found at `bin/dev/git-hooks/pre-commit`

### implement the check

- [x] get staged files matching `modules/*cmd*` via
      `git diff --cached --name-only`
- [x] for each staged file grep lines matching `/# (descr|param) = /`
- [x] extract value after `= ` and measure length
- [x] if length > 55: print filename, line number, content, and length
- [x] set exit code 1 to block commit on any violation
- [x] print summary line on failure:
      `:: descr/param lines too long — shorten before committing`
- [x] match existing hook style — added `SKIP_DESCR_CHECK=1` override

### notes

- threshold is 55 — do not change without flagging it
- the 55 counts only the content after `# descr = ` or `# param = `

### review

- [x] reviewer confirms hook triggers correctly on a test violation
      — independently verified: caught both descr (90 chars) and param
        (87 chars) violations with filename, line, count, and content
- [x] reviewer confirms clean commits are not blocked

### completed — commit 16a1e661c

---

## task 2: static dependency graph tool ##

heavier task — standalone script that maps all module-to-module call
sites across the entire modules/ directory.

### context

protocol-7 modules call each other with the syntax `<[module.name]>->()`
which the loader parses before compilation. mapping these statically is
the prerequisite for lazy loading and standalone script export (both on
the roadmap).

### output file

- [x] write text adjacency list to
      `data/md/documentation/module-dependency-graph.txt`
- [x] write graphviz dot format to
      `data/md/documentation/module-dependency-graph.dot`
      (only when run without `--module` filter)

### implementation: bin/dev/dep-graph

- [x] add `data/lib-path/pm` to `@INC` in BEGIN block
      (see other bin/dev/ scripts for the pattern)
- [x] extract canonical module name from `# name  = ` header line
      (not from filename — header is authoritative)
- [x] scan for primary call pattern: `<\[([a-zA-Z0-9._-]+)\]>`
- [x] also scan for runtime dispatch: `$code\{['"]([a-zA-Z0-9._-]+)['"]\}`
      (used at swap boundaries — see CLAUDE.md swap-boundary section)
- [x] ignore AMOS7 signature footer (last 5 lines of each file:
      the `#,,..,` checksum line and the four `#\\\|` / `#\[7]` lines)
- [x] record edge weight = number of call sites (identifies hot paths)
- [x] no protocol-7 runtime needed — pure static file scan

### command-line flags

- [x] `--text`         sorted adjacency list, default output mode
- [x] `--dot`          graphviz digraph format
- [x] `--reverse`      show reverse deps (who calls module X)
- [x] `--module=NAME`  limit output to one module and its direct deps
- [x] `--depth=N`      hops to follow with --module (default: 1)

### style

- [x] lowercase comments, `[ annotation ]` not `( annotation )`
- [x] use `$ARG` instead of `$_`
- [x] follow conventions visible in `bin/dev/division-13-table`
      as a nearby style reference

### review

- [x] reviewer runs `bin/dev/dep-graph --module=decoder.zenka.receive_entropy`
      and confirms all `<[...]>` call sites in that file appear in output
- [x] reviewer runs `bin/dev/dep-graph --reverse --module=base.log`
      and spot-checks a few callers against grep results
- [x] reviewer checks dot output structure is valid (graphviz not installed)
- [x] reviewer confirms footer lines are excluded from scan

### completed — ready for commit

#,,..,.,,,.,,,,,,,,.,,,.,,..,,...,.,,,..,,,,,,..,,...,..,,..,,,.,,...,,,,,,.,,
#NZGEIW6RWG67J4NNFZOWLURTPVBHPFDSIKRTX7C5X3FMTT42LTREPPXT6DK44ZLJ77QDDFGRC6S36
#\\\|75GFBZ4LQ4JJE57QDOBFTHSH6NIHRDYRSKYHAV7V56DDA2JFTP7 \ / AMOS7 \ YOURUM ::
#\[7]2UPABIWNPF77NDAMVIVCLWVRFOASYSQTBRNLHTYNZEWXW7NULGCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
