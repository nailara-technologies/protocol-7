## [:< ##

package AMOS7::N7FS::Convert;    ############################################

## N7FS version 1 : store format conversion [ spec section 6 ].
##
## one STEP per version [ from -> from + 1 ], chained for older stores. an
## upgrade reads every node in the old form and writes the new form BESIDE it
## under the NEXT epoch of the {previous, current, next} window [
## data/tasks/epoch-validity-search-protocol.md + src/base.ntime.epoch_dec :
## prev = current - 1, next = current + 1, wrapping at 0 \ 385280 ] -- the
## current epoch may hold data, that is the point of the window. `-epoch`
## stays as a test override. only then the state switches : it names the new
## format + epoch and keeps the old one as 'previous'.
##
## after a CONFIRMED switch the old form stays readable while its epoch is the
## window's previous ; a later upgrade \ confirm, once the window moved,
## releases it [ the directory removed, the state forgets 'previous' ] --
## while it is still in the window the next upgrade refuses.
##
## any failure before the switch removes the partial new epoch
## [ created by this run only ] and leaves the state on the old format.
##
## version 1 ships no step : the registry is the interface. a step needs the
## codec of its target format [ AMOS7::N7FS::Store::register_codec ].

use v5.32.0;
use utf8;
use strict;
use English;
use warnings;

##[ global constants ]##
use constant TRUE  => 5;    ##  TRUE.  ##
use constant FALSE => 0;    ##  false  ##

use Exporter;
use base qw| Exporter |;
use vars qw| @EXPORT_OK $VERSION %STEP |;

our $VERSION = qw| AMOS7::N7FS::Convert-VERSION.0000001 |;

@EXPORT_OK = qw|
    register_step
    steps
    upgrade
    confirm
    |;

use AMOS7::N7FS qw| ntime_now b32 random_bytes make_dirs publish_dir
    remove_tree refuse fault |;
use AMOS7::N7FS::Sum   qw| epoch_int epoch_b32 epoch_next epoch_window |;
use AMOS7::N7FS::Disk  qw| disk_require_attached state_read state_write |;
use AMOS7::N7FS::Store qw| codec store_nodes node_path write_epoch |;

## $transform->( $node, { from, to } ) returns the node for format $to
sub register_step {
    my ( $from, $transform ) = @ARG;
    refuse('step : bad source format') if ( $from // '' ) !~ m|\A\d{1,3}\z|;
    refuse( 'step %d : no transform', $from ) if ref $transform ne qw| CODE |;
    $STEP{$from} = { qw| to | => $from + 1, qw| transform | => $transform };
    return $STEP{$from};
}

## the chain from $from up to $to [ or as far as steps reach ]
sub steps {
    my ( $from, $to ) = @ARG;
    my @chain;
    my $at = $from;
    while ( exists $STEP{$at} and ( not defined $to or $at < $to ) ) {
        push @chain, { qw| from | => $at, $STEP{$at}->%* };
        $at = $STEP{$at}{'to'};
    }
    refuse( 'no converter chain from format %d to %d', $from, $to )
        if defined $to and $at != $to;
    return @chain;
}

## $refuse_pending : an upgrade may not run while the old form is still in the
## window [ one previous at a time ]. the window is centered on the CURRENT
## epoch [ the clock -- epoch_dec ], not on the write epoch [ write_epoch is
## never older than the active epochs, which would push the old form out of
## the window at the switch already ]. returns the state, released or not
sub _window_release {
    my ( $id, $state, $refuse_pending ) = @ARG;
    return $state
        if ref $state->{'previous'} ne qw| HASH |
        or not $state->{'confirmed'};
    my %window = map { $ARG => 1 } epoch_window( epoch_int( ntime_now() ) );
    my @gone = grep  { not $window{$ARG} } $state->{'previous'}{'epochs'}->@*;
    if ( not @gone ) {
        refuse(
            'format %d is still in the window [ released '
                . 'when it leaves -- then upgrade again ]',
            $state->{'previous'}{'store_format'}
        ) if $refuse_pending;
        return $state;
    }
    remove_tree( "$id->{'path'}/" . epoch_b32($ARG) ) for @gone;
    my %next = %{$state};
    delete $next{'previous'};
    state_write( $id->{'path'}, \%next );
    return \%next;
}

## %opt : disk, root, host_dir, host, target
## [ format, default : as far as the registered steps reach ], epoch
## [ a test override ; default : next of the window ]
sub upgrade {
    my %opt   = @ARG;
    my $id    = disk_require_attached(%opt);
    my $state = state_read( $id->{'path'} );
    my $from  = $state->{'store_format'};

    refuse( 'a previous upgrade [ format %d ] awaits confirm',
        $state->{'previous'}{'store_format'} )
        if ref $state->{'previous'} eq qw| HASH |
        and not $state->{'confirmed'};

    ## a confirmed previous : release it once it leaves the window ##
    $state = _window_release( $id, $state, TRUE );

    my @chain = steps( $from, $opt{'target'} );
    return { qw| from | => $from, qw| to | => $from, qw| nodes | => 0 }
        if not @chain;
    my $to = $chain[-1]{'to'};

    my $old = codec($from);
    my $new = codec($to);

    ## the target epoch : NEXT of the window ; -epoch overrides [ tests ] ##
    my $epoch = $opt{'epoch'} // epoch_next( write_epoch($state) );
    refuse( 'epoch %s out of range', $epoch ) if $epoch !~ m|\A\d{1,6}\z|;
    refuse( 'epoch %d belongs to this store already', $epoch )
        if grep { $ARG == $epoch } $state->{'epochs'}->@*;
    my $edir = "$id->{'path'}/" . epoch_b32($epoch);
    refuse( 'epoch directory %s exists', $edir ) if -e $edir or -l $edir;

    ## preflight : every old node verifies and reads before any write ##
    my @nodes = store_nodes( $id->{'path'}, $state->{'epochs'}->@* );
    my @read;
    foreach my $n (@nodes) {
        $old->{'verify_node'}->( $n->{'path'}, $n );
        push @read, [ $n, $old->{'read_node'}->( $n->{'path'} ) ];
    }

    ## write beside ##
    my $ok = eval {
        make_dirs( $edir, 0700 );
        foreach my $pair (@read) {
            my ( $n, $node ) = @{$pair};
            $node->{'addr'} = {
                qw| epoch | => $epoch,
                qw| amos |  => $n->{'amos'},
                qw| bmw |   => $n->{'bmw'},
            };
            foreach my $step (@chain) {
                $node = $step->{'transform'}->(
                    $node,
                    {   qw| from | => $step->{'from'},
                        qw| to |   => $step->{'to'}
                    }
                );
                refuse( 'step %d : no node returned', $step->{'from'} )
                    if ref $node ne qw| HASH |;
            }
            my $final = node_path( $id->{'path'}, $node->{'addr'} );
            make_dirs( $final =~ s|/[^/]+\z||r, 0700 );
            my $tmp = sprintf qw| %s.tmp.%s |, $final, b32( random_bytes(5) );
            make_dirs( $tmp, 0700 );
            $new->{'write_node'}->( $tmp, $node );
            publish_dir( $tmp, $final );
            fault(qw| convert:after-node |);
            $new->{'verify_node'}->( $final, $node->{'addr'} );
        }

        ## verify the whole new epoch once more, by listing it ##
        my @written = store_nodes( $id->{'path'}, $epoch );
        refuse( 'converted %d of %d nodes', scalar @written, scalar @nodes )
            if @written != @nodes;
        $new->{'verify_node'}->( $ARG->{'path'}, $ARG ) for @written;
        fault(qw| convert:before-switch |);
        1;
    };
    if ( not $ok ) {
        my $err = $EVAL_ERROR;
        remove_tree($edir);
        die $err;
    }

    ## the switch : one new state record ##
    my %next = %{$state};
    %next = (
        %next,
        qw| store_format | => $to,
        qw| epochs |       => [$epoch],
        qw| previous |     => {
            qw| store_format | => $from,
            qw| epochs |       => $state->{'epochs'},
        },
        qw| confirmed | => FALSE,
        qw| converted | => "$from->$to",
    );
    state_write( $id->{'path'}, \%next );

    return {
        qw| from |  => $from,
        qw| to |    => $to,
        qw| epoch | => $epoch,
        qw| nodes | => scalar @nodes,
    };
}

## the new form verified again ; the old form released once it leaves the
## window [ _window_release ]
sub confirm {
    my %opt   = @ARG;
    my $id    = disk_require_attached(%opt);
    my $state = state_read( $id->{'path'} );
    $state = _window_release( $id, $state, FALSE );
    refuse('nothing to confirm')
        if ref $state->{'previous'} ne qw| HASH |
        or $state->{'confirmed'};

    my $codec = codec( $state->{'store_format'} );
    my @nodes = store_nodes( $id->{'path'}, $state->{'epochs'}->@* );
    $codec->{'verify_node'}->( $ARG->{'path'}, $ARG ) for @nodes;

    state_write( $id->{'path'}, { %{$state}, qw| confirmed | => TRUE } );
    return {
        qw| nodes |  => scalar @nodes,
        qw| format | => $state->{'store_format'}
    };
}

1;

#,,,.,,..,...,...,..,,..,,,,.,.,.,,..,,,.,,,,,..,,...,...,...,...,...,.,,,..,,
#IBRAVJVAOEQVXXS2AUWKXFHVN24QRQR6C335TO643NAUM2RGHB7FQKG7JZU6FALHQHQ7LCEN3OTNU
#\\\|4GO6SLFT325IBBAUC7UBA4DHSG3JPX4JNOWY6SAQBCRJXSLEOTD \ / AMOS7 \ YOURUM ::
#\[7]P4USHPAR2U5SI6JZOXRY2FC5SMTGFCAFL4CVUF7L7OTUHJRLSOCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
