# ondemand idle timeout with active STRM producer streams

## change
`modules/base.event.callback.io-idle-restart` now checks whether any session has an open outbound STRM producer stream (`$data{'session'}{$sid}{'streams'}{$cmd_id}{'producer'}`) before re-arming the on-demand shutdown timer. If any producer stream is open, the timer is not armed.

## why
On-demand zenki that serve long-lived push streams (e.g. `graphics-matrix.orbital-sync`) would otherwise idle-shutdown mid-subscription, because outbound STRM traffic does not generate inbound commands that would reset the idle timer.

## coverage
The fix is generic in `base.*` and covers every zenka that uses `base.stream.open` as a producer, including `graphics-matrix`, `X-11`, `nodes`, `kimi-web`, `ticker`, `radio`, `discover`, `external`, and `mod-test`.

## sys-deps
`sys-deps` has no STRM producer streams, so this change is a no-op for it.

#,,..,,,,,,,,,.,.,.,.,,,.,,.,,.,,,...,.,.,.,,,..,,...,..,,,,,,.,,,,,,,.,,,.,,,
#ODNGYUDXAODUJDUOUHUB325LOEA6BEYIYGGKUVDPDKNCBAR4HNBUYE4LAAIYRMRN3EWCFERHITR7W
#\\\|WTDLPOA3F2SFA3PRFTSBK4T5BKUUJOSWC4NZMHF3THGWQPHX4ZF \ / AMOS7 \ YOURUM ::
#\[7]232VVYP47QMHPXQNYEXMUOBU2MZCAC3CLS3BIH5BJYVFMA2QS6DA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
