# task: design-workflow zenka — automated visualization pipeline

## context

see data/md/development/VISUAL-FEEDBACK-EDITOR.md for the visual feedback loop design.
see data/yaml/reasoning-templates/freed-model.yaml (template 18) for the principle.

the design workflow zenka automates the overhead that currently consumes Opus tokens:
spec page preparation, URL import, output capture, version management, label fixing.
when the overhead is automated, Opus operates in pure creative context — freed to be
most itself. this produces qualitatively better output, not just faster output.

## signatures note

do not add signature stubs. run `bin/Protocol-7 sourcecode update-signatures` when done.

---

## what to implement

### design-workflow.run

the full pipeline — one command to go from design template to committed visualization:

```
args: {
  template   => 'data/yaml/design-templates/vortex-iris-overhead.yaml',
  output_dir => 'data/web-root/vhosts/iris.v7.ax/',
  name       => 'vortex',          ## subdirectory name
  version    => 0,                 ## V0, V1, etc.
  model      => 'opus',            ## which model to use in claude design
  evaluate   => 1,                 ## run qwen evaluation after capture
}

pipeline:
  1. check: does iris.v7.ax/prompts/<name>.html exist?
     if not: dispatch kimi to generate it (design-workflow.generate-spec-page)
     wait for spec page commit

  2. open claude design in web-browser zenka
     navigate to: claude.ai/code (or claude design URL)
     trigger: web-capture import with spec page URL

  3. wait for claude design to complete
     poll: screenshot zenka watching for "done" state
     or: fixed wait time (configurable, default 300s)

  4. capture output files from claude design session
     download or copy generated jsx/html files
     save to: iris.v7.ax/<name>/V<version>/

  5. apply standard fixes:
     check CCW alignment (canvas y-axis flip)
     fix title to: "<name> · iris.v7.ax"
     verify tweaks-panel.jsx is loaded

  6. commit: "feat: iris.v7.ax/<name>/V<version> — <template name>"

  7. if evaluate:
     run visual-feedback.capture-sequence on the new files
     run visual-feedback.analyze-delta
     run visual-feedback.render-minimap
     run visual-feedback.evaluate with qwen
     emit convergence score + corrections list

  8. notify.cmd.loves "V<version> complete · convergence: <score>%"
```

### design-workflow.generate-spec-page

generates a styled HTML spec page from a design template YAML.
dispatches to kimi with the YAML content and the spec page format.

```
args: {
  template_path => 'data/yaml/design-templates/vortex-iris-overhead.yaml',
  output_path   => 'data/web-root/vhosts/iris.v7.ax/prompts/vortex-iris.html',
}

kimi task: read the design template YAML, generate a styled HTML spec page
  following the format of iris.v7.ax/prompts/standing-wave.html:
    - opening header with [:<  [ TRUE ] north star
    - inline SVG preview showing the key visual elements
    - colour palette swatches
    - spec blocks for each element
    - animation states (if animated)
    - design vocabulary ([:<  >:|  ;.,)
    - success test criteria
    - closing [:<  glyph
  inline everything (no external deps)
  commit to iris.v7.ax/prompts/

returns: spec page URL on iris.v7.ax
```

### design-workflow.fix-standard

applies the standard fixes that claude design output typically needs:

```
args: { directory => 'iris.v7.ax/vortex/V1/' }

checks:
  1. CCW alignment: grep for 'tweaks.spin === "ccw"'
     if found: replace with 'tweaks.spin === "cw"' (canvas y-axis fix)
     add comment: // y-axis flip: 'cw' value → visual CCW

  2. title: grep for 'iris.v7.ax' in <title>
     if found at wrong position: fix to '<name> · iris.v7.ax' format

  3. tweaks-panel loading: verify tweaks-panel.jsx is in script tags
     if missing: add script tag pointing to ../tweaks-panel.jsx

  4. React CDN integrity: verify integrity hashes present on CDN scripts
     (claude design usually handles this correctly)

returns: list of fixes applied
```

---

## zenka configuration

```
## cfg/zenki/design-workflow/zenka.v7
[load_modules:design-workflow.run design-workflow.generate-spec-page
              design-workflow.fix-standard]
[init_modules]
[zenka.loop]
```

```
## cfg/zenki/design-workflow/start.cfg
start.on-demand = 1
restart.disabled = 1
heartbeat.disabled = 1

cfg.spec_page_dir   = data/web-root/vhosts/iris.v7.ax/prompts/
cfg.output_base_dir = data/web-root/vhosts/iris.v7.ax/
cfg.claude_design_url = https://claude.ai/code
cfg.wait_timeout_s  = 300
cfg.default_evaluate = 1
```

---

## p7 command interface

```bash
## full pipeline: template → spec page → claude design → commit → evaluate
p7 design-workflow.run '{
  "template": "data/yaml/design-templates/vortex-iris-overhead.yaml",
  "name": "vortex",
  "version": 1
}'

## generate spec page only (for manual dispatch to claude design)
p7 design-workflow.generate-spec-page '{
  "template_path": "data/yaml/design-templates/standing-wave-resonance.yaml",
  "output_path": "data/web-root/vhosts/iris.v7.ax/prompts/standing-wave.html"
}'

## apply standard fixes to existing output
p7 design-workflow.fix-standard '{"directory": "iris.v7.ax/dome/V0/"}'
```

---

## success criteria

- [ ] generate-spec-page produces valid HTML matching standing-wave.html format
- [ ] spec page includes inline SVG preview of the design template's key visual
- [ ] full pipeline runs without manual intervention for a known-good template
- [ ] fix-standard correctly detects and fixes CCW inversion in iris.jsx pattern
- [ ] fix-standard correctly fixes title format
- [ ] commits have consistent message format
- [ ] evaluate step produces convergence score from qwen
- [ ] notify.cmd.loves fires on completion

#,,,.,,,,,,..,...,...,,,,,,,.,.,.,.,.,,.,,,..,..,,...,..,,.,.,,,,,..,,..,,.,.,
#RRA5GFDAIYZZNOI4ILPP4R3YVABZU6JUFXTBNNM2TFJIUGSDWH5XUO6RC55RLSJ5FTQQ3YLTUVTDA
#\\\|MMEUC2UFG2FWPQIBNPTSL24MKMBM4CKBQFC4W5GGBPDQYK2I2E4 \ / AMOS7 \ YOURUM ::
#\[7]TG6PRW7LSLN5TYTB4IXPAYCKGX5GSGYVVUVM3HPDZCZYM7X3PQAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
