#!/usr/bin/perl
use v5.32.0;
use strict;
use warnings;
use English;
use FindBin;
use Cwd      ();
use JSON::PP ();

## the shared stream-json formatter [ AMOS7::Claude::Stream ] against the ##
## frozen copy of the old bin/mcp-server-p7 formatter, on recorded shapes ##

my $root = Cwd::abs_path("$FindBin::RealBin/../..");
use lib "$FindBin::RealBin/../../data/lib-path/pm";
require AMOS7::Claude::Stream;

my $json = JSON::PP->new->utf8->canonical;
my ( $ok, $n ) = ( 0, 0 );

sub check {
    my ( $label, $cond ) = @ARG;
    $n++;
    $ok++ if $cond;
    say( ( $cond ? 'ok' : 'NOT ok' ) . " $n : $label" );
}

## the old mcp formatter, kept verbatim as the reference ##
sub old_events {
    my $line  = shift;
    my $short = sub {
        my ( $text, $max ) = @ARG;
        $text //= '';
        $text =~ s|\s*\n\s*| / |g;
        return length $text > $max ? substr( $text, 0, $max ) . ' ..' : $text;
    };
    my $d = $line =~ m|^\{| ? eval { $json->decode($line) } : undef;
    return "out : $line" if ref $d ne qw| HASH |;

    my $type = $d->{'type'} // '';
    if ( $type eq 'system' ) {
        return sprintf 'init : session %s model %s',
            $d->{'session_id'} // '-', $d->{'model'} // '-'
            if ( $d->{'subtype'} // '' ) eq 'init';
        return 'system : ' . ( $d->{'subtype'} // '' );
    }
    if ( $type eq 'result' ) {
        return sprintf 'final : %s%s : %s', $d->{'subtype'} // '',
            defined $d->{'total_cost_usd'}
            ? sprintf( ' [ %.2f usd ]', $d->{'total_cost_usd'} )
            : '',
            $short->( $d->{'result'}, 400 );
    }
    my @out;
    foreach my $block ( @{ $d->{'message'}{'content'} // [] } ) {
        next if ref $block ne qw| HASH |;
        my $bt = $block->{'type'} // '';
        if ( $bt eq 'text' ) {
            push @out, 'text : ' . $short->( $block->{'text'}, 400 );
        } elsif ( $bt eq 'tool_use' ) {
            push @out, sprintf 'tool : %s %s', $block->{'name'} // '',
                $short->( $json->encode( $block->{'input'} // {} ), 200 );
        } elsif ( $bt eq 'tool_result' ) {
            my $c = $block->{'content'};
            $c = join ' ',
                map { ref $ARG ? $ARG->{'text'} // '' : $ARG } @{$c}
                if ref $c eq qw| ARRAY |;
            push @out, sprintf 'result%s : %s',
                $block->{'is_error'} ? ' [ error ]' : '',
                $short->( $c, 200 );
        }
    }
    return @out;
}

## the mcp-side call, as bin/mcp-server-p7 makes it ##
sub new_events {
    my $line = shift;
    my $d    = $line =~ m|^\{| ? eval { $json->decode($line) } : undef;
    return "out : $line" if ref $d ne qw| HASH |;
    return AMOS7::Claude::Stream::describe(
        $d,
        'user_text' => 1,
        'input'     => sub { $json->encode( $ARG[0] ) }
    );
}

open( my $fh, '<:encoding(UTF-8)',
    "$FindBin::RealBin/fixture" . "s/claude-stream-lines.txt" )
    or die "fixture : $OS_ERROR\n";
my @lines = map { chomp; $ARG } <$fh>;
close $fh;
my $total = 0;
foreach my $i ( 0 .. $#lines ) {
    my @old = old_events( $lines[$i] );
    my @new = new_events( $lines[$i] );
    $total += scalar @new;
    check(
        sprintf(
            'line %d : %d event line(s) identical', $i + 1, scalar @new
        ),
        join( "\n", @old ) eq join( "\n", @new )
    );
}
check( 'the fixture produced event lines', $total >= 12 );

## the zenka side : key=value tool input, no user text ##
my @z = AMOS7::Claude::Stream::describe(
    $json->decode(
              '{"type":"assistant","message":{"content":[{"type":"tool_use",'
            . '"name":"Read","input":{"file_path":"/tmp/x",'
            . '"limit":20}}]}}'
    )
);
check(
    'zenka form : tool input as key=value',
    "@z" eq 'tool : Read file_path=/tmp/x limit=20'
);
@z = AMOS7::Claude::Stream::describe(
    $json->decode(
              '{"type":"user","message":{"content":[{"type":"text",'
            . '"text":"echo"}]}}'
    )
);
check( 'zenka form : user text dropped', not @z );
@z
    = AMOS7::Claude::Stream::describe(
    $json->decode('{"type":"user","message":{"content":"plain string"}}'),
    'user_text' => 1 );
check( 'string content does not die', "@z" eq 'text : plain string' );

say "$ok of $n";
exit( $ok == $n ? 0 : 1 );

#,,..,.,.,,,,,,..,,.,,.,.,...,,.,,.,.,..,,..,,..,,...,...,,,,,,,,,..,,..,,...,
#WOCCLFNRWFLOX6OPXNDWESYWR73UXRC3RURUIH2BGKMRKGRAOKKJMDLBBWPOWD7BOF7WNHLEFSIAW
#\\\|5PZI7QOAXNAD2IXLMZUEVME5JZOXOOI5I4G74ISLBLL5C3LM7KT \ / AMOS7 \ YOURUM ::
#\[7]GM4FS2XQA7NQIFYL7NLJRWBPBMWFSMJHG2JWTVUG6LVB3S5VC2CA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
