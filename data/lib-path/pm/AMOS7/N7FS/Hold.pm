## [:< ##

package AMOS7::N7FS::Hold;    ###############################################

## receiver-signed journal holds : the named pre-change sequence stays
## restorable until its expiry or an explicit release.

use v5.32.0;
use utf8;
use strict;
use English;
use warnings;

use constant TRUE  => 5;
use constant FALSE => 0;

use Exporter;
use base qw| Exporter |;
use vars qw| @EXPORT_OK $VERSION |;

our $VERSION = qw| AMOS7::N7FS::Hold-VERSION.BEOU7FA |;

@EXPORT_OK = qw| hold_create hold_release hold_list hold_expire
    hold_records_verify hold_selector_seq |;

use AMOS7::N7FS       qw| ntime_now ntime14 refuse fault |;
use AMOS7::NTIME      qw| parse_y_age |;
use AMOS7::N7FS::Disk qw| disk_lock disk_read_id disk_require_attached
    state_read store_key_signer witness_note_format |;
use AMOS7::N7FS::Journal qw| journal_replay journal_write |;
use AMOS7::N7FS::Record  qw| record_write record_scan |;

sub _empty_set {
    return {
        qw| nodes |       => [],
        qw| meta |        => [],
        qw| references |  => [],
        qw| releases |    => [],
        qw| trees |       => [],
        qw| categories |  => [],
        qw| assignments | => [],
    };
}

sub hold_records {
    my $id = shift;
    return { map { $ARG->{'path'} => $ARG }
            record_scan( $id, qw| hold |, qw| holds |, qw| hold | ) };
}

sub hold_selector_seq {
    my ( $replay, $selector ) = @ARG;
    refuse('hold : a journal point is required') if not defined $selector;
    if ( $selector =~ m|\A\d+\z| ) {
        refuse( 'hold : journal sequence %d is beyond the head %d',
            $selector, $replay->{'seq'} )
            if $selector > $replay->{'seq'};
        return $selector + 0;
    }
    my @matches = grep {
               $ARG->{'path'} eq $selector
            or $ARG->{'path'} eq "$selector.hold"
            or index( $ARG->{'path'}, "$selector." ) == 0
    } values $replay->{'hold_history'}->%*;
    refuse( 'hold : no hold matches [ %s ]',   $selector ) if not @matches;
    refuse( 'hold : ambiguous hold id [ %s ]', $selector ) if @matches > 1;
    return $matches[0]{'seq'} + 0;
}

sub hold_create {
    my %opt   = @ARG;
    my $lock  = $opt{'_id'} ? undef : disk_lock( disk_read_id(%opt) );
    my $id    = $opt{'_id'}    // disk_require_attached(%opt);
    my $store = $opt{'_store'} // store_key_signer( %opt, qw| id | => $id );
    my $state = state_read( $id->{'path'}, $id->{'store_pub'} );
    refuse('hold is only available for store format 3')
        if $state->{'store_format'} != 3;
    my $replay = $opt{'_replay'} // journal_replay($id);
    my $seq    = $opt{'seq'}     // $replay->{'seq'};
    refuse( 'hold : sequence %d is beyond the journal head %d',
        $seq, $replay->{'seq'} )
        if $seq !~ m|\A\d+\z|
        or $seq > $replay->{'seq'};
    my $age = $opt{'hold_age'} // parse_y_age('1Y1');
    refuse('hold : age must be a nonnegative ntime duration')
        if $age !~ m|\A\d+\z|;
    my $record = record_write(
        $id, $store,
        qw| hold |,
        qw| holds |,
        qw| hold |,
        {   qw| disk |    => $id->{'disk'},
            qw| seq |     => $seq + 0,
            qw| reason |  => $opt{'reason'} // 'manual hold',
            qw| source |  => $opt{'source'},
            qw| expires | => sub { ntime14( $ARG[0] + $age ) },
        }
    );
    my $add = _empty_set();
    $add->{'holds'} = [
        {   map { $ARG => $record->{$ARG} }
                qw| path seq reason source ntime expires |
        }
    ];
    my $journal = journal_write( $id, $store, $add, _empty_set(), {} );
    witness_note_format(
        %opt,
        qw| id |          => $id,
        qw| state |       => $state,
        qw| journal_seq | => $journal->{'seq'}
    );
    return { %{$record}, qw| journal_seq | => $journal->{'seq'} };
}

sub hold_release {
    my %opt   = @ARG;
    my $lock  = $opt{'_id'} ? undef : disk_lock( disk_read_id(%opt) );
    my $id    = $opt{'_id'}    // disk_require_attached(%opt);
    my $store = $opt{'_store'} // store_key_signer( %opt, qw| id | => $id );
    my $state = state_read( $id->{'path'}, $id->{'store_pub'} );
    my $replay   = $opt{'_replay'} // journal_replay($id);
    my $selector = $opt{'name'}    // $opt{'id'}
        // refuse('hold-release needs a hold id');
    my @active = grep {
               $ARG->{'path'} eq $selector
            or $ARG->{'path'} eq "$selector.hold"
            or index( $ARG->{'path'}, "$selector." ) == 0
    } values $replay->{'holds'}->%*;
    refuse( 'hold-release : no live hold matches [ %s ]', $selector )
        if not @active;
    refuse( 'hold-release : ambiguous hold id [ %s ]', $selector )
        if @active > 1;
    my $drop = _empty_set();
    $drop->{'holds'} = [ { qw| path | => $active[0]{'path'} } ];
    my $journal = journal_write( $id, $store, _empty_set(), $drop, {} );
    witness_note_format(
        %opt,
        qw| id |          => $id,
        qw| state |       => $state,
        qw| journal_seq | => $journal->{'seq'}
    );
    return { %{ $active[0] }, qw| journal_seq | => $journal->{'seq'} };
}

sub hold_expire {
    my ( $id, $store, $state, $replay, $now ) = @ARG;
    my @expired
        = grep { $ARG->{'expires'} <= $now } values $replay->{'holds'}->%*;
    return { qw| expired | => [] } if not @expired;
    my $drop = _empty_set();
    $drop->{'holds'} = [
        map {
            { qw| path | => $ARG->{'path'} }
        } @expired
    ];
    my $journal = journal_write( $id, $store, _empty_set(), $drop, {} );
    return {
        qw| expired |     => \@expired,
        qw| journal_seq | => $journal->{'seq'}
    };
}

sub hold_list {
    my ( $id, $state, $replay ) = @ARG;
    my @out;
    foreach my $path ( sort keys $replay->{'holds'}->%* ) {
        my $hold   = { $replay->{'holds'}{$path}->%* };
        my $before = journal_replay( $id, qw| upto | => $hold->{'seq'} );
        $hold->{'trees'} = [ sort keys $before->{'trees'}->%* ];
        $hold->{'references'}
            = grep { not $ARG->{'dropped'} }
            values $before->{'references'}->%*;
        push @out, $hold;
    }
    return @out;
}

sub hold_records_verify {
    my ( $id, $replay ) = @ARG;
    my $records = hold_records($id);
    foreach my $path ( keys %{$records} ) {
        refuse( 'format 3 : unlisted hold record %s', $path )
            if not $replay->{'hold_history'}{$path};
    }
    foreach my $path ( keys $replay->{'hold_history'}->%* ) {
        refuse( 'format 3 : missing hold record %s', $path )
            if not $records->{$path};
        my $expected = $replay->{'hold_history'}{$path};
        foreach my $field (qw| seq reason source ntime expires |) {
            refuse( 'format 3 : hold record %s differs from journal', $path )
                if ( $records->{$path}{$field} // '' ) ne
                ( $expected->{$field} // '' );
        }
    }
    return scalar keys %{$records};
}

1;

#,,,.,.,,,...,..,,,..,..,,...,..,,,.,,..,,...,..,,...,...,.,.,,..,,,.,..,,.,.,
#HCXB52QBI77TPUM4HLBLX2VYIGMZZXKNDR7P547H3LJVQQEAE7Y3OU2JOWO25LCANH4M4F5HOJJUQ
#\\\|ZVRC36727PKXL3IVRLF7CI5UDOCM6PACO4IDBJZQZBS2GE5YD6Z \ / AMOS7 \ YOURUM ::
#\[7]T6BGXNBLYYN2NYEGPX5R3MKRW4CQFIWYIFRVSSQW3UAJLDS5QMCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
