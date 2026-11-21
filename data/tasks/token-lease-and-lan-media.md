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

- groups and levels ALREADY EXIST and are reused, not duplicated : the cube access
  groups [ `<admin-user>`, `<AMOS-user>` in access.zenki, resolved by cube for every
  command check ], a security level per group with the caller's effective level = the
  maximum over its groups [ data/md/design/UI-SHOW-SECURITY-LEVELS.md, built as
  ui.caller.security-level ], web roles per relayed command in access.web with the
  user -> role map in host config and the approval ladder [ click, pin, passphrase,
  second passphrase -- data/md/design/WEB-UI-USER-LOGIN.md ]
- what is missing is MANAGEMENT, on one shared base with two namespaces
  [ owner 2026-11-21 ] :
  - the base : one generic group record [ name, members, security level, scopes, ttl
    ceilings ] with one set of commands in the users zenka [ group-list \ group-get \
    group-add \ group-remove, later group-create ], signed like user records, exchanged
    between hosts by remote-fetch as users are
  - namespace 'cube' : system principals [ zenki, host users ], single-member as
    implemented today, resolved by cube for every command check -- unchanged in
    behaviour, only managed through the base
  - namespace 'web' : people and roles for web access [ access.web roles, lease users,
    media shares ], multi-member, own levels
  - no implicit crossing : a web group never grants cube rights by itself ; where a web
    role needs a cube command an explicit mapping names it [ as access.web does today ].
    web levels are capped below the cube admin level
  - later : profiles for admin levels [ owner 2026-11-21 ], in the devmod pattern
    [ cfg/devmod-commands allow-lists the safe commands, base.devmod.unsafe_commands is
    everything else, base.devmod.unload_unsafe removes them ] : e.g. admin-read
    [ status \ list \ show ], admin-modify [ + changing commands ], full admin. a command
    reaches a lower profile only when listed there ; an unclassified new command is
    full admin only [ fail closed ]. profiles resolve into the same command masks as
    access.* -- no second enforcement path
- the later key-based level source [ per-key level, maxed with the group level, see
  UI-SHOW-SECURITY-LEVELS.md ] is where lease tokens plug in : a lease carries a scope
  and at most its group's level
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

#,,,,,,,.,,.,,.,,,,,,,..,,,,,,..,,.,.,...,.,,,..,,...,...,,.,,,.,,,,.,,,,,.,.,
#U5RKPACXUYHVWGEK2IOMBVBZ2TGHV6N67BIMIXIXLL4WJ3CVJRYPES4QUW7NDELJHU7UOJGWE4BCO
#\\\|P7F2KM33XKPWB5HPC5RMSZ5ZNOKCTLTQ3YYWEG5TNMHPWFCDIXD \ / AMOS7 \ YOURUM ::
#\[7]HKPTMTTA6ZVDRIEESGHSFQWOVS6YYUKSQREQ4CV5W6RNBZMFGUBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
