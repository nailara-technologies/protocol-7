---
name: feedback-small-generic-components-before-wiring
description: "user's design-approach preference: for multi-feature-converging problems, infer a few small generic components each individually complete, rather than hard-committing to the first mechanism that closes the immediate ticket"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 5d437747-f04b-4b79-bedc-b5ebe9e545a1
  modified: 2026-07-18T13:57:46.639Z
---

When a fix touches a problem that several other in-flight or planned
features also need (seen with: jobsite/httpd auth 401 turning into a
cross-host zenka trust design touching cred-mesh, discover, TOFU,
nameserv — see [[project-cross-host-trust-bootstrap-gap]]), the user
explicitly stops implementation-in-progress rather than let it land as a
one-off shim.

**Why:** stated directly — "the main requirement having slowed things
down is to remain flexible and generic enough for more than one usecase,
and to avoid poking in the dark and hard commit to the first thing hit
and then later end up with an architectural component that did not
consider half of the usecases required of it later, leading to large
refactoring requirements again." This happened concretely: I was
mid-implementation (about to generate a shared secret and wire cube
route-send for a session token) when the user caught that the design
assumed jobsite and httpd/web share a cube — an assumption that breaks
for the very reason `/jobs-sync` is HTTP instead of a native zenka route
(to support a remote jobsite deployment).

**How to apply:** when a bug fix or feature request sits at the
intersection of multiple named systems (here: auth, cred-mesh, discover,
nameserv, C25519 identity), before writing code:
1. Ask whether the obvious/narrow fix would still work under the other
   known use cases that touch the same area, even if those use cases
   aren't in scope today.
2. Prefer decomposing into a small number of independently-complete
   generic components over one bespoke mechanism, even if that means the
   immediate ticket stays unresolved for longer.
3. It is fine, and preferred, to pick a low-stakes / easily-reversible
   feature as the pilot to prove a new generic mechanism against (here:
   jobs-sync auth, chosen explicitly because local auth can be disabled
   again at zero cost, and a real second host exists to test the
   actually-hard case).
4. Don't stop at "design conversation" complete — the user wants the
   decomposition itself made concrete (named components, what each one
   owns) before any code, but is comfortable proceeding once that
   decomposition is agreed, rather than needing every detail nailed down
   first.

#,,,.,,,.,,,,,..,,.,.,..,,,,,,...,...,,,,,...,..,,...,.,.,.,,,...,..,,,,,,...,
#5LEE7MCVH22YJGGYYW4P2B5PWSGFSSOMRRKYZU4S76L552HS2LVJJAK73HVCAZFMJOXOJXAQGRXL4
#\\\|7HNP773WY6KKM5R4X2FEOTA5N2WWYAA5URULWOEW55EWB3UZPX7 \ / AMOS7 \ YOURUM ::
#\[7]INUMPYYL37DP4UWC2LRZ74B3NHUC7FS6AGUSD6LWIJARLGCJEOAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
