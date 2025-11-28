package HTTPSD::RouteTemplateRequest;
use v5.24;
use strict;
use warnings;

=head1 NAME

HTTPSD::RouteTemplateRequest - Route HTTP requests to template processor

=head1 SYNOPSIS

    my $route = route_template_request('/docs/installation.html');
    # Returns: { type => 'template', template_path => '...', ... }

=cut

sub route_template_request {
    my ($request_path) = @_;
    
    # Determine if this request should be routed to template processor
    # Returns hashref with routing decision
    
    my $route = {
        type => 'static',  # or 'template', 'acme_challenge', 'skip'
        path => $request_path,
    };
    
    return $route;  # TODO: Implement routing logic
}

1;
