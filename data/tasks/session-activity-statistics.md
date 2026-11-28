# session activity statistics [ return chance for the cache keep-alive, graphs ]

status : IDEA 2026-11-28 -- owner agreed on the shape ; nothing built.

## why

the keep-alive pays when the owner comes back while the cache is warm :
k pings cost ~k x [ 0.1 C + F ] , a return saves ~1.9 C [ C context, F the
ping's own fixed cost ~1K ]. the context size matters little [ it sits on
both sides ] ; the return chance decides. today : a fixed cap [ 6 pings ]
and coding.cfg.keepalive_min_context [ 97K ].

## data [ read-only ]

- claude code transcripts [ ~/.claude/projects/*/*.jsonl ] : timestamps of
  the OWNER's messages only -- not tool results, notices, cross-session
  messages, compactions, keep-alive turns
- kimi sessions where they carry owner prompts
- the result and every graph stay OUTSIDE the repo [ personal rhythm data :
  a /data/<project>-data dir or the owner's private notes ] -- only the
  script and this note are tracked

## shape

- active stretch : owner messages with gaps < ~20 min, chained across
  sessions and projects
- breaks : short [ < 20 min ], nap [ 20 min - 1.5 h ], rest [ longer ]
- factors per break : length of the stretch before and of the last few
  together, weekday, start hour, day \ night
- model : P [ return within the next hour | idle h, stretch length,
  weekday, hour ] -- smoothed, sparse cells borrow from their neighbours
- known appointments [ the events reminders, eg. a video call ] : a planned
  absence with a known end -- keep caches alive across it [ return chance
  high at its end ], unless the model expects sleep right after [ a long
  stretch before, night, the usual pattern after that kind of event ].
  an appointment may carry an optional duration and an 'after : rest'
  hint from the owner. example : a call at 13:00, ~1 h -- bridge 12:40 to
  ~14:15 [ a reminder before it, the end plus a margin ]
- keep-alive rule : ping while P x 1.9 C > 0.1 C + F ; replaces the fixed
  cap and most of the size minimum
- graphs : stretches \ breaks over days, break against the stretch before,
  week x hour map ; neutral, kept with the data

## rules for the implementer

no sha, no json internally [ the jsonl is read at the edge only, numbers
leave ] ; output in native p7 config style ; lowercase comments with [ ]
brackets ; perl floor 5.32 ; never print transcript content, only times ;
no commit, no sign, no reload ; never touch files you did not change.

#,,,,,,,.,,,.,,,.,,,,,,..,...,,,.,,,.,,.,,..,,..,,...,..,,...,,.,,,..,.,.,..,,
#G24SLIEN75W57SXZUWKKT46R4AJ3K52IANH4ODUYIPB76M5QO7OUVJ3UWLH4AYBXBMPUNOHID6UVG
#\\\|VQF3BHDRFGTFEKB4DI6JJ3UBDFKD2UNIVZU5EF2E5E3DWL4NBNH \ / AMOS7 \ YOURUM ::
#\[7]TP2GD2O6G2MMJ4B4ZY4UYNBBP5GR2M5ZVWJVUXU6I4GAGQTQOEAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
