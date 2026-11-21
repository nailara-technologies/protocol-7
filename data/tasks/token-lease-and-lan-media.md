# token leases : renewed web tokens for zenki and the ui, then lan media for mpv

status : brief, not dispatched [ owner 2026-11-21 ]. builds on src/web.cmd.auth-issue,
web.cmd.auth-revoke, plugin.web.auth.* [ sessions, bearer, admit ], jobsite.sync.token_for_url,
v7-zenki.cmd.jobsite-sync-token, the content zenka [ content.cmd.add-entry, get_list,
update.notify_zenki ] and mpv.get_playlist.

## problem

- web tokens are minted by hand [ `web.auth-issue <user> -ttl <s>` ] and installed by hand
  [ jobsite : pipe into `v7-zenki.jobsite-sync-token+`, restart, revoke the old one ].
  when one expires the consumer just stops -- jobsite sync dies silently until renewed
- the web ui asks for a token instead of a password : an expired one means pasting a new
  one, there is no renewal from a live session
- long ttls [ one year ] exist only because renewal is manual
- media on one lan host cannot be played by the mpv zenka of another

## stage 0 : groups in the users zenka [ owner 2026-11-21 ]

the existing split stays : the users zenka holds the per-host records [ value-get \
value-set, remote-get \ remote-fetch for peers ], user-edit is the form for ONE record,
host-edit the host records. groups are missing :

- the users zenka owns group records next to the user records : name, members, scopes,
  ttl ceilings. commands group-create \ group-add \ group-remove \ group-list \ group-get,
  and remote-fetch for groups as for users [ exchange between hosts ]
- host-edit defines a host's user bucket : one field on the host record names the
  group[s] whose users exist there ; installing a host creates exactly those users
  [ the same path that provisions 'root' through users.record.default_fields ]
- user-edit edits one user's details and shows its memberships ; membership changes go
  through the users commands, so rights are checked in one place
- lease users and scopes [ stage 1 ] hang off groups : 'may get jobs-sync tokens' is a
  group property, not a special case inside a consumer

## stage 1 : token leases [ jobsite first ]

1. a lease grant : a consuming zenka may call `web.auth-issue` on the issuing host over the
   zenka network for its OWN lease user only [ e.g. jobsite-push ], up to a maximum ttl.
   declared in access.* plus one check in auth-issue -- not a general admin right
2. renewal : the consumer renews at about two thirds of the ttl [ delay from
   <[base.interval.next]> ], switches to the new token in memory, then revokes the old one
   by its hash. no restart ; the token never touches argv, a log or a reply body
3. failure : issuer unreachable -> keep the old token until expiry, retry with backoff,
   one clear warning before expiry instead of a silent stop
4. short ttls : once renewal works, default lease ttls drop from a year to days
5. the manual path [ v7-zenki.jobsite-sync-token+ ] stays as the bootstrap \ fallback

## stage 2 : ui session renewal

- a live ui session [ token prompt login ] renews its token before expiry through the
  same issue + revoke path [ sliding session, bounded by a maximum session age ]
- the page shows the remaining time and renews on activity ; an idle session still ends
- logout revokes the current token [ web.auth-logout ]

## stage 3 : lan media through content and mpv

1. the sharing host : httpd serves a media directory read-only [ range requests exist :
   httpd.parse_range_header, async file transfer ], no listing, no uploads
2. `httpd.media-list <filter>` returns matching files as signed, short-lived urls
   [ a lease token per url or per list, scoped read-only to that directory ]
3. the content zenka on the playing host imports them [ `content.import-remote <host>
   <filter>` or add-entry per url ] ; content already checks types and notifies mpv
4. renewal on play : before an entry plays [ play_next ], content renews its url through
   the lease path -- a leaked url expires, a long playlist keeps working
5. mpv unchanged : it follows the content list as today
6. later : n7fs trees as one more source behind the same list command [ the n7fs mount,
   data/tasks/n7fs-logical-trees-and-mount.md ]

## generic and interoperable [ owner 2026-11-21 ]

the lease is not a jobsite, ui or media feature : one identity \ token layer every
consumer uses, shaped so that outside software can speak to it without protocol-7 code.

- standard wire forms at the edge : bearer use as rfc 6750, revocation as rfc 7009,
  introspection as rfc 7662, renewal as an oauth 2 refresh-token grant [ rfc 6749 ] with
  rotation ; zenka-to-zenka renewal as token exchange [ rfc 8693 ] where a caller acts
  for a lease user. a later oidc provider face [ discovery, userinfo ] reuses the same
  store -- not stage 1, but nothing may block it
- the internal model is the reference, the standards are views onto it : users, groups,
  lease users with a scope + ttl ceiling, tokens stored as hashes. internal checksums
  stay BMW \ AMOS ; external token formats follow their spec only at the edge
- scopes, not per-feature flags : 'jobs-sync', 'media:read:<share>', 'ui' -- a new
  consumer declares a scope, it adds no auth code of its own
- one store, every consumer : web.auth.*, zenka access grants and the lan media urls
  read the same users \ leases, so a revoke ends access everywhere at once
- p7 config style for the declarations [ users, lease users, scopes, ceilings ] ;
  json only where an rfc defines the wire body

## rules

- p7 config style, no json ; internal checksums BMW \ AMOS, no sha ; perl floor 5.32
- timers \ retries through <[base.interval.next]>
- tokens : only hashes stored, never in argv \ logs \ replies [ as auth-issue today ]
- a grant is per lease user and ttl ceiling, fail closed when absent
- no host names, addresses or personal data in repo files

#,,,.,,,.,...,,,.,,,,,.,.,.,.,,,,,...,,.,,,,,,..,,...,...,...,,..,,..,,..,,..,
#3JTBEU4CJPCMVIDVR45IU32FURO4AUIZSS2ULM3XFGNNVEFDYMUPFM2KCPXZRFZEXTXEMWNKKKARW
#\\\|LIOUJ6LNYYK45S6HSWOLXZD7RQCDI6XTODUUQWXP44PXDYCGWU7 \ / AMOS7 \ YOURUM ::
#\[7]7TKJJNHEZZEFFKNAGFII5YKI5FU2EWMD6FHPB4ZLKO7UOJOBHCAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
