# Add Multiline Command Support to p7c and p-7-r

## Overview

Both client tools need to support protocol-7's native multiline command format. Currently, multiline content requires base32 encoding as a workaround. The native multiline format uses SMTP-style termination with an HTTP-like header/body structure.

## Protocol-7 Multiline Command Format

```
command+
Header-Key: value
Content-Length: 42

body content here
more body lines
.
```

Key characteristics:
- Command name ends with `+` (e.g., `coding.ask-reply+`)
- Optional headers section (key: value pairs)
- Empty line separates headers from body
- Body content is raw (no encoding needed)
- Terminated by single `.` on its own line

## Current Behavior

Both tools currently:
1. Concatenate argv into single-line command
2. Append `\n` and send
3. No stdin reading support

## Target Behavior

### Detection
When command (argv[1]) ends with `+`:
- Switch to multiline mode
- No positional args allowed after command (all content from stdin)
- Read from stdin until EOF or explicit `.` terminator
- Pass through to server as-is with proper framing

### Usage Examples

```bash
## Heredoc style
p7c coding.ask-reply+ <<'EOF'
length: 42
encoding: base64

c29tZSBiYXNlNjQgY29udGVudA==
.
EOF

## Pipe style
git diff | p7c review.diff+

## File redirect
p7c config.load+ < /path/to/config.yaml

## Remote via p-7-r
p-7-r remote.host coding.ask-reply+ <<'EOF'
priority: high

Please review this code...
.
EOF
```

## Implementation Files

### 1. bin/c_src/p7c.c (Unix socket client)

**Changes needed:**
- After building `cmd_str`, check if `argv[1]` ends with `+`
- If multiline: enter passthrough mode
- Read stdin line by line (or in chunks)
- Send each line as-is to socket
- On EOF or line containing only `.`, terminate

**Key code location:** Lines 241-257 (command string building)

**Pseudo-code:**
```c
// After building cmd_str normally
int is_multiline = (strlen(argv[1]) > 0 && argv[1][strlen(argv[1])-1] == '+');

if (is_multiline) {
    // Send command line (already has \n from cmd_str)
    write(socket_fd, cmd_str, strlen(cmd_str));

    // Passthrough stdin to socket
    char line[4096];
    while (fgets(line, sizeof(line), stdin)) {
        write(socket_fd, line, strlen(line));
        if (strcmp(line, ".\n") == 0 || strcmp(line, ".\r\n") == 0) {
            break;
        }
    }
} else {
    // Existing single-line behavior
    write(socket_fd, cmd_str, strlen(cmd_str));
}
```

### 2. bin/c_src/p-7-r.c (TCP remote client)

**Changes needed:**
- Same logic as p7c.c
- Location: Lines 356-372 (command string building) and line 524 (write)
- Handle the case where no additional args allowed after `+` command

**Key difference:** p-7-r requires hostname[:port] as argv[1], command is argv[2]
- Check `argv[2]` for trailing `+`
- If multiline: argc should be exactly 3 (no args after command)

## Error Handling

### Multiline with extra args (error)
```bash
p7c command+ arg1 arg2   ## ERROR: multiline commands take no positional args
```

Should print to stderr and exit with code 2.

### Missing terminator
If stdin ends without `.\n`, the server will timeout or error. Client should:
- Optionally warn if EOF reached without terminator
- Or just pass EOF through (server handles the error)

## Testing Strategy

### Basic multiline
```bash
echo -e "test+\n\nhello\n." | p7c test+
```

### With headers
```bash
p7c coding.ask-reply+ <<'EOF'
format: base64
length: 8

dGVzdGluZw==
.
EOF
```

### Large content (chunking)
```bash
cat /var/log/large.log | p7c process.log+
```

## Notes

- No encryption of body content needed (link-upgrade handles transport)
- Stream-locking mode already enabled in both clients
- The server side (`base.handler.command`) already handles multiline parsing
- This is purely a client-side feature addition

## Migration Path

1. Implement in p7c first (local testing)
2. Port to p-7-r (remote testing)
3. Update documentation
4. Base32 encoding becomes fallback for non-upgraded clients

## Future Consideration: Dot-Safe Mode (`++`)

The `+` suffix has a limitation: body content containing `.` on its own line will prematurely terminate the command. This is acceptable for:
- User-generated content (no stray dots)
- Base64/gzip encoded data (no bare newlines)
- Manual testing

But problematic for:
- Arbitrary file content (source code, logs, configs)
- Pre-formatted text with horizontal rules (`---` becomes `-` after markdown processing, but `.` literals exist)
- Quoted email messages (which may contain `.` lines)

### Proposed Solution: `++` Suffix (Space-Prefix Framing)

A `command++` mode uses mandatory line-prefixing to make the protocol unambiguous. **Note:** `p7c` stays "raw" — it validates and passes through. The caller handles space-prefixing.

**Wire format:**
```
command++
Header: value

 body line 1
 body line 2
 .
 still part of body
 .
EOF
```

**`p7c` responsibilities (raw passthrough):**
1. Detect `++` suffix (check before `+` to avoid ambiguity)
2. Pass stdin through unchanged
3. Treat line containing only ` .` (space-dot) as terminator (not `\n.\n`)
4. Optional: warn if line doesn't start with space (protocol compliance)

**Wrapper/script responsibilities (transformation):**
```bash
## Wrapper script adds space prefixing
space_prefix() {
    while IFS= read -r line; do
        printf ' %s\n' "$line"
    done
    printf ' .\n'  ## terminator
}

space_prefix < file.txt | p7c doc.upload++
```

**Server responsibilities:**
1. Detect `++` suffix on command
2. Strip first space from each received line
3. Treat line containing only ` .` as terminator

**Zenka convenience routines:**
Perl modules should provide helpers:
```perl
## High-level: handles space-prefixing automatically
<[protocol-7.send-multiline]>->(
    command => 'doc.upload++',
    content => $arbitrary_text,  ## dots, newlines, whatever
);
```

**Advantages over SMTP dot-stuffing:**
- Simpler: always prefix with space, always strip first char
- No conditional logic per line
- Binary-safe: works with any byte content (space is 0x20)

**Performance note:**
Native C auto-prefixing in `p7c` can be postponed until file zenka / data zenka performance actually requires it. Wrapper scripts are sufficient for scripting use cases.

#,,..,.,.,,.,,,,.,..,,..,,.,,,.,,,...,,.,,,,,,..,,...,..,,,.,,.,,,.,,,...,.,,,
#R2I3TPFR4TRMDQYF43IBTOXYG6GD5KFGPPASZBCNW42XIX4SQY2UPEHS5DYSUUCIFU7565672WKTK
#\\\|2XLZDJAHQ5MYIIP3UHZ3HCH7ZODNGZ3B4RUHQO2DI3OOLDY26VE \ / AMOS7 \ YOURUM ::
#\[7]N2FFNJLFT3AW5GPJCGY6FA5G235BE2DIVLA5DD3XIQBV7QU4TKDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
