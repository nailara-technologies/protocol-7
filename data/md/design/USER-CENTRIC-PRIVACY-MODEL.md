# User-Centric Privacy Model

## Core Principle: Privacy as Explicit, Not Default

In Protocol-7, privacy is not something you protect by hiding—it's something you **grant explicitly**. The network's default assumption is: **don't know what you don't need to know**.

```
Traditional Model (leak by default):
  ┌─────────────────────────────────────┐
  │ User data: EVERYTHING               │
  │ ↓                                   │
  │ [implicitly shared]                 │
  │ ↓                                   │
  │ Network knows: TOO MUCH             │
  │ User must OPT OUT of sharing        │
  └─────────────────────────────────────┘

Protocol-7 Model (private by default):
  ┌─────────────────────────────────────┐
  │ User data: ONLY WHAT'S NEEDED       │
  │ ↓                                   │
  │ [explicitly marked personal]        │
  │ ↓                                   │
  │ Network knows: ONLY WHAT'S SHARED   │
  │ User must OPT IN to sharing         │
  │ Personal prefs marked explicit      │
  └─────────────────────────────────────┘
```

## Leaf-Most Branch Locality

### Your Place in the Network

```
Protocol-7 Network Topology:

                    [ROOT]
                      │
              ┌───────┴───────┐
              │               │
           [Region A]      [Region B]
              │               │
        ┌─────┼─────┐    ┌────┼────┐
        │     │     │    │    │    │
     [City1][City2][City3] ...   [CityN]
        │     │     │
    ┌───┴──┐ ┌┴┐   ┌┴────┐
    │      │ │ │   │     │
 [Org A] [Org B] [Community X]
    │      │         │
    │   ┌──┴──┐   ┌──┴──┐
    │   │     │   │     │
  [Team][Team][Team] [Your Branch] ← YOU ARE HERE
    │    │     │       │
    └────┴─────┴───────┘
         (leaf-most)

You inherit from: Team → Org → City → Region → Root
You contribute to: Your Branch (anonymized)
```

### What "Leaf-Most" Means

```
Your Branch (leaf-most locality):
  ┌─────────────────────────────────────┐
  │ • Physically closest network node   │
  │ • Social/professional community     │
  │ • Shared context and culture        │
  │ • Similar workflow patterns         │
  │ • Common application usage          │
  └─────────────────────────────────────┘

Why this matters for privacy:
  • Inherits defaults matching your context
  • Receives optimizations for your use cases
  • Shares statistics with minimum exposure
  • Personal diffs stay within community bounds
```

## The Personal Config/Zenka

### User Namespace: `user.*`

```
┌─────────────────────────────────────────────────────────────┐
│                 USER CONFIGURATION SPACE                    │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  user.personal.*        ← MARKED AS PERSONAL                │
│  ├── These values:                                          │
│  │   • Never leave device                                    │
│  │   • Explicitly marked by user                             │
│  │   • Override all inherited defaults                       │
│  │   • Require explicit consent to share                     │
│  │                                                           │
│  │   Examples:                                               │
│  │   • user.personal.name = "Alice"                          │
│  │   • user.personal.ssh_key = "..."                         │
│  │   • user.personal.preferences.terminal.font_size = 14     │
│  │                                                           │
│  └── Marked via:                                            │
│      • Prefix: user.personal.*                              │
│      • Flag: { personal => true }                           │
│      • Command: settings.personal.set                       │
│                                                             │
│  user.local.*           ← LOCAL COMPUTATION                 │
│  ├── These values:                                          │
│  │   • Stay on local device                                  │
│  │   • Can be reconstructed from network                     │
│  │   • Cache, temporary state, computed values               │
│  │                                                           │
│  │   Examples:                                               │
│  │   • user.local.cache.recent_files = [...]                 │
│  │   • user.local.state.window_positions = {...}             │
│  │   • user.local.computed.workflow_efficiency = 0.87        │
│  │                                                           │
│  └── Can be cleared without data loss                       │
│                                                             │
│  user.inherited.*       ← FROM NETWORK                      │
│  ├── These values:                                          │
│  │   • Received from branch/network                          │
│  │   • Community defaults                                    │
│  │   • Statistics-derived optimizations                      │
│  │                                                           │
│  │   Examples:                                               │
│  │   • user.inherited.defaults.theme = "dark_teal"           │
│  │   • user.inherited.optimizations.editor_tab_size = 4      │
│  │   • user.inherited.workflow_patterns = [...]              │
│  │                                                           │
│  └── Read-only locally (changes go upstream via contribution) │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Personal vs. Inherited: The Decision Flow

```
User wants to change a setting:

          ┌─────────────────────┐
          │ Change setting:     │
          │ terminal.opacity    │
          └──────────┬──────────┘
                     │
                     ▼
          ┌─────────────────────┐
          │ Is this personal?   │
          │ (Would others want  │
          │  different value?)  │
          └──────────┬──────────┘
                     │
         ┌───────────┴───────────┐
         │                       │
        YES                     NO
         │                       │
         ▼                       ▼
┌─────────────────┐    ┌─────────────────┐
│ Mark as:        │    │ This could be   │
│ user.personal.* │    │ a new default!  │
│                 │    │                 │
│ Stays local     │    │ Contribute to   │
│ Never shared    │    │ branch:         │
│ Always respected│    │ "I prefer 0.95" │
└─────────────────┘    │                 │
                       │ If others agree │
                       │ it becomes the  │
                       │ new inherited   │
                       │ default         │
                       └─────────────────┘

Result: Only truly personal things are personal.
        Everything else improves the network.
```

## What the Network Knows: Transparent Visibility

### The User Dashboard

```
┌─────────────────────────────────────────────────────────────┐
│           YOUR PRIVACY DASHBOARD                            │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  WHAT THE NETWORK KNOWS ABOUT YOU:                          │
│  ═════════════════════════════════                          │
│                                                             │
│  ┌─ Impersonal Contributions ─────────────────────────┐    │
│  │                                                     │    │
│  │  Statistics Zenka has received:                     │    │
│  │  • Application type preferences (3 categories)      │    │
│  │  • Visual theme: "dark_teal" (anonymized)           │    │
│  │  • Workflow efficiency patterns (aggregated)        │    │
│  │  • 47 preference diffs contributed to branch        │    │
│  │                                                     │    │
│  │  [View full details]  [Download your data]          │    │
│  │                                                     │    │
│  └─────────────────────────────────────────────────────┘    │
│                                                             │
│  ┌─ Personal Data (NEVER SHARED) ──────────────────────┐    │
│  │                                                     │    │
│  │  These values stay on your device:                  │    │
│  │  • user.personal.name                               │    │
│  │  • user.personal.credentials.*                      │    │
│  │  • user.personal.private_key                        │    │
│  │  • user.personal.preferences.font_size              │    │
│  │                                                     │    │
│  │  Count: 12 personal settings                        │    │
│  │  Last sync attempt: NEVER                           │    │
│  │                                                     │    │
│  │  [Verify no network exposure]                       │    │
│  │                                                     │    │
│  └─────────────────────────────────────────────────────┘    │
│                                                             │
│  ┌─ Inherited from Network ────────────────────────────┐    │
│  │                                                     │    │
│  │  Your branch ("dev-team-nyc") provides:             │    │
│  │  • Default theme: "dark_teal"                       │    │
│  │  • Default editor: configured for Rust/Perl         │    │
│  │  • Workflow optimizations: 47 patterns              │    │
│  │  • Network routing: optimized for East Coast        │    │
│  │                                                     │    │
│  │  [View inheritance chain]  [Request changes]        │    │
│  │                                                     │    │
│  └─────────────────────────────────────────────────────┘    │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Explicit Consent for Sharing

```
When sharing is requested:

┌─────────────────────────────────────────────────────────────┐
│  ⚠️  SHARE PERSONAL PREFERENCE?                              │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  You are about to share:                                    │
│                                                             │
│  Setting: terminal.font_size = 14                           │
│  Current status: PERSONAL (local only)                      │
│  Requested action: Contribute to branch defaults            │
│                                                             │
│  Impact analysis:                                           │
│  • Your value will be aggregated with 23 others             │
│  • If pattern emerges, may become new default               │
│  • No link to your identity will be stored                  │
│  • You can revoke this contribution anytime                 │
│                                                             │
│  [Share Anonymously]  [Keep Personal]  [Learn more]         │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## The Diff Model: Minimal Personal Exposure

### Calculating What Needs to Be Personal

```
Branch defaults for your context:
┌─────────────────────────────────────────────────────────┐
│ theme                    = "dark_teal"                  │
│ terminal.opacity         = 0.90                         │
│ terminal.font_size       = 12                           │
│ editor.tab_size          = 4                            │
│ editor.show_whitespace   = false                        │
│ workflow.sidepanel       = "right"                      │
│ notifications.enabled    = true                         │
│ ... (100+ more defaults)                                │
└─────────────────────────────────────────────────────────┘

Your personal preferences:
┌─────────────────────────────────────────────────────────┐
│ terminal.font_size       = 14    ← DIFFERENT            │
│ editor.show_whitespace   = true  ← DIFFERENT            │
│ theme                    = "dark_teal"  ← SAME          │
│ terminal.opacity         = 0.90  ← SAME                 │
│ ...                                                     │
└─────────────────────────────────────────────────────────┘

What you actually need to store personally:
┌─────────────────────────────────────────────────────────┐
│ Personal diff:                                          │
│ {                                                       │
│   "terminal.font_size"     => 14,                       │
│   "editor.show_whitespace" => true                      │
│ }                                                       │
│                                                         │
│ Everything else inherited from branch.                  │
│ Minimal exposure. Maximum benefit.                      │
└─────────────────────────────────────────────────────────┘
```

### Dynamic Diff Shrinking

```
Over time, diffs can shrink as defaults improve:

Month 1:
  Your diffs: 15 settings different from defaults
  → 15 personal overrides needed

Month 6 (defaults improved from community patterns):
  Your diffs: 7 settings different from defaults
  → 8 of your preferences became new defaults!
  → Only 7 personal overrides needed

Month 12 (more alignment):
  Your diffs: 3 settings different from defaults
  → Community converged on optimal patterns
  → Only truly personal preferences remain

Result: Less personal data to manage over time.
        Better defaults for everyone.
```

## Implementation: The Privacy Markers

### Code-Level Privacy Controls

```perl
## Setting a value with privacy marker ##

# Personal - never leaves device
<[settings.set]>->(
    'terminal.font_size' => 14,
    { 'privacy' => 'personal' }  # Stays in user.personal.*
);

# Local - can be reconstructed, stays device-local
<[settings.set]>->(
    'cache.recent_files' => $files,
    { 'privacy' => 'local' }     # Goes to user.local.*
);

# Inheritable - can contribute to network defaults
<[settings.set]>->(
    'theme.variant' => 'ocean',
    { 'privacy' => 'inheritable' } # Goes to user.inherited.* (computed)
);

## Querying what the network knows ##
my $network_knowledge = <[privacy.dashboard.get]>->();
# Returns structured report of all shared data
```

### Privacy-Aware Statistics

```perl
## Statistics collection with privacy checks ##

sub statistics.collect_event {
    my ( $event_type, $data, $privacy_level ) = @_;

    # Check if this data type is allowed at this privacy level
    my $allowed = <[privacy.check_allowed]>->(
        $event_type, $privacy_level
    );

    return undef unless $allowed;

    # Anonymize based on privacy rules
    my $anonymized = <[privacy.anonymize]>->( $data, {
        'remove_identifiers' => true,
        'bucket_time' => '10_minutes',
        'min_k_anonymity' => 5,
    });

    # Only contribute if passes privacy threshold
    if ( <[privacy.validate_contribution]>->($anonymized) ) {
        <[statistics.contribute]>->($anonymized);
    }
}
```

## Privacy Leaks: Prevention and Detection

### The Privacy Boundary

```
┌─────────────────────────────────────────────────────────────┐
│                    PRIVACY BOUNDARY                         │
│                    (Your Device)                            │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│   INSIDE (Safe)              OUTSIDE (Requires Explicit     │
│                                         Consent)            │
│   ─────────────              ─────────────────────          │
│                                                             │
│   • File names               • Anonymized file types        │
│   • Exact timestamps         • Time buckets (10min)         │
│   • User identity            • Aggregate counts             │
│   • Personal content         • Semantic clusters            │
│   • Private keys             • Public verification          │
│   • Location (exact)         • Region (approximate)         │
│   • Personal preferences     • Preference patterns          │
│                                                             │
│   ┌─────────────────┐       ┌─────────────────┐            │
│   │  user.personal  │       │  statistics.*   │            │
│   │  user.local     │       │  (anonymized)   │            │
│   │  user.keys.*    │       │  branch.defaults│            │
│   │  user.content.* │       │  (inherited)    │            │
│   └─────────────────┘       └─────────────────┘            │
│                                                             │
│   [NEVER CROSS] ────────► [CAN CROSS with consent]         │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Detection of Accidental Leaks

```perl
## Privacy leak detection ##

sub privacy.validate_transmission {
    my $data = shift;

    # Check for identifiers
    if ( contains_identifier($data) ) {
        <[privacy.alert]>->("Identifier found in outgoing data");
        return false;
    }

    # Check resolution
    if ( temporal_resolution($data) < $MIN_BUCKET_SIZE ) {
        <[privacy.alert]>->("Temporal resolution too high");
        return false;
    }

    # Check k-anonymity
    if ( k_anonymity($data) < $MIN_K ) {
        <[privacy.alert]>->("Insufficient k-anonymity");
        return false;
    }

    # Check against personal registry
    my $personal_keys = <[settings.personal.list]>->();
    foreach my $key ( keys %$data ) {
        if ( exists $personal_keys->{$key} ) {
            <[privacy.alert]>->("Personal key in transmission: $key");
            return false;
        }
    }

    return true;
}
```

## Summary: Privacy as Architecture

```
┌─────────────────────────────────────────────────────────────┐
│         PROTOCOL-7 PRIVACY PRINCIPLES                       │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  1. PRIVATE BY DEFAULT                                      │
│     Nothing leaves device unless explicitly marked          │
│                                                             │
│  2. TRANSPARENT VISIBILITY                                  │
│     User can see exactly what network knows about them      │
│                                                             │
│  3. MINIMAL DIFFERENCE                                      │
│     Only personal preferences different from defaults       │
│     need personal marking                                   │
│                                                             │
│  4. EXPLICIT CONSENT                                        │
│     Sharing requires opt-in, not opt-out                    │
│                                                             │
│  5. LEAF-MOST LOCALITY                                      │
│     Inherit from closest branch, minimize exposure          │
│                                                             │
│  6. CONTINUOUS IMPROVEMENT                                  │
│     As defaults improve, personal diffs shrink              │
│                                                             │
│  7. DETECT AND PREVENT LEAKS                                │
│     Automatic validation prevents accidental exposure       │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

The result: **You know what the network knows. And it's never more than it needs to know.**

---

*Privacy through explicit marking, minimal diffs, and transparent visibility.*

#,,,,,...,,,.,.,,,,.,,,,.,.,.,.,,,,,.,...,,,.,..,,...,...,.,,,,..,..,,...,...,
#O6VBJU4WWCHECSAHCHOOGLMMHR4H2KSW77VURSLOC3ZCHF7XBA23EG353REQW54PGBUQODVZVM33Y
#\\\|KLEQPM6UPCKWSOT7ROCICC6P7A77A3DHZYZY34DFLAXQ6F4G7UD \ / AMOS7 \ YOURUM ::
#\[7]RNBO5XKSK7G4LSILODOFTW6NYA5GMT2KJLJIJGZZBXNX7F5TEYBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
