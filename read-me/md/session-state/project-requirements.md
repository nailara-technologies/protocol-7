# Protocol-7 Project Requirements

**Last Updated: 2025-03-01 04:34:08 UTC**
**Author: nailara-technologies**

## Development Environment Guidelines

### Code Structure Standards

1. **Module File Structure**
   - Do NOT add redundant `sub { }` declarations in module files
   - Rely on the Protocol-7 namespace handling via filenames instead
   - Each module file should contain the implementation directly without subroutine wrappers
   - Files under `modules/` directory are automatically treated as callable subroutines by name

2. **Module File Header Format**
   ```perl
   ## [:< ##

   # name = module.name.here

   # Brief description of module purpose

   # Implementation code starts here...
