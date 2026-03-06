# AI Models Dependencies

## Current Dependencies (AnyEvent::HTTP - Active)

### Debian Packages Required

```bash
# Core AnyEvent (Event.pm integration)
libanyevent-perl        # 7.170-2+b7 or later
libanyevent-http-perl   # 2.25-2 or later
```

### Protocol-7 Profile

```yaml
## .deps/profiles.yaml
ai-models:
  description: "AI/LLM model support (local and remote backends)"
  apt:
    - libanyevent-http-perl
    - libanyevent-perl
```

No CPAN modules required - pure Debian packages.

---

## Historical Dependencies (IO::Async - Discarded)

During development, we investigated `IO::Async::Loop::Event` but **discarded it**
because it required polling (`loop_once()`) rather than true Event.pm integration.

### What Was Installed (for reference)

```bash
# Debian packages (pre-existing on system, not removed)
libio-async-perl        # 0.805-1
libio-async-ssl-perl    # 0.25-1
libnet-async-http-perl  # 0.50-1

# CPAN module (manually installed, can be removed)
IO::Async::Loop::Event  # 0.03
```

### To Remove IO::Async::Loop::Event (Optional Cleanup)

```bash
# Check if installed
perl -MIO::Async::Loop::Event -e1 && echo "installed" || echo "not installed"

# Remove if desired (system-wide CPAN install)
sudo cpanm --uninstall IO::Async::Loop::Event
```

**Note:** The Debian packages (`libio-async-perl`, etc.) are pre-existing system
dependencies. They don't conflict with our AnyEvent solution and can remain.

---

## Verification

```bash
# Verify AnyEvent::HTTP works with Event.pm
perl -MAnyEvent -MAnyEvent::HTTP -e '
    $AnyEvent::MODEL = "Event";
    print "AnyEvent backend: " . AnyEvent->detect . "\n";
    print "AnyEvent::HTTP: OK\n";
'
```

Expected output:
```
AnyEvent backend: Event
AnyEvent::HTTP: OK
```

---

## Summary

| Component | Status | Action |
|-----------|--------|--------|
| `libanyevent-perl` | ✅ Required | Keep |
| `libanyevent-http-perl` | ✅ Required | Keep |
| `IO::Async::Loop::Event` (CPAN) | ❌ Not needed | Optional: uninstall |
| `libio-async-perl` (Debian) | ⚪ Pre-existing | Neutral - keep or remove as desired |
| `libnet-async-http-perl` | ⚪ Pre-existing | Neutral - keep or remove as desired |

---

#,,.,,,..,.,,,.,.,,,.,,.,,,.,,.,.,.,.,...,..,,.,.,...,...,.,.,,.,,..,,,,.,..,,
#RUYCEU2LW5PQRRCMV7SMGUJLQYBNN3M4IAUFBDKSMTTLRUOP7WSMSJA2EPNGCJQH6QEGSQISGKJU2
#\\\|4UESL5D7K7Q4O4FJDBFJTMDVU3JITT2IENVRPNDQMLYQWL2DCGV \ / AMOS7 \ YOURUM ::
#\[7]DGH6ZCLGGV7G77KF4RTHCXRFPE7TRVJBSCYY25YW4UCZ72TA7KAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
