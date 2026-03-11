# Task: Investigate New Command Permission Mask Compilation

## Problem Statement

New commands added to `access.zenki` files are not being recognized by the cube router even after reload/restart of affected zenki. The error persists:

```
no perm. [ src 'zulum' cmd|usr 'receive-entropy' ]
```

Even though `access.cmd.usr.zulum = *.receive-entropy` is configured.

## Symptoms

1. **Permission errors persist after reload**: Changing `access.zenki` and reloading the source zenka (zulum) doesn't clear the permission denial
2. **Wildcard patterns not matching**: `*.receive-entropy` should match `cube-13.receive-entropy` but doesn't
3. **Direct commands work**: When called directly from CLI, commands work fine - only routed commands fail
4. **Module loads but permissions don't update**: New modules are picked up on restart, but permission masks seem cached

## Investigation Path

### Phase 1: Permission Mask Compilation

The key module is `base.parser.access_conf`:

```
: 007 : <[base.log]>->( 2, ': compiling command permission masks..,' );
```

Investigate:
- [ ] When does `base.parser.access_conf` run? (init vs reload)
- [ ] Does it recompile masks on `reload config` or only on full restart?
- [ ] Where are compiled masks stored? (`%access_cmd_usr` hash?)
- [ ] Is there a cache invalidation mechanism?

### Phase 2: Pattern Matching Logic

Investigate how wildcard patterns are matched:
- [ ] Does `*.receive-entropy` match `cube-13.receive-entropy` correctly?
- [ ] Is there an issue with hyphenated zenka names (`cube-13` vs `cube_13`)?
- [ ] Check if the pattern is being parsed as `cube-13` or `cube` + `13.receive-entropy`

### Phase 3: Reload vs Restart Behavior

Document the difference:
- [ ] What happens on `zenka.reload` vs `v7.restart zenka` vs full cube restart?
- [ ] Which phase recompiles access masks?
- [ ] Is there a way to force mask recompilation without restart?

### Phase 4: Multi-Level Access Control

cube-13 has TWO access control layers:
1. `configuration/zenki/cube/access.zenki` - for cube-routed commands
2. `configuration/zenki/cube-13/access.zenki` - for direct connections
3. `configuration/zenki/cube-13/access.users` - for authenticated users

Investigate:
- [ ] Which file is actually being checked for zulum → cube-13 routing?
- [ ] Does the cube route through its own masks or delegate to cube-13?

## Related Code

```perl
## base.parser.access_conf - line 7 ##
<[base.log]>->( 2, ': compiling command permission masks..,' );

## base.cmd.reload - config phase ##
if ( $arg eq qw| config | or $arg eq qw| all | ) {
    delete <access.cmd.usr>;
    <[base.logs]>->( '[%d] < reload config >', $id );
    if (<[base.reload_config]>) {
        $reply->{'data'} .= sprintf "%s reload config  [ success ]\n", $s_str;
    }
    <[base.parser.access_conf]> if $arg eq qw| config |;  ## <-- called here ##
}
```

## Workaround Found

Using wildcard `*.receive-entropy` instead of `cube-13.receive-entropy` allows zulum to call the command, but this is not ideal for security.

## Acceptance Criteria

- [ ] Identify why `cube-13.receive-entropy` permission is not recognized
- [ ] Determine correct reload procedure for access.zenki changes
- [ ] Document whether cube (main) or cube-13 access files are used for routing
- [ ] Fix or document the pattern matching for hyphenated zenka names

## References

- `modules/base.parser.access_conf` - permission mask compilation
- `modules/base.cmd.reload` - reload phases
- `configuration/zenki/cube/access.zenki` - main cube access
- `configuration/zenki/cube-13/access.zenki` - cube-13 specific access
- `configuration/zenki/cube-13/access.users` - user authentication

#,,,.,..,,,..,,..,.,,,,.,,..,,,.,,...,,..,.,.,..,,...,..,,..,,,..,...,.,,,,.,,
#5IYCDOOPKNXJSNUE3JK4HKGP4ZGEQD5R3IFEGYUX357BZUXKUZ5GVSTAVNUJRNJSU2FM7YDL5FA3U
#\\\|KJ3DYQLIBVWE22GYYAXEKXBAPUOP3P3OHZSWY2CY5S4I5AA5LXD \ / AMOS7 \ YOURUM ::
#\[7]GM2V2WBO6HM5HBFNEIT2XT5YIIBIYS6YIFDOPZ6WVBMCW25SASCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
