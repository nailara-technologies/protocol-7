# paragraph template engine : prompts from named paragraphs, dependencies, flags, curves

status : brief, not dispatched [ owner 2026-11-21 ]. builds on the existing resolvers
[ the p7_template_resolve mcp tool, data/yaml/context-templates/, povray.template.resolve ].
the rendering side is designed already and is reused, not redrawn :
data/md/design/VISUAL-GENERATION-NATIVE-ZENKA.md [ povray as precision skeleton and
controlnet conditioning source ; scene slices distributed over the network's povray
instances ], data/md/INITIATIVE-MAP.md initiative P [ slice rendering : each node
renders its slice ], VISUAL-INPUT-PIPELINE-AND-LIVING-TEMPLATES.md [ povray precision
frame + t2i skinning + best-5 tournament ], LIVING-BACKGROUND-SYSTEM.md [ povray as
rendering layer ]. this brief adds the PROMPT side those pipelines need.
first users : rendering prompts [ icon redraws with a local image model, elf avatar
extraction, kittens -- desktop-ui-surfaces.md part 3 ], then text \ code task prompts.

## problem

- prompts are written whole ; a variation means a copied and edited prompt
- deeper or more refined generation steps are new prompts instead of additions
- nothing records which parts a result came from, so tuning is guesswork

## shape

1. paragraphs as units : each building block is a named paragraph [ p7 config style,
   one file per family ], optionally with parameters
2. dependency resolution : a paragraph declares what it needs [ 'material : blue
   translucent' needs 'light : edge' ] ; the engine resolves order, includes each
   paragraph once, refuses cycles and missing names with a clear message
3. context flags : paragraphs carry conditions [ icon, avatar, kitten, high-detail,
   dark-background ] ; one template set serves many purposes, flags select
4. refinement by addition : a deeper generation step is a few more paragraphs or flags,
   never a rewritten prompt -- each step stays traceable to its parts
5. numerical proportions : paragraphs carry weights [ emphasis, share of the prompt,
   sampler strengths where the model takes them ] ; proportions can be harmonic
   ratios and are experimented with like any other parameter
6. global curves : one curve maps a single control [ e.g. detail level, refinement
   step, style strength ] onto many weights at once -- moving along the curve
   shifts the whole template coherently instead of tuning weights one by one
7. grid templates for reference images : pre-configured layout grids [ proportions,
   anchor points, symmetry axes, safe margins ] that generation aligns to, taken from
   our js based visualizations [ the same geometry that renders there exports as a
   grid ], from povray scenes or any other 3d source -- the condition is that the
   source is reproducible [ scene + parameters regenerate the same grid ] or aligned
   to a grid that already is. a grid is one more paragraph family : selected by flags, weighted, moved
   along the same curves -- so icon sets, avatars and pages share one composition
8. the 3d <-> image loop : a minimal translucent skeleton scene [ rough geometry,
   camera, light -- povray ] fixes composition, depth and perspective ; its render
   guides a text-to-image step [ depth \ outline as structure ] that brings in a whole
   world ; the result goes back into the scene [ texture, backdrop, image_map ] for the
   next render iteration [ consistent light, another camera angle ], and so on. each
   round adds detail while the geometry keeps the proportions -- every round recorded
   like any other step [ scene parameters + paragraphs + curve position ]
9. categorical sub-theming : on top of the base theme [ the desktop tokens ], a
   category adds its own paragraph set -- a motif, a world, a palette accent -- for
   one group of things [ the media icons, the work context, a project's windows, a
   friend's shared view ]. the same skeleton scenes and grids keep everything
   coherent, the category only changes what fills them. personalised desktops become
   a choice of categories and curves, not a hand-made theme
10. provenance : every rendered prompt records its paragraphs, flags, weights and
   curve position ; with the success statistics of the content abstraction layer
   [ intent-and-pending-decisions.md ] the engine learns which combinations work

## stages

1. paragraphs, flags, dependency resolution, the rendered prompt with provenance
2. weights and one global curve ; the icon redraw prompt as first family
3. statistics per combination ; curve presets per model
4. text \ code task prompts through the same engine

## rules

- p7 config style, no json ; BMW \ AMOS checksums, no sha ; perl floor 5.32
- paragraphs are data, not code : no evaluation of template content
- no personal data in shared paragraphs ; personal ones live in the user's context

#,,,.,,.,,.,,,.,.,,,.,,,,,,,.,.,,,.,.,..,,,..,..,,...,..,,,,.,...,,,.,.,.,,.,,
#EWAJMHJNMXD47I7GUEP4RMS6BBRP5JHAXC2EWIKWCQTANUCMXCVSX5YNU3YKTREV6O3BLHOP36IQS
#\\\|6WTPE6RGWM4KE3AROFEC5CAL7DJROAL64XAPZIRXH3TJ3XAFALU \ / AMOS7 \ YOURUM ::
#\[7]XN3VXSZIXKNQXKTNQVCUFSJSG77NWAXU6IPQO5I37UHSLLVWGEAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
