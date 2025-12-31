# Protocol-7 Test Scripts

Test scripts for experimentation and validation. These are kept in version control (not /tmp/) to survive WSL crashes and support extracting working patterns into actual modules.

## Vision Parser Testing

### Direct Command Test
Test the vision parser with a simple command:

```bash
# Simple test call
p7 coding.vision-parser.analyze_and_extract /data/projects/protocol-7/data/gfx/backgrounds/3QJWKKGAVUNBCV27J3665ZMGRQDTVTFET6HTN4UT66BQCE2GELTQ.png

# With custom prompts
p7 "coding.vision-parser.analyze_and_extract" -m param \
  image_path="/path/to/image.jpg" \
  vision_prompt="Analyze this image for code/UI elements" \
  extraction_prompt="Extract structured JSON"
```

**Note**: The vision-parser uses **deferred callbacks**, so:
- Initial call returns immediately with "deferred" status
- Actual result arrives asynchronously via callback handler
- Results are stored in `coding.vision-parser.jobs` registry

### Checking Job Status
After triggering analysis, check the job registry:

```bash
# List all jobs and their status
p7 coding.eval-code '<coding.vision-parser.jobs>'

# Check specific job (if you know the job ID)
p7 coding.eval-code 'my $jobs = <coding.vision-parser.jobs>; $jobs->{job_id_here}'

# Get completed results
p7 coding.eval-code 'foreach (values %{<coding.vision-parser.jobs>}) { print $_->{extraction_result} if $_->{extraction_result} }'
```

### Synchronous Test Wrapper (WIP)
The `test-vision-parser.pl` script provides a synchronous interface by:
1. Triggering the async analysis
2. Polling the job registry for completion
3. Returning results when ready

**Status**: Still being refined due to shell escaping complexity

### Expected Output
The vision model outputs JSON with potential formatting issues:
- Spurious spaces in JSON strings: `{ "field" : "val ue" }`
- Newlines in quoted strings from response streaming
- These will be fixed by the extraction normalization stage

## Future Test Scripts

As new features are added, create tests here first, then extract the working pattern into actual Protocol-7 modules.

## Guidelines

- Keep scripts focused and single-purpose
- Document usage examples
- Note any known limitations
- Scripts can be removed once patterns are integrated into modules
- Use absolute paths for file references
