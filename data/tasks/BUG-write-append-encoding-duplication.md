# BUG: write_append/write_new_file encoding duplication bug
# Status: Confirmed, workaround applied, permanent fix needed
#
# ## Reproduction
#
# When writing a file containing UTF-8 characters (specifically em-dashes `—`
# encoded as `\u2014`), `write_append` or `write_new_file` produces:
#
#   1. First, the content is written but **duplicated** with garbled prefix
#      (e.g., `Ã¢â¬â` appearing before the correct `—`)
#   2. The file exists but is corrupted
#
# ## Root Cause (Hypothesis)
#
# The tool's internal encoding handling does not properly normalize the input
# content before writing. When the input contains Unicode characters that
# require encoding conversion (e.g., `\u2014` → UTF-8 bytes `0xE2 0x80 0x94`),
# the tool appears to write the content in two states:
#
#   - The original input form (raw `\u2014`)
#   - The encoded form (UTF-8 `0xE2 0x80 0x94`)
#
# The result is a concatenation of both, producing the garbled prefix.
#
# ## Workaround
#
# Manually copy the correct content, strip the duplication, and re-sign.
# This was done for:
#
#   - `data/md/design/THREE-CORE-SELF-CLEANSING-IMPLOSION.md`
#
# ## Permanent Fix Required
#
# The tool needs an explicit `encoding` parameter that:
#
#   1. Defaults to UTF-8
#   2. Explicitly encodes the input string to the specified encoding
#      BEFORE writing to disk
#   3. Uses that encoded byte sequence as the file content
#
# Current behavior: the tool writes the Python string representation
# without explicit encoding, causing the double-write.
#
# ## Affected Files
#
# - `write_append` tool
# - `write_new_file` tool
# - Both share the same underlying write mechanism
#
# ## Impact
#
# Any file written with Unicode characters (em-dashes, curly quotes,
# accented characters, etc.) will be corrupted. This affects all
# documentation, design docs, and any markdown files with special
# characters.
#
# ## Priority
#
# **High** — affects all markdown documentation and any future content
# written by this agent.

#,,,.,,..,,,.,..,,,,.,..,,,.,,,,,,.,.,,,.,.,.,..,,...,...,..,,.,.,..,,,,.,...,
#WXIGQNWSGG6T7AAXHQFV5FOBXERTCLNJLRIJ6PIOAMKPVQKLCPNWXDUFD2XNCZOPDYFVRKZQ77SPC
#\\\|GWBCZWGDUA3PVRP3TYYDSK3DZ6K5X22HWQMS6CSHCWZR57PBXF2 \ / AMOS7 \ YOURUM ::
#\[7]GHEJBJZB3H54HWYRCGMKILJ27OGIYBLD6HPIZUS22CDMQW2YLUAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
