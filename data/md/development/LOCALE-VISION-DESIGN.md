
    .: base.locales — vision-guided harmonic translation system :.


##[ overview ]################################################################

    locale strings are not just translated — they are visually optimized.
    a vision model inspects the rendered result after each translation and
    iterates until the label achieves harmonic balance in its render context.

    this works equally for all render targets the system already produces:

        web / html         ← headless browser screenshot or httpd render
        terminal / ansi    ← X11 screenshot, framebuffer, or tmux capture
        graphics-matrix    ← orbital visualization SVG / canvas export

    the vision model sees genuine visual composition in all three cases.
    translucency, color, spatial weight, line breaks, and alignment are
    all part of the harmonic score — not just linguistic accuracy.


##[ why terminal rendering matters ]##########################################

    our terminal applications already have rich visual identity:
    translucency, ANSI color palette, box-drawing characters, glow effects.

    this means:
      - a translated label interacts with composited layers behind it
      - color contrast and legibility vary with the background in context
      - a label that works in one terminal theme may fail in another
      - character width differences [ latin vs cyrillic vs CJK ] shift layouts

    a vision model can detect all of these directly from a screenshot.
    no heuristic character-count logic is needed — the model just sees.


##[ translation + optimization loop ]#########################################

    .: phase 1 — initial translation :.

        model receives :
          - source string and key
          - all existing entries in the same locale file [ style context ]
          - render target hint [ web / terminal / matrix ]
          - neighbouring rendered labels [ visual style reference ]

        model writes initial translation to locale file in standard format :
          key : translated string

    .: phase 2 — render :.

        zenka renders the UI component containing the new label.
        render method by target :

          web        →  headless chromium screenshot [ existing httpd infra ]
          terminal   →  X11 screenshot via scrot/import or tmux capture-pane
                        with compositor active [ translucency preserved ]
          matrix     →  graphics-matrix export [ orbital visualization frame ]

        render is cropped to label region + reasonable margin for context.
        full-screen render preserved as reference for color/contrast analysis.

    .: phase 3 — vision inspection :.

        vision model receives :
          - rendered screenshot [ cropped + full context ]
          - original source string for reference
          - current translation
          - target: harmonic balance checklist [ see below ]

        scores and optionally suggests :
          - label too long : find shorter synonym or split to two lines
          - visual weight off : adjust capitalization, punctuation, spacing
          - color contrast insufficient : flag to zenka for palette adjustment
          - alignment broken : flag layout issue [ zenka must fix template ]
          - translucency conflict : label legible against all expected backgrounds?

    .: phase 4 — iterate or approve :.

        if score >= threshold : approve, store render hash, commit
        if score < threshold and rounds < max_rounds :
            model applies suggestion, re-render, re-inspect
        if max_rounds reached : store best result with score, flag for review

    .: phase 5 — commit :.

        locale file entry gains metadata comment block :
          key : translated string
          key.score : 0.91
          key.render_hash : <AMOS checksum of approved render>
          key.render_target : terminal
          key.rounds : 2

        render hash locks the approved visual state.
        if UI template changes and hash no longer matches,
        entry is flagged for re-review on next locale load.


##[ harmonic balance checklist ]##############################################

    vision model evaluates against these axes :

        legibility       ← readable at expected font size and contrast
        weight balance   ← label visual mass proportional to its container
        line rhythm      ← if multiline: line breaks at natural phrase boundaries
        color harmony    ← label color integrates with surrounding palette
        spatial fit      ← no overflow, no excessive whitespace
        translucency     ← legible against range of background compositions
        style coherence  ← matches tone and register of sibling labels


##[ locale file format extension ]############################################

    backward compatible — existing loaders ignore unknown keys gracefully.
    base.locales.load_file reads key : value, skips lines it does not parse.

    existing format [ unchanged ] :
        playlist_updated : Die Playliste wurde aktualisiert..

    extended format [ vision-approved entries ] :
        playlist_updated : Die Playliste wurde aktualisiert..
        playlist_updated.score : 0.91
        playlist_updated.render_hash : EWVYDKMW3QIKBPVPLJT5KD
        playlist_updated.render_target : terminal
        playlist_updated.rounds : 1

    auto-translate entries that have never been vision-reviewed
    carry no metadata — they are valid but flagged as unreviewed
    in the locale registry.


##[ auto-translate flow ]#####################################################

    trigger: zenka requests a locale key that does not exist for active language

        1. base.locales detects missing key
        2. queues translation request: key + source string + render_target
        3. translation model produces initial string [ smallest capable model ]
        4. if render_target available: enter vision loop
           else: store without render hash, mark as text-only-approved
        5. result written to locale file immediately [ zenka uses it now ]
        6. vision review completes asynchronously, updates file + hash

    this means UI never blocks — translation is available immediately,
    visual optimization happens in the background and locks on completion.


##[ render target registry ]##################################################

    each zenka declares its render targets in start config :

        locales.render_target = terminal
        locales.render_target = web

    graphics-matrix zenka additionally exports :
        locales.render_target = matrix
        locales.matrix_export_cmd = graphics-matrix.export_frame

    terminal screenshot method configured per zenka :
        locales.screenshot_cmd = scrot -u -q 90 -
        locales.screenshot_cmd = tmux capture-pane -p   [ text-only fallback ]

    web screenshot uses existing httpd infrastructure :
        headless chromium driven via existing httpd.benchmark or new util


##[ vision model selection ]##################################################

    vision-capable models queried from registry:
        models with tag 'vision' + language quality score for target language

    preference order :
        1. vision model already warm [ loaded in inference server ]
        2. smallest vision model with quality >= threshold for target language
        3. remote node vision model if local VRAM insufficient

    for terminal rendering: even modest vision models [ 7B ] perform well
    since terminal screenshots are low-resolution and high-contrast.
    this may be achievable on cpu-only nodes for some languages.


##[ graphics-matrix integration ]#############################################

    the orbital visualization already has harmonic geometry as a core principle.
    labels in the matrix space go through the same optimization as visual geometry:

      - label position affects node glow and spatial weight
      - translated labels of different lengths shift the visual balance
      - the vision model sees the full orbital frame, not just the label crop
      - score includes: does the label integrate with the surrounding field?

    this connects locale translation directly to the cursor / glow / channel
    pipeline already implemented. a translated label is not approved until
    the vision model confirms it harmonizes with the orbital field it inhabits.


##[ module layout ]###########################################################

    base.locales.auto_translate       ← entry point: missing key handler
    base.locales.vision_review        ← render + vision inspect loop
    base.locales.render.terminal      ← terminal screenshot capture
    base.locales.render.web           ← headless browser render
    base.locales.render.matrix        ← graphics-matrix frame export
    base.locales.hash_check           ← render hash validation on load
    base.locales.write_entry          ← write key + metadata to locale file


##[ open questions ]##########################################################

    - render hash granularity: hash the cropped label region only, or
      include a hash of the full-frame color histogram as context?
      full histogram catches palette shifts that affect contrast.

    - async vs sync vision review: current proposal is async [ zenka gets
      translation immediately, vision review updates later ]. is there a
      case where blocking on vision review is preferable?
      answer: only for release builds where unreviewed strings are rejected.

    - multiline label handling: some terminal UIs wrap at fixed column width.
      vision model needs to know the column width constraint.
      proposal: zenka declares locales.max_label_width = 40 in start config.

    - shared render cache: if two zenki have the same label in different
      locale files, can they share the render hash?
      yes, if render_target and template context match — keyed by
      AMOS checksum of ( source_string + render_target + template_hash ).


#############################################################################

#,,,.,...,,.,,,,,,,,,,,,,,.,,,,..,,,,,,.,,...,..,,...,...,,,.,..,,,..,..,,,.,,
#4RUQRIXXY2F5TX5E32UBJV4VNI6OE64FTHEGOBLONVU27KZSPK2RSWC5CKN76GBCCZBQSFCC64DU4
#\\\|RKSHFIAD3G6R7P7ZM3H5XCQ6NQ53ABTETVX2IS7RSQLPUNGQ5PA \ / AMOS7 \ YOURUM ::
#\[7]A2ELCIMG7DJJRI2XCL7XIVD7XMASOSB46Z6ZQJ522WJOTIGGIOBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
