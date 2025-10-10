# Task: Organize html-unsorted/ into html-form/

**Status:** PENDING (waiting for html-unsorted/ directory to be populated)
**Created:** 2025-10-10
**Similar Completed Task:** perl-form reorganization (see git history)

---

## Objective

Import and organize AI-generated HTML files from `html-unsorted/` into the structured `html-form/` directory with:
1. Topic-based categorization
2. Optimized file naming
3. INDEX.md files for fast AI retrieval
4. No remote git commits during reorganization

---

## Task Steps (Checklist)

- [ ] **Step 1:** Explore html-unsorted/ structure
  - Count files and subdirectories
  - Identify file types and patterns
  - Check git tracking status

- [ ] **Step 2:** Analyze content and identify topics
  - Read sample files from each subdirectory
  - Identify main themes (consciousness, visualization, protocols, etc.)
  - Map content to appropriate html-form/ categories

- [ ] **Step 3:** Design/verify html-form/ category structure
  - Review existing html-form/ directories
  - Create new categories if needed
  - Plan file-to-category mappings

- [ ] **Step 4:** Import and organize files
  - Move git-tracked files using `git mv`
  - Move untracked files using regular `mv`
  - Optimize file names for clarity (e.g., `div7-viz.html` → `division-by-7-visualization.html`)
  - Preserve directory hierarchies where appropriate

- [ ] **Step 5:** Create INDEX.md files
  - Master INDEX.md in html-form/
  - Category-specific INDEX.md files
  - Include keywords, topics, and search patterns
  - Add visual/interactive feature descriptions

- [ ] **Step 6:** Verify and document
  - Confirm html-unsorted/ is empty
  - Count total files organized
  - Verify git status
  - Create summary report

---

## Expected html-form/ Category Structure

Based on common AI-generated HTML patterns, expect categories like:

```
html-form/
├── INDEX.md                          # Master navigation
├── visualizations/                   # Interactive visualizations
│   ├── consciousness/               # Consciousness emergence visuals
│   ├── geometric/                   # Geometric pattern displays
│   ├── harmonic/                    # Harmonic pattern animations
│   └── network/                     # Network topology visualizations
├── interfaces/                       # UI/interface demonstrations
│   ├── control-panels/              # Control system interfaces
│   ├── dashboards/                  # Status dashboards
│   └── interactive-demos/           # Interactive demonstrations
├── documentation/                    # HTML documentation pages
│   ├── concepts/                    # Concept explanations
│   ├── tutorials/                   # Step-by-step tutorials
│   └── references/                  # Reference documentation
├── claude-insights/                  # Claude-generated HTML insights
│   ├── claude-3/                    # Claude 3 outputs
│   └── claude-4/                    # Claude 4 outputs
├── tools/                           # HTML-based tools
│   ├── analyzers/                   # Analysis tools
│   ├── converters/                  # Format converters
│   └── generators/                  # Content generators
└── prototypes/                      # Experimental prototypes
    ├── consciousness-experiments/   # Consciousness exploration UIs
    ├── harmonic-interfaces/         # Harmonic system interfaces
    └── protocol-demos/              # Protocol-7 demonstrations
```

---

## File Naming Optimization Patterns

### From → To Examples

**Be Descriptive:**
- `div7.html` → `division-by-7-visualization.html`
- `viz1.html` → `harmonic-resonance-visualization.html`
- `demo.html` → `consciousness-emergence-demo.html`

**Topic-First:**
- `interactive_cube.html` → `cube-interactive-3d-visualization.html`
- `zenki_display.html` → `zenki-process-status-display.html`

**Category Indicators:**
- `consciousness-viz-v2.html` → Keep version, ensure category placement
- `harmonic-interface.latest.html` → Preserve version markers

**Hyphen Separation:**
- `consciousness_emergence_demo.html` → `consciousness-emergence-demo.html`

---

## INDEX.md Template Structure

Each category INDEX should include:

### Header
```markdown
# [Category Name] HTML Index

**Purpose:** [Brief description of category contents]

## Files in this Category
```

### File Entries
```markdown
**`filename.html`**
- **Topics:** [main topics covered]
- **Features:** [interactive features, visualizations, etc.]
- **Technologies:** [JavaScript libraries used, Canvas, WebGL, etc.]
- **Related Perl Modules:** [links to perl-form/ if applicable]
- **Keywords:** `tag1`, `tag2`, `tag3`
```

### Navigation Aids
```markdown
## Quick Search Patterns

**For [topic]:** `path/to/file.html`
**For [feature]:** `path/to/file.html`

## Technology Index

- **Three.js:** [files using Three.js]
- **D3.js:** [files using D3]
- **Canvas API:** [files using Canvas]
- **WebGL:** [files using WebGL]
```

---

## Special Considerations for HTML Files

### Interactive Features to Document
- Animation types (CSS, JavaScript, WebGL)
- User interaction methods (click, drag, keyboard)
- Data visualization techniques
- Real-time updates or static displays

### Dependencies to Track
- JavaScript libraries (Three.js, D3.js, P5.js, etc.)
- CSS frameworks (Bootstrap, Tailwind, custom)
- External data sources
- WebAssembly modules

### Metadata to Extract
- Creation date (from git or file comments)
- AI model that generated it (Claude 3/4, GPT, etc.)
- Related Protocol-7 concepts
- Implementation status (prototype, functional, conceptual)

---

## Cross-Reference with perl-form/

Create links between related content:

**HTML → Perl:**
- Visualization → Mathematical computation module
- Interface → Backend processing script
- Demo → Implementation algorithm

**Perl → HTML:**
- Note in perl INDEX which concepts have visual representations
- Link from consciousness modules to consciousness visualizations

---

## Git Handling

### For Git-Tracked Files
```bash
git mv html-unsorted/file.html html-form/category/optimized-name.html
```

### For Untracked Files
```bash
mv html-unsorted/file.html html-form/category/optimized-name.html
```

### For Duplicates
```bash
# If file exists in both locations, use git rm -f for source
git rm -f html-unsorted/duplicate.html
```

---

## Quality Checks

Before marking complete:

- [ ] All files from html-unsorted/ moved
- [ ] html-unsorted/ is empty (or contains only . and ..)
- [ ] All moved files have optimized names
- [ ] Each major category has INDEX.md
- [ ] Master html-form/INDEX.md created
- [ ] Cross-references to perl-form/ added where appropriate
- [ ] Git status shows only intended changes
- [ ] No remote commits made
- [ ] Statistics documented (file counts, categories, etc.)

---

## Success Metrics

**Completeness:**
- 100% of html-unsorted/ files categorized
- 0 files remaining in html-unsorted/

**Organization:**
- Clear category boundaries
- Logical file placement
- Consistent naming conventions

**Discoverability:**
- INDEX files with comprehensive keywords
- Search patterns documented
- Technology/feature indexing complete

**Maintainability:**
- Related files grouped together
- Version markers preserved
- Dependencies documented

---

## Reference: perl-form/ Reorganization Results

**Successfully reorganized:**
- 20 files moved from perl-unsorted/
- 83 total Perl modules organized
- 5 INDEX.md files created
- 10 top-level categories
- 31 total directories

**Optimizations applied:**
- Descriptive naming (div7 → division-by-7)
- Purpose-first naming (language_dedup → text-deduplication-compressor)
- Full hierarchy preservation (symbolic-implementation/)

**INDEX features:**
- Topic-based navigation
- Keyword tagging
- Search pattern examples
- Cross-category references
- Quick navigation guides

---

## Notes for Future Execution

1. **Start with git status** - Understand what's tracked vs untracked
2. **Sample before bulk moves** - Read a few files to verify categorization
3. **Optimize names incrementally** - Don't try to perfect all names at once
4. **Preserve hierarchies** - If html-unsorted/ has subdirs with clear purpose, keep structure
5. **Create INDEX files last** - Once all files are placed, navigation becomes clearer
6. **Document as you go** - Note any unusual patterns or decisions for future reference

---

## Estimated Time

Based on perl-form/ reorganization:
- **Analysis:** 10-15 minutes (exploring structure, reading samples)
- **Planning:** 5-10 minutes (mapping files to categories)
- **Moving files:** 10-20 minutes (depends on file count)
- **Creating INDEX files:** 20-30 minutes (5 comprehensive indexes)
- **Verification:** 5-10 minutes (checking results)

**Total:** ~50-85 minutes for 20-30 files

Scale accordingly based on actual html-unsorted/ file count.

---

## Command Shortcuts

```bash
# Quick exploration
find html-unsorted -type f -name "*.html" | wc -l
ls -la html-unsorted/

# Check git status
git status --short html-unsorted/

# Sample file content
head -50 html-unsorted/sample.html

# Verify final state
find html-form -name "*.html" | wc -l
find html-form -name "INDEX.md"
ls html-unsorted/  # Should be empty

# Count by category
for dir in html-form/*/; do echo "$(basename "$dir"): $(find "$dir" -name "*.html" | wc -l) files"; done
```

---

**Ready to execute when html-unsorted/ is populated.**
**Reference this file to maintain consistency with perl-form/ organization.**
