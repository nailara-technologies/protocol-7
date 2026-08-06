## [:< ##

# name = REPO-PII-LEAK-PREVENTION
# descr = design for a repo-tracked but externally-configured system that
#         catches personal/sensitive data before it enters git history,
#         and audits full history for what's already there

## why this needs its own system, not just discipline

git history is append-only by design. a file removed in a later commit
is not gone — it is one `git log --all -- <path>` away from anyone who
looks. a commit message that narrates *what* was redacted and *why* can
itself be the leak, quoting the exact string it claims to have removed.
a filename can be identifying even when the file's content is not. none
of this is exotic — it is the standard shape of git-history PII leakage,
and it recurs precisely because each individual commit looks reasonable
in isolation. "don't commit personal data" as a purely human discipline
degrades under volume, especially with LLM-assisted commits, bulk
imports, and multi-file dumps where not every file gets read before
`git add -A`.

this is also not a novel problem space — dedicated model categories
exist purely for PII/sensitive-data detection in text and code, from
several vendors. the reasoning below assumes that lineage rather than
re-deriving it, and scopes down to what this repo specifically needs.

worth naming the actual limit here so the system isn't designed against
a false promise: remediation reduces propagation surface and time-to-
detection, it does not achieve non-existence. purging a record doesn't
un-happen the event — some parent context (a remote's reflog, a backup,
another clone, a collaborator's memory) retains a trace of it, and the
purge action itself is a new, observable fact layered on top. there is
no fully closed system to purge *within*. that isn't a reason to skip
remediation — surface area and dwell time are the actual, controllable
variables — it's a reason not to treat "purged" as "never happened" when
deciding how much residual disclosure is acceptable in what remains.

## leak vectors (generalized, not tied to any one incident)

a complete system has to check all of these, because each one defeats a
system that only checks a subset:

1. **tracked file content** — structured or unstructured files whose
   *content* is a personal record (assessment docs, CVs, exported
   personal data, anything with a real name + identifying detail
   co-located).
2. **filenames/paths themselves** — a filename can identify a person or
   a private domain/vhost even when the file's content is generic or
   the file no longer exists at HEAD.
3. **blob content strings inside otherwise-generic files** — a personal
   name or private domain embedded as a code identifier, cache key,
   config value, or comment inside a file that is not itself "about"
   that person.
4. **commit messages, both directions** — the commit that *introduces*
   sensitive content, and (more easily missed) a later commit that
   *removes* it while narrating the specifics in its message body. the
   second is more dangerous because it reads as responsible cleanup
   while being the actual leak.
5. **tag objects and tag messages** — a separate object type from
   commits; annotated tags carry their own message text and are easy to
   forget when sweeping commit messages only.
6. **bulk/unreviewed imports** — any multi-file import or directory dump
   where the commit is scoped to "add these files" rather than "read
   and approve each file." this is where accidental inclusion is most
   likely, because volume defeats manual review.
7. **fake or placeholder personal data** — synthetic names/data used for
   testing or examples should be treated identically to real PII by the
   detection/removal workflow. the goal is a reflexive process that
   doesn't require judgment calls about authenticity at commit time;
   carving out an exception for "it's not real" reintroduces the
   judgment call the system exists to remove.
8. **the incident record itself** — documentation of a past leak +
   remediation is useful and should exist, but must describe the
   *category* of exposure without repeating identifying specifics
   (names, filenames that embed names, domains). the documentation
   should not become vector 1.
9. **outbound dispatch payloads** — a genuinely different channel from
   git history: prompts sent to external inference APIs (`kimi_dispatch`/
   `claude_dispatch` and equivalents) can carry the same personal data
   the other vectors guard against, just leaving via a request instead of
   a commit. same underlying problem, different surface, needs its own
   check at dispatch time rather than being assumed covered by the
   repo-history-focused parts of this design.

## requirements

**detection, pre-commit and pre-push:**
- regex/pattern-based scan of the actual diff being committed (not just
  changed-file content at HEAD) — names, address/phone shapes, personal
  domains, structured-assessment-file markers.
- scan applies to: file content, file *paths* being added, and the
  commit message being authored in the same operation.
- pattern/keyword list lives **outside the repository tree** —
  `/data/<project>-data/` or equivalent, per the existing no-PII-in-repo
  memory rule for credentials. a scanner whose own config file is
  personal-data-shaped would be vector 1 applied to itself.
- optional second-pass, local-inference-assisted check (coding zenka or
  equivalent) for patterns too context-dependent for regex alone — e.g.
  distinguishing an intentional public author-attribution mention from
  an unrelated personal-data leak using a name that happens to match.
- entity taxonomy and substitution shape: don't invent one from scratch —
  the established pattern (a standard entity taxonomy — PERSON, LOCATION,
  PHONE_NUMBER, EMAIL_ADDRESS, etc. — feeding a detect → replace-with-
  numbered-placeholder (`[PERSON_1]`, `[ADDRESS_1]`) → reconstruct-on-
  return pipeline) is well-precedented in existing open PII-anonymization
  tooling and is the right reference shape, both for the pre-commit
  scanner's pattern categories and for vector 9's outbound dispatch check
  (send the placeholder-substituted version externally, reconstruct
  locally on the response). pick a specific free/open implementation to
  reference once evaluated — not chosen yet.
- **existing in-project precedent for reversible protection**: `modules/
  p7-log.anon.*` already does domain-separated Twofish key derivation
  from the system key-tree (`p7-log.anon.key`) and stores
  `[checksum, twofish(plaintext)]` pairs, reversible via `p7-log.anon.
  resolve`/`p7-log.anon.store` (`AMOS7::Twofish`). that pipeline targets
  log entries specifically, but the mechanism generalizes to files on
  disk: instead of encrypting an entire file (expensive, and requires
  knowing up front that it needs protecting) or fully deleting/redacting
  a detected span (lossy, no reconstruction), selectively Twofish-encrypt
  *only the matched sensitive spans* in place, using the same key-tree-
  derived domain-separated key approach. this is the useful middle
  ground specifically for the case where what needs protecting isn't
  known ahead of time — detection can run opportunistically/retroactively
  and encrypt just what it finds, without committing to a fixed entity
  taxonomy or an all-or-nothing encryption decision at write time.

**periodic full-history audit** (separate tool, not just the commit-time
gate, since gates only catch what passes through them going forward):
- sweep `git log --all` content (`-S"<pattern>"`), commit messages, tag
  messages, and filenames against the external pattern list.
- report, don't auto-fix — remediation (filter-repo path/text/message
  passes) is high-blast-radius and needs a human decision per hit, same
  as the tag-drift-fix script's clean/dirty/ambiguous/unmatched split
  rather than blind auto-apply.

**documented recovery procedure** (this repo already has the pieces,
they should be a runbook, not re-derived each time):
- `git filter-repo --path ... --invert-paths` for whole-file removal.
- `--replace-text` for blob content strings — does **not** touch commit/
  tag messages.
- `--replace-message` (or `--message-callback` for non-literal rewording)
  for commit/tag message text — a separate pass, easy to forget since
  the flag names are easy to conflate.
- any history rewrite orphans existing tags from the branch's real
  ancestry; re-anchoring (or deleting genuinely-abandoned tags) is a
  required follow-up step, not optional cleanup — a script for this
  already exists in this repo (`bin/dev/fix-tag-drift`).
- force-push is the last step, not a step to batch multiple unrelated
  fixes into — verify (content sweep + `git fsck` + tag-drift check)
  before every push, since the local rewrite succeeding does not
  guarantee it is the *complete* fix for a given exposure.
- assume GitHub (or any remote) retains pre-rewrite objects by hash
  until garbage-collected — force-push/retag does not delete them
  server-side. if the exposure is serious enough to matter at that
  level, closing it requires a support-side GC request, not another
  local push.

## open, not yet decided

- exact pattern-list format/location and who maintains it.
- whether the pre-commit/pre-push gate blocks the operation outright or
  warns-and-requires-explicit-override.
- whether the periodic audit runs as a standalone `bin/dev/*` script
  (matching `fix-tag-drift`'s shape) or as a zenka command.

#,,,.,.,,,,,,,.,,,,.,,..,,.,.,,,,,.,,,...,.,,,..,,...,...,...,,.,,,.,,.,,,,,.,

#,,,,,...,,,,,,..,.,,,,,,,.,.,,..,.,.,,..,.,,,..,,...,..,,.,.,.,.,..,,...,,..,
#V42G23VHZLJKTVUPVOT3GQT5U2DDUOVGQJ2IBXDG4YZZDIC64FRADMLDK2QY6ZSEQE6BXIJC4VGJW
#\\\|ZAECN2RAS5R2TYU35WNZX67U54GNM4MEGCYXBY7IYLOL7V37KPF \ / AMOS7 \ YOURUM ::
#\[7]HU5KRR62GGKJ7XXCOACIIK2Z7FHRC2EDZSVICO3ER73VC5HE4QAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
