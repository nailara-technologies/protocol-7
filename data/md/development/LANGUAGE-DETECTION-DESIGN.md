
    .: base.language — layered language detection system :.


##[ overview ]################################################################

    language detection as a shared base service, callable from any zenka.
    three detection layers escalate only when confidence is insufficient.
    builds on the existing base.locales infrastructure and language codes.

    consumers :

        job-site-scan.util.fix_encoding   ← primary motivation
        language.detect command           ← standalone p7c access
        translation dispatch              ← route to correct model
        model benchmarking                ← score model per language
        future: channels zenka            ← auto-detect reply language


##[ detection layers ]########################################################

    .: layer 1 — byte frequency heuristic :.

        fastest path — no files, no deps, microseconds.

        - script range detection : cyrillic / latin / arabic / cjk etc.
          derived from unicode block ranges, eliminates most candidates
          immediately based on byte pattern alone

        - per-language character frequency scoring :
          for each candidate language, count how many of its encoding's
          special chars appear in the text weighted by expected frequency.
          german:  ä ö ü ß e n i s r t  [ high frequency latin chars ]
          french:  é è ê à ç ô û
          bulgarian: full cyrillic block distribution
          result: language + raw score

        - confidence: high for long text, low for short strings < 20 chars
          threshold: score_leader / score_second > 2.0  →  confident

    .: layer 2 — wordlist match :.

        activated when layer 1 confidence < threshold.
        milliseconds, small memory footprint.

        wordlist sources [ in priority order ] :
          1. data/locales/<zenka>/locales.<lang>  — existing locale strings
          2. /usr/share/dict/<lang>               — system aspell/hunspell dicts
          3. data/language/wordlist/<lang>.txt    — downloaded wordlists [ see below ]

        scoring: tokenize input → intersect with wordlist → hit_ratio
          hit_ratio = matched_tokens / total_alpha_tokens
          confident when hit_ratio > 0.35 for winning language
          and gap to second place > 0.15

        wordlist download [ via debian zenka ] :
          configured languages trigger automatic aspell dict install:
            debian.install_package( "aspell-$lang_code" )
          extracted to data/language/wordlist/<lang>.txt on first use
          refreshed when package version changes

    .: layer 3 — inference fallback :.

        activated when layers 1+2 both below confidence threshold.
        used for: short strings, mixed content, ambiguous scripts.

        - select smallest available model with language detection capability
          preference: cpu-only 4B models [ gemma-3-4b, qwen2.5-3b etc. ]
          queried from model registry: models with tag 'language-detection'

        - prompt template: data/language/prompt/detect.tmpl
          returns: { language: "de", confidence: 0.94, alternatives: [...] }

        - result cached by content checksum [ AMOS checksum of input ]
          cache stored in data/language/cache/detect/


##[ module layout ]###########################################################

    base.language.detect            ← main entry point, orchestrates layers
    base.language.heuristic         ← layer 1: byte frequency scoring
    base.language.wordlist          ← layer 2: dict lookup + hit ratio
    base.language.inference         ← layer 3: model query + cache
    base.language.wordlist_install  ← debian zenka integration for dict download
    base.language.encoding_map      ← language → encoding candidates table

    shared with base.locales :
      same language code convention: 'de' 'en' 'fr' 'bg' 'pl' etc.
      existing locale files contribute to layer 2 wordlist scoring
      system.language used as prior when available


##[ encoding map ]############################################################

    centralized table, shared between detection and fix_encoding :

    %language_encoding = (
        de => [qw| ISO-8859-15 ISO-8859-1  Windows-1252 |],
        fr => [qw| ISO-8859-15 ISO-8859-1  Windows-1252 |],
        pl => [qw| ISO-8859-2  Windows-1250              |],
        bg => [qw| Windows-1251 ISO-8859-5               |],
        ru => [qw| Windows-1251 KOI8-R                   |],
        cs => [qw| ISO-8859-2  Windows-1250              |],
        el => [qw| ISO-8859-7  Windows-1253              |],
        tr => [qw| ISO-8859-9  Windows-1254              |],
    );

    job-site-scan.util.fix_encoding imports this via base.language.encoding_map
    instead of maintaining its own copy. one table, all modules use it.


##[ data.language tree ]######################################################

    data/
      language/
        wordlist/
          de.txt         ← extracted aspell-de word list
          bg.txt
          fr.txt
          ...
        cache/
          detect/        ← AMOS-checksum keyed inference results
        prompt/
          detect.tmpl    ← inference prompt template
        config/
          languages.yaml ← configured languages + download state


##[ call interface ]##########################################################

    .: module call :.

        my $result = <[base.language.detect]>->( $text );
        ## returns hashref:
        ##   { language => 'de', confidence => 0.91,
        ##     method => 'wordlist', alternatives => ['nl', 'fr'] }

        my $result = <[base.language.detect]>->( $text, { hint => 'de' } );
        ## hint biases layer 1 scoring, skips layer 3 if hint confirms

    .: p7c command :.

        p7c language.detect "text to detect"
        p7c language.detect :file:/path/to/file

    .: fix_encoding integration :.

        ## when language unknown, detect first then repair ##
        my $lang   = <[base.language.detect]>->($raw)->{'language'};
        my $fixed  = <[job-site-scan.util.fix_encoding]>->($raw, $lang);


##[ model benchmarking integration ]##########################################

    language quality scoring feeds the model registry directly :

        model registry entry gains :
          languages_tested : [de, bg, en]
          language_quality :
            de : 0.87
            bg : 0.72
            en : 0.95
          language_updated : 2026-05-14

    benchmark flow :
        1. select test corpus per language [ data/language/bench/<lang>/ ]
        2. run sample texts through model via coding zenka tool
        3. score output: wordlist hit ratio + grammar heuristics + native speaker score
        4. write result to model registry
        5. language.detect layer 3 queries registry for model selection

    this enables : p7c models.best_for language=de size=4B cpu_only=1
    returns the highest quality cpu-runnable model for german text tasks.
    gemma-3-4b and qwen2.5-3b are strong candidates for this tier.


##[ bulgarian / translation path ]############################################

    bulgarian is already in the encoding map and locale system [ locales.bg ].
    the detection system treats it identically to other languages.

    once two bulgarian models are registered with quality scores :
        translation dispatch: detect(source_text) → route to bg model
        job-site-scan: detect german job posting → translate summary to bg
        consensus: run same job through de model + bg model → compare

    no special casing required — language codes are first-class throughout.


##[ open questions ]##########################################################

    - where does base.language live as a zenka?
      option a: loaded into every zenka that needs it [ like base.locales ]
      option b: standalone language zenka, all detection routed through it
                [ better for caching — one cache shared across all zenki ]
      option b preferred once traffic justifies it; start with option a.

    - wordlist format: raw newline-separated words, or AMOS-indexed?
      raw is simplest and compatible with aspell extraction.
      AMOS index adds fast lookup but adds complexity — defer.

    - confidence threshold values: 2.0 ratio and 0.35 hit_ratio are guesses.
      tune against real job posting samples once first version runs.


#############################################################################

#,,.,,..,,...,,..,.,,,.,.,...,,.,,,.,,,,.,,..,..,,...,...,..,,,..,,..,,..,...,
#WYBKKSCKIKKXYYLWZOKOKT4V2E7HKHW6NCDFBPZZUT2N3W63JYBTJ3K22H4REMQCUZ2EPLHVXN6YK
#\\\|NC67GJ62VPXLTOHUECJ43YASPXR2I6AZ2J3ZYFWEKH4FYQE723N \ / AMOS7 \ YOURUM ::
#\[7]MQ2DJLE3W222K6AIIMMG3LLG47LNNTLFESHQXCOXMUXRAOHT7GBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
