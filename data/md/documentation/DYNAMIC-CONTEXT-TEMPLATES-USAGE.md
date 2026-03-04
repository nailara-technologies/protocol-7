# Dynamic Context Templates - Usage Guide

## Overview

Dynamic context templates enable AI system messages and chat context to be assembled from registered provider commands rather than hardcoded strings. This provides fresh, relevant context for each request.

## Architecture

```
models.backend.* → web.cmd.render-template → web.process_template_recursive
                         ↓
              context.* provider commands
                         ↓
              git, modules, files, tasks
```

## Components Implemented

### 1. web.cmd.render-template
Renders templates with context provider support.

**Usage:**
```perl
my $result = <[web.cmd.render-template]>->({
    template_path => 'configuration/models/system-messages/coding-assistant.tmpl',
    meta => { model => 'kimi', task_id => '...' },
    budget => 4000,  ## token budget
});

if ( $result->{status} eq 'success' ) {
    my $system_message = $result->{content};
}
```

### 2. Context Providers

#### context.git.recent_changes
Returns recent git diff stat, truncated to budget.
```
<[context.git.recent_changes:budget=1500]>
```

#### context.task.active
Returns current active task.
```
<[context.task.active]>
```

#### context.modules.list
Lists modules in a namespace.
```
<[context.modules.list:namespace=coding:budget=800]>
```

#### context.file
Returns file content, truncated to budget.
```
<[context.file:path=modules/base.handler.command:budget=2000]>
```

### 3. System Message Templates

Templates stored in `configuration/models/system-messages/`:

**coding-assistant.tmpl:**
```
## protocol-7 coding assistant ##

you are a protocol-7 module writer. work in the existing code style.

## active task ##
<[context.task.active]>

## recent changes ##
<[context.git.recent_changes:budget=1500]>

## relevant modules ##
<[context.modules.list:namespace=coding:budget=800]>
```

## Integration with Models

To use in a models backend:

```perl
## in modules/models.backend.kimi_web ##

## 1. Render system message template ##
my $template_result = <[protocol-7.route-send]>->(
    {   command   => qw| cube.web.render-template |,
        call_args => {
            template_path => 'configuration/models/system-messages/coding-assistant.tmpl',
            budget => 4000,
        },
        reply => {
            handler => qw| models.handler.template_rendered |,
            params  => { original_reply_id => $reply_id },
        }
    }
);

## 2. Use rendered content as system message ##
## (in models.handler.template_rendered)
my $system_message = $result->{content};

## 3. Prepend to conversation ##
my $full_prompt = $system_message . "\n\n" . $user_prompt;
```

## Token Budget Convention

Providers receive budget via call args:
- `budget=N` - approximate token count
- Providers convert to chars (~4 chars/token)
- Self-truncate to fit

## Testing

Manual test:
```bash
## Test context provider directly ##
p7c context.git.recent_changes budget=500

## Test template rendering ##
p7c web.render-template template_path=configuration/models/system-messages/coding-assistant.tmpl budget=4000
```

## Status

**Phase 1:** ✅ Complete - web.cmd.render-template
**Phase 2:** ✅ Complete - Initial context providers
**Phase 3:** 🔄 In Progress - System message templates
**Phase 4:** ⏳ Pending - Chat context assembly

## Next Steps

1. Wire render-template into models.backend.*
2. Add budget allocation logic (system:history:current = 25:50:25)
3. Test end-to-end with kimi
4. Add more providers: context.history.recent, context.history.relevant (phase 2)

---

*Created: 2026-03-03*

#,,,.,,.,,..,,...,.,,,..,,.,.,,,,,.,.,.,,,..,,..,,...,...,..,,...,..,,.,,,...,
#XPPHEA2ZY7RWCPOMZMG2WX7ASSFBZFG5WYAX2IZCMG63UPCLQPD4UJFIGUNHYIRF4HNOSIVQDECTK
#\\\|IPZGPR3A34YQLUHJKKLYAP6G2GCPXL27OQI7RQBN224DWNMKZSS \ / AMOS7 \ YOURUM ::
#\[7]RVNDUMDVKNPGCN4V463TJ7QTXVOXJMX6WLLBF5D5TTIFQJUWE4CQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
