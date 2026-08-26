## user-edit draft primitives — skipped return value note [ 2026-08-10 ]

`user-edit.draft.write` mirrors `user-edit.outbox.write`'s path resolution,
id validation, and write shape, and adds the empty-state guard from
`mpv.snapshot.write` (which exists under that name). When the passed data
is not a hashref, has no keys, or every top-level value is undef or empty
string, the write is skipped and returns `(qw| skipped |, 'no data to save')`
in list context or `qw| skipped |` in scalar context. `skipped` was chosen
so callers can distinguish "nothing to save" from `TRUE` (write succeeded)
and `FALSE` (real write failure) without colliding with either numeric value.

#,,..,...,.,,,,.,,,,,,..,,,,,,.,,,,,,,,,,,..,,..,,...,...,,,,,..,,..,,,,.,,..,
#KWDVWSC6AAO5CQ4JNCPG3WN454WF224CQVUSP2ZLRRY3QRWSNGGG4KIGMULBWRGVDR3L4DE6IGBP2
#\\\|UCMVTYRSLJMMOQREXKFOS3DTB2CTR6ZP425PSDOBFXM42KVPKVR \ / AMOS7 \ YOURUM ::
#\[7]PAZV7FSJB7U2O4RRLS33S5TWNWTFI4HVIBXMY2UV4X3W4OOMUOBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
