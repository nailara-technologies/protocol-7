# zenki : idle timeout without start.on-demand [ config consistency ]

## problem [ found 2026-09-30 on mod-test ]

a zenka that sets an idle timeout [ `[base.zenki.set_ondemand_timeout:N]`
in its start.cfg zenka-init or zenka.v7 ] but is NOT marked
`start.on-demand = 1` for v7-zenki : at idle its
`base.handler.ondemand_timeout` asks `v7-zenki.idle-term`, v7-zenki rejects
it [ "only on-demand zenki can self-terminate on idle" ], the zenka exits
directly anyway [ `base.handler.ondemand_idle_term_reply` ], v7-zenki sees a
vanished session on an 'online' zenka -> status error -> restart. repeats
every idle period. mod-test had it since its start.cfg was copied from calc
[ fixed 2026-09-30 : start.on-demand = 1 ].

## task

1. list every zenka with an idle timeout [ grep set_ondemand_timeout in
   cfg/zenki/*/start.cfg and zenka.v7 ] and compare with `start.on-demand`
2. report the mismatches ; for each, say which fits [ make it on-demand, or
   drop the timeout ] from its role [ always-on in start-set-up.base ? ]
3. do NOT change them without the user's decision -- a list with a
   recommendation per zenka
4. optional, for later : a check at v7-zenki start that warns once about
   such a mismatch [ read-only, log level 1 ]

## done [ 2026-09-30, claude ]

mismatches [ idle timeout, no `start.on-demand` ] : channels [ 600s, in
zenka.v7 ], osd-logo [ 33s ], power [ 33s ]. none in start-set-up.base.
all three got `start.on-demand = 1`, osd-logo \ power also
`restart.disabled = 1` [ calc \ geoloc pattern ]. osd-logo is started \
ended by tile [ `tile.callback.start_osd_logo` : `v7-zenki.start_once` \
`terminate-implicit` -- neither reads the flag, only `idle-term` does ].
its old appliance use [ logo stays present ] would need no timeout.
registered by a v7-zenki reload [ "registering 3 ondemand zenki at cube" ].
step 4 [ warn once at v7-zenki start on such a mismatch ] still open.

#,,.,,..,,..,,.,,,...,,,.,,.,,...,,,,,..,,,..,..,,...,...,...,..,,...,..,,...,
#HM2UJPREPABMQD2WKXDV6K5OE3USJMOAKGAFVJCEWC43BAC4FJMI5LF2RODZ3YBO4LPMC4QGRRNC6
#\\\|5SHJ27C4NX63HMBJFZTO46PPM52XJD4OQEEYANE42YSL7FOWG22 \ / AMOS7 \ YOURUM ::
#\[7]6PCOENECJJDCYKBVJBTVLWUGM24AILV3FN5UMN7DLUFWTHHT3KDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
