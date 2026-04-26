## [:< ##

# name  = [ kimi-task ] httpd-vhost-install
# descr = implement vhost install infrastructure — DNS-gated install, symlink/copy
#         modes, letsencr TLS cert auto-request, sourcecode version tracking

## objective

implement the vhost installation system as P7 modules in the httpd zenka namespace.
reads .vhost-manifest files from data/web-root/vhosts/, installs matching vhosts
to /var/httpd/, requests TLS certs via letsencr zenka where needed, and registers
installed vhosts for version-tracking updates.

## style reference

read data/yaml/docs/protocol-7-coding-style.md before writing any code.

## background

after the web-root-consolidation task, the structure is:
  data/web-root/vhosts/<hostname>/.vhost-manifest  — YAML install descriptor
  data/web-root/vhosts/<hostname>/<content>        — templates and assets

.vhost-manifest fields:
  hostname, install_path, install_mode (symlinked|copy|copy-autoupdate),
  dns_match, tls (yes/no), tls_install_path, version_track, merge_strategy

existing relevant infrastructure:
- letsencr zenka: already implements ACME cert requests (letsencr.* modules)
- httpsd zenka: serves TLS vhosts, already reloads certs automatically
- base.file.*: file operations (symlink, copy, make_path)
- <[protocol-7.route-send]>: for async calls to letsencr zenka
- Net::DNS::Resolver: for DNS resolution checks (already used in nameserv)
- YAML::XS: for reading .vhost-manifest files

## modules to create

### httpd.vhost.read_manifests
- scans data/web-root/vhosts/ for directories containing .vhost-manifest
- parses each manifest with YAML::XS::Load
- stores in <httpd.vhosts.registry>->{$hostname} = { manifest hashref }
- log at level 2: "found N vhost manifests"
- returns arrayref of hostnames found

### httpd.vhost.dns_matches_local
- utility: given a hostname, checks if it resolves to a local IP
- uses Net::DNS::Resolver->new->query($hostname, 'A')
- compares returned IPs against local interface IPs
  (from <nodes.orbital.local_ip> or IO::Interface::Simple)
- returns TRUE if any resolved IP matches a local interface
- returns FALSE if no match or DNS lookup fails
- log at level 3: "DNS check $hostname: matched/unmatched"

### httpd.cmd.install-vhosts
- command: install-vhosts [hostname]  (no arg = all matching)
- calls httpd.vhost.read_manifests to get registry
- for each vhost (or just the specified one):
  1. check dns_match via httpd.vhost.dns_matches_local
     if no match: log at level 2 "skipping $hostname (DNS no match)" and next
  2. create install_path directory if missing (base.file.make_path or mkdir -p)
  3. install based on install_mode:
     'symlinked': create symlink install_path → data/web-root/vhosts/$hostname
     'copy': copy all files from vhost dir to install_path
     'copy-autoupdate': copy + store checksums for update detection
  4. if tls: yes → call httpd.vhost.request_tls_cert for this hostname
  5. register in <httpd.vhosts.installed>->{$hostname} = {
       manifest, installed_at, install_mode, cert_status }
- returns summary: { installed => [...], skipped => [...], errors => [...] }
- log at level 2 for each installed vhost

### httpd.vhost.request_tls_cert
- called after installing a TLS vhost
- checks if cert already exists and is valid (> 30 days remaining)
  check <letsencr.certs>->{$hostname} if available via route-send
- if cert missing or expiring: send route-send to letsencr zenka:
  command: letsencr.request-cert, args: $hostname
  reply handler: httpd.vhost.handler.cert_reply
- if cert valid: log at level 2 "cert for $hostname valid, skipping request"
- log at level 2: "requesting TLS cert for $hostname"

### httpd.vhost.handler.cert_reply
- reply handler for letsencr cert request
- updates <httpd.vhosts.installed>->{$hostname}->{'cert_status'}
- if success: 'active'
- if pending: 'pending' (ACME challenge in progress)
- if failed: 'failed' + error message
- log at level 2: "cert for $hostname: $status"

### httpd.cmd.update-vhosts
- command: update-vhosts [hostname]
- for each installed copy-mode vhost:
  compare current source files to installed files
  if source changed and installed file unchanged (matches previous source):
    copy updated file — auto-update
  if source changed and installed file also changed (local modification):
    log warning: "merge needed for $hostname/$file — skipping"
    store in <httpd.vhosts.merge_needed>
  if 'copy-autoupdate': apply updates automatically
- symlinked mode: nothing to do (already live)
- log at level 2: "updated N files in $hostname"

### httpd.cmd.vhost-status
- command: vhost-status
- shows table: hostname | mode | dns | installed | cert | merge_needed
- reads from <httpd.vhosts.registry> and <httpd.vhosts.installed>
- for each known vhost shows current status at a glance
- uses existing list infrastructure pattern

### httpd.vhost.init_code
- initializes <httpd.vhosts.registry> //= {}
- initializes <httpd.vhosts.installed> //= {}
- initializes <httpd.vhosts.merge_needed> //= {}
- calls httpd.vhost.read_manifests on startup
- log at level 2: "vhost registry initialized with N manifests"

## modules to modify

### httpd.init_code (or httpd start file)
- add call to [httpd.vhost.init_code] during initialization
- note: check if httpd has an init_code module or if this goes in the start file
  read configuration/zenki/httpd/start to determine the right place

## install paths

- source: data/web-root/vhosts/<hostname>/
- http install: /var/httpd/<hostname>/
- https (httpsd): same path or tls_install_path if specified in manifest

## CRITICAL notes

- $ARG not $_ throughout
- lowercase comments only
- route-send returns count not reply — use reply handler for async
- call_args => { 'args' => $string } for route-send
- YAML::XS::Load for manifest parsing (not YAML::Tiny)
- use <[base.perlmod.autoload]>->('YAML::XS') — one module per call
- use <[base.perlmod.autoload]>->('Net::DNS::Resolver') for DNS checks
- symlink creation: use POSIX or File::Spec — check if target exists first
- do NOT add fake signature stubs

## signatures note

do NOT add, verify, or modify AMOS7 signatures. leave new files clean.

## deliverables

1. modules/httpd.vhost.init_code
2. modules/httpd.vhost.read_manifests
3. modules/httpd.vhost.dns_matches_local
4. modules/httpd.cmd.install-vhosts
5. modules/httpd.vhost.request_tls_cert
6. modules/httpd.vhost.handler.cert_reply
7. modules/httpd.cmd.update-vhosts
8. modules/httpd.cmd.vhost-status
9. note on where httpd.vhost.init_code should be called (start file or init_code)

#,,,.,,,,,...,.,.,,,.,,..,,,.,,,,,,..,,.,,,.,,..,,...,...,..,,,.,,,..,,,,,.,.,
#UQNRWDMCQD3PWLAV42MB6EEFRPJQBW3BLHTWMZ4VSUA2FDXAHEBTIXLMI7ZWBMSXFBHVM4WOPMOKI
#\\\|7PBJHTXNEEISAJYX7MINGNDRXZIQWFFO25RMEICET7BJMAFYQPQ \ / AMOS7 \ YOURUM ::
#\[7]HVQKNEV6NO6HWLMJZN6DC7MFQNOFZO47MAATEMWTQE4K6WR43CDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
