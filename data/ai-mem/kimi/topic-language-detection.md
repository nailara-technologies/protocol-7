# Language Detection System — Three-Layer Architecture (May 12 2026)

> Extracted from MEMORY.md. See main memory for cross-references.

## Status
Layer 1 complete, Layer 2 stub, Layer 3 stub. Design docs committed. Code changes staged (awaiting signature password).

## Design Docs
- `data/md/design/LANGUAGE-DETECTION-DESIGN.md` — Three-layer spec + encoding strategy + east-asian rules
- `data/md/design/CHAT-SCRIPT-DESIGN.md` — File-backed multi-model conversation with channels, caller detection, `:all:` consensus mode
- `data/md/design/LOCALE-VISION-DESIGN.md` — Locale-aware visual rendering pipeline

## Modules Created/Modified

| module | purpose |
|--------|---------|
| `base.language.detect` | Orchestrator: heuristic → wordlist → inference |
| `base.language.heuristic` | Layer 1: script range + encoding char-map scoring |
| `base.language.encoding_map` | Centralized `%language_encoding` for 25+ languages + aliases + aspell packages |
| `base.language.encoding_special_chars` | Extract non-ASCII char set from any single-byte encoding (bytes 0x80-0xFF) |
| `jobsite.util.fix_encoding` | Mojibake repair; east-asian guard prevents bigram substitution for ja/zh/ko |
| `jobsite.util.build_prompt` | Generic prompt builder; extracts candidate name from `profile.txt` dynamically; no hardcoded personal info |
| `jobsite.dispatch.repair` | Now calls shared `build_prompt` with `$defects` arrayref |

## Key Technical Decisions

**Layer 1b char-map scoring**: When no wordlist installed, `encoding_map`'s encoding tables provide minimal character-map scoring (always available, zero deps). Confidence ceiling 0.75 when wordlist missing.

**East-asian FFFD rule**: Bigram context scoring does NOT apply to logographic text. `ja/zh/ko` must use validate-not-substitute (try encodings → validate decoded result has plausible script ratio > 20%).

**Generic prompt builder**: Candidate name extracted from `/etc/protocol-7/jobsite/profile.txt` first-line header (`# Candidate Profile — Name`). Repair mode accepts `$defects` arrayref and prepends "RE-ASSESS" framing.

**Checksum algorithms**: AMOS7 (`<[chk-sum.amos]>`) → 7-char; BMW-L13 (`<[chk-sum.bmw.str-b32.L13]>`) → 13-char base32.

## ptd -c Enhancement
`bin/ptd -c` (perl syntax checker) now reports real `perl -c` errors while filtering out false positives from P7 angle-bracket syntax (`<site-yaml.import_max_pages>`). Returns exit code matching `perl -c`.

## Early Pagination Break Optimization
Default scan stops when a page returns all duplicates. `scan :full:` disables optimization. Queue-preload protection for resumed scans prevents re-fetching already-queued jobs.

#,,..,,,,,,,,,...,,,.,.,,,,..,.,.,.,,,,..,..,,..,,...,...,...,,,,,,..,.,,,,.,,
#F2U7PWPY4DJZNFM4MZQZT32UW7OYMY4U5BNYT7BGAITKILG3IOWROCRZZIPKP24JQLQLYILRCFZOQ
#\\\|TFFD4N245KXAKIHZ6Y772LZOGIBQWCVTYCZ7PGYNJZ24ZAD5ET2 \ / AMOS7 \ YOURUM ::
#\[7]P2FSQQNIBNO5VNK5AUJLTIKMJJYBEW7QFSPT7U2RYKH3I4CM2CCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
