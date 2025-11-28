package HTTPSD::ScanContentDirectories;
use v5.24;
use strict;
use warnings;
use File::Spec;
use File::Find;
use Carp qw(carp);

=head1 NAME

HTTPSD::ScanContentDirectories - Scan /data/web and /var/httpd for templates

=head1 SYNOPSIS

    my $content = scan_content_directories('/data/web');
    # Returns: {
    #   '/page.html' => { 
    #       path => '/data/web/page.html',
    #       template => '/data/web/_templates/page.html',
    #       is_template => 1,
    #       mtime => 1234567890,
    #   },
    #   '/blog/post.html' => { ... },
    # }

=cut

=head2 scan_content_directories($base_dir)

Recursively scan directory for content files and associated templates.

Parameters:
  $base_dir - Base directory (default: /data/web)

Returns:
  Hashref mapping request paths to metadata

=cut

sub scan_content_directories {
    my ($base_dir) = @_;
    $base_dir //= '/data/web';
    
    return {} unless -d $base_dir;
    
    my %content = ();
    
    # Find all files in base directory
    File::Find::find({
        wanted => sub {
            return if -d $_;
            return if -l $_;  # Skip symlinks
            
            my $file = $_;
            my $full_path = $File::Find::name;
            
            # Calculate relative path from base_dir
            my $rel_path = File::Spec->abs2rel($full_path, $base_dir);
            
            # Skip template directories themselves
            return if $rel_path =~ m{/_templates/};
            
            # Skip hidden files
            return if $rel_path =~ m{(?:^|/)\.};
            
            # Skip common non-content files
            return if $rel_path =~ m{\.(?:swp|tmp|bak)$};
            
            # Store content metadata
            my $request_path = '/' . $rel_path;
            
            # Check if template exists
            my $template_path = _find_template_for_file($base_dir, $rel_path);
            
            $content{$request_path} = {
                path => $full_path,
                template => $template_path,
                is_template => defined $template_path ? 1 : 0,
                mtime => (stat($full_path))[9],
                size => -s $full_path,
            };
        },
        no_chdir => 1,
    }, $base_dir);
    
    return \%content;
}

=head2 find_template_for_path($request_path, $base_dir)

Find template file for a given request path.

Parameters:
  $request_path - Request path (e.g., /page.html)
  $base_dir - Base directory (default: /data/web)

Returns:
  Template path or undef if not found

=cut

sub find_template_for_path {
    my ($request_path, $base_dir) = @_;
    $base_dir //= '/data/web';
    
    # Remove leading slash
    my $rel_path = $request_path;
    $rel_path =~ s{^/}{};
    
    return _find_template_for_file($base_dir, $rel_path);
}

=head2 get_content_by_type($base_dir, $type)

Get all content files of a specific type.

Parameters:
  $base_dir - Base directory
  $type - File extension or type (e.g., 'html', 'md')

Returns:
  Hashref of matching content

=cut

sub get_content_by_type {
    my ($base_dir, $type) = @_;
    $base_dir //= '/data/web';
    
    my $content = scan_content_directories($base_dir);
    my %filtered = ();
    
    my $pattern = qr/\.\Q$type\E$/;
    foreach my $path (keys %$content) {
        if ($path =~ $pattern) {
            $filtered{$path} = $content->{$path};
        }
    }
    
    return \%filtered;
}

# Private: Find template file associated with content file
sub _find_template_for_file {
    my ($base_dir, $rel_path) = @_;
    
    # Split path into directory and filename
    my ($volume, $dirs, $file) = File::Spec->splitpath($rel_path);
    
    # Build template path: dir/_templates/file
    my $template_dir = File::Spec->catdir($dirs, '_templates') if $dirs;
    $template_dir //= '_templates';
    
    my $template_rel = File::Spec->catfile($template_dir, $file);
    my $template_full = File::Spec->catfile($base_dir, $template_rel);
    
    # Return template path if it exists
    return $template_full if -f $template_full;
    return undef;
}

1;

__END__

=head1 INTEGRATION

Use with httpd.request_handler:

    use HTTPSD::ScanContentDirectories;
    
    my $content = scan_content_directories('/data/web');
    if ($content->{$request_path}{is_template}) {
        # Route to template processor
    } else {
        # Serve static file
    }

=head1 EXAMPLES

Scan /data/web and list all content with templates:

    my $content = scan_content_directories('/data/web');
    foreach my $path (sort keys %$content) {
        if ($content->{$path}{is_template}) {
            print "$path -> " . $content->{$path}{template} . "\n";
        }
    }

Find only HTML files with templates:

    my $html = get_content_by_type('/data/web', 'html');
    foreach my $path (sort keys %$html) {
        print "$path\n" if $html->{$path}{is_template};
    }

Check if specific request has template:

    my $template = find_template_for_path('/docs/guide.html', '/data/web');
    if ($template) {
        print "Template found: $template\n";
    }

=cut
