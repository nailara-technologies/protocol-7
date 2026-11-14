## [:< ##

package AMOS7::N7FS::Cycle;    ##############################################

## host-local cycles : additive placement, a strict gate and guarded cleanup.

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

our $VERSION = qw| AMOS7::N7FS::Cycle-VERSION.H55YUTQ |;

@EXPORT_OK = qw| config_read state_read cycle_gate cycle_run cycle_status |;

use Fcntl qw| LOCK_EX LOCK_NB |;
use JSON::PP;
use AMOS7::NTIME qw| parse_y_age y_age_str |;
use AMOS7::N7FS  qw| read_file write_new_file make_dirs sync_dir random_bytes
    b32 refuse fault ntime_now ntime14 |;
use AMOS7::N7FS::Sum  qw| bmw384_bytes bmw_b32 |;
use AMOS7::N7FS::Sign qw| key_file_signer |;

my $JSON  = JSON::PP->new->utf8->canonical;
my @STEPS = qw| A0-preflight A1-snapshot A2-place A3-relay A4-check
    A5-refresh A6-drill gate D1-retain D2-repack D3-gc D4-purge D5-reclaim |;

sub _cycle_dir { return shift . '/cycle' }

sub _name_ok {
    my $name = shift // '';
    refuse( 'cycle name is invalid [ %s ]', $name )
        if $name !~ m|\A[A-Za-z0-9_.-]{1,64}\z|;
    return $name;
}

sub _config_path {
    my ( $host_dir, $name ) = @_;
    return _cycle_dir($host_dir) . '/' . _name_ok($name) . '.cfg';
}

sub _state_path {
    my ( $host_dir, $name ) = @_;
    return _cycle_dir($host_dir) . '/' . _name_ok($name) . '.state';
}

sub _private_file {
    my ( $path, $label ) = @_;
    my @st = lstat $path;
    refuse( '%s is missing [ %s ]',            $label, $path ) if not @st;
    refuse( '%s is not a regular file [ %s ]', $label, $path )
        if not -f _ or -l $path;
    refuse( '%s must not be accessible by group or others [ %s ]',
        $label, $path )
        if $st[2] & 077;
    return @st;
}

sub _lines {
    my $body = shift // '';
    my %values;
    foreach my $line ( split m|\n|, $body, -1 ) {
        next if $line =~ m|\A\s*(?:#.*)?\z|;
        my ( $key, $value )
            = $line =~ m|\A\s*([A-Za-z0-9_.-]+)\s*[:=]\s*(.*?)\s*\z|;
        refuse( 'invalid config line [ %s ]',  $line ) if not defined $value;
        refuse( 'duplicate config key [ %s ]', $key ) if exists $values{$key};
        $values{$key} = $value;
    }
    return \%values;
}

sub _bool {
    my ( $value, $field ) = @_;
    my $bool = {
        qw| 1 |     => 1,
        qw| yes |   => 1,
        qw| true |  => 1,
        qw| 0 |     => 0,
        qw| no |    => 0,
        qw| false | => 0
    }->{ lc $value // '' };
    refuse( 'cycle %s must be yes or no', $field ) if not defined $bool;
    return $bool;
}

sub config_read {
    my ( $host_dir, $name ) = @_;
    my $path = _config_path( $host_dir, $name );
    _private_file( $path, 'cycle config' );
    my $raw = _lines( read_file($path) );
    my %short;
    foreach my $key ( keys %{$raw} ) {
        my $field = $key;
        $field =~ s|\Acycle\.\Q$name\E\.||
            or $field = $key;
        refuse( 'config key belongs to another cycle [ %s ]', $key )
            if $field =~ m|\Acycle\.|;
        $short{$field} = $raw->{$key};
    }
    my %alias = (
        'snapshot.source'       => 'source',
        'snapshot.method'       => 'snapshot',
        'snapshot.tree'         => 'prefix',
        'snapshot.prefix'       => 'prefix',
        'snapshot.staging'      => 'staging',
        'snapshot.keep-staging' => 'keep-staging',
        'snapshot.shrink-limit' => 'shrink-limit',
        'snapshot.snapshot-cmd' => 'snapshot-cmd',
        'snapshot.category'     => 'category',
        'drill.every'           => 'drill-every',
        'drill.scratch'         => 'drill-scratch',
        'scrub.every'           => 'scrub-every',
        'relay.pending-max'     => 'pending-max',
    );
    my %c;
    foreach my $field ( keys %short ) {
        my $to = $alias{$field} // $field;
        refuse( 'cycle config repeats %s through an alias', $to )
            if exists $c{$to};
        $c{$to} = $short{$field};
    }
    my @known = qw| disk root-key pass-file vault-dir source snapshot prefix
        staging keep-staging shrink-limit snapshot-cmd category period check
        scrub-every refresh drill-every drill-scratch pending-max retain repack
        gc-grace trash-age reclaim-local snapshot-only |;
    my %known = map { $ARG => TRUE } @known;
    refuse( 'unknown cycle config key [ %s ]', $ARG )
        for grep { not $known{$ARG} } sort keys %c;
    refuse( 'cycle %s needs disk and root-key', $name )
        if not length( $c{'disk'} // '' )
        or not length( $c{'root-key'} // '' );
    $c{'snapshot'}      //= 'copy-verify';
    $c{'prefix'}        //= 'snap';
    $c{'keep-staging'}  //= 1;
    $c{'shrink-limit'}  //= 30;
    $c{'period'}        //= '1Y4';
    $c{'check'}         //= 'sampled';
    $c{'scrub-every'}   //= '1Y2';
    $c{'refresh'}       //= 'yes';
    $c{'drill-every'}   //= '1Y1';
    $c{'pending-max'}   //= '3Y3';
    $c{'retain'}        //= 'yes';
    $c{'repack'}        //= 'yes';
    $c{'gc-grace'}      //= '6Y3';
    $c{'trash-age'}     //= '3Y2';
    $c{'reclaim-local'} //= 'no';
    $c{'snapshot-only'} //= 'no';
    refuse( 'cycle check must be sampled or full', $c{'check'} )
        if $c{'check'} ne qw| sampled | and $c{'check'} ne qw| full |;
    refuse('cycle keep-staging must be a positive whole number')
        if $c{'keep-staging'} !~ m|\A[1-9]\d*\z|;
    refuse('cycle shrink-limit must be a number from 0 to 100')
        if $c{'shrink-limit'} !~ m|\A\d+(?:\.\d+)?\z|
        or $c{'shrink-limit'} > 100;

    foreach my $field (
        qw| period scrub-every drill-every pending-max gc-grace trash-age |) {
        refuse( 'cycle %s must use <n>Y<level>', $field )
            if not defined parse_y_age( $c{$field} );
    }
    refuse('cycle reclaim-local must be no or exactly 13Y2')
        if lc( $c{'reclaim-local'} ) ne qw| no |
        and $c{'reclaim-local'} ne qw| 13Y2 |;
    $c{'refresh'}       = _bool( $c{'refresh'},       'refresh' );
    $c{'retain'}        = _bool( $c{'retain'},        'retain' );
    $c{'repack'}        = _bool( $c{'repack'},        'repack' );
    $c{'snapshot-only'} = _bool( $c{'snapshot-only'}, 'snapshot-only' );
    refuse('cycle reclaim-local needs snapshot-only = yes')
        if lc( $c{'reclaim-local'} ) ne qw| no |
        and not $c{'snapshot-only'};
    $c{'config'} = $path;
    return \%c;
}

sub state_read {
    my ( $host_dir, $name ) = @_;
    my $path = _state_path( $host_dir, $name );
    my $body = read_file($path);
    return {} if not defined $body;
    return _lines($body);
}

sub _state_text {
    my $state = shift;
    my @lines = 'format : 1';
    my @keys  = sort grep { $ARG ne qw| format | } keys %{$state};
    my $width = 0;
    foreach my $key (@keys) {
        $width = length $key if length $key > $width;
    }
    foreach my $key (@keys) {
        my $value = $state->{$key} // '';
        refuse( 'cycle state value contains a newline [ %s ]', $key )
            if $value =~ m|[\r\n]|;
        push @lines, sprintf "%-${width}s : %s", $key, $value;
    }
    return join( "\n", @lines ) . "\n";
}

sub _state_write {
    my ( $host_dir, $name, $state ) = @_;
    my $path = _state_path( $host_dir, $name );
    make_dirs( _cycle_dir($host_dir), 0700 );
    my $tmp = "$path.tmp." . b32( random_bytes(5) );
    write_new_file( $tmp, _state_text($state) );
    chmod 0600, $tmp
        or refuse( 'cannot protect cycle state : %s', $OS_ERROR );
    rename $tmp, $path
        or refuse( 'cannot publish cycle state : %s', $OS_ERROR );
    sync_dir( _cycle_dir($host_dir) );
    return;
}

sub _say { say ': ', @ARG }

sub _holder_result {
    my ( $state, $step, $name, $result, $detail ) = @_;
    $detail //= '';
    $detail =~ s|\s+| |g;
    $state->{"step.$step.holder.$name.result"} = $result;
    $state->{"step.$step.holder.$name.detail"} = $detail;
    _say( '  holder ', $name, ' : ', $result,
        length $detail ? ' [ ' . $detail . ' ]' : '' );
    return;
}

sub _lock {
    my ( $path, $label ) = @_;
    open( my $fh, '>>', $path )
        or refuse( 'cannot open %s : %s', $label, $OS_ERROR );
    return {
        qw| handle | => $fh,
        qw| path |   => $path,
        qw| label |  => $label
    };
}

sub _busy {
    my $lock = shift;
    return not flock( $lock->{'handle'}, LOCK_EX | LOCK_NB );
}

sub _open_root {
    my ( $c, $host_dir ) = @_;
    require AMOS7::N7FS::Keys;
    my ( $pass, $fd );
    if ( defined $c->{'pass-file'} ) {
        _private_file( $c->{'pass-file'}, 'cycle pass-file' );
        open( $pass, '<:raw', $c->{'pass-file'} )
            or refuse( 'cannot open cycle pass-file : %s', $OS_ERROR );
        $fd = fileno $pass;
    }
    my $root = AMOS7::N7FS::Keys::root_open(
        qw| path |    => $c->{'root-key'},
        qw| pass_fd | => $fd,
        defined $c->{'vault-dir'}
        ? ( qw| vault_dir | => $c->{'vault-dir'} )
        : (),
    );
    close $pass if defined $pass;
    $root->{'host_dir'} = $host_dir;
    return $root;
}

sub _relay_tag {
    my ( $root, $spec ) = @_;
    return substr(
        bmw_b32(
            bmw384_bytes(
                "p7 n7fs relay v2\0" . $root->{'root_id'} . "\0" . $spec
            )
        ),
        0, 13
    );
}

sub _relay_pending_path {
    my ( $host_dir, $root, $spec ) = @_;
    return "$host_dir/relay-pending/" . _relay_tag( $root, $spec ) . '.json';
}

sub _relay_list_write {
    my ( $host_dir, $root, $from, $to, $names, $subdir ) = @_;
    require AMOS7::N7FS::Holder;
    my $dir = "$host_dir/relay-pending";
    make_dirs( $dir, 0700 );
    my $pending = _relay_pending_path( $host_dir, $root, $to );
    my %all;
    if ( -f $pending ) {
        my $old = eval { $JSON->decode( read_file($pending) ) };
        $all{$ARG} = TRUE for @{ $old->{'blobs'} // [] };
    }
    $all{$ARG} = TRUE for @{$names};
    my $tmp = "$pending.new." . b32( random_bytes(5) );
    write_new_file(
        $tmp,
        $JSON->encode(
            { qw| holder | => $to, qw| blobs | => [ sort keys %all ] }
        )
    );
    rename $tmp, $pending
        or refuse( 'cannot keep the pending list : %s', $OS_ERROR );
    my $body = $JSON->encode(
        {   qw| blobs | => $names,
            defined $subdir ? ( qw| subdir | => $subdir ) : (),
        }
    );
    my $h = AMOS7::N7FS::Holder::holder_parse($from);
    if ( $h->{'type'} eq qw| local | ) {
        my $final = "$h->{'dir'}/relay-list." . _relay_tag( $root, $to );
        my $new   = "$final.new." . b32( random_bytes(5) );
        write_new_file( $new, $body );
        rename $new, $final
            or refuse( 'cannot write the relay list : %s', $OS_ERROR );
        return;
    }
    my $list = "$dir/relay-list." . b32( random_bytes(5) );
    write_new_file( $list, $body );
    AMOS7::N7FS::Holder::holder_put( $from, $list,
        'relay-list.' . _relay_tag( $root, $to ),
        qw| list |, TRUE );
    unlink $list;
    return;
}

sub _relay_pending_age {
    my ( $host_dir, $root, $spec, $now ) = @_;
    my $path = _relay_pending_path( $host_dir, $root, $spec );
    return undef if not -f $path;
    my $time = read_file($path);
    my $data = eval { $JSON->decode($time) };
    return $now - ( $data->{'time'} // 0 )
        if ref $data eq qw| HASH |
        and defined $data->{'time'};
    my @st = stat $path;
    return undef if not @st;
    require AMOS7::NTIME;
    return $now - AMOS7::NTIME::unix_to_ntime( $st[9], 0 );
}

sub _check_one {
    my ( $root, $host_dir, $h, $coverage, $accept_clock ) = @_;
    require AMOS7::N7FS::Seal;
    require AMOS7::N7FS::Placement;
    my $r = AMOS7::N7FS::Seal::holder_check(
        qw| root |     => $root,
        qw| holder |   => $h->{'spec'},
        qw| coverage | => $coverage,
    );
    AMOS7::N7FS::Placement::receipt_write(
        qw| host_dir |          => $host_dir,
        qw| root |              => $root,
        qw| spec |              => $h->{'spec'},
        qw| version |           => $r->{'version'},
        qw| nodes |             => $r->{'nodes'},
        qw| samples |           => $r->{'samples'},
        qw| coverage |          => $r->{'coverage'},
        qw| covered |           => $r->{'covered'},
        qw| covered_nodes |     => $r->{'covered_nodes'},
        qw| covered_addresses | => $r->{'covered_list'},
        qw| accept_clock |      => $accept_clock ? TRUE : FALSE,
    );
    return $r;
}

sub _newest_snapshot {
    my ( $root, $spec, $prefix ) = @_;
    require AMOS7::N7FS::Seal;
    my ( undef, $head, $map )
        = AMOS7::N7FS::Seal::_context( $root, $spec, TRUE );
    return undef if not defined $head;
    my ($tree) = sort {
        ( $map->{'trees'}{$b}{'created'} // '' )
            cmp( $map->{'trees'}{$a}{'created'} // '' )
            or $a cmp $b
    } grep {
        index( $ARG, $prefix ) == 0
            and ( $map->{'trees'}{$ARG}{'held'} // -1 )
            == ( $map->{'trees'}{$ARG}{'files'} // -2 )
    } keys %{ $map->{'trees'} // {} };
    return $tree;
}

## the replication rule is a parameter so a holder quorum can replace strict
## domain coverage without changing the other gate conditions or the pipeline
sub cycle_gate {
    my %opt  = @_;
    my $rule = $opt{'rule'} // 'strict';
    refuse('cycle gate rule must be strict or a code reference')
        if ref $rule ne qw| CODE | and $rule ne qw| strict |;
    my @conditions;
    push @conditions,
        {
        qw| name |   => qw| additive |,
        qw| ok |     => $opt{'additive_ok'} ? TRUE : FALSE,
        qw| detail | => $opt{'additive_detail'}
            // 'every additive step finished'
        };
    my @stale = @{ $opt{'stale'} // [] };
    push @conditions,
        {
        qw| name |   => qw| stale-head |,
        qw| ok |     => not( $opt{'stale_error'} or @stale ) ? TRUE : FALSE,
        qw| detail | => $opt{'stale_error'}
            // ( @stale ? join( ', ', @stale ) : 'no holder head is stale' )
        };
    my $frozen = $opt{'frozen'};
    push @conditions,
        {
        qw| name | => qw| shrink-freeze |,
        qw| ok |   => not( $opt{'freeze_error'}
            or ( $frozen and not $opt{'accept_shrink'} ) )
        ? TRUE
        : FALSE,
        qw| detail | => $opt{'freeze_error'} // (
            $frozen
            ? "freeze at $frozen->{'tree'}"
                . ( $opt{'accept_shrink'} ? ' accepted for this run' : '' )
            : 'no shrink-guard freeze'
        )
        };

    my $clock_limit = parse_y_age('1Y4');
    my $clock_delta
        = ( $opt{'effective_now'} // 0 ) - ( $opt{'local_now'} // 0 );
    my @clock_future = @{ $opt{'clock_future'} // [] };
    my $clock_bad
        = $opt{'clock_error'}
        || $clock_delta > $clock_limit
        || @clock_future;
    push @conditions,
        {
        qw| name |   => qw| clock |,
        qw| ok |     => $clock_bad ? FALSE : TRUE,
        qw| detail | => $opt{'clock_error'} // (
              @clock_future ? 'future heads : ' . join( ', ', @clock_future )
            : $clock_delta > $clock_limit
            ? "clock floor is $clock_delta ntime ahead [ limit $clock_limit ]"
            : 'local clock, floor and head times are plausible'
        )
        };

    my @under;
    if ( not $opt{'coverage_error'} ) {
        my $nodes  = $opt{'nodes'}  // {};
        my $proofs = $opt{'proofs'} // {};
        foreach my $address ( sort keys %{$nodes} ) {
            my $node  = $nodes->{$address};
            my $proof = $proofs->{$address}
                // { qw| domains | => {}, qw| holders | => {} };
            my $covered
                = ref $rule eq qw| CODE |
                ? $rule->( $address, $node, $proof )
                : scalar( keys $proof->{'domains'}->%* ) >= $node->{'target'};
            push @under, [ $address, $node, $proof ] if not $covered;
        }
    }
    my $coverage_detail = $opt{'coverage_error'} // (
        @under
        ? sprintf '%d nodes below target [ first %s : %d '
            . 'holder proofs, %d domains, target %d ]',
            scalar @under,
            $under[0][0],
            scalar( keys $under[0][2]{'holders'}->%* ),
            scalar( keys $under[0][2]{'domains'}->%* ),
            $under[0][1]{'target'}
        : 'every node meets its target on fresh full receipts'
    );
    push @conditions,
        {
        qw| name | => qw| replication |,
        qw| ok |   => not( $opt{'coverage_error'} or @under ) ? TRUE : FALSE,
        qw| detail | => $coverage_detail
        };

    my $drill = $opt{'drill'};
    my $drill_bad
        = $opt{'drill_error'}
        || !defined $drill
        || ( $drill->{'time'} // 0 )
        > ( $opt{'effective_now'} // 0 ) + $clock_limit
        || ( $opt{'effective_now'} // 0 ) - ( $drill->{'time'} // 0 )
        > ( $opt{'drill_max_age'} // 0 );
    push @conditions,
        {
        qw| name |   => qw| drill |,
        qw| ok |     => $drill_bad ? FALSE : TRUE,
        qw| detail | => $opt{'drill_error'} // (
            defined $drill
            ? "last pass $drill->{'tree'} on "
                . "$drill->{'holder'} at $drill->{'time'}"
            : 'no passing restore drill'
        )
        };
    my $ok = not grep { not $ARG->{'ok'} } @conditions;
    return {
        qw| ok |         => $ok ? TRUE : FALSE,
        qw| conditions | => \@conditions,
        qw| under |      => \@under,
        qw| rule |       => ref $rule eq qw| CODE | ? qw| custom | : $rule,
    };
}

sub _gate_evidence {
    my ( $c, $root, $host_dir, $disk_root, $state, $accept_shrink, $rule )
        = @_;
    my %gate = (
        qw| rule |          => $rule // 'strict',
        qw| accept_shrink | => $accept_shrink ? TRUE : FALSE,
        qw| local_now |     => ntime_now(),
    );
    my @failed
        = grep { ( $state->{"step.$ARG.result"} // '' ) eq qw| failed | }
        @STEPS[ 0 .. 6 ];
    $gate{'additive_ok'} = not @failed;
    $gate{'additive_detail'}
        = @failed
        ? 'failed additive steps : ' . join( ', ', @failed )
        : 'every additive step of this run finished';
    $gate{'effective_now'} = $gate{'local_now'};
    my $clock_ok = eval {
        $gate{'effective_now'} = AMOS7::N7FS::Placement::n7fs_now( $host_dir,
            $root->{'root_id'} );
        1;
    };
    $gate{'clock_error'} = $EVAL_ERROR if not $clock_ok;

    my $survey_ok = eval {
        my $holders
            = AMOS7::N7FS::Placement::holders_load( qw| root | => $root );
        my $survey = AMOS7::N7FS::Seal::head_survey( $root,
            { map { $ARG => $holders->{$ARG}{'spec'} } keys %{$holders} } );
        $gate{'stale'}
            = [ sort grep { $survey->{$ARG}{'stale'} } keys %{$holders} ];
        $gate{'clock_future'} = [
            sort grep {
                defined $survey->{$ARG}{'head'}
                    and $survey->{$ARG}{'head'}{'time'}
                    > $gate{'local_now'}
                    + parse_y_age('1Y4')
            } keys %{$holders}
        ];
        1;
    };
    $gate{'stale_error'} = $EVAL_ERROR if not $survey_ok;

    my $prefix = $c->{'prefix'};
    $prefix =~ s|:+\z||;
    $prefix .= ':';
    require AMOS7::N7FS::Snapshot;
    my $freeze_ok = eval {
        $gate{'frozen'} = AMOS7::N7FS::Snapshot::retention_frozen(
            qw| host_dir | => $host_dir,
            qw| disk |     => $c->{'disk'},
            qw| prefix |   => $prefix,
        );
        1;
    };
    $gate{'freeze_error'} = $EVAL_ERROR if not $freeze_ok;

    my $copies_ok = eval {
        my %placement = (
            qw| host_dir |          => $host_dir,
            qw| disk |              => $c->{'disk'},
            qw| root |              => $root,
            qw| allow_stale |       => TRUE,
            qw| unreachable_grace | => 0,
        );
        $placement{'disk_root'} = $disk_root if defined $disk_root;
        my ( undef, $nodes )
            = AMOS7::N7FS::Placement::_disk_nodes(%placement);
        my ( $holders, undef, $status, $proven )
            = AMOS7::N7FS::Placement::_copies(%placement);
        my %proofs;
        foreach my $address ( keys %{$nodes} ) {
            $proofs{$address}{'domains'} = $proven->{$address} // {};
            $proofs{$address}{'holders'} = {};
            foreach my $name ( keys %{$holders} ) {
                next
                    if $holders->{$name}{'role'} ne qw| durable |
                    or $status->{$name}{'state'} ne qw| counted |
                    or ( $status->{$name}{'coverage'} // '' )
                    !~ m{\A(?:full|scrub)\z}
                    or not $status->{$name}{'covered_set'};
                $proofs{$address}{'holders'}{$name} = TRUE
                    if $status->{$name}{'covered_set'}{$address};
            }
        }
        $gate{'nodes'}  = $nodes;
        $gate{'proofs'} = \%proofs;
        1;
    };
    $gate{'coverage_error'} = $EVAL_ERROR if not $copies_ok;

    require AMOS7::N7FS::Drill;
    my $drill_ok = eval {
        $gate{'drill'} = AMOS7::N7FS::Drill::drill_latest( $host_dir, $root );
        $gate{'drill_max_age'} = 2 * parse_y_age( $c->{'drill-every'} );
        1;
    };
    $gate{'drill_error'} = $EVAL_ERROR if not $drill_ok;
    for my $key (
        qw| stale_error coverage_error drill_error freeze_error clock_error |)
    {
        next if not defined $gate{$key};
        chomp $gate{$key};
        $gate{$key} =~ s|\s+| |g;
    }
    return cycle_gate(%gate);
}

sub _gate_report {
    my ( $state, $gate, $rule ) = @_;
    foreach my $condition ( $gate->{'conditions'}->@* ) {
        my $name   = $condition->{'name'};
        my $result = $condition->{'ok'} ? qw| ok | : qw| shut |;
        my $detail = $condition->{'detail'} // '';
        $detail =~ s|\s+| |g;
        $state->{"gate.$name.result"} = $result;
        $state->{"gate.$name.detail"} = $detail;
        _say( 'gate ', $name, ' : ', $result, ' [ ', $detail, ' ]' );
    }
    my $result = $gate->{'ok'} ? qw| open | : qw| shut |;
    $state->{'step.gate.result'} = $result;
    $state->{'step.gate.detail'}
        = $gate->{'ok'}
        ? 'all conditions passed'
        : 'destructive phase skipped';
    $state->{'gate.rule'} = ref $rule eq qw| CODE | ? qw| custom | : $rule;
    _say( 'gate ', $result,
        $gate->{'ok'} ? '' : ' [ no destructive step ran ]' );
    return;
}

sub _retention_prepare {
    my ( $c, $root, $host_dir, $disk_root, $host, $accept_shrink, $issues )
        = @_;
    require AMOS7::N7FS::Disk;
    require AMOS7::N7FS::Journal;
    require AMOS7::N7FS::Tree;
    require AMOS7::N7FS::Snapshot;
    my $registered
        = AMOS7::N7FS::Placement::holders_load( qw| root | => $root );
    my @holders;
    foreach my $name ( sort keys %{$registered} ) {
        next if $issues->{$name};
        my ( undef, $head, $map )
            = AMOS7::N7FS::Seal::_context( $root,
            $registered->{$name}{'spec'}, TRUE );
        push @holders, [ $name, $registered->{$name}{'spec'}, $map ];
    }
    refuse('retain needs a registered holder with a sealed head')
        if not @holders;

    my ( %rules, %pins, %rule_holder );
    foreach my $holder (@holders) {
        my $map = $holder->[2];
        foreach my $prefix ( keys %{ $map->{'retention'} // {} } ) {
            my $rule = $map->{'retention'}{$prefix};
            refuse( 'retention rules differ for %s : %s has %s ; %s has %s',
                $prefix,      $rule_holder{$prefix}, $rules{$prefix},
                $holder->[0], $rule )
                if exists $rules{$prefix} and $rules{$prefix} ne $rule;
            $rules{$prefix}       = $rule;
            $rule_holder{$prefix} = $holder->[0];
        }
        $pins{$ARG} = TRUE for keys %{ $map->{'pins'} // {} };
    }
    foreach my $holder (@holders) {
        foreach my $prefix ( keys %rules ) {
            refuse( 'retention rule %s is missing on %s',
                $prefix, $holder->[0] )
                if not exists $holder->[2]{'retention'}{$prefix};
        }
    }
    my $accepted_prefix = $c->{'prefix'};
    $accepted_prefix =~ s|:+\z||;
    $accepted_prefix .= ':';
    foreach my $prefix ( sort keys %rules ) {
        next if $accept_shrink and $prefix eq $accepted_prefix;
        my $frozen = AMOS7::N7FS::Snapshot::retention_frozen(
            qw| host_dir | => $host_dir,
            qw| disk |     => $c->{'disk'},
            qw| prefix |   => $prefix,
        );
        refuse( 'retention is frozen for %s after a shrunk snapshot [ %s ]',
            $prefix, $frozen->{'tree'} )
            if defined $frozen;
    }

    my %disk_opt = (
        qw| host_dir | => $host_dir,
        qw| disk |     => $c->{'disk'},
    );
    $disk_opt{'root'} = $disk_root if defined $disk_root;
    my $id = AMOS7::N7FS::Disk::disk_read_id(%disk_opt);
    my $stored
        = AMOS7::N7FS::Disk::state_read( $id->{'path'}, $id->{'store_pub'} );
    refuse('retain is only available for store format 3')
        if $stored->{'store_format'} != 3;
    my $replay = AMOS7::N7FS::Journal::journal_replay($id);
    my $trees  = { map { $ARG->{'name'} => $ARG->{'created'} }
            AMOS7::N7FS::Tree::tree_list( $id, $stored, $replay ) };
    my $now
        = AMOS7::N7FS::Placement::n7fs_now( $host_dir, $root->{'root_id'} );
    my ($future) = sort { $b <=> $a } grep { $ARG > $now } values %{$trees};
    refuse( 'newest tree is later than the local clock [ %s > %s ]',
        $future, $now )
        if defined $future;
    my $plan = AMOS7::N7FS::Seal::retention_plan(
        qw| trees | => $trees,
        qw| rules | => \%rules,
        qw| pins |  => \%pins,
        qw| now |   => $now,
    );
    my ( @keep, @drop );

    foreach my $item ( @{$plan} ) {
        push @{ $item->{'keep'} ? \@keep : \@drop }, $item;
    }
    return {
        qw| id |       => $id,
        qw| stored |   => $stored,
        qw| replay |   => $replay,
        qw| holders |  => \@holders,
        qw| keep |     => \@keep,
        qw| drop |     => \@drop,
        qw| disk_opt | => \%disk_opt,
        qw| host |     => $host,
    };
}

sub _retention_addresses {
    my $prep = shift;
    my ( $id, $replay, $holders )
        = @{$prep}{qw| id replay holders |};
    my ( @expired, %expired, %kept, %preserved );
    foreach my $item ( $prep->{'keep'}->@* ) {
        my $manifest = $replay->{'trees'}{ $item->{'tree'} }{'manifest'};
        $kept{$ARG} = TRUE
            for AMOS7::N7FS::Seal::_manifest_files( $id, $manifest );
    }
    foreach my $item ( $prep->{'drop'}->@* ) {
        my $manifest = $replay->{'trees'}{ $item->{'tree'} }{'manifest'};
        push @expired, $manifest,
            AMOS7::N7FS::Seal::_manifest_files( $id, $manifest );
    }
    %expired = map { $ARG => TRUE } @expired;
    foreach my $target ( @{$holders} ) {
        foreach my $address ( keys $target->[2]{'nodes'}->%* ) {
            next if not $expired{$address};
            my $disks = $target->[2]{'nodes'}{$address}{'disks'} // {};
            $preserved{$address} = TRUE
                if grep { $ARG ne $id->{'disk'} } keys %{$disks};
        }
    }
    return ( \@expired, \%kept, \%preserved );
}

sub _retention_drop_local {
    my $prep = shift;
    my ( $id, $replay, $host )
        = @{$prep}{qw| id replay host |};
    my ( $expired, $kept, $preserved ) = _retention_addresses($prep);
    my %expired = map { $ARG => TRUE } @{$expired};
    my ( %import_roots, %reference_dropped );
    foreach my $item ( $prep->{'drop'}->@* ) {
        my $tree = $replay->{'trees'}{ $item->{'tree'} };
        my ( $fh, $head )
            = AMOS7::N7FS::Tree::manifest_open( $id, $prep->{'stored'},
            $tree );
        close $fh;
        require AMOS7::N7FS;
        my $source = AMOS7::N7FS::unb32( $head->{'root_b32'} // '' )
            // refuse('retain : a tree manifest has no valid source root');
        push $import_roots{ $tree->{'created'} }->@*, $source;
    }
    foreach my $item ( $prep->{'drop'}->@* ) {
        my $tree = $replay->{'trees'}{ $item->{'tree'} };
        my @refs = map {
            $replay->{'references'}{ join "\0", @{$ARG}{qw| node path |} }
                // ()
        } $tree->{'references'}->@*;
        if ( not $tree->{'references'} ) {
            push @refs, grep {
                my $ref = $ARG;
                $ref->{'ntime'} eq $tree->{'created'}
                    and grep {
                    my $source = $ARG;
                    $ref->{'holder'} eq $source
                        or index( $ref->{'holder'}, "$source/" ) == 0
                    } $import_roots{ $ref->{'ntime'} }->@*
            } values $replay->{'references'}->%*;
        }
        @refs = grep {
                    $expired{ $ARG->{'node'} }
                and not $kept->{ $ARG->{'node'} }
                and not $preserved->{ $ARG->{'node'} }
                and
                not $reference_dropped{ join "\0", @{$ARG}{qw| node path |} }
        } @refs;
        $reference_dropped{ join "\0", @{$ARG}{qw| node path |} } = TRUE
            for @refs;
        AMOS7::N7FS::Tree::tree_drop(
            $prep->{'disk_opt'}->%*,
            qw| host |       => $host,
            qw| name |       => $item->{'tree'},
            qw| references | => \@refs,
        );
    }
    return scalar $prep->{'drop'}->@*;
}

sub _retention_prune {
    my ( $prep, $target, $root, $host_dir, $disk_root, $host ) = @_;
    my ( $expired, undef, $preserved ) = _retention_addresses($prep);
    return AMOS7::N7FS::Placement::holder_prune(
        $prep->{'disk_opt'}->%*,
        defined $disk_root ? ( qw| disk_root | => $disk_root ) : (),
        qw| root |           => $root,
        qw| host_dir |       => $host_dir,
        qw| host |           => $host,
        qw| host_pub |       => $host->public,
        qw| name |           => $target->[0],
        qw| tree_addresses | => $expired,
        qw| keep_addresses | => [ keys %{$preserved} ],
    );
}

sub _pending_names {
    my ( $host_dir, $root, $spec ) = @_;
    my $path = _relay_pending_path( $host_dir, $root, $spec );
    return [] if not -f $path;
    my $data = eval { $JSON->decode( read_file($path) ) };
    refuse( 'pending relay list is invalid [ %s ]', $path )
        if ref $data ne qw| HASH |
        or ref $data->{'blobs'} ne qw| ARRAY |;
    return $data->{'blobs'};
}

sub _destructive_phase {
    my %opt       = @_;
    my $state     = $opt{'state'};
    my $run_step  = $opt{'run_step'};
    my $c         = $opt{'config'};
    my $root      = $opt{'root'};
    my $host      = $opt{'host'};
    my $host_dir  = $opt{'host_dir'};
    my $disk_root = $opt{'disk_root'};
    my $dry       = $opt{'dry_run'} ? TRUE : FALSE;
    my $rule      = $opt{'rule'} // 'strict';
    require AMOS7::N7FS::Seal;
    require AMOS7::N7FS::Placement;
    my $gate = _gate_evidence( $c, $root, $host_dir, $disk_root, $state,
        $opt{'accept_shrink'}, $rule );

    if ($dry) {
        my ($additive)
            = grep { $ARG->{'name'} eq qw| additive | }
            $gate->{'conditions'}->@*;
        $additive->{'detail'}
            = 'additive changes not run [ dry-run ] ; current state checked';
    }
    _gate_report( $state, $gate, $rule );
    return { qw| gate | => $gate, qw| failed | => FALSE }
        if not $gate->{'ok'} and not $dry;

    my $registered
        = AMOS7::N7FS::Placement::holders_load( qw| root | => $root );
    my @names      = sort keys %{$registered};
    my $error_text = sub {
        my $error = shift // 'step failed';
        chomp $error;
        $error =~ s|\s+| |g;
        return $error;
    };
    my ( %blocked, %issues );
    foreach my $name (@names) {
        my ( undef, $head ) = eval {
            AMOS7::N7FS::Seal::_context( $root, $registered->{$name}{'spec'},
                TRUE );
        };
        $issues{$name} = $error_text->($EVAL_ERROR) if $EVAL_ERROR;
        $issues{$name} = 'no sealed head'
            if not $EVAL_ERROR and not defined $head;
        $blocked{$name} = TRUE if $issues{$name};
    }
    my $skip_blocked = sub {
        my ( $step, $name ) = @_;
        _holder_result( $state, $step, $name, qw| skipped |,
            'holder unavailable or an earlier destructive step failed' );
        return;
    };
    my $guarded_step = $run_step;
    $run_step = sub {
        my ( $step, $code ) = @_;
        my $result = $guarded_step->( $step, $code );
        if ( ( $state->{"step.$step.result"} // '' ) eq qw| failed | ) {
            $blocked{$ARG} = TRUE for @names;
        }
        return $result;
    };

    $run_step->(
        'D1-retain',
        sub {
            my $wait = grep { $issues{$ARG} ne 'no sealed head' }
                grep { $issues{$ARG} } @names;
            if ( not $c->{'retain'} ) {
                _holder_result( $state, 'D1-retain', $ARG, qw| skipped |,
                    'retain = no' )
                    for @names;
                return {
                    $wait ? ( qw| result | => qw| degraded | ) : (),
                    qw| detail | => 'retention disabled'
                };
            }
            my $prep = eval {
                _retention_prepare( $c, $root, $host_dir, $disk_root, $host,
                    $opt{'accept_shrink'}, \%issues );
            };
            if ( not defined $prep ) {
                my $error = $error_text->($EVAL_ERROR);
                $blocked{$ARG} = TRUE for @names;
                _holder_result( $state, 'D1-retain', $ARG, qw| failed |,
                    $error )
                    for @names;
                return {
                    qw| result | => qw| failed |,
                    qw| detail | => $error
                };
            }
            foreach my $name (@names) {
                next if not $issues{$name};
                _holder_result(
                    $state,
                    'D1-retain',
                    $name,
                    $issues{$name} eq 'no sealed head'
                    ? qw| skipped |
                    : qw| degraded |,
                    $issues{$name}
                );
            }
            foreach my $item ( $prep->{'keep'}->@*, $prep->{'drop'}->@* ) {
                _say( '  ', $item->{'keep'} ? 'keep ' : 'drop ',
                    $item->{'tree'}, ' [ ', $item->{'reason'}, ' ]' );
            }
            my ($expired) = _retention_addresses($prep);
            my $drops = scalar $prep->{'drop'}->@*;
            if ($dry) {
                foreach my $target ( $prep->{'holders'}->@* ) {
                    _holder_result(
                        $state,
                        'D1-retain',
                        $target->[0],
                        qw| ok |,
                        "would drop $drops trees locally and prune at most "
                            . scalar( @{$expired} )
                            . ' expired addresses'
                    );
                }
                return {
                    $wait ? ( qw| result | => qw| degraded | ) : (),
                    qw| detail | => "would drop $drops "
                        . "trees ; nothing changed"
                };
            }
            if ( $wait and $drops ) {
                my $error
                    = "retention has $drops drops planned "
                    . "while a holder is unreachable"
                    . ' ; its pins and disk tags cannot be checked';
                $blocked{$ARG} = TRUE for @names;
                _holder_result( $state, 'D1-retain', $ARG, qw| failed |,
                    $error )
                    for grep { not $issues{$ARG} } @names;
                return {
                    qw| result | => qw| failed |,
                    qw| detail | => $error
                };
            }
            my $local = eval { _retention_drop_local($prep) };
            if ( not defined $local ) {
                my $error = $error_text->($EVAL_ERROR);
                $blocked{$ARG} = TRUE for @names;
                _holder_result( $state, 'D1-retain', $ARG, qw| failed |,
                    "local retain : $error" )
                    for @names;
                return {
                    qw| result | => qw| failed |,
                    qw| detail | => $error
                };
            }
            my $bad = FALSE;
            foreach my $target ( $prep->{'holders'}->@* ) {
                my $r = eval {
                    _retention_prune( $prep, $target, $root, $host_dir,
                        $disk_root, $host );
                };
                if ( not defined $r ) {
                    my $error = $error_text->($EVAL_ERROR);
                    $blocked{ $target->[0] } = TRUE;
                    $bad = TRUE;
                    _holder_result( $state, 'D1-retain', $target->[0],
                        qw| failed |, $error );
                    next;
                }
                _holder_result( $state, 'D1-retain', $target->[0], qw| ok |,
                          "dropped $drops trees locally ; pruned "
                        . "$r->{'drop'} nodes and $r->{'trees'} "
                        . "trees" );
            }
            return {
                  $bad  ? ( qw| result | => qw| failed | )
                : $wait ? ( qw| result | => qw| degraded | )
                : (),
                qw| detail | => "$drops trees dropped locally"
            };
        }
    );

    $run_step->(
        'D2-repack',
        sub {
            my ( $bad, $packs ) = ( FALSE, 0 );
            foreach my $name (@names) {
                if ( $blocked{$name} ) {
                    $skip_blocked->( 'D2-repack', $name );
                    next;
                }
                if ( not $c->{'repack'} ) {
                    _holder_result( $state, 'D2-repack', $name, qw| skipped |,
                        'repack = no' );
                    next;
                }
                my $spec = $registered->{$name}{'spec'};
                my $r    = eval {
                    AMOS7::N7FS::Seal::repack_packs(
                        qw| root |      => $root,
                        qw| holder |    => $spec,
                        qw| host_dir |  => $host_dir,
                        qw| signer |    => $host,
                        qw| threshold | => 30,
                        qw| dry_run |   => $dry,
                        qw| grace |     => parse_y_age( $c->{'gc-grace'} ),
                        qw| keep |      =>
                            _pending_names( $host_dir, $root, $spec ),
                        qw| only_root | => FALSE,
                    );
                };
                if ( not defined $r ) {
                    my $error = $error_text->($EVAL_ERROR);
                    $blocked{$name} = TRUE;
                    $bad = TRUE;
                    _holder_result( $state, 'D2-repack', $name, qw| failed |,
                        $error );
                    next;
                }
                $packs += scalar $r->{'packs'}->@*;
                _holder_result(
                    $state,
                    'D2-repack',
                    $name,
                    qw| ok |,
                    sprintf '%s%d packs',
                    $dry ? 'would repack ' : 'repacked ',
                    scalar $r->{'packs'}->@*
                );
            }
            return {
                $bad ? ( qw| result | => qw| failed | ) : (),
                qw| detail | => ( $dry ? 'would repack ' : 'repacked ' )
                    . "$packs packs"
            };
        }
    );

    $run_step->(
        'D3-gc',
        sub {
            my ( $bad, $removed, $bytes ) = ( FALSE, 0, 0 );
            foreach my $name (@names) {
                if ( $blocked{$name} ) {
                    $skip_blocked->( 'D3-gc', $name );
                    next;
                }
                my $spec = $registered->{$name}{'spec'};
                my $r    = eval {
                    my $receipt
                        = AMOS7::N7FS::Placement::receipt_fresh( $host_dir,
                        $root, $spec, ntime_now() );
                    AMOS7::N7FS::Seal::holder_gc(
                        qw| root |    => $root,
                        qw| holder |  => $spec,
                        qw| receipt | => $receipt,
                        qw| grace |   => parse_y_age( $c->{'gc-grace'} ),
                        qw| keep |    =>
                            _pending_names( $host_dir, $root, $spec ),
                        qw| only_root | => FALSE,
                        qw| delete |    => $dry ? FALSE : TRUE,
                    );
                };
                if ( not defined $r ) {
                    my $error = $error_text->($EVAL_ERROR);
                    $blocked{$name} = TRUE;
                    $bad = TRUE;
                    _holder_result( $state, 'D3-gc', $name, qw| failed |,
                        $error );
                    next;
                }
                $removed += $r->{'removed'};
                $bytes   += $r->{'bytes'};
                _holder_result(
                    $state,
                    'D3-gc',
                    $name,
                    qw| ok |,
                    sprintf '%s%d blobs, %d bytes [ %d young kept ]',
                    $dry ? 'would trash ' : 'trashed ',
                    $r->{'removed'},
                    $r->{'bytes'},
                    $r->{'young'}
                );
            }
            return {
                $bad ? ( qw| result | => qw| failed | ) : (),
                qw| detail | => ( $dry ? 'would trash ' : 'trashed ' )
                    . "$removed blobs, $bytes bytes"
            };
        }
    );

    $run_step->(
        'D4-purge',
        sub {
            my ( $bad, $days, $bytes ) = ( FALSE, 0, 0 );
            foreach my $name (@names) {
                if ( $blocked{$name} ) {
                    $skip_blocked->( 'D4-purge', $name );
                    next;
                }
                my $spec = $registered->{$name}{'spec'};
                my $r    = eval {
                    AMOS7::N7FS::Seal::holder_trash_purge(
                        qw| root |   => $root,
                        qw| holder | => $spec,
                        qw| older |  => parse_y_age( $c->{'trash-age'} ),
                        qw| delete | => $dry ? FALSE : TRUE,
                    );
                };
                if ( not defined $r ) {
                    my $error = $error_text->($EVAL_ERROR);
                    $blocked{$name} = TRUE;
                    $bad = TRUE;
                    _holder_result( $state, 'D4-purge', $name, qw| failed |,
                        $error );
                    next;
                }
                $days  += $r->{'days'};
                $bytes += $r->{'bytes'};
                _holder_result(
                    $state,
                    'D4-purge',
                    $name,
                    qw| ok |,
                    sprintf '%s%d trash buckets, %d bytes',
                    $dry ? 'would purge ' : 'purged ',
                    $r->{'days'},
                    $r->{'bytes'}
                );
            }
            return {
                $bad ? ( qw| result | => qw| failed | ) : (),
                qw| detail | => ( $dry ? 'would purge ' : 'purged ' )
                    . "$days trash buckets, $bytes bytes"
            };
        }
    );

    $run_step->(
        'D5-reclaim',
        sub {
            if ( lc( $c->{'reclaim-local'} ) eq qw| no | ) {
                _holder_result( $state, 'D5-reclaim', qw| local |,
                    qw| skipped |, 'reclaim-local = no' );
                return { qw| detail | => 'local reclaim disabled' };
            }
            refuse('local reclaim requires a snapshot-only disk')
                if not $c->{'snapshot-only'}
                or $c->{'reclaim-local'} ne qw| 13Y2 |;
            if ( grep { $blocked{$ARG} } @names and not $dry ) {
                _holder_result( $state, 'D5-reclaim', qw| local |,
                    qw| skipped |, 'an earlier holder step failed' );
                return { qw| detail | => 'local reclaim blocked' };
            }
            require AMOS7::N7FS::Release;
            my %disk_opt = (
                qw| host_dir | => $host_dir,
                qw| disk |     => $c->{'disk'},
                qw| host |     => $host,
                qw| older |    => parse_y_age('13Y2'),
                qw| dry_run |  => $dry,
            );
            $disk_opt{'root'} = $disk_root if defined $disk_root;
            my $r = eval { AMOS7::N7FS::Release::store_reclaim(%disk_opt) };
            if ( not defined $r ) {
                my $error = $error_text->($EVAL_ERROR);
                _holder_result(
                    $state, 'D5-reclaim', qw| local |, qw| failed |,
                    $error
                );
                return {
                    qw| result | => qw| failed |,
                    qw| detail | => $error
                };
            }
            my $count = scalar $r->{'released'}->@*;
            _holder_result(
                $state,
                'D5-reclaim',
                qw| local |,
                qw| ok |,
                sprintf '%s%d nodes, %d bytes older than 13Y2 [ %d held ]',
                $dry ? 'would reclaim ' : 'reclaimed ',
                $count,
                $r->{'freed'},
                scalar keys $r->{'held'}->%*
            );
            return {
                qw| detail | => ( $dry ? 'would reclaim ' : 'reclaimed ' )
                    . "$count nodes, $r->{'freed'} bytes" };
        }
    );

    my $failed
        = grep { ( $state->{"step.$ARG.result"} // '' ) eq qw| failed | }
        qw| D1-retain D2-repack D3-gc D4-purge D5-reclaim |;
    my $degraded
        = grep { ( $state->{"step.$ARG.result"} // '' ) eq qw| degraded | }
        qw| D1-retain D2-repack D3-gc D4-purge D5-reclaim |;
    _say('dry-run : no destructive data or state was changed') if $dry;
    return {
        qw| gate |     => $gate,
        qw| failed |   => $failed   ? TRUE : FALSE,
        qw| degraded | => $degraded ? TRUE : FALSE
    };
}

sub _cycle_dry_run {
    my %opt      = @_;
    my $host_dir = $opt{'host_dir'} // refuse('cycle needs a host dir');
    my $name     = _name_ok( $opt{'name'} );
    my ( $c, $root, $host );
    my $preflight = eval {
        $c    = config_read( $host_dir, $name );
        $root = _open_root( $c, $host_dir );
        $host = key_file_signer( $opt{'host_key'} // "$host_dir/host.key" );
        require AMOS7::N7FS::Disk;
        require AMOS7::N7FS::Placement;
        require AMOS7::N7FS::Seal;
        my $status = AMOS7::N7FS::Disk::disk_status(
            defined $opt{'root'} ? ( qw| root | => $opt{'root'} ) : (),
            qw| host_dir |       => $host_dir,
            qw| host |           => $host,
            qw| disk |           => $c->{'disk'},
            qw| allow_rollback | => FALSE,
        );
        refuse( 'cycle disk is not attached here [ %s ]', $c->{'disk'} )
            if not defined $status->{'attached'};
        1;
    };
    return { qw| exit | => 4, qw| error | => $EVAL_ERROR }
        if not $preflight;
    my $state = {
        qw| format | => 1,
        qw| cycle |  => $name,
        qw| period | => $c->{'period'},
    };
    my $run_step = sub {
        my ( $step, $code ) = @_;
        my $result = eval { fault("cycle:before-$step"); $code->() };
        if ( not defined $result ) {
            my $error = $EVAL_ERROR // 'step failed';
            chomp $error;
            $error =~ s|\s+| |g;
            $state->{"step.$step.result"} = qw| failed |;
            $state->{"step.$step.detail"} = $error;
            _say( $step, ' failed [ ', $error, ' ]' );
            return;
        }
        $state->{"step.$step.result"} = $result->{'result'} // qw| ok |;
        $state->{"step.$step.detail"} = $result->{'detail'} // '';
        _say(
            $step,
            ' ',
            $result->{'result'} // 'ok',
            length( $result->{'detail'} // '' )
            ? ' [ ' . $result->{'detail'} . ' ]'
            : ''
        );
        return $result;
    };
    _say(     'dry-run : additive steps are not '
            . 'run ; no locks or state are written' );
    my $destructive = _destructive_phase(
        qw| state |         => $state,
        qw| run_step |      => $run_step,
        qw| config |        => $c,
        qw| root |          => $root,
        qw| host |          => $host,
        qw| host_dir |      => $host_dir,
        qw| disk_root |     => $opt{'root'},
        qw| dry_run |       => TRUE,
        qw| accept_shrink | => $opt{'accept_shrink'} ? TRUE : FALSE,
        qw| rule |          => $opt{'gate_rule'} // 'strict',
    );
    my $exit
        = $destructive->{'failed'}                                       ? 2
        : not $destructive->{'gate'}{'ok'} || $destructive->{'degraded'} ? 1
        :                                                                  0;
    $state->{'last.result'}
        = $exit == 2 ? qw| failed |
        : $exit == 1 ? qw| degraded |
        :              qw| clean |;
    return { qw| exit | => $exit, qw| state | => $state };
}

sub cycle_run {
    my %opt      = @_;
    my $host_dir = $opt{'host_dir'} // refuse('cycle needs a host dir');
    my $name     = _name_ok( $opt{'name'} );
    return _cycle_dry_run(%opt) if $opt{'dry_run'};
    make_dirs( _cycle_dir($host_dir), 0700 );
    my $cycle_lock
        = _lock( _cycle_dir($host_dir) . "/$name.lock", 'cycle lock' );
    return {
        qw| exit |  => 3,
        qw| error | => 'another cycle with this name is running'
        }
        if _busy($cycle_lock);
    my $writer_lock = _lock( "$host_dir/holders.lock", 'holder-writer lock' );
    return {
        qw| exit |  => 3,
        qw| error | => 'another n7fs holder writer is running'
        }
        if _busy($writer_lock);

    my ( $c, $root, $host, $state );
    my $preflight = eval {
        $c = config_read( $host_dir, $name );
        refuse(
            'leftover cycle state temporary file [ %s ]',
            _state_path( $host_dir, $name ) . '.tmp'
            )
            if -e _state_path( $host_dir, $name ) . '.tmp'
            or -l _state_path( $host_dir, $name ) . '.tmp';
        $root = _open_root( $c, $host_dir );
        my $host_key = $opt{'host_key'} // "$host_dir/host.key";
        $host = key_file_signer($host_key);
        require AMOS7::N7FS::Disk;
        my $status = AMOS7::N7FS::Disk::disk_status(
            defined $opt{'root'} ? ( qw| root | => $opt{'root'} ) : (),
            qw| host_dir |       => $host_dir,
            qw| host |           => $host,
            qw| disk |           => $c->{'disk'},
            qw| allow_rollback | => FALSE,
        );
        refuse( 'cycle disk is not attached here [ %s ]', $c->{'disk'} )
            if not defined $status->{'attached'};
        require AMOS7::N7FS::Placement;
        AMOS7::N7FS::Placement::n7fs_now( $host_dir, $root->{'root_id'} );
        1;
    };
    if ( not $preflight ) {
        my $error = $EVAL_ERROR // "n7fs : cycle preflight refused\n";
        return { qw| exit | => 4, qw| error | => $error };
    }
    $state = {
        qw| format |       => 1,
        qw| cycle |        => $name,
        qw| period |       => $c->{'period'},
        qw| last.started | => ntime14( ntime_now() ),
    };
    my $previous = state_read( $host_dir, $name );
    $state->{$ARG} = $previous->{$ARG}
        for grep {m|\Ascrub\..+\.last\z|} keys %{$previous};
    $state->{'last.ok'} = $previous->{'last.ok'}
        if defined $previous->{'last.ok'};
    my $now = ntime_now();
    $state->{'drill.next-due'} = $previous->{'drill.next-due'}
        if defined $previous->{'drill.next-due'};
    my ( $holders, $survey );
    my $survey_ok = eval {
        $holders
            = AMOS7::N7FS::Placement::holders_load( qw| root | => $root );
        require AMOS7::N7FS::Seal;
        $survey = AMOS7::N7FS::Seal::head_survey( $root,
            { map { $ARG => $holders->{$ARG}{'spec'} } keys %{$holders} } );
        require AMOS7::N7FS::Holder;
        foreach my $hname ( keys %{$holders} ) {
            my $h = AMOS7::N7FS::Holder::holder_parse(
                $holders->{$hname}{'spec'} );
            $survey->{$hname}{'error'} = 'holder directory is missing'
                if $h->{'type'} eq qw| local | and not -d $h->{'dir'};
        }
        1;
    };
    return { qw| exit | => 4, qw| error | => $EVAL_ERROR }
        if not $survey_ok;
    my ( $failed, $degraded ) = ( FALSE, FALSE );
    my %adopted;
    my %written;

    my $run_step = sub {
        my ( $step, $code ) = @_;
        my $start = ntime_now();
        $state->{"step.$step.started"} = ntime14($start);
        my $result = eval { fault("cycle:before-$step"); $code->() };
        if ( not defined $result ) {
            my $error = $EVAL_ERROR // 'step failed';
            chomp $error;
            $error =~ s|\s+| |g;
            $state->{"step.$step.result"} = qw| failed |;
            $state->{"step.$step.detail"} = $error;
            _say( $step, ' failed [ ', $error, ' ]' );
            $failed = TRUE;
        } else {
            $state->{"step.$step.result"} = $result->{'result'} // qw| ok |;
            $state->{"step.$step.detail"} = $result->{'detail'} // '';
            $degraded                     = TRUE
                if ( $result->{'result'} // '' ) eq qw| degraded |;
            _say(
                $step,
                ' ',
                $result->{'result'} // 'ok',
                length( $result->{'detail'} // '' )
                ? ' [ ' . $result->{'detail'} . ' ]'
                : ''
            );
        }
        my $took = ntime_now() - $start;
        $state->{"step.$step.took"} = $took < 0 ? 0 : $took;
        return $result;
    };

    $run_step->(
        'A0-preflight',
        sub {
            my $wait = 0;
            foreach my $hname ( sort keys %{$holders} ) {
                my $item = $survey->{$hname};
                my $condition
                    = $item->{'stale'} ? qw| stale |
                    : $item->{'error'} ? qw| unreachable |
                    : $item->{'head'}  ? qw| current |
                    :                    qw| empty |;
                $wait++
                    if $condition eq qw| stale |
                    or $condition eq qw| unreachable |;
                _holder_result(
                    $state,
                    'A0-preflight',
                    $hname,
                    $wait
                        && $condition ne qw| current |
                        && $condition ne qw| empty |
                    ? qw| degraded |
                    : qw| ok |,
                    $condition
                        . (
                        $item->{'error'} ? ' : ' . $item->{'error'} : ''
                        )
                );
            }
            return {
                ( $wait ? ( qw| result | => qw| degraded | ) : () ),
                qw| detail | => scalar( keys %{$holders} )
                    . ' holders surveyed'
            };
        }
    );
    return _finish( $host_dir, $name, $state, $failed, $degraded ) if $failed;

    my $available = sub {
        my $hname = shift;
        return (    not $survey->{$hname}{'stale'}
                and not $survey->{$hname}{'error'} );
    };

    $run_step->(
        'A1-snapshot',
        sub {
            return { qw| detail | => 'no source configured' }
                if not defined $c->{'source'};
            require AMOS7::N7FS::Snapshot;
            my $r = AMOS7::N7FS::Snapshot::snapshot_run(
                defined $opt{'root'} ? ( qw| root | => $opt{'root'} ) : (),
                qw| host_dir |       => $host_dir,
                qw| disk |           => $c->{'disk'},
                qw| host |           => $host,
                qw| source |         => $c->{'source'},
                qw| method |         => $c->{'snapshot'},
                qw| tree |           => $c->{'prefix'},
                qw| staging |        => $c->{'staging'},
                qw| keep_staging |   => $c->{'keep-staging'},
                qw| shrink_limit |   => $c->{'shrink-limit'},
                qw| snapshot_cmd |   => $c->{'snapshot-cmd'},
                qw| category |       => $c->{'category'},
                qw| category_rules | => [],
                qw| protect | => [ $opt{'host_key'} // "$host_dir/host.key" ],
            );
            my $wait = $r->{'unstable'} || $r->{'shrunk'};
            return {
                $wait ? ( qw| result | => qw| degraded | ) : (),
                qw| detail | => sprintf '%s, %d files, %d unstable%s',
                $r->{'tree'}, $r->{'files'}, $r->{'unstable'},
                $r->{'shrunk'} ? ', retention frozen' : ''
            };
        }
    );

    $run_step->(
        'A2-place',
        sub {
            my @exclude = grep { not $available->($ARG) } keys %{$holders};
            my $r       = AMOS7::N7FS::Placement::place_missing(
                defined $opt{'root'}
                ? ( qw| root |      => $opt{'root'},
                    qw| disk_root | => $opt{'root'}
                    )
                : (),
                qw| host_dir |          => $host_dir,
                qw| disk |              => $c->{'disk'},
                qw| root |              => $root,
                qw| host_pub |          => $host->public,
                qw| signer |            => $host,
                qw| exclude |           => \@exclude,
                qw| allow_stale |       => TRUE,
                qw| check_coverage |    => $c->{'check'},
                qw| unreachable_grace | => 0,
            );
            my ( $bad, $wait ) = ( FALSE, FALSE );
            foreach my $hname ( sort keys %{$holders} ) {
                next if defined $holders->{$hname}{'via'};
                my $result = $r->{'results'}{$hname};
                my $check  = $r->{'checks'}{$hname};
                if ( defined $result and not $result->{'ok'} ) {
                    $bad = TRUE;
                    _holder_result( $state, 'A2-place', $hname, qw| failed |,
                        $result->{'error'} );
                } elsif ( defined $check and not $check->{'ok'} ) {
                    $bad = TRUE;
                    _holder_result( $state, 'A2-place', $hname, qw| failed |,
                        $check->{'error'} );
                } elsif ( defined $result ) {
                    $written{$hname} = TRUE;
                    _holder_result( $state, 'A2-place', $hname, qw| ok |,
                              "$result->{'sealed'} nodes, "
                            . "checked $check->{'coverage'}" );
                } elsif ( not $available->($hname) ) {
                    _holder_result( $state, 'A2-place', $hname,
                        qw| degraded |, 'unreachable or stale' );
                } else {
                    _holder_result( $state, 'A2-place', $hname, qw| ok |,
                        'nothing to place' );
                }
            }
            $wait = TRUE if $r->{'unplaced'};
            return {
                  $bad  ? ( qw| result | => qw| failed | )
                : $wait ? ( qw| result | => qw| degraded | )
                : (),
                qw| detail | => "$r->{'unplaced'} nodes under-replicated"
            };
        }
    );
    $failed = TRUE
        if ( $state->{'step.A2-place.result'} // '' ) eq qw| failed |;

    $run_step->(
        'A3-relay',
        sub {
            my ( $bad, $wait, $pending ) = ( FALSE, FALSE, 0 );
            foreach my $hname (
                sort grep { defined $holders->{$ARG}{'via'} }
                keys %{$holders}
            ) {
                my $h   = $holders->{$hname};
                my $hub = $h->{'via'};
                if ( not exists $holders->{$hub} ) {
                    $bad = TRUE;
                    _holder_result( $state, 'A3-relay', $hname, qw| failed |,
                        "unknown via holder $hub" );
                    next;
                }
                if ( not $available->($hname) or not $available->($hub) ) {
                    $wait = TRUE;
                    _holder_result( $state, 'A3-relay', $hname,
                        qw| degraded |,
                        'holder or hub unreachable or stale' );
                    next;
                }
                my $pair = eval {
                    my $adopt = AMOS7::N7FS::Seal::relay_nodes(
                        qw| root |       => $root,
                        qw| from |       => $holders->{$hub}{'spec'},
                        qw| to |         => $h->{'spec'},
                        qw| adopt_only | => TRUE,
                        qw| room |       => sub {
                            AMOS7::N7FS::Placement::holder_room( $h, shift );
                        },
                    );
                    unlink _relay_pending_path( $host_dir, $root,
                        $h->{'spec'} )
                        if not $adopt->{'waiting'};
                    $adopted{$hname} = TRUE if $adopt->{'nodes'};
                    my $list = AMOS7::N7FS::Seal::relay_nodes(
                        qw| root |      => $root,
                        qw| from |      => $holders->{$hub}{'spec'},
                        qw| to |        => $h->{'spec'},
                        qw| list_only | => TRUE,
                    );
                    _relay_list_write( $host_dir, $root,
                        $holders->{$hub}{'spec'},
                        $h->{'spec'}, $list->{'names'}, $list->{'subdir'} );
                    [ $adopt, $list ];
                };
                if ( not defined $pair ) {
                    my $error = $EVAL_ERROR // 'relay failed';
                    chomp $error;
                    $bad = TRUE;
                    _holder_result( $state, 'A3-relay', $hname, qw| failed |,
                        $error );
                    next;
                }
                my ( $adopt, $list ) = @{$pair};
                $wait = TRUE if $adopt->{'waiting'} or $list->{'names'}->@*;
                $pending += $list->{'names'}->@*;
                my $age = _relay_pending_age( $host_dir, $root, $h->{'spec'},
                    ntime_now() );
                $wait = TRUE
                    if defined $age
                    and $age > parse_y_age( $c->{'pending-max'} );
                _holder_result(
                    $state,
                    'A3-relay',
                    $hname,
                    $adopt->{'waiting'}
                        || $list->{'names'}->@* ? qw| degraded | : qw| ok |,
                    sprintf 'adopted %d, listed %d, waiting %d',
                    $adopt->{'nodes'},
                    scalar( $list->{'names'}->@* ),
                    $adopt->{'waiting'}
                );
            }
            return {
                  $bad  ? ( qw| result | => qw| failed | )
                : $wait ? ( qw| result | => qw| degraded | )
                : (),
                qw| detail | => "$pending blobs pending"
            };
        }
    );
    $failed = TRUE
        if ( $state->{'step.A3-relay.result'} // '' ) eq qw| failed |;

    $run_step->(
        'A4-check',
        sub {
            my ( $bad, $wait, $done ) = ( FALSE, FALSE, 0 );
            my $now = ntime_now();
            foreach my $hname ( sort keys %{$holders} ) {
                my $h = $holders->{$hname};
                if ( not $available->($hname) ) {
                    $wait = TRUE;
                    _holder_result( $state, 'A4-check', $hname,
                        qw| degraded |, 'unreachable or stale' );
                    next;
                }
                if (    not defined $survey->{$hname}{'head'}
                    and not $written{$hname}
                    and not $adopted{$hname} ) {
                    $wait = TRUE;
                    _holder_result( $state, 'A4-check', $hname,
                        qw| degraded |, 'no sealed head yet' );
                    next;
                }
                my $receipt
                    = AMOS7::N7FS::Placement::receipt_fresh( $host_dir,
                    $root, $h->{'spec'}, $now );
                my $last      = $previous->{"scrub.$hname.last"};
                my $scrub_age = defined $last ? $now - $last : 9**20;
                my $scrub_due = $h->{'role'} eq qw| durable |
                    && $scrub_age >= parse_y_age( $c->{'scrub-every'} );
                my $receipt_age
                    = defined $receipt ? $now - $receipt->{'time'} : 9**20;
                my $check_due
                    = $adopted{$hname}
                    || $written{$hname}
                    || $receipt_age
                    >= AMOS7::N7FS::Placement::parse_age('3Y2') / 2;
                if ( not $scrub_due and not $check_due ) {
                    _holder_result( $state, 'A4-check', $hname, qw| ok |,
                        'receipt and scrub current' );
                    next;
                }
                my $coverage = $scrub_due ? qw| scrub | : $c->{'check'};
                my $r        = eval {
                    _check_one( $root, $host_dir, $h, $coverage, FALSE );
                };
                if ( not defined $r ) {
                    my $error = $EVAL_ERROR // 'holder check failed';
                    chomp $error;
                    $bad = TRUE;
                    _holder_result( $state, 'A4-check', $hname, qw| failed |,
                        $error );
                    next;
                }
                $done++;
                $state->{"scrub.$hname.last"} = ntime14( ntime_now() )
                    if $scrub_due;
                _holder_result( $state, 'A4-check', $hname, qw| ok |,
                    "$r->{'nodes'} nodes, coverage $r->{'coverage'}" );
            }
            return {
                  $bad  ? ( qw| result | => qw| failed | )
                : $wait ? ( qw| result | => qw| degraded | )
                : (),
                qw| detail | => "$done holders checked"
            };
        }
    );
    $failed = TRUE
        if ( $state->{'step.A4-check.result'} // '' ) eq qw| failed |;

    $run_step->(
        'A5-refresh',
        sub {
            return { qw| detail | => 'refresh disabled' }
                if not $c->{'refresh'};
            my ( $bad, $wait, $done ) = ( FALSE, FALSE, 0 );
            foreach my $hname ( sort keys %{$holders} ) {
                if ( not $available->($hname) ) {
                    $wait = TRUE;
                    _holder_result( $state, 'A5-refresh', $hname,
                        qw| degraded |, 'unreachable or stale' );
                    next;
                }
                if (    not defined $survey->{$hname}{'head'}
                    and not $written{$hname}
                    and not $adopted{$hname} ) {
                    $wait = TRUE;
                    _holder_result( $state, 'A5-refresh', $hname,
                        qw| degraded |, 'no sealed head' );
                    next;
                }
                my $r = eval {
                    AMOS7::N7FS::Seal::head_refresh( $root,
                        $holders->{$hname}{'spec'} );
                };
                if ( not defined $r ) {
                    my $error = $EVAL_ERROR // 'head refresh failed';
                    chomp $error;
                    $bad = TRUE;
                    _holder_result(
                        $state, 'A5-refresh', $hname, qw| failed |,
                        $error
                    );
                    next;
                }
                $done++;
                _holder_result( $state, 'A5-refresh', $hname, qw| ok |,
                    "head v$r->{'version'}" );
            }
            return {
                  $bad  ? ( qw| result | => qw| failed | )
                : $wait ? ( qw| result | => qw| degraded | )
                : (),
                qw| detail | => "$done heads refreshed"
            };
        }
    );
    $failed = TRUE
        if ( $state->{'step.A5-refresh.result'} // '' ) eq qw| failed |;

    $run_step->(
        'A6-drill',
        sub {
            require AMOS7::N7FS::Drill;
            my $now = ntime_now();
            my $due = $state->{'drill.next-due'} // 0;
            return { qw| detail | => "next due $due" } if $due > $now;
            my $prefix = $c->{'prefix'};
            $prefix =~ s|:+\z||;
            $prefix .= ':';
            my @candidates;

            foreach my $hname ( sort keys %{$holders} ) {
                next
                    if $holders->{$hname}{'role'} ne qw| durable |
                    or not $available->($hname);
                my $tree
                    = _newest_snapshot( $root, $holders->{$hname}{'spec'},
                    $prefix );
                next if not defined $tree;
                my $latest
                    = AMOS7::N7FS::Drill::drill_latest( $host_dir, $root,
                    $holders->{$hname}{'spec'} );
                push @candidates, [ $latest->{'time'} // 0, $hname, $tree ];
            }
            @candidates = sort { $a->[0] <=> $b->[0] or $a->[1] cmp $b->[1] }
                @candidates;
            if ( not @candidates ) {
                $state->{'drill.next-due'}
                    = $now + parse_y_age( $c->{'drill-every'} );
                return {
                    qw| result | => qw| degraded |,
                    qw| detail | => 'no reachable complete snapshot tree'
                };
            }
            my ( $hname, $tree ) = @{ $candidates[0] }[ 1, 2 ];
            if ( not defined $tree ) {
                $state->{'drill.next-due'}
                    = $now + parse_y_age( $c->{'drill-every'} );
                _holder_result( $state, 'A6-drill', $hname, qw| degraded |,
                    'no complete snapshot tree' );
                return {
                    qw| result | => qw| degraded |,
                    qw| detail | => 'no complete snapshot tree'
                };
            }
            my $r = eval {
                local $ENV{'TMPDIR'} = $c->{'drill-scratch'}
                    // $ENV{'TMPDIR'};
                AMOS7::N7FS::Drill::drill_run(
                    qw| root |     => $root,
                    qw| host_dir | => $host_dir,
                    qw| holder |   => $holders->{$hname}{'spec'},
                    qw| tree |     => $tree,
                );
            };
            $state->{'drill.next-due'}
                = $now + parse_y_age( $c->{'drill-every'} );
            if ( not defined $r ) {
                my $error = $EVAL_ERROR // 'drill failed';
                chomp $error;
                _holder_result( $state, 'A6-drill', $hname, qw| failed |,
                    $error );
                die $error;
            }
            $state->{'drill.last'}   = ntime14( ntime_now() );
            $state->{'drill.holder'} = $hname;
            _holder_result( $state, 'A6-drill', $hname, qw| ok |,
                "$r->{'tree'}, $r->{'files'} files" );
            return { qw| detail | => "$hname : $r->{'tree'} passed" };
        }
    );
    $failed = TRUE
        if ( $state->{'step.A6-drill.result'} // '' ) eq qw| failed |;
    if ( $opt{'no_destructive'} ) {
        $state->{'destructive.result'} = qw| skipped |;
        _say('destructive phase disabled [ -no-destructive ]');
        return _finish( $host_dir, $name, $state, $failed, $degraded );
    }
    my $destructive = _destructive_phase(
        qw| state |         => $state,
        qw| run_step |      => $run_step,
        qw| config |        => $c,
        qw| root |          => $root,
        qw| host |          => $host,
        qw| host_dir |      => $host_dir,
        qw| disk_root |     => $opt{'root'},
        qw| accept_shrink | => $opt{'accept_shrink'} ? TRUE : FALSE,
        qw| rule |          => $opt{'gate_rule'} // 'strict',
    );
    $failed   = TRUE if $destructive->{'failed'};
    $degraded = TRUE
        if not $destructive->{'gate'}{'ok'} or $destructive->{'degraded'};
    return _finish( $host_dir, $name, $state, $failed, $degraded );
}

sub _finish {
    my ( $host_dir, $name, $state, $failed, $degraded ) = @_;
    my $exit = $failed ? 2 : $degraded ? 1 : 0;
    $state->{'last.finished'} = ntime14( ntime_now() );
    $state->{'last.exit'}     = $exit;
    $state->{'last.result'}
        = $exit == 2 ? qw| failed |
        : $exit == 1 ? qw| degraded |
        :              qw| clean |;
    $state->{'last.ok'} = $state->{'last.finished'} if $exit == 0;
    _state_write( $host_dir, $name, $state );
    return { qw| exit | => $exit, qw| state | => $state };
}

sub cycle_status {
    my %opt      = @_;
    my $host_dir = $opt{'host_dir'}
        // refuse('cycle status needs a host dir');
    my $name  = _name_ok( $opt{'name'} );
    my $state = state_read( $host_dir, $name );
    return { qw| exit | => 1, qw| error | => "no cycle state for $name\n" }
        if not keys %{$state};
    my $now      = ntime_now();
    my $finished = $state->{'last.finished'} // 0;
    _say(
        'cycle ',
        $name,
        ' : ',
        $state->{'last.result'} // 'unknown',
        ' [ last run ',
        $finished || '-',
        ', ',
        y_age_str( $now - $finished ),
        ' ago, exit ',
        $state->{'last.exit'} // '-',
        ' ]'
    );

    foreach my $step (@STEPS) {
        next if not exists $state->{"step.$step.result"};
        _say(
            $step,
            ' ',
            $state->{"step.$step.result"},
            ' [ started ',
            $state->{"step.$step.started"} // '-',
            ', took ',
            y_age_str( $state->{"step.$step.took"} // 0 ),
            length( $state->{"step.$step.detail"}  // '' )
            ? ', ' . $state->{"step.$step.detail"}
            : '',
            ' ]'
        );
        my $prefix = "step.$step.holder.";
        foreach my $key (
            sort
            grep { index( $ARG, $prefix ) == 0 and $ARG =~ m|\.result\z| }
            keys %{$state}
        ) {
            my $holder = substr( $key, length $prefix );
            $holder =~ s|\.result\z||;
            _say( '  holder ', $holder, ' : ', $state->{$key},
                ' [ ', $state->{"$prefix$holder.detail"} // '', ' ]' );
        }
    }
    foreach my $condition (
        qw| additive stale-head shrink-freeze clock replication drill |) {
        next if not exists $state->{"gate.$condition.result"};
        _say( 'gate ', $condition, ' : ', $state->{"gate.$condition.result"},
            ' [ ', $state->{"gate.$condition.detail"} // '', ' ]' );
    }
    my $due = $state->{'drill.next-due'} // 0;
    _say(
        'next drill due : ',
        $due || '-',
        $due > $now ? ' [ in ' . y_age_str( $due - $now ) . ' ]' : ' [ due ]'
    );
    my $last   = $state->{'last.ok'} // 0;
    my $period = parse_y_age( $state->{'period'} // '1Y4' )
        // parse_y_age('1Y4');
    my $stale = $now - $last > 2 * $period;
    _say(
        'last clean run : ',
        $last || '-',
        ' [ ',     y_age_str( $now - $last ),
        ' ago ; ', $stale ? 'overdue' : 'current', ' ]'
    );
    return { qw| exit | => $stale ? 1 : 0, qw| state | => $state };
}

1;

#,,..,,..,,.,,...,,,.,,..,...,.,.,,..,.,.,..,,..,,...,...,,,,,.,.,,,.,,,.,,..,
#P2UFOXTSTLRAP7RBXPTVTN7WYVHFPVTW2FV75EIYGFQV3PC7OI4SGHNHHN6FQTS7CIO32JOKOP4OQ
#\\\|YRX52QORKXVK67YCPR5D4AGPEJZWQDIKPGQXB7ROMPSWVMSXKTC \ / AMOS7 \ YOURUM ::
#\[7]RA3RXEXJZ3T67XRMV2YK73YZWFV6ZQ5GDA4Y6KR5WCZMN5NNUWDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
