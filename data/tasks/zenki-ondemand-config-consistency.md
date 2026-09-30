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

#,,.,,,..,...,,,.,,,,,,.,,...,,,.,.,.,.,.,.,.,..,,...,...,,,.,,,,,,,,,,..,..,,
#PV6LYBZIPLNF5LGBYHO4AC5JEVKWFB5VFLBNYOZ65FSC3ED3Z2L6RWIYBCKKBXM72EIMRNHDI5NVQ
#\\\|56UY3MTYR6NUB7ISUFOLEIBBR47AT3BDRA64EA36YYAB3KAROGH \ / AMOS7 \ YOURUM ::
#\[7]RKBCVUROVEBGGSV4USIBD2B6AOF3YOKHB352QA44YRMWCOHATADY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
