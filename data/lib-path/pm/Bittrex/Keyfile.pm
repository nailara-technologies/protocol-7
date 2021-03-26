package Bittrex::Keyfile;

=encoding utf8

=head1 NAME

Bittrex::Keyfile - utility module for handling a keyfile

=head1 SYNOPSIS

  use Bittrex::Keyfile;

  my ($key, $secret) = Bittrex::Keyfile::load();

=cut

use FindBin;
use File::Spec;
use Config::Simple;

=head1 DESCRIPTION

This is primarily a utility module for the Bittrex API wrapper.

=head2 Methods

=over

=cut

################################################################################
=item B<load($keyfile)>

This method reads a user's API key and secret from a local keyfile.  The user
may specify a specific file to parse, or it will attempt to find a file called
C<apikey.cfg> in the same folder as the runnign script.

The keyfile is parsed using C<Config::Simple> and expects top-level parameters
named C<key> and C<secret>.  For example:

  key=MY_API_KEY
  secret=MY_SECRET

On success, returns a tuple containing the key and secret found the keyfile.

=cut

# TODO add support for environment variables (e.g. BITTREX_KEYFILE)

#---------------------------------------
sub load {
  my $keyfile = shift;

  # if not supplied by the user, look where the script is running
  unless (defined $keyfile) {
    my $local = File::Spec->catfile($FindBin::Bin, 'apikey.cfg');
    $keyfile = $local if -f $local;
  }

  return undef unless -f $keyfile;

  my $cfg = new Config::Simple($keyfile);
  return undef unless defined $cfg;

  my $key = $cfg->param('key');
  my $secret = $cfg->param('secret');

  return ($key, $secret);
}

1;  ## EOM

=back

=head1 COPYRIGHT

Copyright (c) 2017 Jason Heddings

Licensed under the terms of the L<MIT License|https://opensource.org/licenses/MIT>,
which is also included in the original L<source code|https://github.com/jheddings/bittrex>
of this project.

=cut
