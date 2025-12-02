package HTTPSD::TemplateCache;
use v5.24;
use strict;
use warnings;
use Time::HiRes qw(time);
use Carp        qw(carp);

=head1 NAME

HTTPSD::TemplateCache - Cache rendered templates for performance

=head1 SYNOPSIS

    cache_set('/page.html', '<h1>Welcome</h1>', 1800);
    my $cached = cache_get('/page.html');
    # Returns content or undef if expired/not found

=cut

# Global cache state
my %CACHE          = ();                 # path => { content, mtime, size }
my $CACHE_TTL      = 1800;               # 30 minutes default
my $MAX_CACHE_SIZE = 5 * 1024 * 1024;    # 5 MB
my $CURRENT_SIZE   = 0;                  # Track total cache size

=head2 cache_get($key)

Retrieve cached content if not expired.

Parameters:
  $key - Cache key (usually request path)

Returns:
  Cached content or undef if not found or expired

=cut

sub cache_get {
    my ($key) = @_;

    return undef unless exists $CACHE{$key};

    my $entry = $CACHE{$key};

    # Check TTL
    my $now = time();
    if ( $now - $entry->{created} > $entry->{ttl} ) {

        # Entry expired, remove it
        _remove_cache_entry($key);
        return undef;
    }

    # Update access time for statistics
    $entry->{accessed} = $now;
    $entry->{hits}++;

    return $entry->{content};
}

=head2 cache_set($key, $content, $ttl)

Store content in cache with TTL.

Parameters:
  $key - Cache key (usually request path)
  $content - Content to cache
  $ttl - Time-to-live in seconds (default: 1800 = 30 min)

Returns:
  1 on success, 0 if content exceeds max cache size

=cut

sub cache_set {
    my ( $key, $content, $ttl ) = @_;

    $ttl //= $CACHE_TTL;

    # Check size
    my $content_size = length($content);
    if ( $content_size > $MAX_CACHE_SIZE ) {
        carp(
            "Cache entry too large: $key ($content_size bytes > $MAX_CACHE_SIZE)"
        );
        return FALSE;
    }

    # Remove existing entry if present (to update size correctly)
    if ( exists $CACHE{$key} ) {
        _remove_cache_entry($key);
    }

    # Add to cache
    $CACHE{$key} = {
        content  => $content,
        created  => time(),
        accessed => time(),
        mtime    => time(),
        ttl      => $ttl,
        size     => $content_size,
        hits     => 0,
    };

    $CURRENT_SIZE += $content_size;

    # Evict old entries if cache too large
    _evict_if_necessary();

    return TRUE;
}

=head2 cache_invalidate($key)

Remove specific cache entry.

Parameters:
  $key - Cache key to remove

Returns:
  1 if removed, 0 if not found

=cut

sub cache_invalidate {
    my ($key) = @_;

    return FALSE unless exists $CACHE{$key};

    _remove_cache_entry($key);
    return TRUE;
}

=head2 cache_clear()

Clear entire cache.

Returns:
  Number of entries cleared

=cut

sub cache_clear {
    my $count = scalar( keys %CACHE );
    %CACHE        = ();
    $CURRENT_SIZE = 0;
    return $count;
}

=head2 cache_stats()

Get cache statistics.

Returns:
  Hashref with cache metrics

=cut

sub cache_stats {
    my $total_hits    = 0;
    my $total_entries = scalar( keys %CACHE );
    my $oldest_entry  = time();
    my $newest_entry  = 0;

    foreach my $key ( keys %CACHE ) {
        my $entry = $CACHE{$key};
        $total_hits += $entry->{hits} // 0;
        $oldest_entry = $entry->{created}
            if $entry->{created} < $oldest_entry;
        $newest_entry = $entry->{accessed}
            if $entry->{accessed} > $newest_entry;
    }

    return {
        entries          => $total_entries,
        size_bytes       => $CURRENT_SIZE,
        size_mb          => sprintf( '%.2f', $CURRENT_SIZE / 1024 / 1024 ),
        max_size_mb      => sprintf( '%.2f', $MAX_CACHE_SIZE / 1024 / 1024 ),
        total_hits       => $total_hits,
        oldest_entry_age => time() - $oldest_entry,
        newest_entry_age => time() - $newest_entry,
    };
}

=head2 cache_cleanup()

Remove expired entries from cache.

Returns:
  Number of entries removed

=cut

sub cache_cleanup {
    my @expired_keys = ();
    my $now          = time();

    foreach my $key ( keys %CACHE ) {
        my $entry = $CACHE{$key};
        if ( $now - $entry->{created} > $entry->{ttl} ) {
            push @expired_keys, $key;
        }
    }

    foreach my $key (@expired_keys) {
        _remove_cache_entry($key);
    }

    return scalar(@expired_keys);
}

=head2 set_default_ttl($ttl)

Set default TTL for future cache_set calls.

Parameters:
  $ttl - Time-to-live in seconds

=cut

sub set_default_ttl {
    my ($ttl) = @_;
    $CACHE_TTL = $ttl if defined $ttl;
}

=head2 set_max_size($bytes)

Set maximum cache size.

Parameters:
  $bytes - Maximum cache size in bytes

=cut

sub set_max_size {
    my ($bytes) = @_;
    $MAX_CACHE_SIZE = $bytes if defined $bytes;
}

# Private: Remove cache entry and update size
sub _remove_cache_entry {
    my ($key) = @_;

    if ( exists $CACHE{$key} ) {
        $CURRENT_SIZE -= $CACHE{$key}{size};
        delete $CACHE{$key};
    }
}

# Private: Evict entries if cache exceeds max size
sub _evict_if_necessary {
    if ( $CURRENT_SIZE > $MAX_CACHE_SIZE ) {

        # Use LRU (Least Recently Used) eviction
        # Sort by access time, remove oldest accessed entries

        my @entries = sort { $CACHE{$a}{accessed} <=> $CACHE{$b}{accessed} }
            keys %CACHE;

        # Remove oldest entries until under size limit
        while ( $CURRENT_SIZE > $MAX_CACHE_SIZE && @entries ) {
            my $key = shift @entries;
            _remove_cache_entry($key);
        }
    }
}

1;

__END__

=head1 CONFIGURATION

Default settings can be customized:

    use HTTPSD::TemplateCache;
    
    set_default_ttl(3600);        # 1 hour
    set_max_size(10 * 1024 * 1024);  # 10 MB

=head1 INTEGRATION

Use with template processor:

    use HTTPSD::TemplateCache;
    
    # Check cache first
    my $cached = cache_get($request_path);
    if (defined $cached) {
        return $cached;  # Serve from cache
    }
    
    # Process template
    my $rendered = process_template($template_path);
    
    # Store in cache
    cache_set($request_path, $rendered, 1800);
    
    return $rendered;

Cleanup periodically:

    # In main loop or signal handler
    my $removed = cache_cleanup();
    print "Removed $removed expired entries\n" if $removed;

Monitor cache:

    my $stats = cache_stats();
    print "Cache: $stats->{entries} entries, $stats->{size_mb} MB\n";

=head1 CACHE EVICTION

When cache exceeds max size:
  1. Cleanup removes expired entries first
  2. If still over limit, LRU eviction removes least-recently-used entries
  3. Oldest accessed entries are removed first

This ensures: Always room for new cache entries without manual cleanup

=head1 EXAMPLES

Simple caching:

    cache_set('/docs/guide.html', '<h1>Guide</h1>');
    my $content = cache_get('/docs/guide.html');

Cache with custom TTL:

    # Cache for 1 hour
    cache_set('/homepage.html', $rendered_html, 3600);

Invalidate on content update:

    # When template is modified
    cache_invalidate('/docs/guide.html');

Monitor cache health:

    my $stats = cache_stats();
    printf("Cache: %d entries, %.2f MB / %.2f MB\n",
        $stats->{entries},
        $stats->{size_mb},
        $stats->{max_size_mb}
    );

=cut
