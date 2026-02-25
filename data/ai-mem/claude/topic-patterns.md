# Event & Handler Patterns

## Event Handler Pattern (CRITICAL)
- Event handlers receive an Event object as first param, not data directly
- Extract data: `my $event = shift->w; my $server = $event->data;`
- Handlers may be called two ways: direct calls (pass args directly) or via event watcher (Event object)
- Handle both: check `$id->can('w')` to detect watcher vs direct call
- Safe dereferencing: always check `ref $var eq qw| TYPE |` AND `defined $var->$*` before deref
  ```perl
  if ( ref $line_sref eq qw| SCALAR | and defined $line_sref->$* ) { ... }
  ```

## Variable Watcher Backup/Restore Pattern (CRITICAL)
- Stop watcher before modification: `$session->{'watcher'}->{'input_buffer'}->stop;`
- Back up reference: `$session->{'http'}->{'original_watcher'} = $watcher_ref;`
- Restore and restart: `$watcher_ref = $backed_up_ref;` then `$watcher_ref->again();`
- **Never use `->now()`**: use `->again()` to restart (now triggers immediately)
- Fallback: if backup missing, recreate watcher with default handler
- Used in: httpd.handler.input.body_remainder for ACME POST body accumulation

## Development Environment Quirk
- `restore-p7-permissions` runs automatically on commit via hook
- Can cause 200+ permission changes even for single-file fixes
- Expected and correct behavior — not a problem with your code

#,,..,.,.,,,,,,,.,,.,,..,,,.,,..,,.,,,.,,,,,,,..,,...,..,,...,,,.,,.,,.,.,...,
#SDZV7I6KBST6QKWFI2ICZU3YWSB5YQIKWD4DUJAZ7TUBXRNKLP3Q57JNLP3DMNE7WGQCNKZELQ7AO
#\\\|5QXL2ILFRU6AQ4SDHQVVTX7Y3CYKH3C6RXAI4IIPSD6CAAK2OKK \ / AMOS7 \ YOURUM ::
#\[7]2VI7L6O47EKYLVWW5V3V5GJIEZVTB5Y3M6CK6V5SPWXDYXVFECCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
