---
name: language detection system
description: three-layer language detection as shared base service, encoding map, locale vision pipeline
type: project
originSessionId: 9e81219d-67a4-445c-8e14-06a7463ea31e
---
Three design docs committed 2026-05-14:
- data/md/development/LANGUAGE-DETECTION-DESIGN.md — three-layer detection
- data/md/development/LOCALE-VISION-DESIGN.md — vision-guided harmonic translation
- fix_encoding rewritten generically (no word list), base.language.encoding_map created

Layer stack: byte-frequency heuristic → wordlist match → inference fallback.
Layer 1b: encoding char table (0x80-0xFF via Encode) always available, zero deps.
Graceful degradation: confidence ceiling 0.75 without wordlist, tagged {wordlist=>0}.
East-asian rule: ja/zh/ko use validate-not-substitute, NOT bigram FFFD repair.

encoding_map: 30 languages, %aspell_package for debian auto-install.
Language→encoding: german→ISO-8859-15, bulgarian→Windows-1251, etc.

Locale vision pipeline: model writes translation → render screenshot (web/terminal/matrix) → vision model scores harmonic balance → iterate → store render hash. Works for terminal apps with translucency too. Auto-translate fills missing keys async, vision review locks result.

**Why:** fix_encoding needed generic solution; language detection shared by translation dispatch, model benchmarking, channels zenka.

**How to apply:** base.language.detect implementation is next kimi task after bin/chat.

#,,,,,...,.,.,,..,,,.,.,.,.,,,.,,,..,,,.,,.,.,..,,...,...,..,,.,.,,..,..,,...,
#F4POJR476SD7CHBSOLJF6VVM2FSOZFZS6BVIDYCCXG5UGTYLZHIIAEL3BH3RG5E4BMDG3RGRU6LBQ
#\\\|ITFZ4QFCU24NJ7IJDFPT4WAGO6CKHZLVGPJDYHDU74FLZQ6CT6R \ / AMOS7 \ YOURUM ::
#\[7]CUNNKS65CSJMJZR2SQYGR4TAT6SLTZU2BPMLFLBV2D7C5WMQKUCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
