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

## rules

- p7 config style, no json ; internal checksums BMW \ AMOS, no sha ; perl floor 5.32
- timers \ retries through <[base.interval.next]>
- tokens : only hashes stored, never in argv \ logs \ replies [ as auth-issue today ]
- a grant is per lease user and ttl ceiling, fail closed when absent
- no host names, addresses or personal data in repo files

#,,.,,,,.,,..,,,,,,,.,...,.,,,,,.,.,.,..,,,..,..,,...,...,,.,,,.,,.,.,..,,,..,
#JTD6FC5GNQEQIBRJHN3D6V2F7657JT6H7WVOHDSPDN7Q5RR7RURU2TANLBBKZNR3CRPFY4YRD6IJO
#\\\|GC5OH6CKVIHYO2QSJQW5AFG4W7K67NQZ24XNBF4ANL7D24KFSNB \ / AMOS7 \ YOURUM ::
#\[7]L6OOA3JZRWLX6GI7XEWDIKDQTZTSCWFRDUPCWIL2IRDTQRYZ44DA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
