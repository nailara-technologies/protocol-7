## Zenki Creation Guide - April 2026 [COMPLETE]

**Template**: `data/yaml/context-templates/zenki-create.yaml`

Based on successful implementation of kimi-web zenka, this guide covers creating new protocol-7 zenki with proper structure.

### Zenka Types
| Type | Characteristics | Examples |
|------|-----------------|----------|
| **Standard** | Background service, no console | coding, models, data, storage |
| **Console** | Interactive terminal | amos-term, nshell |
| **Child-bearing** | Spawns sub-processes/zenki | v7, kimi-web |
| **Hybrid** | Multiple characteristics | coding (service + inference) |

### Critical Implementation Rules

1. **Never `my $call = shift` in *.cmd.* modules**
   - $call is pre-declared by dispatcher
   - Use: `my $args = $call->{'args'} // {}`

2. **Auth wiring is mandatory**
   ```
   # configuration/zenki/cube/auth.zenki:
   auth.setup.usr.<zenka-name> = :zenka:
   ```
   Missing this causes: "user not accepted for auth type :zenka:"

3. **Don't load self in modules.load**
   ```
   # WRONG:
   modules.load = auth net ... <zenka-name>

   # RIGHT:
   modules.load = auth net ...  # <zenka-name> auto-loaded
   ```

4. **Return format for cmd modules**
   ```perl
   return { 'mode' => qw| true |, 'data' => $result };
   # NOT: return { mode => TRUE, ... }
   ```

5. **$ARG/@ARG preservation**
   - ALWAYS use English.pm aliases
   - NEVER use `$_` or `@_`

### File Structure

```
modules/<zenka-name>.init_code                    # required
modules/<zenka-name>.cmd.<command>                 # exposed commands
modules/<zenka-name>.handler.<event>               # event handlers
modules/<zenka-name>.internal.<helper>             # utilities

configuration/zenki/<zenka-name>/
├── start                                          # main config
├── zenka-startup.v7                               # v7 integration
├── pm-dep/                                        # perl deps
└── source/                                        # source tracking

cube/access.zenki: access.cmd.usr.<name> = <commands>
cube/auth.zenki:   auth.setup.usr.<name> = :zenka:
```

### Child-Bearing Zenki Specifics

From kimi-web implementation:
- Call `<[v7.register_child_zenka]>->(qw| <name> |)` in init_code
- Track child PIDs in registry hash: `<zenka-name>.agent.registry`
- Use `event.add_timer` for health checks
- Implement graceful shutdown with context preservation

### Console Zenki Specifics

- Use AMOS7::TERM patterns for input handling
- Handle terminal state (raw mode, echo)
- Restore terminal on exit
- Consider SHM buffer for output

### Testing Checklist

```bash
# 1. Syntax check
./bin/dev/ptd modules/<zenka-name>.*

# 2. Start zenka
p7c v7.start <zenka-name>

# 3. Test command
p7c <zenka-name>.commands

# 4. Check logs if failure
p7c show-buffer <zenka-name>
```

### Common Error Messages

| Error | Cause | Fix |
|-------|-------|-----|
| "my variable $call masks earlier declaration" | `my $call = shift` in cmd | Remove `my $call = shift` |
| "file.zenka_dir.make_path not defined" | Using non-existent function | Use `file.make_path` or create on-demand |
| "user not accepted for auth type :zenka:" | Missing auth.zenki entry | Add `auth.setup.usr.<name>` |
| "no match /modules/<zenka-name>" | Loading self in modules.load | Remove from modules.load |

### Template Usage

```bash
# Use the zenka creation template
p7c coding.ask template=zenki-create zenka_name=my-zenka zenka_type=standard
```

### Files to Know
- `data/yaml/context-templates/zenki-create.yaml` <- Base creation template
- `modules/v7.register_child_zenka` <- Child zenka registration
- `modules/cube.auth.zenki` <- Auth routing

---

#,,,,,,..,,.,,,,,,..,,...,.,.,.,,,,.,,,,.,.,.,...,...,...,.,.,...,,.,,.,.,,,.,
#NSDBRKPWNIEW4DRGQDQK4C43EMVFGGFATVZH4CWJ6K5FNF6LYSOH6LPDNDGFDLSU6XFNLGR3WHHSG
#\\\|O4LCVBMGHNJAD7HEJIAAKGOWLZYR57MBHLXJVLBRM2Z6UT3HWXM \ / AMOS7 \ YOURUM ::
#\[7]C7XH76LZGUP55DGNIGNGWL3CYK3VKLHS4ZRSNOXPKC34TN5LNSAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
