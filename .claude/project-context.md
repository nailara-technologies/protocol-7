# Protocol-7 Project Context for LLMs

This file provides quick navigation to project documentation optimized for LLM understanding.

## Note to Claude

**You are encouraged to update and improve these context files!**

Feel free to:
- Update `data/yaml/project-context/system-architecture.yaml` as the project evolves
- Add new YAML context files for emerging patterns
- Improve documentation clarity and structure
- Keep cross-references synchronized
- Add insights from code reviews and development sessions

These files exist to help future Claude instances (and other LLMs) understand the project efficiently. Maintain them as living documentation.

## Quick Reference (Token-Efficient)

**Structured YAML:** `data/yaml/project-context/system-architecture.yaml`
- Core concepts (zenki, zenka, cube, v7)
- Directory structure and patterns
- Module syntax (`<variable>`, `<[function]>`)
- Command structure and common tools
- ~200 lines of structured, parseable information

## Full Documentation (Comprehensive)

When more detail is needed, reference these comprehensive guides:

### System Understanding
- **Startup Guide:** `data/asc/what-AI-thinks/markdown-form/protocol7/docs/p7-startup-guide.md`
  - Core components and startup flow
  - Zenki management through v7
  - Authentication and security
  - Command reference
  - Common patterns and troubleshooting

- **Protocol Description:** `data/asc/what-AI-thinks/markdown-form/protocol7/docs/p7-protocol-desc.md`
  - Protocol overview and architecture
  - Message types and routing
  - Security features
  - Network topology

- **Data Directory Context:** `data/asc/what-AI-thinks/markdown-form/protocol7/docs/data_.context.md`
  - Resource organization
  - Graphics, fonts, templates
  - Internationalization
  - Library structure

## Code Review Documentation

**Template:** `data/yaml/templates/code-review-template.yaml`
- YAML task specification for LLM code reviews
- Structured documentation format
- Quality criteria and validation rules

**Example Review:** `data/yaml/code-reviews/src/crypt.C25519.init_code`
- Comprehensive module documentation
- Regex patterns, constants, mappings
- Security analysis and recommendations

## Key Insights for Development

### Module Structure
```
src/module-name.function-name  # One function per file
src/module-name.init_code      # Runs at initialization
src/module-name.pre_init       # Runs before init_code
```

### Variable Syntax (Custom Perl Extensions)
```perl
<variable.name>          → $data{'variable'}{'name'}
<[function.name]>        → $code{'function.name'}->()
```

### Configuration Files
```
cfg/zenki/<zenka-name>/start-set-up.*
cfg/zenki/<zenka-name>/shared-params
```

## Working with the Project

1. **Start here:** Read `system-architecture.yaml` for quick context (2-3 min read)
2. **Deep dive:** Reference full markdown docs when implementing features
3. **Code review:** Use templates in `data/yaml/templates/` for documentation
4. **Examples:** Study existing zenki configs in `cfg/zenki/`

## Token Usage Strategy

- **First interaction:** Load `system-architecture.yaml` (~1-2K tokens)
- **Specific features:** Reference relevant markdown sections
- **Code work:** Keep YAML reference active, markdown on-demand
- **Reviews:** Use template structure for consistency

This layered approach balances comprehensive understanding with token efficiency.
