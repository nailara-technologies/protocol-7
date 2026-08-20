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
my @tags = map { lc $ARG } split /\s*,\s*/, $tags_str;
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

#,,,,,,,,,,.,,,,.,,,,,.,.,,,,,,..,,,,,,.,,..,,.,.,...,...,,,,,.,.,,..,.,.,,..,
#SP4T5GKT3YJ3BK3PYOVNWIHREEJLAW7TQBLG4YX5YKDMSD2W2EHB3KW4CYKPLXDL53CMBMAVDICQY
#\\\|EHZVT3WUKSZYHK72NXJHVRKKBMQ2R42XIV55PEUWI6ZA4MGPY66 \ / AMOS7 \ YOURUM ::
#\[7]NGBDITU3WG3K2WBZNGMKDKDVFFYSMW4G4VHY5I64FKQQWQSKV6DQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
