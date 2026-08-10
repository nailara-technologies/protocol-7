## user-edit draft primitives — skipped return value note [ 2026-08-10 ]

`user-edit.draft.write` mirrors `user-edit.outbox.write`'s path resolution,
id validation, and write shape, and adds the empty-state guard from
`mpv.snapshot.write` (which exists under that name). When the passed data
is not a hashref, has no keys, or every top-level value is undef or empty
string, the write is skipped and returns `(qw| skipped |, 'no data to save')`
in list context or `qw| skipped |` in scalar context. `skipped` was chosen
so callers can distinguish "nothing to save" from `TRUE` (write succeeded)
and `FALSE` (real write failure) without colliding with either numeric value.

#,,,,,..,,,,,,...,,..,,,,,..,,,,.,,.,,,.,,..,,..,,...,..,,..,,..,,.,,,,,,,..,,
#INVH2FFVSQBMCKHXSYAQ3XQBSGNCW72JERGML63VF7VLSJM7WQTWOK74W6JOYJPPOV7I7SYZ6KFT6
#\\\|Q6XPZJOSTUKLS4VZBZ4RZPKXQXJV4FMJ4ECYPHDSSKZZ6DV3SKF \ / AMOS7 \ YOURUM ::
#\[7]IJFRJSED4M7DXBV3LZRMNUCSUXCFKQZDCPG3CUKMMGTQ273CACCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
