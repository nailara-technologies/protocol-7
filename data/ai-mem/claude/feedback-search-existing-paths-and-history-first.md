---
name: search-existing-paths-and-history-first
description: before building a feature, search every existing caller of the thing it adds [ ncode s ] ; before naming a cause, check the file's own history -- both missed 2026-10-09
metadata:
  type: feedback
---

two misses on 2026-10-09, same root : acting on the first plausible reading
without one cheap search.

1. **letsencr auto-enrollment** was designed off a `TODO` in
   handler_renewal_continue as if enrollment did not exist. the user found three
   callers of `request-certificate` already [ httpd.vhost.request_tls_cert via
   install-vhosts 'tls: yes', httpd.handler.acme_request, httpsd ] -- the new
   path would have ordered a SECOND certificate for every new tls vhost. fixed
   by the 'explicit' claim [ b81afdc92 ].
2. **a stray separator line** in form.chrome was blamed on the sign run. the
   file's own history [ `git log -- <file>` + show each version ] proved it
   existed since the file was created -- and led to 56 more files.

**Why:** a feature that duplicates an existing path, or a fix aimed at the wrong
cause, costs more than the search that would have prevented it ; the user had
to catch both.
**How to apply:** before adding a capability, `bin/ncode s src <command \
module name>` for every caller of what it touches and read them ; before
stating why something is in a file, check that file's history with
`git -c color.ui=false log --format=%h -- <file>` and show the versions.

#,,,.,..,,.,.,..,,..,,,,.,,..,..,,.,,,.,,,..,,..,,...,...,...,.,.,.,.,.,,,,.,,
#DF6NZ3HYMNMD7D3PMBURF2XGJB6OOMVQGGCYLK45ITDVCJEKALIEZE3WI6HY5U2DUU24OJ42ZAYMS
#\\\|4REZJGR33N4HH6WIP3KYRIBRJ6VJMQC3PWI7FUECAWKRBCGXFKK \ / AMOS7 \ YOURUM ::
#\[7]LED4NUHCLGEFAKFGFXZ3IZHZUQDSBD3B6PJT3O4E4TVJHIBST4CI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
