# Protocol-7 Command Headers - Best Practices

The header metadata in command modules is **automatically parsed** and displayed to users. Make these descriptions excellent.

---

## Header Metadata

Every command module has three standard headers:

```perl
## [:< ##

# name  = zenka.child.cmd.action-name
# param = <required> [optional]
# descr = Clear description of what command does
```

---

## Where Headers Are Displayed

### In `zenka.commands` Output

When users query the zenka for available commands:

```
> letsencrypt.commands
Available commands:
  child.cmd.renew-certificate    Renew certificate for domain - fetches new cert from Let's Encrypt via ACME
  child.cmd.new-certificate      Obtain new certificate for domain - performs full ACME enrollment
  parent.cmd.status              Show current certificate renewal status and statistics
```

The `# descr` text appears here automatically!

### In Zenka Help Systems

- Interactive help: `letsencrypt.cmd.action --help`
- Command discovery: `letsencrypt.commands` or `zenka.child.commands`
- Documentation generation

---

## Writing Great Descriptions

### DO - Write Clear, Concise Descriptions

```perl
# descr = Renew certificate for domain - fetches new cert from Let's Encrypt via ACME
# Good: Clear action, mentions service, concise
```

```perl
# descr = Check current certificate renewal status and upcoming renewals
# Good: States what user sees, clear purpose
```

```perl
# descr = Revoke certificate to disable HTTPS for specified domain
# Good: Shows consequence, clear action, one sentence
```

### DON'T - Write Vague or Over-complicated

```perl
# descr = Process certificate-related activities
# Bad: Too vague, doesn't say what it does
```

```perl
# descr = This command handles the renewal of certificates that are expiring soon by contacting the ACME server and managing the challenge responses and then finalizing the order and downloading the certificate
# Bad: Too long, run-on sentence, too detailed
```

### DO - Mention Key Parameters When Important

```perl
# param = <domain> [days_threshold]
# descr = Check if certificate for domain needs renewal (default: 30 days before expiry)
# Good: Explains what [optional] parameter does
```

```perl
# param = <domain> <email>
# descr = Register new account and obtain certificate for domain (requires email for notifications)
# Good: Explains what required parameters do
```

### DO - Include Context When Helpful

```perl
# descr = Manually trigger certificate renewal check (runs automatically every 24 hours)
# Good: Shows relationship to automatic system
```

```perl
# descr = View renewal statistics and last check timestamp
# Good: Shows what user can expect to see
```

---

## Description Guidelines

### Length
- **Ideal**: One sentence, 50-80 characters
- **Maximum**: 120 characters
- **Minimum**: 20 characters (must be meaningful)

### Content
1. **Action verb**: What does the command do?
   - Renew, obtain, check, revoke, verify, view, update
2. **Object**: What is affected?
   - certificate, domain, account, status, renewal
3. **Context** (optional): Where/how/why?
   - via Let's Encrypt ACME
   - for automatic renewal
   - triggered manually or by timer

### Tone
- **Professional but accessible** - not overly technical
- **Active voice** - "Renew certificate for domain" not "Certificate renewal processing"
- **User-focused** - describe what user wants to accomplish
- **Consistent** - match style of other commands in zenka

---

## Examples from Protocol-7

### Weather Zenka

```perl
# descr = Return currently monitored station id
# Good: Short, clear, shows what you get
```

```perl
# descr = Set location name for current weather monitoring
# Good: Shows action and purpose
```

### Cube (Message Router)

```perl
# descr = List all connected users and their sessions
# Good: Shows output clearly
```

```perl
# descr = Show status of currently running zenki
# Good: Clear purpose
```

---

## ACME Command Examples

### Renewal Commands

```perl
# name  = letsencrypt.child.cmd.renew-certificate
# param = <domain>
# descr = Renew certificate for domain - fetches new cert from Let's Encrypt via ACME
```

### Status Commands

```perl
# name  = letsencrypt.parent.cmd.renewal-status
# param = [domain]
# descr = Show certificate renewal status - lists upcoming renewals and failures
```

### Account Commands

```perl
# name  = letsencrypt.child.cmd.account-status
# param =
# descr = Check ACME account status and configuration
```

### Maintenance Commands

```perl
# name  = letsencrypt.parent.cmd.clear-renewal-timers
# param = <domain>
# descr = Clear renewal failure timers for domain (use after manual fix)
```

---

## Self-Documenting Zenka

Good headers make the zenka **self-documenting**:

**Without good descriptions**:
```
> letsencrypt.commands
Available commands:
  child.cmd.renew-certificate
  child.cmd.new-certificate
  parent.cmd.renewal-check
  parent.cmd.clear-timers
```

User must read code or docs to understand what each does.

**With good descriptions**:
```
> letsencrypt.commands
Available commands:
  child.cmd.renew-certificate        Renew cert - fetches from Let's Encrypt via ACME
  child.cmd.new-certificate          New cert - performs full ACME enrollment
  parent.cmd.renewal-status          Show upcoming renewals and current statistics
  parent.cmd.clear-renewal-timers    Clear renewal failure timers (manual fix recovery)
```

Users can understand everything without reading docs!

---

## Checklist for Command Headers

When creating a new command module:

- [ ] `# name` is unique and follows `zenka.role.cmd.action-name` pattern
- [ ] `# param` clearly lists required and optional parameters
- [ ] `# descr` is one sentence, clear, and complete
- [ ] `# descr` starts with action verb
- [ ] `# descr` mentions important context if needed
- [ ] `# descr` is under 120 characters
- [ ] `# descr` would be helpful to someone discovering the command via `.commands`
- [ ] Tested that description displays correctly in zenka.commands

---

## Example: Complete Command Header

```perl
## [:< ##

# name  = letsencrypt.child.cmd.renew-certificate
# param = <domain>
# descr = Renew certificate for domain - fetches new cert from Let's Encrypt via ACME

my $call = shift;
my $domain = $call->{'args'};

return { 'mode' => 'false', 'data' => 'domain required' }
    unless $domain;

# ... implementation ...

return { 'mode' => 'true', 'data' => "renewal initiated for $domain" };

0;
```

**Breaking down the description**:
- ✓ Clear action: "Renew certificate"
- ✓ For what: "for domain"
- ✓ Context: "fetches new cert"
- ✓ From where: "from Let's Encrypt via ACME"
- ✓ One sentence
- ✓ Self-explanatory to users

---

## Integration with Zenka System

The Protocol-7 system automatically:

1. **Parses** `# descr` from module headers during module loading
2. **Displays** descriptions in `.commands` queries
3. **Caches** descriptions for performance
4. **Shows** in help systems and documentation generation
5. **Includes** in remote zenka command lists

No extra work needed - just write good descriptions and they appear everywhere!

---

## Why This Matters

A well-documented zenka is:
- **User-friendly** - people discover commands easily
- **Self-explanatory** - reduces need for external docs
- **Professional** - shows attention to detail
- **Maintainable** - anyone can understand what commands do
- **Discoverable** - works with protocol-7's introspection system

Great command descriptions are free documentation!

---

## Summary

The `# descr` field is your command's help text. Write it as if you're explaining to someone who just typed `.commands`:

> "This command [action] your [object] [how/where/why]"

Example:
> "Renew certificate for domain - fetches new cert from Let's Encrypt via ACME"

Clear, concise, complete. That's it!

