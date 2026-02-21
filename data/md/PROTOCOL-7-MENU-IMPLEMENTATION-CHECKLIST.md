# Protocol-7-Menu Push Architecture - Implementation Checklist

## Phase 1: Core Event-Driven Rendering ✅ (DESIGNED)

### Hash Structure & Watchers
- [x] `protocol-7-menu.menu-structure-init` - Initialize structure with watcher
- [x] `<protocol-7-menu.menu-structure>` - Canonical hash data structure
- [x] `protocol-7-menu.structure-changed` - Watcher callback for diff logic

### Update Command & Handlers
- [x] `protocol-7-menu.cmd.menu-update` - Receive push updates from providers
- [x] `protocol-7-menu.add-provider-items` - Create new provider menu items in GUI
- [x] `protocol-7-menu.remove-provider-items` - Remove provider's menu items from GUI
- [x] `protocol-7-menu.update-provider-items` - Fine-grained item updates

### Helpers & Documentation
- [x] `protocol-7-menu.provider-register` - Helper for external zenka
- [x] `protocol-7-menu.example-provider` - Usage documentation & pattern
- [x] Architecture documentation

## Phase 2: Integration & Testing 🔄 (IN PROGRESS)

### Graphical Menu System Integration
- [ ] Update `protocol-7-menu.graphical-menu-init` to initialize provider-based structure
- [ ] Ensure GUI handles provider submenus correctly
- [ ] Test menu rendering with multiple providers
- [ ] Test dynamic add/remove of providers during runtime

### Event System Integration
- [ ] Verify `<[event.add_var]>` correctly supports variable key watchers
- [ ] Test hash watcher fires on `'last-changed'` writes
- [ ] Verify watcher doesn't trigger on non-watched keys

### Provider Testing
- [ ] Create test provider zenka (mock weather data)
- [ ] Test push update cycle (register → update → check GUI)
- [ ] Test provider unregister (menu items disappear)
- [ ] Test multiple providers simultaneously
- [ ] Test concurrent updates from different providers

## Phase 3: Optional Status Polling 📋 (PLANNED)

### Timestamp-Based Change Detection
- [ ] Implement `.updated` command in provider zenka pattern
  - Returns: `TRUE <timestamp>` (has data)
  - Param: `<timestamp>` returns change tree if newer
  - Param: `<branch.path>` returns status of specific branch
- [ ] Create `protocol-7-menu.poll-provider-status` (optional catch-up on init)
- [ ] Document timestamp format and usage

## Phase 4: Multi-Level Provider Architecture 🚀 (FUTURE)

### Intermediate Formatter Zenka Pattern
- [ ] Example: weather-display zenka
  - Consumes weather.zenka updates
  - Formats output
  - Pushes to protocol-7-menu
- [ ] Example: system-status aggregator
- [ ] Documentation on composable middleware

## Phase 5: Hash Synchronization Network 🌐 (FUTURE)

### Network-Level Data Mounting
- [ ] Implement `<[event.mount_remote_branch]>` infrastructure
- [ ] Allow subscribing to remote zenka hash branches
- [ ] Automatic sync over zenka network
- [ ] Conflict resolution for dual updates

## Known Issues & Notes

### Current Limitations
- [ ] Placeholder signatures in created modules need real AMOS7 checksums
- [ ] JSON handling assumes JSON module is available (needs verification)
- [ ] GUI item lookup by label (fragile—should use internal IDs)
- [ ] No ACL/permission system for menu updates (future)

### Testing Requirements
1. **Start graphical menu**: `p7 protocol-7-menu`
2. **Simulate provider**: Create test zenka that calls `menu-update`
3. **Observe GUI**: Menu items should appear/update/disappear dynamically
4. **Monitor logs**: Verify watcher fires and diff logic executes

### Edge Cases to Handle
- [ ] Provider tries to update before menu initialized
- [ ] Multiple updates from same provider in quick succession
- [ ] Provider sends malformed JSON data
- [ ] GUI submenu widget destroyed before update arrives
- [ ] Large number of providers (performance testing)

## Code Quality Checklist

- [ ] Remove PLACEHOLDER_SIGNATURE_HASH with real AMOS7 checksums
- [ ] Add comprehensive error handling
- [ ] Verify JSON module import in protocols where needed
- [ ] Add debug logging levels for troubleshooting
- [ ] Document parameter formats and examples
- [ ] Test with both Gtk3 and non-graphical modes

## Documentation Status

- [x] Architecture overview document created
- [x] Example provider implementation included
- [x] Data flow diagrams in documentation
- [ ] API reference for all commands
- [ ] Troubleshooting guide
- [ ] Performance considerations guide

---

## Next Immediate Steps

1. **Integrate with graphical-init**: Update `protocol-7-menu.graphical-init` to call `menu-structure-init`
2. **Test event system**: Verify `event.add_var` works with variable keys
3. **Create mock provider**: Test with simple weather or RSS provider
4. **Fix checksums**: Replace PLACEHOLDER with real AMOS7 signatures
5. **Stress test**: Multiple rapid updates from different providers

## Branch/Version Info

- **Branch**: `dev/protocol-7-menu-push-architecture`
- **Status**: Core architecture implemented, awaiting integration testing
- **Dependencies**: Gtk3 (graphical mode), JSON (for data serialization)

#,,..,,..,.,,,.,.,...,.,,,.,.,.,,,.,,,.,.,...,..,,...,...,...,.,.,..,,,,.,.,,,
#M4AXQR2FMLLUMJDYZDUFRJFJAV52FD4AVWPJ3YOOP6KQ3M5BXHHVVJ4KCI7CG7C3WVBAC24TIJTSC
#\\\|4WI2RQ7GMN7BNJJQWLL74S7D3FYHGX4VN75Q2BCJS6S4NHUASS4 \ / AMOS7 \ YOURUM ::
#\[7]XEPVT3GDLWF2FROAAHRBKVQNUD7GQMLZEKXHXA63JPVRKWMTL6CI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
