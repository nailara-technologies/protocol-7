---
name: compile-errors-buffer
description: when `reload source` reports [ warning ] or [ error ], the details are in `<zenka>.show-buffer compile-errors` -- an on-demand buffer, separate from and parallel to the zenka buffer
metadata:
  type: reference
---

owner 2026-11-20 : the `compile-errors` buffer is created on demand and captures
compilation errors \ warnings separately, in parallel to the `zenka` buffer. it is
reliable : when `reload source` shows warnings or errors, they are in it.

**How to apply:** after a reload with `[ warning ]` \ `[ error ]`, read
`::: <alias> <zenka>.show-buffer compile-errors` [ or `p7c ...` locally ] first,
instead of digging through the zenka log. a clean reload leaves it empty \ absent.
example : the remote perl 5.36 warned on `qw| \ |` [ fixed ef6cb532f ] -- the local
5.42 and the 5.32 floor check did not show it, the buffer did.

#,,.,,.,,,,..,..,,...,.,.,...,..,,...,.,,,,..,..,,...,...,...,.,,,.,.,.,.,..,,
#JR7UFGSQ6FFSW4ETOKWVCK4YXR2FVWFTD5MKDLJ56QPR7MEBDAGY3Z7BQOFCH7FFFIROR25ETAIB6
#\\\|WTPHEIDGMSLNW7QFH3NHJZ7ZUDNBGQEMU7XZUSWZE7W7QQCSU3V \ / AMOS7 \ YOURUM ::
#\[7]7DS7I53RIZNGVPCXCKYJ55NWEWYZO3RHSFD56FLBQ6ETEXTBZUCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
