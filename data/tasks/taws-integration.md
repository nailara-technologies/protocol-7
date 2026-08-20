## [:< ##

# name  = task: TAWS integration — Amiga Workbench simulation as P7 web frontend
# descr = integrate TAWS (taws.ch) as web-browser zenka start page with P7
#         zenki serving the backend instead of PHP/ASPX server scripts

## kimi memory

if in doubt about P7 patterns, coding style, or project context — read first:
```bash
cat data/ai-mem/kimi/MEMORY.md
cat data/ai-mem/kimi/coding-style.md
```

## context

TAWS (The Amiga Workbench Simulation) is a pure JavaScript simulation of
AmigaOS 1.0 through 4.1, running in any browser. active since 2001, version
0.40 released February 2026. author: Michael Rupp (taws.ch).

TAWS supports server-side integration via PHP/ASPX scripts that let the
Workbench browse and operate on real server directories. replacing those
scripts with P7 httpd endpoints makes TAWS the visual frontend to a
Protocol-7 distributed network:

- drawers = P7 namespace tree nodes
- icons = zenki (double-click starts them on demand)
- shell = routes to nshell / p7c
- MultiView = web-browser zenka renders P7 content
- HippoPlayer = radio zenka streams MOD/SID/audio

this is the first instance of a generic pattern: web component + P7 backend.
the template system integration (future) would generate the Config.js and
endpoint wiring from a template. for now: working integration is the goal.

## signatures note

do not add signature stubs. do not run `bin/Protocol-7 sourcecode update-signatures`.
do not add or modify subroutine whitelists — these are managed separately.

---

## phase 1: obtain and host TAWS

### step 1: contact Michael Rupp

email taws.ch author requesting permission to host TAWS locally within
Protocol-7 for backend integration. context to provide:
- Protocol-7 is Public Domain
- AMOS7 is named after AMOS Professional (now Public Domain)
- the web-browser zenka view stack is inspired by Amiga screen-pull
- no commercial use, personal/community deployment
- credit and link to taws.ch preserved

if permission granted → proceed. if no response → use URL parameter approach
(load taws.ch directly in web-browser zenka, no local hosting needed for phase 1).

### step 2: host TAWS in P7 web root

```bash
mkdir -p data/web-root/shared/taws/
## copy TAWS files here (WB.html + assets)
## or: configure web-browser.loading_page to load taws.ch directly
```

add to `cfg/zenki/web-browser/zenka-startup.v7`:
```
web-browser.default_uri = https://taws.ch/WB.html?preset=os_4.1_boing_glow
```

or for local hosting:
```
web-browser.default_uri = file:///data/projects/protocol-7/data/web-root/shared/taws/WB.html
```

---

## phase 2: P7 backend replacing PHP server scripts

TAWS Config.js defines server script endpoints. replace with P7 httpd routes.

### TAWS server operations needed

| operation | PHP script | P7 replacement |
|---|---|---|
| list directory | `ls.php?dir=X` | `httpd` → `p7c file.list X` |
| read file | `read.php?file=X` | `httpd` → serve from web-root |
| write file | `write.php` | `httpd` → `p7c file.write` |
| create drawer | `mkdir.php` | `httpd` → `p7c file.mkdir` |
| move/copy | `move.php` | `httpd` → `p7c file.move` |
| delete | `delete.php` | `httpd` → `p7c file.delete` |

### new httpd routes

add to web zenka or httpd configuration:
```
/api/taws/ls     → handler: web.handler.taws_ls
/api/taws/read   → handler: web.handler.taws_read  
/api/taws/write  → handler: web.handler.taws_write
/api/taws/mkdir  → handler: web.handler.taws_mkdir
/api/taws/move   → handler: web.handler.taws_move
/api/taws/delete → handler: web.handler.taws_delete
```

response format: whatever TAWS Config.js expects from the PHP scripts —
read TAWS documentation/source to determine the JSON/text format.

### Config.js modification

in TAWS Config.js, set script paths to P7 endpoints:
```javascript
var scriptLS     = '/api/taws/ls';
var scriptRead   = '/api/taws/read';
var scriptWrite  = '/api/taws/write';
// etc.
```

---

## phase 3: namespace tree as Workbench filesystem

the P7 data namespace tree maps naturally to Workbench drawers:

```
Work:                    → <system.root_path>/data/
  Tasks/                → data/tasks/ (open tasks as icons)
  Completed/            → data/tasks/completed/
  Modules/              → src/ (zenka source as icons)
  Documentation/        → data/md/development/
  Tools/                → bin/dev/ (development tools as icons)
  Music/                → (radio zenka stream sources)
```

zenka icons: double-clicking a `.zenka` icon calls `p7c v7.start_once <zenka>`
and opens a window showing the zenka's current state / commands.

---

## phase 4: web-browser zenka integration

configure the web-browser zenka to load TAWS as default page:

```
## cfg/zenki/web-browser/zenka-startup.v7
web-browser.window.profile          = automatic
web-browser.window.profile-fallback = fullscreen
web-browser.default_uri             = https://taws.ch/WB.html?preset=random
```

for kiosk mode with specific preset:
```
web-browser.default_uri = https://taws.ch/WB.html?preset=os_1.3&noforce
```

the `noforce` parameter lets users change the preset via Workbench Preferences.

---

## phase 5: future — template system integration

once P7's template system can generate web components from YAML specs:

```yaml
## data/yaml/web-components/taws.yaml
component: taws
version:   0.40
base_url:  https://taws.ch/WB.html
backend:   p7-httpd
namespace: data/
presets:
  default: os_4.1_boing_glow
  kiosk:   os_1.3
  random:  random
```

the template system generates `Config.js` and the httpd handler wiring
automatically. adding a new web component becomes: write a YAML spec,
the rest is generated.

---

## test sequence

```bash
## 1. load TAWS in web-browser zenka
p7c web-browser.cmd.load_uri 'https://taws.ch/WB.html?preset=os_1.3'

## 2. verify Workbench renders and screen-pull works
## (visual check — pull down screen to reveal P7 dark blue background)

## 3. test HippoPlayer with modland stream
p7c web-browser.cmd.load_uri \
  'https://taws.ch/WB.html?playmod=https://ftp.modland.com/pub/src/Protracker/BlackStar/the%20race.mod'

## 4. once backend wired: open a drawer and verify P7 directory listing
## (visual check — Work: drawer shows data/tasks/ contents)
```

## success criteria

- [ ] TAWS loads in web-browser zenka (phase 1)
- [ ] Workbench screen-pull works within the zenka window
- [ ] HippoPlayer plays MOD files from modland.com
- [ ] P7 httpd endpoints respond to TAWS directory listing requests (phase 2)
- [ ] Work: drawer shows actual P7 namespace tree contents (phase 3)
- [ ] double-clicking a zenka icon starts the zenka via v7.start_once (phase 3)
- [ ] web-browser zenka loads TAWS as default start page (phase 4)
- [ ] no signature stubs added, no subroutine whitelist changes made

#,,,.,,..,..,,...,.,,,..,,.,.,...,..,,...,,..,..,,...,...,,,,,,,,,...,,,.,,..,
#TLJXV6AKXVQH3UDAAHXQZY3CYJUD33DJP6PPKS3WJLINOJSU35TKKE2WGK5AMBTT5J6TJICVHWVYY
#\\\|WY3KM2GBUTOSOV2IUTHZE7XFBRV2TFMRC3VE35RKZRFUEJ7OQRV \ / AMOS7 \ YOURUM ::
#\[7]ANHFUQKIW3UAPRFE6INQIVYVYNA7OXFJIBGPDH7SOMDS5KYYPABA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
