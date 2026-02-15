## [:< ##

# name = coding.vision-parser.extraction.workflow
# descr = multi-stage extraction: vision→JSON→YAML→validate→refine

my $params = shift;

my $job_id        = $params->{'job_id'}      // '';
my $vision_text   = $params->{'vision_text'} // '';
my $context_label = 'extraction';

return {
    'success' => FALSE,
    'error'   => 'job_id required'
    }
    unless length($job_id);

return {
    'success' => FALSE,
    'error'   => 'vision_text required'
    }
    unless length($vision_text);

<models.conversations> //= {};

unless ( exists <models.conversations>->{$job_id} ) {
    return {
        'success' => FALSE,
        'error'   => "conversation not found: $job_id"
    };
}

my $start_time = <[base.time]>->(4);

## STAGE 1: Parse vision output into JSON (already done, stored in turn 1)
<[base.logs]>->(
    2, "[$context_label] STAGE 1: vision analysis complete (%d bytes)",
    length($vision_text)
);

## STAGE 2: Translate to YAML using LLM
## Template-based prompt with vision result substitution
my $yaml_prompt = <<'EOF';
Convert the following text analysis to valid YAML format.

Key requirements:
- Valid YAML syntax (no invalid quotes or special chars)
- Preserve all fields and information from the input
- Maintain data types where possible (strings, numbers, booleans)
- Use clear, hierarchical structure

Input text:
<{VISION_TEXT}>

Output YAML:
EOF

## Add YAML translation prompt to conversation
<[models.conversation.add_turn]>->(
    {   'job_id'  => $job_id,
        'role'    => 'system',
        'content' => 'Translate the vision analysis to YAML',
        'context' => $context_label
    }
);

<[base.logs]>->( 2, "[$context_label] STAGE 2 : queuing YAML translation" );

## STAGE 3: Validate YAML structure
## This would be done in Perl after LLM produces YAML
## Check for: valid YAML syntax, required fields, data completeness

## For now, return workflow structure for later phases
my $workflow = {
    'job_id'       => $job_id,
    'stage'        => 'yaml_translation',
    'vision_bytes' => length($vision_text),
    'next_step'    => 'queue_yaml_llm'
};

<[base.logs]>->(
    1, "[$context_label] workflow initialized: stage=%s",
    $workflow->{'stage'}
);

my $elapsed_ms = ( <[base.time]>->(4) - $start_time ) * 1000;

return {
    'success'    => TRUE,
    'job_id'     => $job_id,
    'work'       => $workflow,
    'elapsed_ms' => $elapsed_ms
};

#,,.,,.,,,,..,...,,.,,,..,,..,.,.,..,,,..,,,,,.,.,...,..,,...,,,,,,,,,,.,,.,.,
#N3GPHUSNLVS2X7FE5P75BQYE4YERZGSCXABHBDLJ3J2JPIVL4JKPHGHEFAXQWCRBUBILARSZZC5B4
#\\\|GD4FRCDRVDUCASLCCSEK222VU6UUOYQMZ3AEASTK2IBTTXT6LTY \ / AMOS7 \ YOURUM ::
#\[7]3CSXICVMK5OPQO3UK2H7LFX33ZOYEJR7DDT6ZWYSMADUNTIUYUCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
