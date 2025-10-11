use strict;

use warnings;

use Digest::BMW;

sub bmw_checksum_with_resume {

    my ( $file, $start_checksum, $start_position ) = @_;

    # Validate inputs

    die "File not specified" unless $file;

    die "File does not exist: $file" unless -e $file;

    die "Start position required with start checksum"

        if defined($start_checksum) && !defined($start_position);

    # Initialize checksum object

    my $bmw = Digest::BMW->new();

    $bmw->add_bits($start_checksum) if defined($start_checksum);

    # Open and read file

    open( my $fh, '<', $file ) or die "Cannot open $file: $!";

    if ( defined($start_position) ) {

        seek( $fh, $start_position, 0 )

            or die "Cannot seek to position $start_position: $!";

    }

    while ( read( $fh, my $buffer, 8192 ) ) {

        $bmw->add($buffer);

    }

    close($fh);

    return $bmw->hexdigest();

}

1;
