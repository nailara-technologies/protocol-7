# module test zenka — design

## purpose

a dedicated zenka for non-destructive testing of P7 modules and zenki.
runs in isolation from the production zenka network — separate sockets,
separate address space, no risk of interfering with live state.

---

## core constraints

- **non-destructive**: must not touch production data, sockets, or state
- **isolated**: separate unix socket path, separate var/ subtree
- **generic**: any module can be loaded and tested without custom harness
- **reportable**: structured output consumable by benchmark dispatcher
- **restartable**: clean startup and teardown for each test run

---

## architecture

```
[ test runner / dispatcher ]
         |
         | unix socket (test address)
         ↓
[ module-test zenka ]
    - loads module under test
    - receives task via standard coding zenka protocol
    - executes module with test input
    - captures output and errors
    - returns structured result
         |
         ↓
[ report collector ]
    - scores result against suite expectation
    - appends to test report
```

the module-test zenka speaks the same protocol as the coding zenka —
the dispatcher sends tasks the same way regardless of test_target.
only the socket address differs.

---

## socket and address management

production coding zenka:  `/var/run/protocol-7/coding.sock`
module-test zenka:        `/var/run/protocol-7/coding-test.sock`
                          (or `/tmp/p7-test-$pid.sock` for ephemeral runs)

address registration:
- test zenka registers under a separate name (e.g. `coding-test`)
- cube routes to it normally via dot notation (`coding-test.submit`)
- OR: dispatcher connects directly to test socket, bypassing cube

direct socket mode is simpler and safer for test isolation —
no risk of test traffic leaking into production routing tables.

### address lifecycle

```
test run starts  → spawn test zenka, bind test socket
test run ends    → send shutdown, socket removed
crash/timeout    → supervisor detects dead socket, cleans up
```

ephemeral sockets use pid in the path — no conflicts between
parallel test runs. each run is fully independent.

---

## module loading

the test zenka starts with a minimal base load (cube comms, logging,
task queue) and then loads the module under test on demand:

```perl
## dynamic load for test isolation ##
<[base.perlmod.autoload]>->('module.under.test');
```

this mirrors how modules are loaded in production. the test zenka
does not pre-load the full coding zenka module set — only what the
test suite declares as dependencies.

dependency declaration in suite yaml:

```yaml
modules_required:
  - coding.tools.dispatch
  - coding.tools.handler.read_file
  - file.zenka_dir.load
```

the test zenka loads exactly these before running the task.

---

## test var/ subtree

```
/var/protocol-7/coding-test/
    results/        task results (mirrors coding/results/)
    state/          ephemeral state for test run
    scratch/        test fixtures, temp files
```

scratch files are created fresh per run from suite yaml fixtures:

```yaml
fixtures:
  - path: scratch/test_module.pm
    content: |
      ## [:< ##
      # name = test.fixture
      ...
```

the test zenka sets `<system.root_path>` to the scratch dir for
modules that resolve file paths — they read/write scratch files,
never production files.

---

## result capture

the test zenka wraps module execution and captures:

```perl
{
    task_id    => '...',
    output     => '...',      ## final result text
    tool_calls => [...],      ## tools invoked during execution
    errors     => [...],      ## any logged errors
    duration   => 1.24,       ## seconds
    exit_state => 'complete', ## complete | timeout | crash | error
}
```

this structured result is returned to the dispatcher for scoring
against the suite expectation.

---

## open questions (to refine)

- **cube dependency**: does the test zenka need to register with cube,
  or can it operate in standalone mode (no cube connection)?
  standalone is cleaner for isolation but loses access to cube-routed
  modules. likely: standalone with a mock cube shim for module calls
  that route through cube.

- **privilege model**: test zenka should run as the same user as
  coding zenka (taeki / admin group) so file permissions match.
  chmod child not needed if no writes to production paths.

- **parallel runs**: multiple test zenki can run in parallel with
  different sockets. suite runner controls concurrency limit.

- **state machine scope**: async tool loop is complex — does the
  test zenka run the full async state machine, or a simplified
  blocking version for predictability? blocking is easier to reason
  about for test correctness; async is more representative of
  production behavior.

---

## relation to model benchmark runner

| concern              | module test zenka        | model benchmark runner   |
|----------------------|--------------------------|--------------------------|
| what is tested       | P7 module behavior       | LLM model quality        |
| task routing         | test socket (isolated)   | GPU/CPU backend          |
| scoring              | exact / tool_check       | regex / llm_judge        |
| state after run      | discarded                | stored in benchmark.store|
| trigger              | manual / CI              | new model discovery      |

both consume the same suite yaml format and report via the same
dispatcher — they are two modes of one infrastructure, not two systems.

---

## implementation sequence

```
[ ] define test zenka start config (minimal module load, test socket)
[ ] var/ subtree setup (coding-test/ with scratch/, results/, state/)
[ ] task intake via direct socket (no cube dependency initially)
[ ] module dynamic loading from suite yaml modules_required
[ ] fixture file creation in scratch/ before run
[ ] result capture wrapper (output, tool_calls, errors, duration)
[ ] return structured result to dispatcher for scoring
[ ] cleanup on run end (scratch purge, socket removal)
[ ] parallel run support (ephemeral sockets with pid suffix)
[ ] async state machine option (post-initial implementation)
```

#,,,.,,,,,.,.,..,,,.,,.,,,.,.,.,.,,,,,.,,,,.,,..,,...,...,.,.,,..,.,.,.,,,...,
#2S5RDYPRQZSRWTF4CARKT7LOZNYXBGWG46HX2X454SBZDLEFTBQFQCKZCFHUGLBAWFWK2LJMQHRFO
#\\\|3Y25ACQVRPKNEFUVOZKLUDNLGL6PP5IVRAZWF4GFRA6BP7QTRYD \ / AMOS7 \ YOURUM ::
#\[7]H7NSNAXYTFWCXSDRKRGZX4XTBWA7URZQQGXTWJNLW7DAMRABW2CQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
