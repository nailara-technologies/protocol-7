# ext-pkg zenka

external package-manager installs : the pip / npm / uv-tool sibling to
the `os-pkg` zenka [ apt-only ] .., covers anything installable via a
language\tool package manager that is not apt or cpan — see
`data/tasks/ext-pkg-zenka.md` for the full scoping context.

## scope

package-manager-backed installs only .., no build step , no docker , no
tarball fetching — anything needing that belongs to `build-zenka`
instead .., deliberately the simplest of the three dependency systems
[ `.deps/profiles.yaml` + os-pkg , build-zenka , ext-pkg ] ..

## lifecycle contract

**install-if-missing ONLY** .., ext-pkg bootstraps a tool onto a fresh
machine and then leaves it alone : never force-reinstall , never
upgrade — registered tools manage their own updates [ kimi-cli via the
uv tool upgrade path , claude via its own versions/ updater ] ..,
ongoing version management stays with each tool's own mechanism ..

## registry format

one yaml per package under `packages/<name>.yaml` :

| field           | meaning                                                        |
|-----------------|----------------------------------------------------------------|
| `name`          | registry entry name [ = filename ]                             |
| `manager`       | `pip` \| `npm` \| `uv-tool`                                    |
| `package`       | package name as known to the manager                           |
| `check`         | presence-check shell command : exit 0 = present , stdout       |
|                 | captured for the version record                                |
| `install`       | install shell command [ run only when check fails ]            |
| `self_updating` | informational : tool manages its own updates                   |
| `update_owner`  | informational : which mechanism owns version management        |

first entries : `kimi-cli` [ uv-tool ] and `claude` [ npm ] — install
mechanisms verified against the actual host installs 2026-07-29 ..,
per-entry verification notes are in the yaml files ..

## cpan decision [ task 1.2 ]

**cpan stays under `bin/p7-deps` / `.deps/profiles.yaml` — it does NOT
register here as a fourth manager.** rationale :

- different lifecycle contract : `.deps/profiles.yaml` cpan entries are
  version-pinned *project build\run dependencies* grouped into profiles
  [ installed\verified as a set ] .., ext-pkg entries are self-updating
  *end-user tools* installed once and then left alone — merging the two
  would blur the install-if-missing guarantee that is load-bearing here
- `bin/p7-deps` already handles apt+cpan uniformly per profile ..,
  moving cpan out would split that system in two for no coverage gain
- no blind spot is created : the phase-2 coverage audit [ task 2.1 ]
  reads all three registries [ profiles.yaml , build-zenka recipes ,
  ext-pkg packages ] into one status view , so cpan remains visible
  from the same place either way

## status records

every `package-ensure` run writes
`/var/protocol-7/ext-pkg/status/<name>.yaml` :

```yaml
package: kimi-cli
manager: uv-tool
status: present            # present | installed-this-run | install-failed | error
version: 1.49.0            # parsed from check output , empty if unparseable
check_output: 'kimi, version 1.49.0'
checked_at: '2026-07-29T04:00:00Z'
detail: '...'
```

this is the data the phase-2 coverage audit [ task 2.1 ] reads ..,

## usage

```bash
p7c ext-pkg.package-ensure kimi-cli
p7c ext-pkg.package-ensure claude
```

module implementing this command : `modules/ext-pkg.cmd.package-ensure`
[ auto-registered cmd_name : `package-ensure` , the `.cmd.` filename
segment is what the loader uses to derive it -- see CLAUDE.md module
file format ]

## notes

- commands run as the zenka user [ `system.amos-zenka-user` =
  `protocol-7` ] .., presence checks therefore reflect *that* user's
  PATH — a tool installed only under another user's `~/.local/bin`
  reports absent and would be installed for the zenka user .., this is
  intentional bootstrap semantics , not a bug
- unsigned files : sign before commit with
  `bin/Protocol-7 sourcecode update-signatures <path>`

#,,,.,..,,..,,.,.,.,.,.,.,,.,,,,.,,,.,.,,,...,..,,...,...,.,,,,.,,.,.,,..,,.,,
#3O75EOPJFOY2DTSYWZZSIOWBAHOD6GNJABJXDIZ5XODA7NDVTSFVFPSSPZSAUA2BGFEM6MFBS274Y
#\\\|IDY772U6IO4FBQVX2CCSZHQIA3ZHEH5DPP7Z336TQPJH4T3GAX5 \ / AMOS7 \ YOURUM ::
#\[7]AL6FOOQCUO446ZLHM4HJZEXNYSK6QH7L72KV2IZULQKBBKMZTECQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
