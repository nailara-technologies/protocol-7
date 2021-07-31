use strict;
use warnings;

package Devel::REPL::Plugin::CompletionDriver::Turtles;

# ABSTRACT: Complete Turtles-based commands

our $VERSION = '1.003028';

use Devel::REPL::Plugin;
use Devel::REPL::Plugin::Completion;    # die early if cannot load
use namespace::autoclean;

sub BEFORE_PLUGIN {
    my $self = shift;
    $self->load_plugin('Completion');
}

around complete => sub {
    my $orig = shift;
    my ( $self, $text, $document ) = @_;

    my $prefix  = $self->default_command_prefix;
    my $line_re = qr/^($prefix)(\w+)/;

    my @orig = $self->$orig( $text, $document );

    if ( my ( $pre, $method ) = ( $text =~ $line_re ) ) {
        my $filter = qr/^\Q$method/;
        return (
            @orig,
            (   map  {"$pre$_"}
                grep { $_ =~ $filter }
                map  { /^expr?_command_(\w+)/ ? $1 : () }
                map  { $_->name } $self->meta->get_all_methods
            ),
        );
    } else {
        return @orig;
    }
};

__PACKAGE__

__END__

=pod

=encoding UTF-8

=head1 NAME

Devel::REPL::Plugin::CompletionDriver::Turtles - Complete Turtles-based commands

=head1 VERSION

version 1.003028

=head1 SUPPORT

Bugs may be submitted through L<the RT bug tracker|https://rt.cpan.org/Public/Dist/Display.html?Name=Devel-REPL>
(or L<bug-Devel-REPL@rt.cpan.org|mailto:bug-Devel-REPL@rt.cpan.org>).

There is also an irc channel available for users of this distribution, at
L<C<#devel> on C<irc.perl.org>|irc://irc.perl.org/#devel-repl>.

=head1 AUTHOR

Yuval Kogman E<lt>nothingmuch@woobling.orgE<gt>

=head1 COPYRIGHT AND LICENCE

This software is copyright (c) 2007 by Matt S Trout - mst (at) shadowcatsystems.co.uk (L<http://www.shadowcatsystems.co.uk/>).

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

#,,.,,,..,,,,,...,,,,,,,,,.,,,..,,..,,.,.,,..,..,,...,..,,...,.,,,,,,,..,,,,.,
#ZBABDSHB5IJ3VL5MRUFEASI2XFCSBMXYSKS6FZIQSVQUYCSBSPONN3S66PQHH5A7WGNJNLGQR45BE
#\\\|Q6YNG45NOTYRSAXVHXHJGCRD4C3UCS3AQL3BIK6BXW7TRAC6AMR \ / AMOS7 \ YOURUM ::
#\[7]VKY76TK3PLZWK2E5G3TTC66YN2UTJ5ERW74EXMKGPESDTR3NK6BY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
