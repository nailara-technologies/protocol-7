package HTTPSD::RouteTemplateRequest;
use v5.24;
use strict;
use warnings;
use Carp qw(carp);

=head1 NAME

HTTPSD::RouteTemplateRequest - Route HTTP requests to template processor or static handler

=head1 SYNOPSIS

    my $route = route_template_request('/docs/installation.html', $content_metadata);
    # Returns: { 
    #   type => 'template',      # or 'static', 'acme_challenge', 'api', 'skip'
    #   path => '/docs/installation.html',
    #   template_path => '...',  # if type == 'template'
    #   reason => 'has_template',
    # }

=cut

=head2 route_template_request($request_path, $content_metadata)

Determine routing for HTTP request.

Parameters:
  $request_path - Request path (e.g., /page.html)
  $content_metadata - Metadata from ScanContentDirectories (optional)

Returns:
  Hashref with routing decision:
    type: 'template' | 'static' | 'acme_challenge' | 'api' | 'skip'
    path: Request path
    template_path: (if type == 'template')
    reason: Why this routing was chosen

=cut

sub route_template_request {
    my ( $request_path, $content_metadata ) = @_;

    # Normalize request path
    $request_path = _normalize_path($request_path);

    # Default routing decision
    my $route = {
        type   => 'static',
        path   => $request_path,
        reason => 'unknown',
    };

    # ACME challenge requests: always bypass
    if ( _is_acme_challenge($request_path) ) {
        return {
            type   => 'acme_challenge',
            path   => $request_path,
            reason => 'acme_challenge_path',
        };
    }

    # API requests: skip template processing
    if ( _is_api_request($request_path) ) {
        return {
            type   => 'api',
            path   => $request_path,
            reason => 'api_endpoint',
        };
    }

    # Static assets: always serve as static
    if ( _is_static_asset($request_path) ) {
        return {
            type   => 'static',
            path   => $request_path,
            reason => 'static_asset',
        };
    }

    # Content with template: route to processor
    if ( $content_metadata && ref $content_metadata eq 'HASH' ) {
        if ( $content_metadata->{is_template} ) {
            return {
                type          => 'template',
                path          => $request_path,
                template_path => $content_metadata->{template},
                reason        => 'has_template',
            };
        }
    }

    # Default: serve as static
    return {
        type   => 'static',
        path   => $request_path,
        reason => 'no_template_found',
    };
}

=head2 route_batch($request_paths, $content_map)

Route multiple requests efficiently.

Parameters:
  $request_paths - Arrayref of request paths
  $content_map - Hashref from scan_content_directories

Returns:
  Hashref mapping paths to routing decisions

=cut

sub route_batch {
    my ( $request_paths, $content_map ) = @_;

    my %routes = ();

    foreach my $path (@$request_paths) {
        my $metadata = $content_map->{$path};
        $routes{$path} = route_template_request( $path, $metadata );
    }

    return \%routes;
}

# Private: Normalize request path
sub _normalize_path {
    my ($path) = @_;

    # Ensure leading slash
    $path = '/' . $path unless $path =~ m{^/};

    # Remove query string
    $path =~ s{\?.*$}{};

    # Remove fragment
    $path =~ s{#.*$}{};

    # Normalize multiple slashes
    $path =~ s{//+}{/}g;

    # Remove trailing slash (except root)
    $path =~ s{/$}{} unless $path eq '/';

    return $path;
}

# Private: Check if path is ACME challenge
sub _is_acme_challenge {
    my ($path) = @_;

    # ACME challenges are always at this path
    return TRUE if $path =~ m{^/\.well-known/acme-challenge/};

    return FALSE;
}

# Private: Check if path is API request
sub _is_api_request {
    my ($path) = @_;

    # Common API paths (can be configured)
    return TRUE if $path =~ m{^/api/};
    return TRUE if $path =~ m{^/api$};
    return TRUE if $path =~ m{^/webhook/};
    return TRUE if $path =~ m{^/rest/};

    return FALSE;
}

# Private: Check if path is static asset
sub _is_static_asset {
    my ($path) = @_;

    # Common static file extensions
    return TRUE if $path =~ m{\.(
        css|js|png|jpg|jpeg|gif|svg|ico|
        woff|woff2|ttf|otf|eot|
        mp3|mp4|webm|ogg|webp|
        pdf|zip|tar|gz|7z|
        txt|xml|json|yaml|yml
    )$}ix;

    # Static directories
    return TRUE
        if $path =~ m{^/(?:static|assets|public|img|images|css|js|fonts)/};

    return FALSE;
}

1;

__END__

=head1 ROUTING LOGIC

The router makes routing decisions in this order:

1. ACME Challenge Routes
   - Path: /.well-known/acme-challenge/*
   - Type: acme_challenge
   - Reason: Critical for certificate issuance, must not be processed

2. API Routes
   - Paths: /api/*, /webhook/*, /rest/*
   - Type: api
   - Reason: API endpoints should not go through template processor

3. Static Assets
   - Extensions: .css, .js, .png, .jpg, .svg, .pdf, etc.
   - Directories: /static/, /assets/, /public/, /css/, /js|, |fonts|
   - Type: static
   - Reason: No template processing needed for binary/static content

4. Content with Templates
   - Has template in _templates/filename
   - Type: template
   - Reason: Process through template engine

5. Default (Fallback)
   - Type: static
   - Reason: Serve as-is

=head1 INTEGRATION

Use with httpd.request_handler:

    use HTTPSD::ScanContentDirectories;
    use HTTPSD::RouteTemplateRequest;
    
    my $content = scan_content_directories('/data/web');
    my $route = route_template_request($request_path, $content->{$request_path});
    
    given ($route->{type}) {
        when ('template') {
            # Call template processor
            process_template($route->{template_path});
        }
        when ('acme_challenge') {
            # Handle ACME challenge
            serve_acme_challenge($request_path);
        }
        when ('api') {
            # Route to API handler
            handle_api_request($request_path);
        }
        when ('static') {
            # Serve static file
            serve_static_file($request_path);
        }
    }

=head1 EXAMPLES

Simple routing:

    my $route = route_template_request('/page.html');
    print "Route type: " . $route->{type} . "\n";

Routing with content metadata:

    my $content = scan_content_directories('/data/web');
    my $metadata = $content->{'/docs/guide.html'};
    my $route = route_template_request('/docs/guide.html', $metadata);
    
    if ($route->{type} eq 'template') {
        print "Process template: " . $route->{template_path} . "\n";
    }

Batch routing:

    my $routes = route_batch(
        ['/page.html', '/api/users', '/static/style.css'],
        $content
    );
    
    foreach my $path (keys %$routes) {
        print "$path -> " . $routes->{$path}{type} . "\n";
    }

=cut
