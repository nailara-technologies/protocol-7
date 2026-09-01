## [:< ##

# name  = note.tag
# descr = add or remove tags on a note section

my ( $section, $tags_str, $task_id ) = @ARG;

return { 'mode' => qw| false |, 'data' => 'section required' }
    unless defined $section && length $section;

return { 'mode' => qw| false |, 'data' => 'tags required' }
    unless defined $tags_str && length $tags_str;

$task_id //= <system.task_id> // 'unknown';

## sanitize section name ##
$section =~ s|[^a-zA-Z0-9._-]|_|g;

## verify section exists ##
my $workspace_dir
    = <[file.zenka_dir.data_path]> . "/notes/$task_id/workspace";
return { 'mode' => qw| false |, 'data' => "section not found: $section" }
    unless -f "$workspace_dir/$section.md";

## parse and sanitize tags ##
my @tags = map { lc $ARG } split m|\s*,\s*|, $tags_str;
@tags = grep { $ARG =~ s|[^a-z0-9-]||g; length $ARG } @tags;

return {
    'mode' => qw| false |,
    'data' => 'no valid tags after sanitization'
    }
    unless @tags;

## update meta ##
my $meta_file = <[file.zenka_dir.data_path]> . "/notes/$task_id/.meta";
my $meta      = {};
if ( -f $meta_file ) {
    $meta = eval { JSON::PP::decode_json( <[file.read]>->($meta_file) ) };
    $meta = {} unless ref $meta eq qw| HASH |;
}

$meta->{'tags'} = {} unless ref $meta->{'tags'} eq qw| HASH |;
$meta->{'tags'}{$section} //= [];

## add tags avoiding duplicates ##
my %existing = map { $ARG => 1 } @{ $meta->{'tags'}{$section} };
my @added;
for my $tag (@tags) {
    unless ( $existing{$tag} ) {
        push @{ $meta->{'tags'}{$section} }, $tag;
        push @added,                         $tag;
    }
}

$meta->{'last_update'} = <[base.time]>->(3);
<[file.write]>->( $meta_file, JSON::PP::encode_json($meta) );

<[base.logs]>->(
    2, "note.tag: tagged '%s' with [%s] for %s",
    $section, join( ', ', @added ), $task_id
);

return {
    'mode' => qw| true |,
    'data' => {
        'section' => $section,
        'added'   => \@added,
        'all'     => $meta->{'tags'}{$section},
        'message' => "tagged '$section' with: " . join( ', ', @added ),
    }
};

#,,.,,..,,.,.,.,,,,,,,,,.,,,.,,..,,..,.,.,,..,.,.,...,..,,...,.,,,,,,,,,,,.,.,
#BQ5EHYISHAWPFPM2EG4RAAMM2IHI6TADJK56KIYVHFEECQEKPP4SIPLMNTX27HXKCRJL7NDLKEEOG
#\\\|CCBPF4Z736JMPA42FOTLX7SO6IFL732X5W2W2WYVVJP2MFIP6XZ \ / AMOS7 \ YOURUM ::
#\[7]5NFQB7KN74JGLNLJNJEFRHHRYMEGPLLS5CWJKL4TJHSTELUXVIDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
