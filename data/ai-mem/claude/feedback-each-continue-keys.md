---
name: feedback-each-continue-keys
description: "continue { keys %hash } on while(each %hash) resets the iterator — infinite loop on first matching key"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: f5b14fde-ecec-4f58-b7f2-95aaab875b62
---

`while (my ($k,$v) = each %$h) { ... } continue { keys %$h }` is an infinite loop. `keys %$h` resets the `each` iterator, so the loop never advances past the first key.

**Why:** Found in `memory.focus.decay` and `memory.tree.score`. The `continue` block was intended to reset the iterator for safety but instead caused infinite iteration on the first key.

**How to apply:** Never put `keys %hash` in a `continue` block on a `while(each)` loop. If iterator reset is needed after modification, restructure using `for my $k (keys %$h)` instead. The `each` iterator is safe to use with value modifications mid-loop; only key deletion needs deferral (collect keys to delete in `@drop`, delete after the loop).

#,,,,,...,.,,,,,,,,,,,,..,,..,,,,,..,,...,..,,..,,...,...,,,,,..,,,..,,,,,...,
#COV7PVHKOHJWP6SXYOKXOP3NXOGSRZD4PNNDGCLWEJ2T6SE6Z2W5236654RPRVNGTGAVDHW33KPPM
#\\\|UHQEJJBPMOIKJ4PI4E3SZ6YBO6YD6K5SRLTKQGXIL62HWFWJBZQ \ / AMOS7 \ YOURUM ::
#\[7]FEL2BWRH6AVPABBC4PTGPNP7J7PYKOGDEHVWDG52GRDJ55CCJIBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
