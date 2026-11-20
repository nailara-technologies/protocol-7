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
example : the remote perl 5.36 warned on `qw| \ |` [ fixed c3b65295f ] -- the local
5.42 and the 5.32 floor check did not show it, the buffer did.

#,,..,,,.,,..,...,,.,,..,,,.,,,.,,,,,,,,.,,..,..,,...,..,,,,.,,.,,.,,,,,,,,,,,
#6E3ZXEYSB6I3FKVYHTRE4FCUBAULH25JXRDUZOX4GHJJBUFU5BZZ4GHU6RXLELJPSAAFDHAM56H5E
#\\\|QS3HGBZ3UEWCBVOZYYEIJ772XD76MQ2WACGLHBS5CJPNFEA4EF5 \ / AMOS7 \ YOURUM ::
#\[7]RKXUYHQ5XDBDNLVVBAWPG6S3BPBQZTKQS3N7IAOCGZCLGGGE2EAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
