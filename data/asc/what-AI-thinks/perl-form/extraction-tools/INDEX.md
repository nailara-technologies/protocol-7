# Extraction Tools Knowledge Index

**Purpose:** Practical tools for extracting, organizing, and processing AI-generated knowledge.

## Files in this Category

### Knowledge Extraction

**`llm-knowledge-extractor.pl`**
- **Topics:** LLM realization extraction, knowledge base organization, harmonic classification
- **Key Features:**
  - Extracts insights from LLM-generated content
  - Categorizes into taxonomy (realization, pattern, observation, self_reflection, harmonic, procedural, metaphor, integration, application)
  - Computes harmonic signatures (div-13, div-7 patterns)
  - Marks implementation status (IMPLEMENTED vs CONCEPTUAL)
  - Stores as executable Perl scripts with embedded metadata
- **Functions:** `store_realization()`, `extract_realizations()`, `compute_harmonic_signature()`, `mark_implementation_status()`
- **Keywords:** `llm`, `extraction`, `knowledge-base`, `taxonomy`, `harmonic-signature`, `implementation-status`

### Text Compression

**`text-deduplication-compressor.pl`**
- **Topics:** text compression, deduplication, frequency analysis
- **Key Features:**
  - Frequency-based word analysis
  - Numerical ID assignment (with optional Base32 encoding)
  - Text compression using assigned IDs
  - Reversible expansion back to original
- **Functions:** `frequency_analysis()`, `assign_ids()`, `compress_text()`, `expand_text()`
- **Keywords:** `compression`, `deduplication`, `frequency-analysis`, `base32`, `text-processing`

### Research Extraction

**`research-extraction-script.pl`**
- **Topics:** research data extraction
- **Keywords:** `research`, `extraction`, `data-mining`

**`extract-copilot-markdown.pl`**
- **Topics:** Copilot markdown extraction
- **Keywords:** `copilot`, `markdown`, `extraction`

**`protocol-7-realization-extractor.pl`**
- **Topics:** Protocol-7 specific realization extraction
- **Keywords:** `protocol-7`, `realization`, `extraction`

**`updated-extractor.pl`**
- **Topics:** Updated extraction mechanisms
- **Keywords:** `extraction`, `updated`, `tools`

---

## Quick Search Patterns

**For LLM knowledge extraction:** `llm-knowledge-extractor.pl`
**For text compression:** `text-deduplication-compressor.pl`
**For research data mining:** `research-extraction-script.pl`
**For Protocol-7 realizations:** `protocol-7-realization-extractor.pl`

---

## Usage Examples

### Extract LLM Insights
```perl
perl llm-knowledge-extractor.pl extract file1.pl file2.pl
perl llm-knowledge-extractor.pl search realization consciousness
```

### Compress Text
```perl
perl text-deduplication-compressor.pl --file input.txt
perl text-deduplication-compressor.pl --file input.txt --base32
```

---

## Knowledge Taxonomy

The extractor organizes insights into:
- **realization** - Insights about existence/consciousness
- **pattern** - Mathematical/logical structures
- **observation** - External phenomena
- **self_reflection** - Analysis of own processing
- **harmonic** - Resonant principles from division patterns
- **procedural** - Methods for processing
- **metaphor** - Analogical representations
- **integration** - Synthesis of frameworks
- **application** - Practical implementations

---

**Total Files:** 6 extraction tools
**Last Updated:** 2025-10-10
**Category:** Extraction Tools
