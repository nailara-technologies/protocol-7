## [:< ##

# name  = task: contextualized error replies for routing failures
# descr = replace generic "no perm" with specific replies that identify
#         the actual mistake: .cmd. in routing path, dotted sub-command
#         names, non-.cmd. subroutines being called as commands, load-time
#         mismatch detection. first step toward intelligent reply system.

## the problem

generic reply today:
```
[3202544] no perm. [ src 'cube' cmd|usr 'zenka.cmd.status' ]
```

the caller sees "no perm" but the actual issue is one of several
distinct mistakes, each with a specific fix:

```
mistake 1:  .cmd. left in the routing path
            tried: zenka.cmd.status
            should be: zenka.status
            (the .cmd. segment is stripped at load time)

mistake 2:  trying to call a non-.cmd. subroutine as a command
            tried: zenka.internal_helper
            internal_helper exists in %code but is not a .cmd. module
            fix: wrap in a .cmd. module or use the correct .cmd. name

mistake 3:  extra dots after .cmd.
            tried: zenka.cmd.do.something
            only one segment after .cmd. is valid
            fix: zenka.do-something (hyphenated, single segment)

mistake 4:  calling a callback / event handler as a command
            tried: zenka.handler.on_data
            these are internal and not externally callable
            fix: expose via a .cmd. wrapper if needed
```

## detection at load time

when modules load, inspect all entries in %code for structural anomalies:

```perl
for my $name ( keys %code ) {
    # detect: .cmd. not at correct position
    if ( $name =~ /\.cmd\./ && $name !~ /^[^.]+\.cmd\.[^.]+$/ ) {
        warn "malformed cmd module: '$name' — extra dots after .cmd.";
        $data{diag}{malformed_cmds}{$name} = 'extra_dots';
    }

    # detect: non-.cmd. module callable as command (in subroutine whitelist
    # but not a .cmd. module)
    # → register in $data{diag}{non_cmd_whitelisted}{$name}
}
```

store detected anomalies in `$data{diag}{cmd_anomalies}` at load time.

## reply generation

in `base.handler.command` (VSY5TBA / 74PTQ6Q paths), before emitting
generic "no perm", check for known patterns:

```perl
# check: did the command contain .cmd. ?
if ( $cmd =~ /\.cmd\./ ) {
    my $clean = $cmd;
    $clean =~ s/\.cmd\././g;   # strip .cmd. segment
    return reply_with(
        "FALSE: '.cmd.' is not part of the external command name. "
      . "Try: $clean\n"
      . "Syntax: <zenka>[.<route>].<command>"
    );
}

# check: is this a known non-.cmd. module in %code?
if ( exists $code{$cmd} && !exists $code{"${cmd}_cmd_"} ) {
    return reply_with(
        "FALSE: '$cmd' is an internal subroutine, not a command. "
      . "Expose via a .cmd. wrapper module if needed."
    );
}

# check: is this in the anomaly registry?
if ( exists $data{diag}{cmd_anomalies}{$cmd} ) {
    my $reason = $data{diag}{cmd_anomalies}{$cmd};
    return reply_with( "FALSE: '$cmd' is malformed ($reason). "
      . "Check module structure." );
}

# fallthrough: generic no perm
```

## message template additions

add to `src/protocol.protocol-7.message-templates`:

```
qw| CMD_HAS_DOT   | => "FALSE: '.cmd.' is stripped from command names. Try: '%s'\nSyntax: <zenka>[.<route>].<command>",
qw| NON_CMD_SUB   | => "FALSE: '%s' is an internal subroutine, not a whitelisted command.",
qw| MALFORMED_CMD | => "FALSE: '%s' has malformed command structure (%s).",
```

## future direction

this is the first step toward:
- LLM-assisted log message optimization (analyze, rank, preview, commit, rollback)
- pattern library for common error classes (like signal-cancel-log-library
  but for error reply patterns)
- ncode zenka as the interface for browsing and editing message templates
  with LLM assistance

## dispatch prompt

implement contextualized error reply detection in `base.handler.command`
and `base.handler.command.route_to_target`:

1. add .cmd.-in-path detection before the generic VSY5TBA / 74PTQ6Q reply
   — strip .cmd., suggest the corrected command name in the reply

2. add load-time anomaly scan in `base.init_code` or a new
   `base.cmd.diag.scan_modules` module: walk %code, detect malformed
   .cmd. entries and non-.cmd. whitelisted modules, store in
   `$data{diag}{cmd_anomalies}`

3. add message template entries CMD_HAS_DOT, NON_CMD_SUB, MALFORMED_CMD
   to `src/protocol.protocol-7.message-templates`

4. wire the anomaly check into the no-perm reply path: check registry
   before falling through to generic reply

verify: `p7c zenka.cmd.status` → contextual reply naming the fix,
not generic "no perm"

#,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,

#,,,.,,,,,,.,,.,.,..,,,,.,.,,,,.,,,.,,..,,,..,..,,...,...,...,,..,..,,,,,,...,
#X6O4YJS6RMVR2M5QLUDNYR6EZANVGP6DL4UVNFWVQHJFXJ3TLV3KGOVS4KI2LGW52KMSKPQHE4R56
#\\\|VMRELVUPZ2ZZW5C6DNAH75TNRC55UO63LFCKLN4COUUNFHBKZMM \ / AMOS7 \ YOURUM ::
#\[7]QYJMNZQDNLAJNDKVVKNCLEY3Q2LVYQNR7N4SVQVLCODLBI5UYUBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
