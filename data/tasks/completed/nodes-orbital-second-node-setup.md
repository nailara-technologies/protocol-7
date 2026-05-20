# task: second orbital node setup

## context

the orbital visualization requires a second P7 node to show distinct elements.
currently only self-echo is available (same coordinates, same position).
a second node would appear at different orbital coordinates and demonstrate:
- two distinct nodes on the grid
- CCW orbital trails at different positions
- glow field spanning two cells
- graph edges if nodes connect via external zenka

## options

### option A: WSL2 second instance
run a second P7 instance in the same WSL2 environment on a different unix socket path.
set PROTOCOL_7_UNIX_PATH to a different socket, start a minimal cube+nodes+discover stack.
the discover zenka would need a different mcast bind interface or loopback mcast.

limitation: WSL2 may not support mcast between two sockets on the same interface.
workaround: manually inject a fake HOST packet via `discover.process_host_packet`
with a different IP and p7ref to simulate a second node without actual mcast.

### option B: KVM VM
spin up a minimal Debian VM, install P7 dependencies, run nodes+discover.
the VM would be on the same bridge network as WSL2 (172.24.x.x subnet).
mcast should work over the bridge interface.

this is the cleanest test but requires KVM setup (referenced in topic-migration.md
as a planned migration target anyway).

### option C: inject fake orbital node
add a `p7c discover.inject-orbital` debug command that manually calls
`discover.orbital.store_remote` with a fake hostname, pkey, and p7ref.
the p7ref ADDR_B32 encodes different theta/phi/psi so the visualization
places it at a distinct position.

this is the fastest path to seeing two nodes in the visualization without
any network setup. good for testing the rendering pipeline end-to-end.

## recommended: option C first, then option B

implement option C (inject-orbital command) now for immediate visual testing,
then do option B (KVM) for real multi-node validation.

## option C implementation

create `modules/discover.cmd.inject-orbital`:

  args: "<hostname> <pkey_b32> <p7ref>"
  calls: <[discover.orbital.store_remote]>->($hostname, $pkey_b32, $p7ref)
  returns: mode=size, data="orbital node injected: $hostname"

example usage:
  p7c discover.inject-orbital "NODE-B RGRSNQZ NODE:RGRSNQZ:VMLSBXYAAAAAB"

the p7ref ADDR_B32 suffix encodes position — change last chars for different coords.

## signatures note

do NOT add stub signature line to new files.

#,,.,,,..,.,,,...,.,.,.,.,,,,,.,.,,.,,,,,,,,,,..,,...,..,,.,.,..,,,,.,,,.,.,,,
#7Q4FIWA2SVV4D22AQSD4B67Z5UD2QS6EMQPW4N2YNHA25JY6S57TJJ5O5RFBCUQ64F2SLNSL2YNHE
#\\\|OKWBM345YM4UNQH6FCNM5D57MGCXT6XXRD7Z4DAT5J5N3Z2E52L \ / AMOS7 \ YOURUM ::
#\[7]KKGUQCK7QGVRJKJ7Z7UQXFSOUMIFINSRIW3GG3TD37VCMZR4XEAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
