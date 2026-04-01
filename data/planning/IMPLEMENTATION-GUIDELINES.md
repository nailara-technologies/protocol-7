# Implementation Guidelines for data/planning/

## Module Format

All planning modules follow the standard P7 module format:

```perl
## [:< ##
# name  = data.planning.planner.task-decomposer
# descr = Recursively decompose a task into atomic operations

my $task = shift // '';
my $depth = $args->{'depth'} // 3;
my $budget = $args->{'budget'} // 2000;

## validate input ##
return unless length $task;

## implementation here ##

return {
    'mode' => qw| true |,
    'data' => $result,
};
```

## Return Format

- **Success**: `{ mode => qw| true |, data => $result }`
- **Failure**: `{ mode => qw| false |, data => $error }`
- **Warning**: `{ mode => qw| true |, data => $result, warnings => [$warning1, $warning2] }`

## Logging

Use the logging interface consistently:

```perl
<[base.logs]>->(
    2,     # level: 0=error, 1=default, 2=info, 3=debug
    ':. planner.task-decomposer: %s',
    $task
);
```

- **0 (error)**: Fatal errors, unrecoverable failures
- **1 (default)**: Important operational messages
- **2 (info)**: General progress and information
- **3 (debug)**: Detailed debugging information

## Parameter Handling

### Required Parameters
```perl
my $path = $args->{'path'} // return {
    'mode' => qw| false |,
    'data' => 'path required',
};
```

### Optional Parameters with Defaults
```perl
my $budget = $args->{'budget'} // 2000;
my $depth  = $args->{'depth'} // 3;
```

### Array Parameters
```perl
my @tools = @{$args->{'tools'} // [qw| read_file read_module |]};
```

## Error Handling

### Validation Errors
```perl
return {
    'mode' => qw| false |,
    'data' => "error: $reason",
};
```

### Tool Not Available
```perl
return unless exists $code{'context.file'};
return {
    'mode' => qw| false |,
    'data' => "context.file not available",
}
if not exists $code{'context.file'};
```

### Budget Exceeded
```perl
<[base.logs]>->(
    0,     ':. exceeded budget: %d / %d',
    $used, $budget
);
return {
    'mode' => qw| false |,
    'data' => "budget exceeded: $used / $budget tokens",
};
```

## State Management

### Context Storage
```perl
my $plan_id = $args->{'plan_id'} // time . '-' . $$;
<[file.zenka_dir.write]>->(
    "state/planning/$plan_id/context.json",
    \$context,
    '>',
    0644,
    ':encoding(UTF-8)'
);
```

### Checkpoints
```perl
my $checkpoint_file = "state/planning/$plan_id/checkpoint";
<[file.put]>->( $checkpoint_file, \$checkpoint );
```

## Integration with coding.tools

### Calling coding.tools Handlers
```perl
return $code{'context.file'}->(
    {
        'path'      => $args->{'path'},
        'budget'    => $args->{'budget'} // 2000,
        'from_line' => $args->{'from_line'} // 1,
        'to_line'   => $args->{'to_line'} // 0,
    }
);
```

### Staging Files
```perl
my $stage_name = $path;
$stage_name =~ s|/|__|g;
my $stage_rel = "staged/$stage_name";
<[file.zenka_dir.write]>->(
    $stage_rel, \$content, '>', 0664, ':encoding(UTF-8)'
);
```

## Performance Considerations

### Budget Awareness
- Always respect budget parameters
- Report token usage when significant
- Provide ways to increase budget if needed

### Caching
```perl
if ( !defined $cache{'$task'} ) {
    $cache{'$task'} = $result;
}
return $cache{'$task'};
```

### Lazy Evaluation
```perl
my $result = sub {
    # expensive computation
};
return { 'mode' => qw| true |, 'data' => $result() };
```

## Testing Recommendations

### Unit Tests
- Validate parameter handling
- Test default values
- Verify error conditions
- Check return formats

### Integration Tests
- Test with actual coding.tools
- Verify state persistence
- Test rollback scenarios

### Performance Tests
- Measure token usage
- Benchmark execution time
- Test with large inputs

## Documentation

### Inline Documentation
```perl
## read args ##
my $task = shift // '';

## validate input ##
return unless defined $task and length $task;
```

### Module Metadata
```perl
## [:< ##
# name  = data.planning.planner.task-decomposer
# descr = Recursively decompose a task into atomic operations with dependencies
# author = ai-agent
# version = 0.1.0
```

## Security Considerations

### Path Validation
```perl
my $root = <system.root_path>;
my $real_root = Cwd::abs_path($root) // '';
my $real_dir  = Cwd::abs_path( ( $abs_path =~ s|/[^/]+$||r ) ) // '';
return 'error: path escapes project root'
    if !length $real_root
    or index( $real_dir, "$real_root/" ) != 0
    or $path =~ m|\.\./|;
```

### Input Sanitization
```perl
$task =~ s|[^\w\s\-\.\,]|/g;  # Allow only safe characters
$task =~ s/^\s+//;             # Trim leading whitespace
$task =~ s/\s+$//;             # Trim trailing whitespace
```

## Future Enhancements

### Multi-Agent Coordination
- Plan delegation to specialized agents
- Inter-agent communication protocols
- Consensus mechanisms

### External Integrations
- API call planning
- Database query planning
- External tool orchestration

### Advanced Features
- Plan optimization algorithms
- Predictive resource allocation
- Learning from execution history

## Common Patterns

### Task Decomposition Pattern
```perl
## base case: atomic task ##
return if $depth <= 0;

## check if already atomic ##
return unless $task =~ m|^(create|read|write|modify)\s+.*$|;

## recursive decomposition ##
my @subtasks = decompose($task, $depth - 1);
```

### Step Execution Pattern
```perl
my $step = shift;
my $result = execute_step($step);

## handle success ##
if ( ref $result eq qw| HASH | and $result->{'mode'} eq qw| true | ) {
    return $result;
}

## handle failure ##
return {
    'mode' => qw| false |,
    'data' => $result->{'data'},
    'warnings' => $result->{'warnings'} // [],
};
```

### Error Recovery Pattern
```perl
my $failure = {
    'step'    => $step_id,
    'error'   => $result->{'data'},
    'context' => $context,
};

## attempt recovery ##
my $recovery = apply_recovery_strategy($failure);

## if recovery failed ##
if ( not $recovery ) {
    return rollback_plan($plan, $checkpoint);
}
```

## Code Review Checklist

- [ ] Follows P7 module format
- [ ] Returns proper mode/data structure
- [ ] Logs at appropriate levels
- [ ] Handles errors gracefully
- [ ] Respects budget parameters
- [ ] Validates inputs
- [ ] Documents public interface
- [ ] No forbidden patterns
- [ ] Uses lowercase comments
- [ ] Column width <= 78 chars

## Validation Commands

```bash
# Check module format
ptd_check data.planning.planner.task-decomposer

# Format the module
ptd_format data.planning.planner.task-decomposer

# Validate format
validate_module_format data.planning.planner.task-decomposer
```

## References

- P7 Core Knowledge: Module format, naming conventions, data structures
- coding.tools.*: Existing tool implementations for reference
- data/planning/README.md: High-level architecture overview
- TOOL-SPECIFICATIONS.yaml: Detailed tool parameter definitions

#,,.,,,..,,..,,.,,,,,,,.,,,,.,,.,,,,.,.,,,..,,...,...,..,,...,,.,,...,,,,,,..,
#ZEQS2BR5ZSCZOSUN55SZPIXF6K4HQLE3IDWK3L7KTVXHX2NOEBK332EM3QIMAL7EPCGFINGKB5GW6
#\\\|LQF4WU63IVK4SRKMB4HOYTHQMCT5Z55NA7TFMBBZ3QU3Q7GCCWA \ / AMOS7 \ YOURUM ::
#\[7]MCJDEDDRHAKK2KBXDDOWVO672YADX5CE7NDP5HHKFU52ARLZSOCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
