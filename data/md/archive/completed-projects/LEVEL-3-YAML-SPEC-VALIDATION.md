# Level 3 Enhancement: YAML Spec-Driven Validation & Regression Testing

## Vision: YAML as Implicit Commit Contract

The testing scenarios in `level-3-configuration-templates.yaml` can become more than documentation—they become **executable contracts** that enforce implementation validity.

---

## Three-Layer Quality System

### Layer 1: Pre-Commit Validation (Git Hooks)

**Purpose**: Reject commits that don't fulfill their promises

**How It Works**:
```perl
# .git/hooks/pre-commit (pseudo-code)

# Parse commit message: "Implement step 3: Verification & Repair Orchestrator"
my $step_number = extract_step_number($commit_msg);  # → 3
my $step_name = extract_step_name($commit_msg);      # → "Verification & Repair Orchestrator"

# Load YAML acceptance criteria
my $yaml = YAML::Load(read_file('level-3-configuration-templates.yaml'));
my $acceptance = $yaml->{module_creation_checklist}->{"step_$step_number"}->{acceptance_criteria};

# Verify code changes match acceptance criteria
foreach my $criterion (@$acceptance) {
    if (!code_satisfies_criterion($criterion, $changed_files)) {
        say "REJECT: Commit promises '$criterion' but code doesn't implement it";
        exit 1;  # Block the commit
    }
}

# Commit allowed only if ALL acceptance criteria met
exit 0;
```

**Benefits**:
- Prevents half-finished commits
- Catches incomplete implementations before they're pushed
- Creates accountability for spec compliance
- Documentation becomes enforced contract

---

### Layer 2: State-Machine Zenka (Continuous Validation)

**New Zenka: `yaml-validator`** (on-demand)

**Purpose**: Automatically validate that implementation matches YAML spec

**Architecture**:
```
yaml-validator zenka:
├─ Reads level-3-configuration-templates.yaml
├─ Extracts testing scenarios (8 test cases)
├─ Executes each scenario against running system
├─ Compares actual vs expected results
├─ Generates validation report
└─ Detects regressions (previously-passing tests now failing)
```

**Implementation Pattern**:
```perl
# In yaml-validator.base.validate_scenario

my $scenario = shift;  # From YAML
my $preconditions = $scenario->{preconditions};
my $actions = $scenario->{actions};
my $expected_results = $scenario->{expected_results};

# Setup
foreach my $precond (@$preconditions) {
    execute_setup($precond);
}

# Execute
my $actual_results = execute_actions($actions);

# Validate
foreach my $expected (@$expected_results) {
    if (!matches($actual_results, $expected)) {
        record_failure($scenario, $expected, $actual_results);
    }
}

return { scenario => $scenario->{name}, passed => $passed };
```

**Test Results Storage**:
```perl
<yaml_validator.test_results> = {
    timestamp => time(),
    scenarios_run => 8,
    passed => 7,
    failed => 1,
    regressions => [
        {
            scenario => "test_5_parent_child_dependency_failure",
            previously_passed => "2025-11-13 14:32:10",
            first_failure => "2025-11-13 16:45:22",
            failure_reason => "Child fork returned error instead of installing deps"
        }
    ]
};
```

**Monitoring**:
```bash
# Run validation
yaml-validator validate-all

# Check specific scenario
yaml-validator validate test_2_system_upgrade

# See regression history
yaml-validator show-regressions

# Create test report
yaml-validator report > /tmp/validation-report.txt
```

---

### Layer 3: Regression Testing (Continuous)

**Purpose**: Detect when previously-implemented features break

**How It Works**:
```
v7 heartbeat integration (optional):
├─ Periodically call yaml-validator
├─ Run all 8 test scenarios
├─ Compare results to baseline
├─ Alert if any regressions detected
└─ Track test results over time
```

**Regression Scenarios**:
```yaml
# From YAML - these become automated regression tests

test_1_normal_startup:
  baseline: "All zenka verify as OK (no anomalies)"
  regression_if: "Some zenka show anomalies when they shouldn't"

test_2_system_upgrade:
  baseline: "Anomaly detected, auto-repair triggered"
  regression_if: "System upgrade not detected or repair fails"

test_4b_on_demand_zenka_verification:
  baseline: "On-demand zenka skipped by heartbeat monitoring"
  regression_if: "On-demand zenka checked continuously (performance regression)"

test_5_parent_child_dependency_failure:
  baseline: "Child fork prevented by missing binary deps"
  regression_if: "Fork succeeds with missing deps (startup failure regression)"
```

**Alert on Regression**:
```perl
if ($test_result->{status} eq 'FAILED' && $baseline->{status} eq 'PASSED') {
    <[base.log]>->(0, "REGRESSION DETECTED: %s", $test_result->{scenario});
    <[base.log]>->(0, "  Previous: %s", $baseline->{result});
    <[base.log]>->(0, "  Current:  %s", $test_result->{result});

    # Alert admin
    <[base.notify]>->({
        type => 'regression',
        scenario => $test_result->{scenario},
        severity => 'error'
    });
}
```

---

## Implementation Roadmap

### Phase 1: Pre-Commit Hook (Immediate)

```bash
# Create .git/hooks/pre-commit that:
# 1. Parses commit message for step reference
# 2. Loads YAML acceptance criteria
# 3. Validates changed code matches criteria
# 4. Rejects if incomplete

effort: Small
benefit: High (prevents incomplete commits)
```

### Phase 2: YAML-Validator Zenka (After Level 3)

```bash
# New zenka: yaml-validator
# 1. Reads testing scenarios from YAML
# 2. Executes each scenario
# 3. Compares results to expectations
# 4. Tracks test history

effort: Medium
benefit: High (automated validation)
```

### Phase 3: Regression Testing Integration (After Phase 2)

```bash
# Integrate with v7 heartbeat (optional)
# 1. Periodically run yaml-validator
# 2. Alert on regressions
# 3. Maintain test baseline history

effort: Small
benefit: High (continuous verification)
```

---

## Benefits of This System

### 1. Prevents Incomplete Implementation
- Git hook validates step completeness before commit
- Can't push half-done work
- Spec compliance enforced at commit time

### 2. YAML Becomes Executable Spec
- Documentation is not separate from tests
- Tests are not separate from spec
- Single source of truth
- Automatically synchronized

### 3. Regression Detection
- Previously-working features breaking is caught immediately
- Not just new bugs, but regressions
- Historical tracking (when did it break)
- Impact analysis (which changes caused regression)

### 4. Accountability Loop
```
Spec (YAML)
    ↓
Implementation (Code)
    ↓ Pre-commit hook validates
Commit (Git)
    ↓ yaml-validator tests
Verification (Automated)
    ↓ Regression detection
Regression Alert
    ↓ (if needed)
Spec Update
    ↑ (cycle continues)
```

### 5. Low Maintenance Cost
- Scenarios already written in YAML
- Hook reads YAML as contract
- Zenka executes YAML as tests
- No parallel spec/test files to maintain

---

## Example: Pre-Commit Hook in Action

### Scenario: Developer commits incomplete work

```bash
$ git commit -m "Implement step 3: Create v7.verify_and_install_zenka_dependencies

Added basic module structure but not full logic."

# Hook checks YAML acceptance criteria:
# - "Detects missing dependencies" → NOT IMPLEMENTED
# - "Can install missing via existing installers" → NOT IMPLEMENTED
# - "Tracks state for monitoring" → NOT IMPLEMENTED
# - "Binary deps trigger warnings not errors" → NOT IMPLEMENTED

# Hook output:
REJECT: Step 3 not complete
  Missing: Detects missing dependencies (detected: only stub)
  Missing: Can install missing via installers
  Missing: Tracks state for monitoring

Complete the acceptance criteria before committing.

Commit BLOCKED.

# Developer must:
# 1. Finish implementing all acceptance criteria
# 2. Run hook again (or just commit, hook validates)
# 3. Push only when complete
```

### Scenario: Regression detected by validator

```bash
$ yaml-validator validate-all

✓ test_1_normal_startup
✓ test_2_system_upgrade
✓ test_3_manual_uninstall
✗ test_4b_on_demand_zenka_verification  [REGRESSION!]
✓ test_5_parent_child_dependency_failure
✓ test_6_unprivileged_operation
✓ test_7_parent_child_dependency_failure

REGRESSION DETECTED:
  test_4b_on_demand_zenka_verification
  Expected: On-demand zenka SKIPPED by heartbeat monitoring
  Actual: On-demand zenka being CHECKED continuously

  This is a PERFORMANCE regression - on-demand zenka shouldn't be checked
  while idle. Review recent commits to heartbeat loop.
```

---

## Integration with Level 3

The yaml-validator zenka can be added as **Phase 2** after Level 3 implementation:

```
Level 3 Phase 1: Implement core architecture (7 steps)
         ↓
Level 3 Phase 2: Add YAML validation system
         ├─ Pre-commit hooks (prevent incomplete commits)
         └─ yaml-validator zenka (continuous validation)
         ↓
Continuous benefit: Regressions detected immediately
```

---

## File Structure for Validation

```
/data/projects/protocol-7/
├─ data/yaml/
│  └─ level-3-configuration-templates.yaml
│     ├─ testing_scenarios (→ Hook reads these)
│     ├─ module_creation_checklist (→ Hook validates against)
│     └─ acceptance_criteria (→ Contract enforced)
│
├─ .git/hooks/
│  └─ pre-commit (NEW)
│     └─ Validates: commit msg → YAML specs → code changes
│
├─ modules/
│  └─ yaml-validator.* (NEW zenka - Phase 2)
│     ├─ yaml-validator.base.validate_scenario
│     ├─ yaml-validator.base.compare_to_baseline
│     ├─ yaml-validator.base.detect_regressions
│     └─ yaml-validator.cmd.* (user-facing commands)
│
└─ data/asc/
   ├─ LEVEL-3-YAML-SPEC-VALIDATION.md (this file)
   └─ [other architecture docs]
```

---

## Summary: YAML-Driven Quality Control

This system transforms YAML documentation from passive spec into **active quality control**:

✓ **Pre-Commit**: Enforces spec compliance at commit time
✓ **Execution**: YAML scenarios become automated tests
✓ **Regression**: Detects when promised features break
✓ **Accountability**: Commits must fulfill their promises
✓ **Low Maintenance**: Single source of truth (YAML)

**Result**: Development workflow becomes spec-driven, with continuous verification that implementation matches promises.

---

## Workflow Zenka Integration

The YAML-validator can integrate with the existing workflow system:

```perl
# In workflow definitions or workflow.cmd.validate

workflow.testing:
  phase_1:
    name: "Implementation Phase"
    tasks:
      - task: implement_step_3
        dependencies: [step_1, step_2]

  phase_2:
    name: "Validation Phase"
    tasks:
      - task: yaml_validator.validate_step
        args: [step_3]
        on_failure: return_to_implementation
        acceptance_criteria: "All 4 acceptance criteria must pass"

  phase_3:
    name: "Regression Check"
    tasks:
      - task: yaml_validator.check_regressions
        on_failure: alert_admin
        success_criteria: "No new regressions detected"

  phase_4:
    name: "Approval"
    tasks:
      - task: allow_commit
        prerequisite: [phase_2, phase_3]
```

**Workflow Integration Benefits**:
- YAML validation becomes part of development workflow
- Validation gates task progression
- Failed validation prevents phase advancement
- Regression checks block commits automatically
- Visual progress tracking through phases

---

## Next Steps

1. **Phase 1 (Immediate)**: Create `.git/hooks/pre-commit` that validates step completeness
2. **Phase 2 (After Level 3)**: Implement `yaml-validator` zenka with automated testing
3. **Phase 2b (Parallel)**: Integrate with workflow zenka for structured validation
4. **Phase 3 (Continuous)**: Integrate with v7 heartbeat for ongoing regression detection

This is a **meta-level quality system** that uses the architecture documentation itself as the validation mechanism, reinforced by workflow integration.

#,,..,...,.,.,,,.,,,,,,..,..,,,,,,..,,,..,..,,..,,...,...,,..,,..,,,.,...,.,,,
#ML7TRXPJ6GS6C45HLWYXTJ4XV7LVXI4IUPI3PP2JSV2DZOLISBOZ7EQOARY3X3FVAH5RQOYPGC6MK
#\\\|ZX7BFBO5R73BXBIR4MICWE2ISTKXPDVZFECPQ4LU4Y3WEZTGSBC \ / AMOS7 \ YOURUM ::
#\[7]TTVHDHOBGW2E73HAWFMRBXJ7TUEDUVNJIIVPVXON4JSRZZO7SCDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
