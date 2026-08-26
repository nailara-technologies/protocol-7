## [:< ##

# name  = [ kimi-task ] web-root-consolidation
# descr = consolidate data/web/, data/web-root/, data/html/ into
#         data/web-root/vhosts/ with per-vhost .vhost-manifest files

## objective

consolidate the three existing web content directories into a single canonical
structure under data/web-root/vhosts/, add .vhost-manifest files to each vhost,
and create a shared/ directory for cross-vhost assets. this prepares the
repository for the vhost install infrastructure task that follows.

## style reference

read data/yaml/docs/protocol-7-coding-style.md before writing any code.

## current state — read these directories first

```
data/web/           →  read contents, identify vhosts
data/web-root/      →  read contents, identify vhosts (space.v7.ax/ exists here)
data/html/          →  read contents, identify vhosts
```

## target structure

```
data/web-root/
  vhosts/
    <hostname>/              →  one directory per vhost
      .vhost-manifest        →  YAML install descriptor (see format below)
      <content files>        →  templates, static assets, etc.
  shared/
    templates/               →  shared .tmpl files used by multiple vhosts
    static/                  →  shared CSS, JS, images
    assets/                  →  other shared resources
```

## .vhost-manifest format (YAML)

create one .vhost-manifest per vhost with these fields:

```yaml
# vhost install manifest
hostname: space.v7.ax
install_path: /var/httpd/space.v7.ax
install_mode: symlinked
dns_match: space.v7.ax
tls: yes
tls_install_path: /var/httpd/space.v7.ax
version_track: yes
merge_strategy: ours-if-changed
description: protocol-7 orbital data space visualization
```

fields:
- hostname: the DNS hostname this vhost serves
- install_path: where to install under httpd docroot
- install_mode: 'symlinked' (default) or 'copy' or 'copy-autoupdate'
- dns_match: DNS name to resolve before installing (skip if doesn't match local IPs)
- tls: yes/no — whether httpsd should serve this vhost with TLS
- tls_install_path: path for httpsd (may differ from httpd path)
- version_track: yes — sourcecode zenka watches these files for changes
- merge_strategy: 'ours-if-changed' — keep local modifications in copy mode
- description: human-readable description

## migration steps

1. create data/web-root/vhosts/ directory structure
2. move data/web-root/space.v7.ax/ → data/web-root/vhosts/space.v7.ax/
3. read data/web/ and data/html/ — identify any vhost directories within them
4. move any identified vhosts to data/web-root/vhosts/<hostname>/
5. move any shared/common assets to data/web-root/shared/
6. create .vhost-manifest for each vhost directory
7. update any internal references (template paths, etc.) if needed

## for each vhost found, create an appropriate .vhost-manifest

space.v7.ax manifest:
- hostname: space.v7.ax
- tls: yes
- description: orbital data space visualization

for any other vhosts found — use the hostname as the directory name and
populate manifest fields based on what type of content is there.

## do NOT

- do not delete or modify any template content files
- do not modify cfg/zenki/* files (that is the install task)
- do not add P7 module signature stubs to .vhost-manifest files
  (they are YAML, not P7 modules)

## deliverables

1. data/web-root/vhosts/<hostname>/ directories with content moved
2. data/web-root/vhosts/<hostname>/.vhost-manifest for each vhost
3. data/web-root/shared/ with any shared assets
4. brief list of what was found in data/web/ and data/html/ and what was done

#,,,,,,..,,,,,..,,,..,.,,,...,,..,.,.,.,.,,,.,..,,...,...,...,,,.,.,.,,,,,.,.,
#PDIL6UXEFYB3VOYKWU3PHKIUFY2UYMIXVI5CFFXBEOTTW5KMYJ77GRFHCVVH4ZBEQXXA32CC4NS7K
#\\\|AC5ZSNHH7ZTEXQEFERKTROVCT7YD56U4JGDL3GHSC2C5XP2TKAM \ / AMOS7 \ YOURUM ::
#\[7]AJRGZD543E4IFAANUAOTO6M5HNMCDVGA6IFRIAQWB7IEEGCDO4DQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
