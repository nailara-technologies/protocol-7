write one p7 module file: src/models.storage.adapter.invoke.discover

read the source function first:
    bin/scripts/invoke-ai/invoke-model-recover  lines 76-145 (query_database sub)

also read one existing storage module for config access pattern:
    src/models.storage.discover

then write src/models.storage.adapter.invoke.discover with this header:
    ## [:< ##
    # name  = models.storage.adapter.invoke.discover
    # descr = query invokeai.db and return list of model records as arrayrefs

the module body (file IS the subroutine, no sub declaration):
- get db path from config key 'external.models.invokeai.db', fall back to
  glob("/home/*/.invokeai/db/invokeai.db") then "~/.invokeai/db/invokeai.db"
- run: sqlite3 $db_path "SELECT json_extract(data,'$.name')... FROM model_config"
  (copy the exact sqlite3 query from query_database in the source script)
- parse JSON::PP output, filter records (skip spandrel/unknown, skip C:\ and / paths)
- return arrayref of hashrefs: { name, type, base, format, path, size, source, source_type }

p7 style: lowercase comments, [ brackets ] not (), $ARG not $_, <[module]>->() syntax.
do NOT add the #,,... stub line at the end. leave the file clean for signing.

after writing, verify with: ptd -c src/models.storage.adapter.invoke.discover
report the ptd -c output.

#,,..,...,.,,,.,,,..,,,,.,,.,,,,,,,..,.,,,...,..,,...,...,,.,,,,,,..,,,..,,,,,
#WONAKKAKGKACF7Y2NX27OT6EMEEJREX6FDDG2KRANT46BY6XYNOXRQWFWQ7EPXCPIMFMLLIWGIHUS
#\\\|L2EX4BVMLX6QE7EMSWYSWO7HA6KMPEG4Q4AFIHFGPQXVHTSVOI2 \ / AMOS7 \ YOURUM ::
#\[7]6DW32HTRVD53LWMW4C2YZHZJIKV3CYRGJBYYPKSESEYR7FZNAUBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
