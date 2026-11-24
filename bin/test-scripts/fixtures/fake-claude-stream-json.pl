#!/usr/bin/env perl
use v5.32;
use strict;
use warnings;
use English;
use JSON::PP;

## a fake `claude -p --input-format stream-json --output-format            ##
## stream-json` for test-claude-zenka.pl : speaks the wire format, runs no ##
## model. a turn 'crash' exits without a result, 'slow' waits for an       ##
## interrupt control_request, anything else is echoed with a tool call     ##

$OUTPUT_AUTOFLUSH = 1;
my $json = JSON::PP->new->utf8->canonical;
my ( $resume, $model ) = ( '', '' );
for ( my $i = 0; $i < @ARGV; $i++ ) {
    $resume = $ARGV[ $i + 1 ] if $ARGV[$i] eq '--resume';
    $model  = $ARGV[ $i + 1 ] if $ARGV[$i] eq '--model';
}
my $session = length $resume ? $resume : sprintf '%08x-0000-4000-8000-%012x',
    $PID, time;
my $cost = 0;
my $out  = sub { print $json->encode(shift), "\n" };

print STDERR "fake claude : args @ARGV\n";
$out->(
    {   'type'       => 'system',
        'subtype'    => 'init',
        'session_id' => $session,
        'model'      => length $model ? $model : 'fake'
    }
);
my $result = sub {
    my ( $subtype, $text, $error ) = @ARG;
    $cost += 0.0125;
    $out->(
        {   'type'           => 'result',
            'subtype'        => $subtype,
            'is_error'       => $error ? JSON::PP::true : JSON::PP::false,
            'result'         => $text,
            'session_id'     => $session,
            'total_cost_usd' => $cost
        }
    );
};
my $waiting_interrupt = 0;
while ( my $line = <STDIN> ) {
    my $m    = eval { $json->decode($line) } // next;
    my $type = $m->{'type'}                  // '';
    if ( $type eq 'control_request' ) {
        $out->(
            {   'type'     => 'control_response',
                'response' => {
                    'subtype'    => 'success',
                    'request_id' => $m->{'request_id'}
                }
            }
        );
        if ($waiting_interrupt) {
            $waiting_interrupt = 0;
            $result->( 'error_during_execution', 'interrupted', 1 );
        }
        next;
    }
    next if $type ne 'user';
    my $content = $m->{'message'}{'content'};
    my $text
        = ref $content eq 'ARRAY'
        ? join( ' ', map { $_->{'text'} // '' } @{$content} )
        : $content // '';
    exit 3 if $text eq 'crash';
    if ( $text eq 'spawn' ) {    ## a grandchild, like a tool process ##
        my $kid = fork;
        if ( defined $kid and $kid == 0 ) {
            open STDIN,  '<', '/dev/null';
            open STDOUT, '>', '/dev/null';
            open STDERR, '>', '/dev/null';
            exec 'sleep', '300';
        }
        $text = "spawned $kid";
    }
    $out->(
        {   'type'       => 'assistant',
            'session_id' => $session,
            'message'    => {
                'role'    => 'assistant',
                'content' => [
                    {   'type' => 'text',
                        'text' => "echo : $text"
                    }
                ]
            }
        }
    );
    if ( $text eq 'slow' ) {
        $waiting_interrupt = 1;
        next;
    }
    $out->(
        {   'type'    => 'assistant',
            'message' => {
                'role'    => 'assistant',
                'content' => [
                    {   'type'  => 'tool_use',
                        'name'  => 'Read',
                        'input' => { 'file_path' => '/tmp/x' }
                    }
                ]
            }
        }
    );
    $out->(
        {   'type'    => 'user',
            'message' => {
                'role'    => 'user',
                'content' =>
                    [ { 'type' => 'tool_result', 'content' => 'file body' } ]
            }
        }
    );
    $result->( 'success', "done : $text", 0 );
}
exit 0;

#,,.,,,.,,.,.,,..,,..,,.,,,..,.,.,.,.,.,.,,,.,..,,...,...,,,.,,,.,,,,,...,.,.,
#72CICZME74CHEL5ZA2PRQ6CSWW3TJAZUZGVOHOYGXKMFZHFPITEZOKECMYBWJTDCODB6F67LHWSSY
#\\\|PWSFE7USJYF3SVEKQZAPXPMCJ2ZN47O6ENROJ2UKXADZHZP354C \ / AMOS7 \ YOURUM ::
#\[7]BNMAN4NI2KARRUGP7OCCCSTMSQJXAGVSBYF2ZZRNHJ7737GF5EDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
