# Line-Edit Tools — Encoding Parameter

**Priority:** Low
**Type:** Feature — Tool Enhancement
**Component:** coding zenka line-edit tools
**Related:** modules/coding.tools.handler.delete_lines, insert_line, replace_line, modules/coding.tools.definitions

## Overview

The three line-based edit tools (`delete_lines`, `insert_line`, `replace_line`) have
hardcoded `:encoding(UTF-8)` in both the handler modules and staging open() calls.
They need an optional `encoding` parameter, consistent with `edit_file` and
`replace_in_file` which already expose this.

The `base.file.read` wrapper (used for the read side) now also accepts an encoding
parameter. The write side should match.

## Scope

3 handler modules + 1 definitions block. No new files needed.

### Changes per handler (delete_lines, insert_line, replace_line):

1. accept `encoding` from args — normalize via existing `$norm_encoding` pattern:
   ```perl
   my $raw_enc     = $args->{'encoding'} // 'UTF-8';
   my $norm_encoding = $raw_enc =~ /^:/ ? $raw_enc : ":encoding($raw_enc)";
   ```
2. pass `$norm_encoding` to `file.read` (second arg) for the read side
3. replace hardcoded `':encoding(UTF-8)'` in `file.write_encoded` calls with `$norm_encoding`
4. replace hardcoded `'>:encoding(UTF-8)'` in staging `open()` calls with `">$norm_encoding"`

### Reference implementation — follow delete_lines, insert_line, replace_line:
- read: `<[file.read]>->( $abs_path, $norm_encoding )`
- write: `<[file.write_encoded]>->( $norm_encoding, $abs_path, \@lines )`
- stage open: `open my $fh, ">$norm_encoding", $stage_path`

### Changes in coding.tools.definitions:

Add `encoding` parameter to the three tool schemas, identical to the existing
pattern in `edit_file` (around line 455) and `replace_in_file` (around line 495):

```perl
'encoding' => {
    'type'        => 'string',
    'description' => 'character encoding [ default UTF-8 ]'
},
```

## Acceptance Criteria

- all three handlers accept `encoding` arg and pass it through read + write
- hardcoded `:encoding(UTF-8)` strings replaced — no hardcoded encodings remain
- tool definitions include `encoding` parameter for all three tools
- `ptd -c` passes on all modified modules
- default behavior (no encoding arg) is identical to before — UTF-8

## Notes

- do NOT change the default — omitting `encoding` must still behave as UTF-8
- staging open() uses raw string concat: `">$norm_encoding"` not `'>' . $norm_encoding`
- check both the direct write path AND the chmod-child staging path in each handler
- signatures_note: do not add stub signature lines — leave signing to the system

## Context

This follows the same pattern used in the recent `base.file.read` encoding fix
(commit 6e3cef26b). The line-edit tools were not addressed in that fix because
they use `file.write_encoded` directly rather than going through `base.file.read`.

#,,.,,.,,,.,,,,,.,.,,,.,,,,,.,,..,,..,,.,,,,,,..,,...,...,,.,,.,.,,.,,...,,..,
#AK7YDHSMC5LYQDFLN54Z5S3C7L7FNEI7J6YUY4FTGZNCKCVZAEVETN43CVKUEWVSUH7ZALDCZOODA
#\\\|2ISP7LIDR6NZHU7UYWRE6GIADL3HHUSSALUEPZIJFZ7RKEXTGPL \ / AMOS7 \ YOURUM ::
#\[7]XVX6VN6KUTTMLFSHG6ANEF6UKAJSWMKMHR3MM5LQOPIBLKHEQQBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
