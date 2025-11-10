# HTTP POST Body Buffering Analysis - Protocol-7 httpd

## Executive Summary

The httpd module accumulates POST request bodies **incrementally in linewise mode** until headers are completely parsed, then extracts the body from the input buffer. There is **no explicit mechanism to wait for a complete body based on Content-Length** - the current implementation assumes the body is present in the buffer after headers are parsed. This works for ACME requests but lacks proper handling for bodies that arrive in multiple packets.

---

## Data Structures Used for Body Buffering

### Primary Body Buffer: `$session->{'buffer'}->{'input'}`

**Location:** `/data/projects/protocol-7/modules/base.session.init` (lines 87)

```perl
qw| buffer | => { qw| input | => '', qw| output | => '' }
```

**Type:** Scalar string variable that grows as data arrives
- **Size limit:** `<size.buffer.input>` - maximum capacity of the input buffer
- **Managed by:** Base I/O handlers that read from the socket
- **Watched by:** EV watcher that triggers when buffer changes

### Session Structure Tracking

```perl
$session = {
    'buffer' => {
        'input'  => '',      # Raw accumulating data
        'output' => '',      # Response buffer
    },
    'size' => {
        'buffer' => {
            'input'  => <size.buffer.input>,    # Max input buffer size
            'output' => <size.buffer.output>,   # Max output buffer size
        }
    },
    'http' => {
        'request' => {
            'headers' => {},          # Parsed HTTP headers
            'data'    => '',          # Raw request line + headers
            'body'    => '',          # Extracted body (set by http_post)
        },
        'body' => '',  # Alternative body storage location
    },
    'read-mode'     => 'linewise',    # [linewise|bytewise|binary]
    'bytes-to-read' => 0,             # Used in bytewise mode only
}
```

---

## How Body Buffering Works

### Phase 1: Linewise Mode (Headers Only)

**Handler:** `net.read_linewise_estimated` (reads data incrementally)
**Mode:** `linewise` - reads until newline is found

**Process:**
1. Data is read from socket in chunks sized around average line length (~63 bytes)
2. Data is appended to `$session->{'buffer'}->{'input'}`
3. Buffer is searched for `\n` (linefeed) terminator
4. Once `\n\n` is found, headers are complete
5. Returns 0 = request complete

**Code Location:** `/data/projects/protocol-7/modules/net.read_linewise_estimated` (lines 42-89)

```perl
my $linefeed_match_position;

while ($size_left) {
    $read_length = $size_left if $size_left < $read_length;

    my $num_of_read_bytes = <[base.s_read]>->(
        $session->{'handle'},
        \$session->{'buffer'}->{'input'},  # Append to input buffer
        $read_length
    ) // 0;

    $linefeed_match_position = index $session->{'buffer'}->{'input'},
        chr 10, $LF_match_start_offset;   # Search for \n

    last if $linefeed_match_position >= 0;  # Found end of headers
}

return 0 if $linefeed_match_position >= 0;  # Complete
return 1;                                     # More data needed
```

### Phase 2: Header Parsing

**Handler:** `httpd.request_handler` (parses the accumulated data)

**Process:**
1. Input buffer is searched for request line + headers: `^(.+\r?\n\r?\n)`
2. Headers are extracted and parsed using `HTTP::Request->parse()`
3. `Content-Length` header is read but **NOT used to wait for body**
4. Remaining data in buffer after headers = body data

**Code Location:** `/data/projects/protocol-7/modules/httpd.request_handler` (lines 41-43)

```perl
return 0 if $session->{'buffer'}->{'input'} !~ s|^(.+\r?\n\r?\n)||s;

$session->{'http'}->{'request'}->{'data'} = $LAST_PAREN_MATCH // '';
# Remaining $session->{'buffer'}->{'input'} = POST body data (if present)
```

### Phase 3: Body Extraction (POST Specific)

**Handler:** `httpd.http_post` (extracts body from remaining buffer)

**Process:**
1. Retrieves `Content-Length` header
2. Checks if body exceeds `max_post_size` (default 1MB)
3. **Extracts whatever is in the input buffer as the body**
4. Stores in `$session->{'http'}->{'body'}`
5. Clears the input buffer

**Code Location:** `/data/projects/protocol-7/modules/httpd.http_post` (lines 18-42)

```perl
my $content_length = $headers->{'content-length'} // 0;
my $max_post_size = <httpd.cfg.max_post_size> // ( 1024 * 1024 );

if ( $content_length > $max_post_size ) {
    return <[httpd.send_error_page]>->( $id, 413 );  ## 413 Payload Too Large
}

# Extract body from input buffer (whatever is left after headers)
my $body_data = $session->{'buffer'}->{'input'} // '';

$session->{'http'}->{'body'} = $body_data;
$session->{'buffer'}->{'input'} = '';  # Clear buffer
```

### Phase 4: Body Processing (ACME Handler)

**Handler:** `httpd.handler.acme_request` (uses the extracted body)

**Code Location:** `/data/projects/protocol-7/modules/httpd.handler.acme_request` (lines 14-30)

```perl
my $req_body = '';

if ( exists $session->{'http'}->{'body'} ) {
    # Already parsed and stored by http_post
    $req_body = $session->{'http'}->{'body'};
} elsif ( $session->{'buffer'}->{'input'} &&
          length( $session->{'buffer'}->{'input'} ) > 0 ) {
    # Still in input buffer - extract it
    $req_body = $session->{'buffer'}->{'input'};
    $session->{'buffer'}->{'input'} = '';
} else {
    # No body present
}

# Parse JSON body
my $acme_req = <[httpd.json.decode]>->($req_body) // {};
```

---

## Mechanism for Detecting Body Completeness

### Current Implementation: NONE (Implicit Assumption)

**Current Behavior:**
- The system assumes the **complete body is already in the buffer** after headers are parsed
- No explicit wait for `Content-Length` bytes to be received
- No state machine transition to read exactly N bytes
- **This means incomplete bodies are silently treated as complete if they're all that's in the buffer**

### How This Differs from Bytewise Mode

The `bytewise` read mode provides a proper completion mechanism:

**Location:** `/data/projects/protocol-7/modules/base.handler.command` (lines 203-207)

```perl
elsif ( $input->$* =~ m,^((\($re->{cmd_id}\)|) *SIZE +(0*\d+)\n),o
    and $buffer_length - length( ${^CAPTURE}[0] ) < 0 + ${^CAPTURE}[2] ) {

    $session->{'read-mode'} = qw| bytewise |;    # Switch modes
    $session->{'bytes-to-read'} = 0 + ${^CAPTURE}[2];  # Exact byte count
    return 1;  # Wait for more data
}
```

**Bytewise Handler:** `/data/projects/protocol-7/modules/net.read_bytewise` (lines 49-67)

```perl
my $bytecount = <[base.s_read]>->(
    $session->{'handle'},
    \$session->{'buffer'}->{'input'},
    $read_len
);

$session->{'bytes-to-read'} -= $bytecount;

if ( $session->{'bytes-to-read'} == 0 ) {
    return 0;  # Complete - got all bytes
} else {
    return 1;  # More to read
}
```

---

## Content-Length Usage Pattern

### How Content-Length is Currently Used

1. **Validation Only:** Check if body exceeds max_post_size
2. **Logging:** Log the expected size for debugging
3. **NOT Used For:** Determining when body reception is complete

**Code Location:** `/data/projects/protocol-7/modules/httpd.http_post` (lines 15-28)

```perl
<[base.logs]>->( 2, '[%d] POST request: %s (content-length: %s)',
    $id, $http_uri, $headers->{'content-length'} // 'unknown' );

my $content_length = $headers->{'content-length'} // 0;
my $max_post_size = <httpd.cfg.max_post_size> // ( 1024 * 1024 );

if ( $content_length > $max_post_size ) {
    <[base.logs]>->(
        1, '[%d] POST body too large: %d bytes (max: %d)',
        $id, $content_length, $max_post_size
    );
    return <[httpd.send_error_page]>->( $id, 413 );
}
```

### Missing Pattern Comparison

**What a proper implementation would do:**

```perl
# When body reception is not yet complete:
if ( length($body_data) < $content_length ) {
    # Switch to bytewise mode to wait for rest
    $session->{'read-mode'} = 'bytewise';
    $session->{'bytes-to-read'} = $content_length - length($body_data);
    return <[httpd.handler.acme_request]>->( $id, $http_uri );  # Wait
}
```

---

## Body Accumulation Pattern: Incremental

### Step-by-Step Accumulation

**Timeline of a typical POST request:**

```
Time 1: Client sends "POST /api/certificate/request HTTP/1.1\r\n"
        -> Added to $session->{'buffer'}->{'input'}
        -> linewise handler: incomplete, return 1

Time 2: Client sends "Content-Length: 42\r\n"
        -> Added to $session->{'buffer'}->{'input'}
        -> linewise handler: incomplete, return 1

Time 3: Client sends "\r\n"
        -> Added to $session->{'buffer'}->{'input'}
        -> linewise handler: headers complete! return 0
        -> Request handler extracts headers

Time 4: Client sends "{"domain":"example.com"}"
        -> Would be added to $session->{'buffer'}->{'input'}
        -> BUT: httpd.http_post already extracted what was there
        -> This data might not reach httpd.http_post!
```

### Input Buffer Flow

```
$session->{'buffer'}->{'input'} = "POST /api/... HTTP/1.1\r\nContent-Length: 42\r\n\r\n"
                                   ↓ (linewise mode reads until \n\n found)
                                   Returns 0 (complete)
                                   ↓
                                   Request handler extracts headers
                                   Remaining: ""
                                   ↓
                                   http_post gets empty body!
                                   ↓
                                   If body arrives NEXT:
                                   It goes to input buffer again
                                   But http_post already ran!
```

---

## Other HTTP Handlers: Body Handling Patterns

### httpd.http_get
**Location:** `/data/projects/protocol-7/modules/httpd.http_get`

- **No body handling** - GET requests should have no body
- Processes range headers (Range: bytes=0-1023)
- Handles file serving, templating, caching
- Returns file content in response

### httpd.http_head
**Location:** `/data/projects/protocol-7/modules/httpd.http_head`

- **No body handling** - HEAD requests should have no body
- Similar to GET but only returns headers
- Returns metadata about resources without content

### httpd.http_options
**Location:** `/data/projects/protocol-7/modules/httpd.http_options`

- **No body handling** - OPTIONS requests can have bodies but this handler ignores them
- Returns `Allow` header with supported methods
- Calls `httpd.http_head` with 204 (No Content) code

### httpd.http_post (Only POST Handler)
**Location:** `/data/projects/protocol-7/modules/httpd.http_post`

- **Has body handling** - Only HTTP method that processes bodies
- Routes ACME and certificate requests
- Other POST endpoints return 405 (Method Not Allowed)

---

## Buffer Management Constraints

### Buffer Size Limits

**Input Buffer:**
- Max size: `<size.buffer.input>` (default size not found, likely 64KB-256KB)
- When full: Session input is paused
- Location: `/data/projects/protocol-7/modules/base.handler.read` (lines 73-89)

```perl
my $size_left = $data{'size'}->{'buffer'}->{'input'}
    - length $session->{'buffer'}->{'input'};

if ( $size_left > 0 ) {
    $event->w->start;           # Continue reading
    $handle_href->{'paused'} = FALSE;
} else {                        # No space left
    $handle_href->{'paused'} = TRUE;
    $handle_href->{'paused-watcher'} = $event->w;
    <[base.log]>->( 2, 'input handler paused [ buffer full ]' );
}
```

**Output Buffer:**
- Max size: `<size.buffer.output>`
- Used for HTTP responses
- Managed separately from input

### Buffer Pause/Resume Logic

**Paused State:** When input buffer is full
- Reading is paused (watcher not active)
- New data arriving at socket is not read
- Session becomes unresponsive

**Resume Logic:** In `base.handler.input` (lines 112-122)

```perl
if ( $handle_href->{'paused'} //= FALSE ) {  # Restart reading
    <[base.log]>->( 2, 'restarting input handler =)' );
    if ( defined $handle_href->{'paused-watcher'} ) {
        $handle_href->{'paused-watcher'}->start
            if not $handle_href->{'paused-watcher'}->is_active;
        delete $handle_href->{'paused-watcher'};
    }
    $handle_href->{'paused'} = FALSE;
}
```

---

## Critical Issues with Current Implementation

### Issue 1: No Bytewise Mode for POST Bodies

**Problem:**
- POST bodies are never switched to bytewise mode
- No way to explicitly wait for Content-Length bytes
- Bodies arriving in multiple packets may be incomplete

**Scenario:**
```
Client sends: "POST /api/certificate/request HTTP/1.1\r\n"
              "Content-Length: 1000\r\n"
              "\r\n"
              "First 100 bytes of body..."

httpd.request_handler extracts headers, leaves 100 bytes in buffer
httpd.http_post reads 100 bytes (thinks it's complete)
Remaining 900 bytes arrive later but httpd.http_post already finished
Result: Request processed with incomplete JSON body
```

### Issue 2: No State Transition for Body Reception

**Problem:**
- No mechanism to keep httpd.http_post waiting for more data
- Once headers are parsed, handler is called immediately
- No session state tracks "waiting for body completion"

### Issue 3: Content-Length Ignored for Sequencing

**Problem:**
- Content-Length is checked for size validation only
- Not used to determine: "have we received all the body?"
- Assumes: "if data exists in buffer after headers, it's the complete body"

### Issue 4: Buffer Exhaustion Risk

**Problem:**
- If body + headers > buffer size, buffer gets paused
- Reading stops, but no explicit error to client
- Request hangs silently

---

## Recommendations for Proper Implementation

### Option 1: Bytewise Mode for Bodies (Recommended)

1. After headers are parsed, check if body size is known
2. If Content-Length exists and body is incomplete:
   ```perl
   my $body_len = length($session->{'buffer'}->{'input'});
   my $expected = $headers->{'content-length'} // 0;

   if ($body_len < $expected) {
       $session->{'read-mode'} = 'bytewise';
       $session->{'bytes-to-read'} = $expected - $body_len;
       # Keep handler waiting until body complete
   }
   ```

3. Once bytewise mode reads all bytes, reassign to POST handler

### Option 2: Async Body Buffering

1. Create new buffer specifically for POST bodies
2. Track reception state separately
3. Return "wait" status if body incomplete
4. Resume handler when body complete

### Option 3: Timeout-Based Completion

1. Set timeout for body reception based on Content-Length
2. Assume incomplete if timeout expires
3. Return 408 (Request Timeout) to client

---

## Summary Table

| Aspect | Current Implementation |
|--------|------------------------|
| **Buffer Data Structure** | `$session->{'buffer'}->{'input'}` (string scalar) |
| **Accumulation Method** | Incremental, linewise mode (until `\n\n`) |
| **Complete Detection** | Header parsing completion only, no body checking |
| **Content-Length Role** | Size validation and logging only |
| **Bytewise Mode** | Not used for POST bodies (only Protocol-7 SIZE replies) |
| **Body Extraction** | Whatever remains in buffer after header parsing |
| **State Tracking** | No session state for body reception status |
| **Buffer Pause** | Pauses when full, resumes when content consumed |
| **Error Handling** | No explicit incomplete body detection |
| **Timeout** | Generic HTTP timeout (13 seconds default) |

---

## Key File References

| File | Purpose | Key Line(s) |
|------|---------|-------------|
| `/data/projects/protocol-7/modules/httpd.http_post` | Extracts body from buffer | 35-42 |
| `/data/projects/protocol-7/modules/httpd.request_handler` | Parses headers, triggers POST handler | 41-43, 129-149 |
| `/data/projects/protocol-7/modules/httpd.handler.acme_request` | Uses extracted body | 14-30 |
| `/data/projects/protocol-7/modules/net.read_linewise_estimated` | Incremental buffer reading | 42-89 |
| `/data/projects/protocol-7/modules/net.read_bytewise` | Fixed-size body reading (not used for POST) | 40-67 |
| `/data/projects/protocol-7/modules/base.session.init` | Session buffer initialization | 87 |
| `/data/projects/protocol-7/modules/base.handler.read` | I/O event handler for reading | 41-93 |
| `/data/projects/protocol-7/modules/base.handler.input` | Input buffer watcher | 38-136 |
| `/data/projects/protocol-7/modules/base.handler.command` | Demonstrates bytewise mode for Protocol-7 | 203-207 |

