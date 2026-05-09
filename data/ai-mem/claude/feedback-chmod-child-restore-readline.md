---
name: chmod child restore readline
description: every restore command sent to chmod child needs a readline — missing one desynchronizes the pipe
type: feedback
originSessionId: 0ef5d82f-f706-421c-adcb-385a486685aa
---
After every `print {$chmod_fh} "restore ..."` call, always follow with `<[coding.chmod_child.readline]>` to consume the reply.

**Why:** the chmod child prints exactly one reply per command. If restore's reply is not consumed, the next tool call's readline reads it instead of its own command's reply — pipe is permanently one step out of sync, causing all subsequent writes to fall through to staging silently.

**How to apply:** affects all 6 write handlers: write_new_file, insert_line, delete_lines, replace_line, remove_file, file_rename. Pattern: send command → readline. No exceptions.

#,,,.,.,.,.,,,,,.,,,,,,,,,,,,,,,.,,..,...,,..,..,,...,...,,.,,..,,,,,,,,,,,.,,
#BETGTP4XIWHS2RFIEV2H4J5GH5INXYSKF5GQG5DGCDZGLT3FIIBEOUVXDHOBUP3LEHISL4T4YGTFQ
#\\\|6W6T2GN7MPXL22VV63BP2SUAUBYQIPK4CY6MCFKFQEWCO4VBH6M \ / AMOS7 \ YOURUM ::
#\[7]HO3XBT5QFQUYDTLFA5K72CDRNIQMRCSZ5Z76NZRHEMH5KFL4WKAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
