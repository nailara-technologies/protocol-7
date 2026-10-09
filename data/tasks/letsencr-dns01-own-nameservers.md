# letsencr : dns-01 against our own nameservers

brief [ 2026-10-09 ]. wildcard certificates [ `*.protocol-7.network` was
grouped as an alt name but the production cert covers only the base name ]
need dns-01. the domains are registered at inwx ; instead of the inwx api
[ untested, credentials on a server ] two own `nameserv` instances become
authoritative and letsencr writes the challenge records through them.
inwx stays registrar only : ns records + glue, set by hand, once.

## order

1. nameserv : txt add \ remove-by-value, zone match by longest suffix,
   zone files [ kimi, k2.8 ]
2. letsencr : `nameserv` provider + parent \ child coordination + cleanup
   [ claude -- depends on event loop behaviour ]
3. propagation check against our own authoritative servers [ claude ]
4. two instances [ pri + atom ], challenge records reach both
5. access : set \ remove only from letsencr
6. delegation at inwx [ user ] -> live wildcard test, staging first

## constraints [ found while reading the code ]

- **the child flow is blocking.** `continue_challenge_processing` runs
  create -> respond -> `poll_challenge_status` [ sleep loops ] in one call.
  `route-send` only appends to the session output buffer
  [ `base.protocol-7.command.send.local` ] -- nothing leaves the process
  until the event loop runs [ ai-mem route-send-buffers-timer-gets-event ].
  a `nameserv.*` route-send from inside that flow is not sent before the
  propagation check. FIRST trace how http-01 issued a production cert
  2026-10-09 although its httpd setup is a route-send in the same flow --
  mirror that mechanism, or split the flow into a continuation [ send with
  a reply handler, resume there, reply via `base.callback.cmd_reply` ].
- `letsencr.child.send_to_parent` is a STUB [ returns FALSE, sends nothing ]
  -> the `manual` dns-01 provider never reached the parent either.
- `nameserv.cmd.set-record` REPLACES every record with the same name + type.
  `_acme-challenge.example.com` needs two txt values at once when both
  `example.com` and `*.example.com` are in one order. needs `add-txt`
  [ keeps others ] and `remove-txt <value>` [ removes one ].
- zone for a record name : longest loaded zone that suffixes it -- not
  "strip `_acme-challenge.`" [ the inwx provider's subdomain bug ]. check in
  `nameserv.zone.lookup` whether names are stored relative or absolute.
- `*_delete_txt` is never called [ only listed in base.list.subroutines ] :
  challenge records must be removed on success AND on failure.
- `check_dns_propagation` asks 8.8.8.8 \ 1.1.1.1 \ 8.8.4.4 recursively :
  the first poll caches NXDOMAIN for the soa minimum, the retry budget is
  ~2 min. query both own authoritative servers directly, no recursion,
  propagated = both answer the value [ letsencrypt asks the authoritative
  servers too ].
- second instance : read `nameserv.cmd.publish-node` \ `discover-nodes`
  before inventing replication ; check how a zenka addresses a zenka on
  another host. simplest : letsencr writes to both and checks both.
- access : once delegated, write access to nameserv owns the domains.
  `set-record` \ `add-txt` \ `remove-txt` only for letsencr [ +admin ] in
  `cfg/zenki/cube/access.zenki`.
- a lane calling into a new namespace must be in every affected zenka's
  `modules.load` [ missed twice before ].
- atom has 1G : nameserv goes through the pressure start gate, watch rss.

## inwx provider [ left as is ]

`letsencr.dns.inwx_*` : untested. no cookie jar on `XMLRPC::Lite->proxy`
[ the session cookie from account.login is lost -> later calls fail ],
zone = name minus `_acme-challenge.` [ wrong for subdomains ], no
`account.unlock` for totp accounts. only relevant if a non-delegated domain
ever needs dns-01.

#,,.,,,,,,,..,...,,.,,,.,,..,,,..,,..,.,.,,.,,..,,...,...,,..,..,,,,.,,,,,,..,
#XTMJ4NXEPSCHUXEGZTFMVY43TIKEOI2OWLRL7GQ7VL6GB3ZSINFB3MCBE7TTWTEW54FDI6CYINVEM
#\\\|PRNKLKVPBQ4U3F2RHX3GQ5IPENK3UHJWLMKCTK2H36Q75VHJ6ER \ / AMOS7 \ YOURUM ::
#\[7]H52KM44YWNP74KIG7ZAZVPIKGFRLZZIDLDJ5BPBL4EWID6MUBWAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
