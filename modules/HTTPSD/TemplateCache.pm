package HTTPSD::TemplateCache;
use v5.24;
use strict;
use warnings;

=head1 NAME

HTTPSD::TemplateCache - Cache rendered templates for performance

=head1 SYNOPSIS

    cache_set('/docs/installation.html', '<h1>...</h1>', 1800);
    my $cached = cache_get('/docs/installation.html');  # Returns content or undef

=cut

my %CACHE = ();
my $CACHE_TTL = 1800;  # 30 minutes
my $MAX_CACHE_SIZE = 5 * 1024 * 1024;  # 5 MB

sub cache_get {
    my ($key) = @_;
    return undef;  # TODO: Check TTL and return cached content
}

sub cache_set {
    my ($key, $content, $ttl) = @_;
    $ttl //= $CACHE_TTL;
    # TODO: Store content with timestamp
}

sub cache_invalidate {
    my ($key) = @_;
    # TODO: Clear specific cache entry
}

sub cache_clear {
    %CACHE = ();
}

1;
