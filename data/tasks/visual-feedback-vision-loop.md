# task: visual-feedback vision evaluation and correction loop

## context

implements the vision-model evaluation half of the visual feedback editor
(see data/md/development/VISUAL-FEEDBACK-EDITOR.md for full design).

requires visual-feedback-capture-analyzer.md to be completed first —
this task depends on capture-sequence, analyze-delta, and render-minimap.

the full loop: design prompt + file → capture → minimap → vision model
→ corrections → coding zenka → re-capture → repeat until convergence.

the default vision model is qwen (local). the system is model-agnostic —
any vision model accessible via p7c coding.call-tool or direct API works.
opus 4.7 can be wired in later via the generic API bridge for higher quality.

## signatures note

do not add signature stubs. run `bin/Protocol-7 sourcecode update-signatures` when done.

---

## modules to implement

### visual-feedback.evaluate

sends the minimap to the vision model and parses the structured response.

```
args: {
  minimap_png    => '/var/protocol-7/visual-feedback/minimap.png',
  design_prompt  => 'CCW bioluminescent UV vortex, implosion direction...',
  iteration      => 1,
  vision_model   => 'qwen-vl',    ## or 'kimi-vision', 'llava', etc.
}

returns: {
  convergence   => 67,            ## percentage 0-100
  corrections   => [
    {
      element   => 'rotation direction',
      current   => 'CW',
      target    => 'CCW',
      fix       => 'reverse animation transform direction',
      priority  => 1,
    },
    {
      element   => 'arm color',
      current   => 'gold #FFD700',
      target    => 'UV violet #8A2BE2',
      fix       => 'change arm stroke to #8A2BE2 with glow',
      priority  => 2,
    },
  ],
  raw_response  => '...',
  converged     => 0,             ## 1 when convergence >= threshold
}

## the prompt sent to the vision model:
my $eval_prompt = <<'PROMPT';
you are evaluating a visual design against a specification.
the image shows a minimap timeline: thumbnail frames from an animated
visualization at key moments, with a delta curve below showing when
motion occurs. peak frames (gold border) are the most visually active.

DESIGN SPECIFICATION:
[design_prompt]

EVALUATION TASK:
identify what does not match the specification.
focus only on what needs changing, not what is correct.
be specific: name the visual element, its current state, and target state.

OUTPUT FORMAT (use exactly):
CONVERGENCE: [0-100]%
CORRECTIONS:
1. [element]: currently [current], must be [target]
   fix: [specific code change]
2. [element]: currently [current], must be [target]
   fix: [specific code change]
[continue for all corrections, in priority order]

if convergence is 90% or above, write only:
CONVERGENCE: [number]%
CONVERGED: design matches specification
PROMPT

## send to vision model via appropriate channel:
## option A: qwen local via p7c coding.call-tool
##   p7c coding.call-tool vision_query '{"image": "...", "prompt": "..."}'
## option B: direct llm.service call
##   <[llm.service.vision_query]>->({ image => ..., prompt => ... })
## option C: kimi-web if available
##   p7 kimi-web.vision_query ...

## parse response:
## extract CONVERGENCE: N% → integer
## extract CORRECTIONS: numbered list → array of correction hashes
## set converged = 1 if convergence >= cfg.convergence_threshold
```

### visual-feedback.apply-corrections

dispatches corrections to the coding zenka as targeted edits.

```
args: {
  file_path   => 'data/web-root/vhosts/viz.v7.ax/iris.html',
  corrections => [ { element, current, target, fix, priority }, ... ],
}

returns: {
  applied     => [ correction_1, correction_2 ],   ## successfully applied
  skipped     => [ correction_3 ],                  ## ambiguous, skipped
  edit_count  => 2,
}

## apply corrections in priority order (highest impact first)
## for each correction:
##   build a targeted coding zenka task:
##     "in file X, change Y from A to B. context: [fix description]"
##   dispatch as p7c coding.submit with low reasoning (simple edits)
##   verify: re-read the changed lines, confirm the edit applied

## important: apply one correction at a time, verify between each
## do not batch all corrections into one coding zenka call —
## compound edits are harder to verify and more likely to regress
```

### visual-feedback.loop

orchestrates the full autonomous design refinement cycle.

```
args: {
  file_path      => 'data/web-root/vhosts/viz.v7.ax/iris.html',
  design_prompt  => 'CCW bioluminescent UV vortex...',
  max_iterations => 8,
  vision_model   => 'qwen-vl',
}

returns: {
  final_convergence => 91,
  iterations        => 4,
  converged         => 1,
  final_minimap     => '/var/protocol-7/visual-feedback/final-minimap.png',
  history           => [
    { iteration => 1, convergence => 34, corrections => 3 },
    { iteration => 2, convergence => 67, corrections => 2 },
    { iteration => 3, convergence => 85, corrections => 1 },
    { iteration => 4, convergence => 91, corrections => 0 },
  ],
}

## the loop:
my $iteration = 0;
my $converged = 0;

while ( !$converged && $iteration < $args{max_iterations} ) {
  $iteration++;

  ## 1. capture frames
  my $capture = <[visual-feedback.capture-sequence]>->({ file => $file_path });

  ## 2. analyze delta, select frames
  my $analysis = <[visual-feedback.analyze-delta]>->({
    frame_paths => $capture->{frame_paths}
  });

  ## 3. render minimap
  my $minimap = <[visual-feedback.render-minimap]>->({
    selected_paths => $analysis->{selected_paths},
    delta_curve    => $analysis->{delta_curve},
    timestamps_ms  => $analysis->{timestamps_ms},
  });

  ## 4. evaluate against spec
  my $evaluation = <[visual-feedback.evaluate]>->({
    minimap_png   => $minimap->{minimap_png},
    design_prompt => $args{design_prompt},
    iteration     => $iteration,
  });

  ## record history
  push @history, {
    iteration   => $iteration,
    convergence => $evaluation->{convergence},
    corrections => scalar @{$evaluation->{corrections}},
    minimap     => $minimap->{minimap_png},
  };

  ## check convergence
  if ( $evaluation->{converged} ) {
    $converged = 1;
    last;
  }

  ## 5. apply corrections (only if more iterations remain)
  if ( $iteration < $args{max_iterations} ) {
    <[visual-feedback.apply-corrections]>->({
      file_path   => $file_path,
      corrections => $evaluation->{corrections},
    });
  }
}

## emit final result
return {
  final_convergence => $history[-1]{convergence},
  iterations        => $iteration,
  converged         => $converged,
  final_minimap     => $history[-1]{minimap},
  history           => \@history,
};
```

---

## model configuration

```
## configuration/zenki/visual-feedback/zenka-startup.v7 (additions)

cfg.convergence_threshold = 90
cfg.max_iterations        = 8
cfg.vision_model          = qwen-vl

## vision model endpoints (configure whichever is available):
cfg.vision.qwen_endpoint  = local
cfg.vision.kimi_endpoint  = kimi-web
## cfg.vision.opus_endpoint = api-bridge   ## wire in later via generic API bridge
```

---

## vision model compatibility

the evaluate module must work with any vision model available.
implement an adapter layer:

```perl
## visual-feedback.vision-adapter
## routes to the appropriate vision model based on cfg.vision_model

sub call_vision_model {
  my ($image_path, $prompt, $model) = @_;

  if ( $model eq 'qwen-vl' ) {
    ## local qwen via coding zenka tool
    return <[llm.service.vision_query]>->({
      model  => 'qwen-vl',
      image  => $image_path,
      prompt => $prompt,
    });

  } elsif ( $model eq 'kimi-vision' ) {
    ## kimi web via kimi-web zenka
    return <[kimi.web.vision_query]>->({
      image  => $image_path,
      prompt => $prompt,
    });

  } elsif ( $model eq 'api-bridge' ) {
    ## generic API bridge (opus 4.7, claude 3 vision, etc.)
    ## wired in later — same interface as above
    return <[api-bridge.vision_query]>->({
      model  => cfg.api_bridge_model,
      image  => $image_path,
      prompt => $prompt,
    });
  }
}
```

the adapter means: swapping qwen for opus 4.7 later is one config line change.
the loop, the correction parser, the coding zenka dispatch — all unchanged.

---

## test sequence

```bash
## 1. test evaluate alone (requires minimap from capture-analyzer task)
p7 visual-feedback.evaluate '{
  "minimap_png": "/var/protocol-7/visual-feedback/minimap.png",
  "design_prompt": "CCW bioluminescent UV vortex, implosion direction, violet arms"
}'
## expected: convergence % + list of corrections in machine-parseable format

## 2. test apply-corrections (dry run — verify correction parsing)
## feed the output from step 1 as corrections input

## 3. test full loop on iris.html (the existing visualization)
p7 visual-feedback.loop '{
  "file_path": "data/web-root/vhosts/viz.v7.ax/iris.html",
  "design_prompt": "CCW bioluminescent UV vortex, implosion, violet-blue arms",
  "max_iterations": 3
}'
## watch: does the convergence increase each iteration?
## watch: do the corrections make sense visually?
## watch: does the file actually change between iterations?
```

## success criteria

- [ ] evaluate produces machine-parseable CONVERGENCE + CORRECTIONS output
- [ ] corrections array is ordered by priority (visual impact)
- [ ] apply-corrections applies one correction at a time, verifies each
- [ ] loop increases convergence with each iteration (not oscillating)
- [ ] loop stops on convergence >= 90% without reaching max_iterations
- [ ] loop stops at max_iterations if convergence not reached
- [ ] history records convergence at each iteration
- [ ] final_minimap is the minimap from the last iteration
- [ ] model adapter works with at least one available vision model
- [ ] the CCW/CW correction is detectable from minimap (integration test)

#,,..,,,,,.,.,,.,,..,,..,,,.,,,,.,,,.,..,,,,.,..,,...,...,...,,,.,.,,,..,,.,.,
#RNNG3CPQXGNHZTV26M3FOWJ65EGBEABZIIYIM722QL3BKKS653TVGC6RYWK6NKKNCIMOQKQEB5J2W
#\\\|JC6IYHWXF4DD3N6562RBWD2CMKQ3CFHVGJA6QFPIO3IKDGAZH67 \ / AMOS7 \ YOURUM ::
#\[7]UYVMECLYXHN5GGVVWO6VLJIUDKW4RTYSGRKHAOK3V2AZW52LCYBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
