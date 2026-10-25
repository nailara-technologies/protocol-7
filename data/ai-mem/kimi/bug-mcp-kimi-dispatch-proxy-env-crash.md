---
name: mcp-kimi-dispatch-proxy-env-crash
description: kimi_dispatch MCP tool failed with httpx InvalidURL ':1]' — PROVEN cause = a bracketed [::1] entry in no_proxy of the spawned child's env; fixed in bin/mcp-server-p7 via _sanitize_agent_env() before every agent exec; activates on next MCP restart
metadata:
  type: bug
---

2026-10-25 : kimi_dispatch returned instant failures whose capture was only
`httpx.InvalidURL: Invalid port ':1]'` + a kimi.log path. root cause, PROVEN
by controlled experiments [ Perl fork/exec repro of _kimi_fork_run ] :

- httpx get_environment_proxies [ uv kimi-cli pkg _utils.py ] maps every
  no_proxy entry to a mount key : ipv4 -> all://H , ipv6 -> all://[H] ,
  anything else -> all://*H . a BRACKETED entry like `[::1]` fails all three
  checks -> key `all://*[::1]` -> URL parse -> `Invalid port ':1]'` at
  AsyncOpenAI client init.
- EXPERIMENTS : empty child env = WORKS ; bare `::1` no_proxy = WORKS ;
  bracketed `[::1]` no_proxy = CRASHES [ exact production error ] .
- the crashing MCP-spawned children therefore carried a bracketed `[::1]`
  in their env. NOTE the mcp-server-p7 /proc/<pid>/environ showed
  empty/whitespace — misleading : /proc shows the exec-time stack envp, not
  runtime-modified %ENV, so WHO injects the bracketed form upstream of the
  exec was never identified [ kimi CLI MCP-spawn env handling suspected ;
  kimi_cli pkg itself has no no_proxy code ] . the sanitizer makes the
  injection moot either way.
- also observed : /etc/environment has a malformed `ALL_PROXY=socks5//…`
  [ missing colon ] and .bashrc builds no_proxy dynamically with
  `$(hostname -I …)` [ bare IPv6 on WSL ] — both are fine for httpx but
  are landmines for stricter parsers.

**FIX APPLIED [ bin/mcp-server-p7, syntax-checked ]** : new
`_sanitize_agent_env()` deletes every `^(https?|all|no)_proxy$`i var from
%ENV, called in the worker block of all three spawn paths :
_dispatch_followup [ ~2668 ] , _cloud_fork_run [ ~5230 ] , _kimi_fork_run
[ ~5678 ]. api.kimi.com is reachable DIRECT from this host [ env -i run
completed ] so no proxy vars are needed. ACTIVATES ON NEXT mcp-server-p7
RESTART [ perl reads the file at process start ].

**verify after restart** : `kimi_dispatch` MCP call with a trivial prompt
[ e.g. 'Reply with exactly: dispatch-ok' ] should return a real completion.

**manual workaround still valid** : setsid env no_proxy="localhost,127.0.0.1,
172.24.33.224,172.17.0.1" NO_PROXY=… ~/.local/bin/kimi-legacy -y --afk
-p "$(cat prompt.txt)" --model kimi-code/kimi-for-coding   [ k2.8 ==
kimi-code/kimi-for-coding per %model_map ~line 4291 ]. kimi_check_status
works for manual dispatches [ reads session state, spawns nothing ] ;
kimi_continue MCP spawns and needs the same env treatment manually via
`kimi-legacy -r <uuid>` until the restart.

#,,,,,,..,,,,,,.,,.,.,,..,,.,,,,,,,,.,,,.,.,.,.,.,...,...,...,,,,,,,,,.,.,..,,
#4T6RFLHZFWSYIDE272VUW23322OCVU7M32OCIRWZTQKZPJ5RL3GALAZ4TOAICCT4DEGCTFO7LD7YK
#\\\|CHXCJ4NTSIQW7J5UQRMNGJSLNUHYVMEXOTX54N7YDU4N5V6EACF \ / AMOS7 \ YOURUM ::
#\[7]HHJLJXAEDOKCRM2Q55Q4D6W5DROU6NP52IMFI6Q2FPX5NIWAUMDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
