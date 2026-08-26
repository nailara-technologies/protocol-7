---
name: feedback-no-personal-data-in-repo-tree
description: never write personal data (emails, PII) OR infrastructure-identifying details (real hostnames, IPs of live deployments) into any file inside the repo working tree, even gitignored, even memory files — use dynamic external-path helpers or generic phrasing instead
metadata:
  type: feedback
  originSessionId: c1eec834-9b20-4b16-a6bf-4eea9ef8a64a
---

never write actual personal data (email addresses, specific personal file paths, etc.) into any file inside the git repository's working directory — **not even a gitignored file**. personal/sensitive data must live entirely outside the repo tree, referenced from repo-tracked code only via dynamic path-construction helpers or generic external path strings that carry no PII themselves.

**Extends to infrastructure identifiers, and to memory files themselves — not just PII in source code.** 2026-08-23: while writing a [[topic-next-steps]] entry about long-lived httpd connections, named the actual hostname (`pri`) of a live public-facing deployment in `data/ai-mem/claude/topic-next-steps.md`. User: "that memory entry is too public for that form.." — `data/ai-mem/claude/*.md` is git-tracked and gets committed same as any src file (confirmed: prior commits in this same session included `MEMORY-active.md`/`project-*.md` diffs), so anything written there is exactly as exposed as hardcoding it in `src/`. A real hostname isn't PII in the strict email/personal-file sense this memory originally covered, but the same repo-exposure logic applies to it — and memory files are easy to forget are part of "the repo" since they don't read like code. Fixed by generalizing to "a live public-facing deployment host" — specific enough to be useful, carries no identifying value if the repo is ever shared/pushed.

**Why:** during the jobcenter evidence-dossier work ([[project-jobsite-report-dossier]]), assistant hardcoded the user's two real email addresses as a regex default directly into `src/jobsite.report.mail_evidence_collect` (a tracked file). user stopped it immediately: "wait, you cannot write my personal email address into the public repository code.." First fix attempt used a `[load_config_file:'zenki/jobsite/local-secrets']` + gitignored file — user corrected again: "that will likely not work, because the path is outside the repository directory.." meaning even a gitignored file still physically sits inside the repo's working directory, which breaks the established pattern. Only the third attempt was accepted.

**How to apply:** the correct, user-confirmed pattern:
1. Personal data files live under external dirs already established by convention: `/data/<project>-data/` for bulk personal data (mail exports, letters, CVs — see `jobsite.cfg.*_dir` entries in `cfg/zenki/jobsite/zenka.v7`), `/etc/protocol-7/<zenka>/<file>` for zenka-specific small config/secrets (precedent: `jobsite.cfg.profile_file`).
2. Do NOT hardcode even the `/etc/protocol-7/<zenka>/...` path as a literal string in a config file if a dynamic helper already exists for it — check `base.path-set-up.check-zenka-paths` (`catfile( <system.path.zenka-dirs.etc_P7>, <system.zenka.name> )`) first.
3. Use `<[file.zenka_dir.load]>->('cfg-dir:<zenka>/filename')` (implemented in `base.file.zenka_dir.load`) to resolve and read such files directly from module code — no config-line path string needed at all. Verified working: resolves to `/etc/protocol-7/jobsite/own-addresses.txt` for the `jobsite` zenka.
4. Search convention for finding this pattern next time: `ncode s src 'zenka-dirs.+etc'` or `ncode s src 'cfg-dir:'`.

If personal data is accidentally staged/committed, treat it as a real incident — check history for prior commits before assuming a working-tree fix is sufficient.

#,,,,,,.,,...,...,,..,,,,,..,,,.,,,..,.,.,.,,,..,,...,.,.,..,,,.,,.,.,,..,,,,,
#ARHIFE7HL7OC5247ILGGE4BMRXDGZYB3JS4ODZEUJF6NTGHAUNORQRIGSCUJURYZKNTI5OKEHRZY4
#\\\|LVHILFSZ2VCXUPF5FERMTVJMIWSRPRSWXVJUV2BPGCMME56UTOF \ / AMOS7 \ YOURUM ::
#\[7]JFNUDMX7BMNPVDQSHNDSRCCURQYNUAZO75MVGVPNH53IXZBYNSCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
