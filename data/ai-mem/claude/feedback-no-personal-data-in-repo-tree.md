---
name: feedback-no-personal-data-in-repo-tree
description: never write personal data (emails, PII) into any file inside the repo working tree, even gitignored — use dynamic external-path helpers instead
metadata:
  type: feedback
  originSessionId: c1eec834-9b20-4b16-a6bf-4eea9ef8a64a
---

never write actual personal data (email addresses, specific personal file paths, etc.) into any file inside the git repository's working directory — **not even a gitignored file**. personal/sensitive data must live entirely outside the repo tree, referenced from repo-tracked code only via dynamic path-construction helpers or generic external path strings that carry no PII themselves.

**Why:** during the jobcenter evidence-dossier work ([[project-jobsite-report-dossier]]), assistant hardcoded the user's two real email addresses as a regex default directly into `modules/jobsite.report.mail_evidence_collect` (a tracked file). user stopped it immediately: "wait, you cannot write my personal email address into the public repository code.." First fix attempt used a `[load_config_file:'zenki/jobsite/local-secrets']` + gitignored file — user corrected again: "that will likely not work, because the path is outside the repository directory.." meaning even a gitignored file still physically sits inside the repo's working directory, which breaks the established pattern. Only the third attempt was accepted.

**How to apply:** the correct, user-confirmed pattern:
1. Personal data files live under external dirs already established by convention: `/data/<project>-data/` for bulk personal data (mail exports, letters, CVs — see `jobsite.cfg.*_dir` entries in `configuration/zenki/jobsite/start`), `/etc/protocol-7/<zenka>/<file>` for zenka-specific small config/secrets (precedent: `jobsite.cfg.profile_file`).
2. Do NOT hardcode even the `/etc/protocol-7/<zenka>/...` path as a literal string in a config file if a dynamic helper already exists for it — check `base.path-set-up.check-zenka-paths` (`catfile( <system.path.zenka-dirs.etc_P7>, <system.zenka.name> )`) first.
3. Use `<[file.zenka_dir.load]>->('cfg-dir:<zenka>/filename')` (implemented in `base.file.zenka_dir.load`) to resolve and read such files directly from module code — no config-line path string needed at all. Verified working: resolves to `/etc/protocol-7/jobsite/own-addresses.txt` for the `jobsite` zenka.
4. Search convention for finding this pattern next time: `ncode s src 'zenka-dirs.+etc'` or `ncode s src 'cfg-dir:'`.

If personal data is accidentally staged/committed, treat it as a real incident — check history for prior commits before assuming a working-tree fix is sufficient.

#,,..,..,,,..,..,,,,,,...,,.,,,,,,,.,,.,,,,..,..,,...,...,.,,,,..,,..,,,.,..,,
#RBPC3QZYPZMDPC4O7MXMO2HGSOGSLQYOGPXEVZGKOBX4FKZY3WCYORSXPA4G6HRS6P6AKV32BOIZU
#\\\|TF5GGJZBO5WZOG3D3BPEYJQWSQGHBV34IF27HQINECKQH5QB34S \ / AMOS7 \ YOURUM ::
#\[7]WIT6KVFEXJCQ47HSQUONEK2M2HNXBHO5GREUUGZGB6O5CCJVNOCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
