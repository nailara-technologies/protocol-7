---
name: feedback-web-browser-ephemeral-storage
description: web-browser zenka runs WebKit ephemeral (private-browsing) by default — localStorage/cookies/IndexedDB wiped on every process restart
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 7c17eae7-f6c4-401f-9fec-c5f3fdcd8849
---

`cfg/zenki/web-browser/start.cfg` sets `cfg.ephemeral = 1`
(and `src/web-browser.init_code` defaults it to 1 even if unset). This
makes `src/web-browser.open_window` construct a
`Gtk3::WebKit2::WebsiteDataManager->new_ephemeral` context — a
private-browsing-style profile where localStorage, cookies, and IndexedDB
all live in memory only and are **wiped the instant the zenka process
restarts**. Nothing about this is logged as a warning to the user; it's
silent.

**Why this matters:** discovered 2026-07-02 debugging the jobs.vhost
export-history-sync feature ([[topic-plugin-web-jobs]]). A migration step
that read legacy per-browser `localStorage` data to push it to the server
never ran successfully because the user restarted the `web-browser` zenka to
test the fix — which wiped the exact `localStorage` key the migration needed
to read, before the migration code ever got a chance to run. Confirmed via
`/var/protocol-7/web/jobs/*.yaml` (0 files with the new field) and the `web`
zenka's log buffer (no corresponding sync POSTs), not by guessing.

**How to apply:** any feature relying on this browser's `localStorage`/
cookies/client-side persistence for anything that matters must treat that
storage as **volatile, not durable** — assume it can vanish on any restart
of the `web-browser` zenka (crash, manual restart, host reboot). Any state
that needs to survive must be pushed to a server-side store as soon as
possible, not accumulated client-side and migrated "later." If genuinely
persistent browser storage is needed, either flip `cfg.ephemeral = 0` for
that zenka (accepting whatever tradeoff made ephemeral the default — not yet
investigated) or don't rely on this browser for it; a real Firefox/other
non-ephemeral browser session is a separate, persistent client of the same
sync API and unaffected by this.

#,,,.,,..,.,,,,..,.,,,..,,,.,,..,,..,,.,,,,,.,..,,...,..,,,,,,,.,,..,,.,.,..,,
#UFNPMS5LJ3SBFMCQRAAIV6XE6ZRBCLBHIEITPC4FH7H3ZILVOYCLJKPXFPKELIJIN7WYIZ6V5DJO2
#\\\|IBQIVGYVMLYQGUWD3AHNCMVB7VWMY6RPBNRLDT6BPZHIPQOSUWD \ / AMOS7 \ YOURUM ::
#\[7]HWO3HL7SL7EGBGOV6ZSXCXH7657YXSOQPZM37P2JIGWWCLD6HECQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
