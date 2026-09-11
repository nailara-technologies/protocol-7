## [:< ##

# name  = task: torch.* worker foundation, invoke-replacement as first consumer
# descr = a reusable, explicitly-loaded (not base.*) primitive for P7 zenki
#         that need real torch/CUDA compute in a forked child, proven safe
#         2026-09-10/11 -- invoke.ai replacement is the first real consumer,
#         not the definition of the abstraction

## context

raised 2026-09-10/11, growing out of two separate threads converging:

1. the coding-lora-p7-idioms.md training run needed torch/transformers/
   peft/bitsandbytes -- handled via a bare `IPC::Open3` subprocess
   (`coding.lora_train_spawn` + JSON-line stdout progress), the right
   choice for a one-shot batch job but not "native" (ad-hoc protocol,
   not normal P7 command/reply routing).
2. a long-standing plan ([[topic-invoke-model-manager]], [[topic-invoke-
   model-management]]) to eventually replace invoke.ai itself with a
   native zenka, which needs real, repeated, long-running GPU compute --
   a genuinely different shape than a batch job: a persistent, network-
   addressable service, matching the documented child-zenka pattern
   (`weather.base.fork_weather_child`) rather than the subprocess one.

the user's framing, recorded because it sets the actual scope: build a
generic torch-worker FOUNDATION now, with invoke-replacement as its
first consumer, rather than a bespoke invoke-only implementation --
explicitly not the same kind of premature abstraction as generalizing
the subprocess pattern from only two instances (flagged and deliberately
deferred earlier in this same session) -- this is abstracting the
PRIMITIVE (safe venv + fork discipline), which is worth getting right
once specifically because getting it wrong fails subtly, not the
orchestration SHAPE, which genuinely varies per consumer.

## confirmed live, 2026-09-10/11 -- read before building anything

**`Inline::Python` + torch/CUDA works, with one hard requirement: exact
python-version match.** `libinline-python-perl` (the Debian package)
links against `libpython3.14`, fixed, no override. torch must be
installed for that SAME cpython version -- a mismatched venv (this
session initially had `.venv-lora` at python3.13) fails cleanly (a
catchable `ImportError` citing a bogus "loaded the wrong torch/_C"
message, not the real ABI-mismatch cause) rather than crashing, but it
never works. **fix**: a dedicated venv built with `python3.14 -m venv`
(needs the `python3.14-venv` apt package too, both now in `.deps/
profiles.yaml`'s `ai-models` profile), with torch installed inside it
via plain `pip install torch` (pulls a real CUDA build, `2.14.0+cu130`
confirmed working, no special index needed). Verified working end to
end: `import torch`, a real tensor op, AND real GPU compute (`torch.
randn(..., device="cuda:0")`, matmul, `torch.cuda.synchronize()`,
correct `memory_allocated()`) -- not just detection, actual compute.

**fork-after-embed-before-CUDA is safe, verified live, not just
theoretically sound.** `src/base.fork` is a bare `CORE::fork` -- no
exec, unlike `IPC::Open3` -- so anything touched in the parent before
fork is inherited by the child, and CUDA contexts do NOT survive a raw
fork() correctly if one already exists at fork time (this is the real,
general hazard, not specific to this codebase). Tested the exact
sequence a real child zenka would use: `Inline::Python`'s interpreter
gets embedded at Perl module load time in the PARENT (unavoidable --
that's how `Inline` works) but NO torch/CUDA call happens there; only
the freshly-forked CHILD does `import torch` + first CUDA op. Result:
child's CUDA work succeeded cleanly, AND the parent's own CUDA work
(tested again after the child exited) also succeeded cleanly -- no
corruption either direction. **the one discipline this requires**: the
parent zenka's own code must never call into CUDA/torch before the
fork that spawns each worker. Proven achievable, not automatically
guaranteed by the language -- the base module below exists specifically
to enforce this so individual consumers can't get it wrong.

test scope, honestly: single fork, immediate child CUDA use, parent
CUDA use once after the child exits. NOT yet tested: repeated forks
over a long-running zenka's lifetime, concurrent children, or the
parent's own P7 event loop running alongside a live child -- real
unknowns for the actual implementation, not reasons to doubt the core
finding.

## naming decision, 2026-09-10/11

**`src/torch.*`, not `base.torch.*` or `src/py.torch.*`.**
- not `base.*`: that namespace is loaded broadly across nearly every
  zenka (`base.logs`, `base.fork`, `base.time`) -- embedding a full
  Python interpreter is a heavy, optional, GPU-specific capability only
  opt-in zenki should ever pull in. lives outside `base.*` as its own
  explicitly-loaded module family.
- not `py.*`: presupposes a broader family of distinct Python
  integrations beyond torch that doesn't have evidence yet -- the same
  premature-abstraction shape already flagged and deferred once this
  session for the subprocess-orchestration pattern. name for what's
  actually proven (torch/CUDA fork semantics specifically), not a
  hypothetical future generic-python-bridge family. a genuinely
  different non-torch Python need, if one ever arises, gets its own
  namespace decided against real evidence then.
- no existing `torch.*`/`py.*` collision in `src/` -- confirmed live.

## _Inline/ pollution, confirmed live 2026-09-11 -- required pattern

`use Inline Python => <<'...'` (the plain declarative pragma, including
its `DIRECTORY => $dir` config-pair form) does NOT redirect the build
cache -- it still wrote `_Inline/` into the project's own working
directory regardless. This is the exact pollution [[feedback-cpanm-
triggered-inline-elf-utf8-boundary-bug]] already flagged for Inline::C
("`_Inline/` was NOT added to `.gitignore`") -- same fix applies here,
not a fresh problem: this codebase already has the answer in `data/lib-
path/pm/AMOS7/INLINE.pm`'s `compile_inline_source`/`gen_inline_path`,
which redirects Inline::C's cache to `~/.7/inline-code/<name>` instead
of gitignoring the pollution. **Confirmed live that the SAME fix works
for Inline::Python**, with two requirements the declarative pragma
doesn't satisfy on its own:
1. use the programmatic `Inline->bind(...)` form, not `use Inline
   (...)` -- the declarative pragma silently ignored `DIRECTORY`.
2. the target directory must already EXIST before `bind()` is called --
   Inline validates and errors ("Invalid value ... for config option
   DIRECTORY") rather than auto-creating it, exactly why `AMOS7::
   INLINE.pm` calls `make_path()` first.

```perl
use File::Path qw| make_path |;
my $dir = "$ENV{HOME}/.7/inline-code/<some-name>";
make_path($dir) unless -d $dir;
Inline->bind( 'Python', $python_source, directory => $dir );
```

`torch.init_code` (below) MUST use this pattern from its first version,
not the bare declarative pragma -- verified to leave zero `_Inline/`
residue in the project tree when done this way.

## proposed shape [ not yet built ]

- `torch.init_code` -- embeds `Inline::Python` at load time, using the
  `~/.7/inline-code/` redirect above. MUST NOT touch CUDA/torch here --
  this runs in whatever zenka process loads the module, before any
  fork.
- `torch.fork_worker` -- the safe primitive: fork (via `base.fork`, not
  a bare `CORE::fork`, to keep the prng-reseed behavior), and in the
  child, run a given python callable with args, returning the result
  via normal P7 child-zenka networking (matching `weather.base.
  fork_weather_child`'s pattern) -- NOT ad-hoc JSON-on-stdout like this
  session's `coding.lora_train_spawn` used for its subprocess case.
- venv convention: a dedicated `python3.14`-based venv per consumer
  need (not shared with `.venv-lora`, which stays LLM-training-specific
  -- different dependency graphs, `diffusers` vs `peft`/`bitsandbytes`,
  no reason to couple them). document the exact `python3.14 -m venv` +
  `python3.14-venv`/`libinline-python-perl` apt dependency recipe here
  once the first consumer's venv is actually built.

## first consumer: invoke-replacement zenka [ not yet started, separate
## from this foundation task -- see [[topic-invoke-model-manager]] for
## the existing vision/plan, [[topic-invoke-model-management]] for
## invoke.ai-specific storage/recovery lessons already learned ]

thin consumer of `torch.fork_worker`: `diffusers` pipeline calls +
image storage/provenance logic only, no fork/CUDA-safety plumbing of
its own. needs its own venv (`diffusers` + torch, python3.14) -- not
`.venv-lora`.

## open, not yet decided

- exact P7 networking shape for a `torch.fork_worker` child's reply --
  does it register as a genuine sub-zenka (network-addressable,
  matching weather's children) or reply once and exit? depends on
  whether a consumer wants a long-lived worker pool or one-shot-per-
  request children.
- repeated-fork / concurrent-children lifecycle, untested per the test-
  scope note above -- needs its own verification before the invoke
  zenka is actually built on top of this.

#,,.,,,,.,,,,,,,,,.,.,,..,,,,,.,,.,,,,,,,,..,,,.,,.,,,,.,,,..,..,,,,,,,..,,,,,,

#,,..,,..,,,.,.,.,.,,,,..,,.,,.,,,,,,,,.,,...,..,,...,...,...,.,.,,.,,,,.,..,,
#HOGAFEVKMKP3LORDL7JRZ7CUSLEGMMMJCJDJGUYAZBSYJRXG2VWZDFJXR7AENNP2OUQJ6UQENXDV2
#\\\|PPF46DVGMLGHN64CZ4LA7GVCHDZIFDVBIKJMYUYHG26M43JWDXR \ / AMOS7 \ YOURUM ::
#\[7]ADGDYEMXHIDO2F5NNKBVKYOAUWNVOY64AFQU73BRXSUIH3ODNCBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
