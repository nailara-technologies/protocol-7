# task: repo root cleanup — var/, local/, batches/

## context

three directories exist in the repository root that were never intended to be
there. some contain tracked files that need decisions before removal.

---

## decisions needed

### 1. var/httpd/static/ path — absolute vs relative

`src/web.assets.load_registry` uses:
```perl
my $registry_file = "$project_root/var/httpd/static/.asset-registry.yaml";
```

all other httpd code uses absolute `/var/httpd/` (via `<httpd.site_dir>` or
hardcoded). this module is the exception.

**decision**: update `web.assets.load_registry` to use an absolute path
consistent with the rest of httpd — likely `/var/protocol-7/httpd/static/`
or `/var/httpd/static/`. add an install step (similar to vhost template
install) that creates the directory at the absolute path on first run.

### 2. var/httpd/skins/default.tmpl — source location

all skin code uses absolute `/var/httpd/skins/` at runtime. the template
was accidentally committed at the relative repo path instead.

**decision**: move to `data/web-root/skins/default.tmpl` as the tracked
source of truth. add a deploy/install step that copies it to
`/var/httpd/skins/` (same pattern as vhost template install). the absolute
path directory is currently empty.

### 3. batches/test_vision_batch.yaml

a one-off test batch file, no code references it. contains a tracked image
path for vision testing.

**decision**: move to `workspace/` or `data/batches/` (create if needed),
or just remove if no longer needed.

---

## items to remove after decisions

| path | status | action |
|------|--------|--------|
| `var/httpd/skins/default.tmpl` | tracked | move to `data/web-root/skins/` + deploy step |
| `var/httpd/static/.gitignore` | tracked | git rm (dir recreated by install at absolute path) |
| `var/httpd/static/README.md` | tracked | git rm |
| `batches/test_vision_batch.yaml` | tracked | move to `workspace/` or delete |
| `var/index/` | untracked runtime state | wipe |
| `var/inference-cache/` | untracked runtime state | wipe |
| `var/nameserv/` | untracked runtime state | wipe |
| `var/sys-deps/` | untracked runtime state | wipe |
| `local/` | untracked cpanm local-lib install (ran as local user instead of root) | wipe |

---

## code to update

- `src/web.assets.load_registry` — change `$project_root/var/httpd/static/`
  to absolute path; add config key `<web.cfg.static_dir>` defaulting to
  `/var/httpd/static` for consistency with `<web.cfg.skins_dir>`
- add install/deploy command for skins (similar to `httpd.cmd.install-vhosts`)

---

## gitignore

`.gitignore` already updated to exclude `local/` and `var/index/`,
`var/inference-cache/`, `var/nameserv/`, `var/sys-deps/` from tracking.
once tracked files are removed and `var/httpd/static/` moves to absolute
path, add `var/` entirely to `.gitignore`.

#,,.,,,.,,,,.,.,.,.,.,...,,,.,,,.,.,,,.,,,,,,,..,,...,..,,,,.,,..,.,,,,..,..,,
#KSEHETEUT3EU4QDDYUPGTXW6LEI7AFVMEXISJXRK7FTUG47ZYWB64VHJ3LUEW4YHCS7AMK7HUU4C4
#\\\|YRSCO4W5L3I63XCMURCBGJTOHVBISVYACK75YNLQ4ZPV6NRB34E \ / AMOS7 \ YOURUM ::
#\[7]FIVXDBCE7LQFRLZILDRPB2YJZFLVAQJI4SOSDQR2SJ3IGMTYIADI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
