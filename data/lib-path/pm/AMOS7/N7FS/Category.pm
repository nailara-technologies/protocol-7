## [:< ##

package AMOS7::N7FS::Category;    ###########################################

## versioned category definitions and superseding per-reference assignments.

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

our $VERSION = qw| AMOS7::N7FS::Category-VERSION.WPKVGIQ |;

@EXPORT_OK
    = qw| category_default category_definitions category_set category_list
    category_records_verify category_assignments category_set_reference
    category_report category_assignment_plan category_strict_merge |;

use AMOS7::N7FS qw| refuse fault |;
use AMOS7::N7FS::Disk
    qw| disk_lock disk_read_id disk_require_attached state_read
    store_key_signer witness_note_format |;
use AMOS7::N7FS::Journal   qw| journal_replay journal_write |;
use AMOS7::N7FS::Record    qw| record_write record_scan |;
use AMOS7::N7FS::Store     qw| store_nodes |;
use AMOS7::N7FS::Reference qw| reference_scan reference_address |;

sub category_default {
    return {
        qw| name |             => qw| default |,
        qw| local_encryption | => qw| none |,
        qw| copies |           => 1,
        qw| priority |         => 0,
        qw| replica |          => qw| full |,
        qw| want |             => [],
        qw| foreign_work |     => qw| no |,
        qw| layer |            => qw| private |,
        qw| builtin |          => TRUE,
    };
}

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

sub _name {
    my $name = shift // '';
    refuse( 'category : bad name [ %s ]', $name )
        if $name !~ m|\A[A-Za-z0-9][A-Za-z0-9_.-]{0,127}\z|;
    return $name;
}

sub _policy {
    my $p = shift;
    refuse('category : local encryption must be none or cascade')
        if ( $p->{'local_encryption'} // '' ) !~ m{\A(?:none|cascade)\z};
    refuse('category : copies and priority must be nonnegative integers')
        if ( $p->{'copies'} // '' ) !~ m|\A\d+\z|
        or ( $p->{'priority'} // '' ) !~ m|\A\d+\z|;
    refuse('category : replica must be full or manifest')
        if ( $p->{'replica'} // '' ) !~ m{\A(?:full|manifest)\z};
    refuse('category : foreign work must be no or yes')
        if ( $p->{'foreign_work'} // '' ) !~ m{\A(?:no|yes)\z};
    refuse('category : layer must be private or generic')
        if ( $p->{'layer'} // '' ) !~ m{\A(?:private|generic)\z};
    refuse('category : want must be a list')
        if ref $p->{'want'} ne qw| ARRAY |
        or grep { not defined $ARG or not length $ARG } $p->{'want'}->@*;
    return $p;
}

sub category_definitions {
    my ( $id, $replay ) = @ARG;
    my %out = (
        qw| default |  => category_default(),
        qw| incoming | => {
            %{ category_default() },
            qw| name |     => qw| incoming |,
            qw| copies |   => 2,
            qw| priority | => 50,
        },
    );
    foreach my $path ( sort keys $replay->{'category_history'}->%* ) {
        my ($record)
            = grep { $ARG->{'path'} eq $path }
            record_scan( $id, qw| category |, qw| categories |,
            qw| category | );
        refuse( 'category record %s is missing', $path )
            if not defined $record;
        _name( $record->{'name'} );
        _policy($record);
        $out{ $record->{'name'} } = $record;
    }
    return \%out;
}

sub category_records_verify {
    my ( $id, $replay ) = @ARG;
    my @categories = record_scan( $id, qw| category |, qw| categories |,
        qw| category | );
    my @assignments = record_scan(
        $id,
        qw| assignment |,
        qw| assignments |,
        qw| assignment |
    );
    my %categories  = map { $ARG->{'path'} => $ARG } @categories;
    my %assignments = map { $ARG->{'path'} => $ARG } @assignments;
    foreach my $path ( sort keys $replay->{'category_history'}->%* ) {
        refuse( 'format 3 : missing category record %s', $path )
            if not $categories{$path};
        refuse( 'format 3 : category %s differs from journal', $path )
            if $categories{$path}{'name'} ne
            $replay->{'category_history'}{$path}{'name'};
        _policy( $categories{$path} );
        refuse( 'format 3 : category %s origin differs from journal', $path )
            if ( $categories{$path}{'origin'}{'id'} // $path ) ne
            ( $replay->{'category_history'}{$path}{'origin'}{'id'} // $path )
            or ( $categories{$path}{'origin'}{'disk'} // $id->{'disk'} ) ne
            ( $replay->{'category_history'}{$path}{'origin'}{'disk'}
                // $id->{'disk'} );
    }
    foreach my $path ( sort keys %categories ) {
        refuse( 'format 3 : unlisted category record %s', $path )
            if not $replay->{'category_history'}{$path};
    }
    foreach my $path ( sort keys $replay->{'assignment_history'}->%* ) {
        my $expected = $replay->{'assignment_history'}{$path};
        refuse( 'format 3 : missing category assignment %s', $path )
            if not $assignments{$path};
        foreach my $field (qw| node reference category |) {
            refuse( 'format 3 : assignment %s differs from journal', $path )
                if ( $assignments{$path}{$field} // '' ) ne
                ( $expected->{$field} // '' );
        }
        refuse( 'format 3 : assignment %s origin differs from journal',
            $path )
            if ( $assignments{$path}{'origin'}{'id'} // $path ) ne
            ( $expected->{'origin'}{'id'}              // $path )
            or ( $assignments{$path}{'origin'}{'disk'} // $id->{'disk'} ) ne
            ( $expected->{'origin'}{'disk'}            // $id->{'disk'} );
    }
    foreach my $path ( sort keys %assignments ) {
        refuse( 'format 3 : unlisted category assignment %s', $path )
            if not $replay->{'assignment_history'}{$path};
    }
    require AMOS7::N7FS::Batch;
    my $batches = AMOS7::N7FS::Batch::batch_records_verify( $id, $replay );
    return ( scalar @categories, scalar @assignments, $batches );
}

sub category_set {
    my %opt  = @ARG;
    my $name = _name( $opt{'name'} );
    refuse('category : the built-in default cannot be replaced')
        if $name eq qw| default |;
    my $lock  = disk_lock( disk_read_id(%opt) );
    my $id    = disk_require_attached(%opt);
    my $store = store_key_signer( %opt, qw| id | => $id );
    my $state = state_read( $id->{'path'}, $id->{'store_pub'} );
    refuse('categories are only available for store format 3')
        if $state->{'store_format'} != 3;
    my $replay = journal_replay($id);
    my $old    = category_definitions( $id, $replay )->{$name}
        // category_default();
    my %payload = (
        qw| disk |             => $id->{'disk'},
        qw| name |             => $name,
        qw| local_encryption | => $opt{'local_encryption'}
            // $old->{'local_encryption'},
        qw| copies |       => $opt{'copies'}       // $old->{'copies'},
        qw| priority |     => $opt{'priority'}     // $old->{'priority'},
        qw| replica |      => $opt{'replica'}      // $old->{'replica'},
        qw| want |         => $opt{'want'}         // $old->{'want'},
        qw| foreign_work | => $opt{'foreign_work'} // $old->{'foreign_work'},
        qw| layer |        => $opt{'layer'}        // $old->{'layer'},
    );
    _policy( \%payload );
    my $record = record_write( $id, $store, qw| category |, qw| categories |,
        qw| category |, \%payload );
    fault(qw| category:after-record |);
    my $add = _empty_set();
    push $add->{'categories'}->@*,
        { qw| name | => $name, qw| path | => $record->{'path'} };
    my $journal = journal_write( $id, $store, $add, _empty_set(), {} );
    witness_note_format(
        %opt,
        qw| id |          => $id,
        qw| state |       => $state,
        qw| journal_seq | => $journal->{'seq'}
    );
    return { qw| category | => $record, qw| seq | => $journal->{'seq'} };
}

sub category_list {
    my ( $id, $replay ) = @ARG;
    my $definitions = category_definitions( $id, $replay );
    return map { $definitions->{$ARG} } sort keys %{$definitions};
}

sub _glob_regex {
    my $glob  = shift;
    my $regex = quotemeta $glob;
    $regex =~ s|\\\*|.*|g;
    $regex =~ s|\\\?|.|g;
    return qr|\A$regex\z|s;
}

sub category_assignment_plan {
    my ( $id, $replay, $opt ) = @ARG;
    my $definitions = category_definitions( $id, $replay );
    my @rules;
    foreach my $rule ( ( $opt->{'category_rules'} // [] )->@* ) {
        my ( $glob, $name ) = $rule =~ m|\A(.+)=([^=]+)\z|;
        refuse( 'category-rule must be <glob>=<name> [ %s ]', $rule )
            if not defined $name;
        _name($name);
        refuse( 'unknown category [ %s ]', $name )
            if not exists $definitions->{$name};
        push @rules, [ _glob_regex($glob), $name ];
    }
    my $default = $opt->{'category'} // qw| default |;
    _name($default);
    refuse( 'unknown category [ %s ]', $default )
        if not exists $definitions->{$default};
    return sub {
        my $path = shift;
        foreach my $rule (@rules) {
            return $rule->[1] if $path =~ $rule->[0];
        }
        return $default;
    };
}

sub category_assignments {
    my ( $id, $store, $references, $chooser ) = @ARG;
    my @out;
    foreach my $ref ( @{$references} ) {
        my $category = $chooser->( $ref->{'holder'} );
        my $record   = record_write(
            $id, $store,
            qw| assignment |,
            qw| assignments |,
            qw| assignment |,
            {   qw| disk |      => $id->{'disk'},
                qw| node |      => $ref->{'node'},
                qw| reference | => $ref->{'path'},
                qw| holder |    => $ref->{'holder'},
                qw| category |  => $category,
            }
        );
        fault(qw| assignment:after-record |);
        push @out,
            {
            qw| node |      => $ref->{'node'},
            qw| reference | => $ref->{'path'},
            qw| path |      => $record->{'path'},
            qw| category |  => $category,
            };
    }
    return \@out;
}

sub category_set_reference {
    my %opt      = @ARG;
    my $category = _name( $opt{'category'} );
    my $target   = $opt{'target'} // '';
    my $lock     = disk_lock( disk_read_id(%opt) );
    my $id       = disk_require_attached(%opt);
    my $store    = store_key_signer( %opt, qw| id | => $id );
    my $state    = state_read( $id->{'path'}, $id->{'store_pub'} );
    refuse('categories are only available for store format 3')
        if $state->{'store_format'} != 3;
    my $replay = journal_replay($id);
    refuse( 'unknown category [ %s ]', $category )
        if not exists category_definitions( $id, $replay )->{$category};
    my @refs;

    foreach my $node ( store_nodes( $id->{'path'}, $state->{'epochs'}->@* ) )
    {
        foreach my $ref ( grep { not $ARG->{'dropped'} }
            reference_scan( $node, $id ) ) {
            my $match
                = $target =~ m|\Atree:(.*)\z|s
                ? index( $ref->{'holder'}, $1 ) == 0
                : $ref->{'node'} eq $target;
            push @refs, $ref if $match;
        }
    }
    refuse( 'set-category : no live reference matches [ %s ]', $target )
        if not @refs;
    my $assignments = category_assignments( $id, $store, \@refs,
        sub { return $category } );
    my $add = _empty_set();
    $add->{'assignments'} = $assignments;
    my $drop     = _empty_set();
    my %resolved = map { $ARG->{'path'} => TRUE } @refs;
    if ( keys $replay->{'sync_conflicts'}->%* ) {
        my %records = map { $ARG->{'path'} => $ARG } record_scan(
            $id,
            qw| sync_conflict |,
            qw| sync-conflicts |,
            qw| sync-conflict |
        );
        foreach my $path ( keys $replay->{'sync_conflicts'}->%* ) {
            push $drop->{'conflicts'}->@*, { qw| path | => $path }
                if $resolved{ $records{$path}{'reference'} // '' };
        }
    }
    my $journal = journal_write( $id, $store, $add, $drop, {} );
    witness_note_format(
        %opt,
        qw| id |          => $id,
        qw| state |       => $state,
        qw| journal_seq | => $journal->{'seq'}
    );
    return {
        qw| assignments | => $assignments,
        qw| seq |         => $journal->{'seq'}
    };
}

sub _effective {
    my @policies  = @_;
    my %effective = (
        qw| name |             => qw| effective |,
        qw| local_encryption | => qw| none |,
        qw| copies |           => 1,
        qw| priority |         => 0,
        qw| replica |          => qw| manifest |,
        qw| foreign_work |     => qw| yes |,
        qw| layer |            => qw| generic |,
        qw| want |             => [],
    );
    my %want;
    foreach my $p (@policies) {
        $effective{'local_encryption'} = qw| cascade |
            if $p->{'local_encryption'} eq qw| cascade |;
        $effective{'copies'} = $p->{'copies'}
            if $p->{'copies'} > $effective{'copies'};
        $effective{'priority'} = $p->{'priority'}
            if $p->{'priority'} > $effective{'priority'};
        $effective{'replica'} = qw| full | if $p->{'replica'} eq qw| full |;
        $effective{'foreign_work'} = qw| no |
            if $p->{'foreign_work'} eq qw| no |;
        $effective{'layer'} = qw| private | if $p->{'layer'} eq qw| private |;
        $want{$ARG} = TRUE for $p->{'want'}->@*;
    }
    $effective{'want'} = [ sort keys %want ];
    return \%effective;
}

sub category_strict_merge {
    my ( $name, @policies ) = @ARG;
    my $merged = _effective(@policies);
    $merged->{'name'} = $name;
    return $merged;
}

sub category_report {
    my ( $id, $replay, $address ) = @ARG;
    my $definitions = category_definitions( $id, $replay );
    my @refs        = grep { $ARG->{'node'} eq $address }
        values $replay->{'ref_history'}->%*;
    refuse( 'category show : no reference for [ %s ]', $address )
        if not @refs;
    my @out;
    foreach my $ref ( sort { $a->{'path'} cmp $b->{'path'} } @refs ) {
        my $key        = join "\0", $address, $ref->{'path'};
        my $assignment = $replay->{'assignments'}{$key};
        my $name       = $assignment->{'category'} // qw| default |;
        my $policy     = $definitions->{$name};
        refuse( 'category assignment names unknown category %s', $name )
            if not defined $policy;
        push @out,
            {
            qw| reference | => $ref,
            qw| category |  => $name,
            qw| policy |    => $policy
            };
    }
    return {
        qw| references | => \@out,
        qw| effective |  => _effective( map { $ARG->{'policy'} } @out ),
    };
}

1;

#,,..,...,...,,.,,,,,,,..,...,.,,,,,.,.,.,.,,,..,,...,...,.,,,,..,,,.,,,,,,,,,
#QLOVSOIS7IDH7VDZXWVHNYITQWSKFONZQVR2NFIOCXJ5WQCLXM7LDFWT6TV6Z7GMO2LKG52KFAMN4
#\\\|ZKUNZ2M33VIQPIJXXOH62IUHQGB2IK73GLXXLTOI5NTZOY6DNL6 \ / AMOS7 \ YOURUM ::
#\[7]NSPTDBEUYA3273A5BK4JRV46CPYYUQIQZ656GR6VZNJFANLUPWAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
