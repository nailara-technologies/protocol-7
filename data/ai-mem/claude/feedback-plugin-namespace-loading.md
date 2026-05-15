---
name: feedback-plugin-namespace-loading
description: foreign namespace plugins need explicit white-list registration in zenka start file
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 095ef9b6-c744-46c5-bac8-4d54a2d5ce45
---

`plugin.httpd.*` loads automatically in httpd because `httpd` is in modules.load
and the dep graph includes its plugins. `plugin.web.*` does NOT auto-load in httpd
because `web` module is not loaded there.

**Why:** The dep graph parser expects plugins to be loaded by their parent module's
zenka. Cross-namespace plugins (e.g. plugin.web.jobs in httpd) need explicit
registration: `[base.white-list.register:'plugin.web.jobs']` in the httpd start file.

**How to apply:** When adding a plugin.X.* to a zenka that doesn't load the X module,
add the register call to that zenka's start file. Without it, modules lazy-load
per-request (recompile every call, no persistence between requests).

Also: `file.zenka_dir.data_path` returns the CALLING zenka's var dir, not the
owning zenka's dir. Cross-zenka file access must hardcode the target zenka name
via `<system.path.zenka-dirs>->{'var_P7'} . '/jobsite'` etc.

#,,.,,,..,,..,,.,,,,,,...,,..,,,.,.,.,..,,...,..,,...,...,..,,,,,,...,,.,,,.,,
#7DQJA4FMIMQ6HIWGGWSYC5W57WJIVT5MHZGEX6LOQBUTPTAYQPE5BGS2AZDCGNDJXS27A3AB6EXLS
#\\\|ILGKSVZUQKICZPKGRTD45P72HUWG5WMWHFWRUJTAL7AYHRIKMP4 \ / AMOS7 \ YOURUM ::
#\[7]5DIPJKYXPSRHS7P7UOJZM6MHFBNRKNYAS3IVZ3IHFWTYARVSP6CI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
