## [:< ##

package AMOS7::N7FS::Snapshot;    ##########################################

## repeatable staging pulls, snapshot manifests and the retention shrink
## guard.

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

our $VERSION   = qw| AMOS7::N7FS::Snapshot-VERSION.UXZLPDQ |;
our $UNSTABLE  = 0;
our $COPY_HOOK = undef;

@EXPORT_OK = qw| snapshot_run snapshot_confirm retention_frozen |;

use Cwd qw| abs_path |;
use Digest::BMW;
use Fcntl       qw| O_RDONLY O_NOFOLLOW |;
use Time::HiRes ();
use AMOS7::N7FS qw| host_dir ntime_now ntime14 make_dirs publish_dir
    remove_tree read_file write_new_file_stream refuse fault |;
use AMOS7::N7FS::Sum     qw| bmw384_fh bmw_b32 |;
use AMOS7::N7FS::Disk    qw| disk_read_id state_read |;
use AMOS7::N7FS::Journal qw| journal_replay |;
use AMOS7::N7FS::Store   qw| assimilate |;
use AMOS7::N7FS::Tree    qw| manifest_open tree_drop |;

my %METHOD = map { $ARG => TRUE } qw| cmd reflink copy-verify hardlink |;

sub _config_path {
    my %opt = @ARG;
    return host_dir(%opt) . '/snapshot-retention.cfg';
}

sub _freeze_read {
    my %opt   = @ARG;
    my $path  = _config_path(%opt);
    my $bytes = read_file($path);
    return {} if not defined $bytes;
    my %frozen;
    my $item;
    foreach my $line ( split m|\n|, $bytes ) {
        next if $line =~ m|\A\s*(?:#.*)?\z|;
        if ( $line =~ m|\A\[([^\]/]+)\/([^\]]+)\]\z| ) {
            my ( $disk, $prefix ) = ( $1, $2 );
            $item = $frozen{$disk}{$prefix} = {};
            next;
        }
        my ( $key, $value ) = $line =~ m|\A\s*([a-z-]+)\s*[=:]\s*(.*?)\s*\z|;
        refuse( 'snapshot freeze config has a bad line [ %s ]', $line )
            if not defined $value or not defined $item;
        $item->{$key} = $value;
    }
    return \%frozen;
}

sub _config_quote {
    my $value = shift // '';
    refuse('snapshot freeze values cannot contain newlines')
        if $value =~ m|[\r\n\]]|;
    return $value;
}

sub _freeze_write {
    my (%opt)  = @ARG;
    my $frozen = delete $opt{'frozen'};
    my $path   = _config_path(%opt);
    make_dirs( host_dir(%opt), 0700 );
    my $tmp = "$path.tmp.$PROCESS_ID";
    write_new_file_stream(
        $tmp,
        sub {
            my $fh = shift;
            foreach my $disk ( sort keys %{$frozen} ) {
                foreach my $prefix ( sort keys $frozen->{$disk}->%* ) {
                    my $item = $frozen->{$disk}{$prefix};
                    print {$fh} '[', _config_quote($disk), '/',
                        _config_quote($prefix), "]\n"
                        or die "write $tmp : $OS_ERROR\n";
                    foreach my $key (
                        qw| tree files bytes previous-files
                        previous-bytes shrink-limit time |
                    ) {
                        next if not defined $item->{$key};
                        printf {$fh} "%-14s = %s\n", $key,
                            _config_quote( $item->{$key} )
                            or die "write $tmp : $OS_ERROR\n";
                    }
                    print {$fh} "\n" or die "write $tmp : $OS_ERROR\n";
                }
            }
        },
        0600
    );
    chmod 0600, $tmp or refuse( 'cannot protect %s : %s', $tmp, $OS_ERROR );
    rename $tmp, $path
        or refuse( 'cannot publish %s : %s', $path, $OS_ERROR );
    return;
}

sub retention_frozen {
    my %opt    = @ARG;
    my $disk   = $opt{'disk'}   // '';
    my $prefix = $opt{'prefix'} // '';
    my $frozen = _freeze_read(%opt);
    return $frozen->{$disk}{$prefix};
}

sub snapshot_confirm {
    my %opt    = @ARG;
    my $disk   = $opt{'disk'}   // refuse('snapshot-confirm needs a disk');
    my $prefix = $opt{'prefix'} // refuse('snapshot-confirm needs a prefix');
    $prefix =~ s|:+\z||;
    $prefix .= ':';
    my $frozen = _freeze_read(%opt);
    refuse( 'snapshot : retention is not frozen for %s on %s',
        $prefix, $disk )
        if not $frozen->{$disk}{$prefix};
    my $tree = $frozen->{$disk}{$prefix}{'tree'};
    delete $frozen->{$disk}{$prefix};
    delete $frozen->{$disk} if not keys $frozen->{$disk}->%*;
    _freeze_write( %opt, qw| frozen | => $frozen );
    return $tree;
}

sub _freeze_snapshot {
    my (%opt) = @ARG;
    my $frozen = _freeze_read(%opt);
    $frozen->{ $opt{'disk'} }{ $opt{'prefix'} } = {
        qw| tree |           => $opt{'tree'},
        qw| files |          => $opt{'files'},
        qw| bytes |          => $opt{'bytes'},
        qw| previous-files | => $opt{'previous'}{'files'},
        qw| previous-bytes | => $opt{'previous'}{'bytes'},
        qw| shrink-limit |   => $opt{'shrink_limit'},
        qw| time |           => ntime14( $opt{'end'} ),
    };
    _freeze_write( %opt, qw| frozen | => $frozen );
    return;
}

sub _shrink_guard {
    my %opt      = @ARG;
    my $previous = $opt{'previous'};
    return FALSE if not defined $previous;
    my $shrunk = FALSE;
    foreach my $key (qw| files bytes |) {
        my $before = $previous->{$key} // 0;
        next if $before <= 0;
        $shrunk = TRUE
            if $opt{$key} < $before * ( 1 - $opt{'shrink_limit'} / 100 );
    }
    _freeze_snapshot(%opt) if $shrunk;
    return $shrunk;
}

sub _run {
    my @cmd = @ARG;
    system { $cmd[0] } @cmd;
    refuse( 'snapshot command failed [ %s ] : exit %d',
        $cmd[0], $CHILD_ERROR == -1 ? $OS_ERROR : $CHILD_ERROR >> 8 )
        if $CHILD_ERROR != 0;
    return;
}

sub _source {
    my $source = shift // refuse('snapshot needs a source');
    return { qw| kind | => qw| local |, qw| path | => $source }
        if $source !~ m{\A(?:local|ssh):};
    return { qw| kind | => qw| local |, qw| path | => $1 }
        if $source =~ m|\Alocal:(.*)\z|s;
    my ( $alias, $path ) = $source =~ m|\Assh:([^:]+):(.*)\z|s;
    refuse( 'snapshot : bad ssh source [ %s ]', $source )
        if not defined $path
        or not length $alias
        or not length $path;
    return {
        qw| kind |   => qw| ssh |,
        qw| alias |  => $alias,
        qw| path |   => $path,
        qw| origin | => $source
    };
}

sub _previous_staging {
    my $staging = shift;
    return () if not -d $staging;
    opendir( my $dh, $staging )
        or refuse( 'cannot read staging %s : %s', $staging, $OS_ERROR );
    my @dirs = sort grep { m|\A\d{14}\z| and -d "$staging/$ARG" } readdir $dh;
    closedir $dh;
    return @dirs;
}

sub _stats {
    my $root = shift;
    my ( $files, $bytes ) = ( 0, 0 );
    my $walk;
    $walk = sub {
        my $path = shift;
        my @st   = lstat $path
            or refuse( 'staging entry vanished [ %s ]', $path );
        if ( -d _ and not -l _ ) {
            opendir( my $dh, $path )
                or refuse( 'cannot read staging %s : %s', $path, $OS_ERROR );
            my @names = grep { $ARG ne '.' and $ARG ne '..' } readdir $dh;
            closedir $dh;
            $walk->("$path/$ARG") for @names;
        } elsif ( -f _ ) {
            $files++;
            $bytes += $st[7];
        }
    };
    $walk->($root);
    return { qw| files | => $files, qw| bytes | => $bytes };
}

sub _digest {
    my $path = shift;
    sysopen( my $fh, $path, O_RDONLY | O_NOFOLLOW )
        or refuse( 'cannot open %s : %s', $path, $OS_ERROR );
    binmode $fh;
    my ($digest) = bmw384_fh($fh);
    close $fh;
    return bmw_b32($digest);
}

sub _copy_file {
    my ( $source, $target ) = @ARG;
    my $stable = FALSE;
    foreach my $attempt ( 1 .. 3 ) {
        my @before = Time::HiRes::lstat($source);
        refuse( 'snapshot source vanished [ %s ]', $source ) if not @before;
        my $tmp = "$target.tmp.$PROCESS_ID";
        unlink $tmp if -e $tmp or -l $tmp;
        write_new_file_stream(
            $tmp,
            sub {
                my $out = shift;
                sysopen( my $in, $source, O_RDONLY | O_NOFOLLOW )
                    or die "cannot open $source : $OS_ERROR\n";
                binmode $in;
                while (1) {
                    my $got = sysread( $in, my $buf, 1048576 );
                    die "read $source : $OS_ERROR\n" if not defined $got;
                    last                             if $got == 0;
                    print {$out} $buf or die "write $tmp : $OS_ERROR\n";
                }
                close $in or die "close $source : $OS_ERROR\n";
            },
            $before[2] & 07777
        );
        fault(qw| snapshot:copy-after-write |);
        $COPY_HOOK->($source) if ref $COPY_HOOK;
        my @after = Time::HiRes::lstat($source);
        my $same
            = @after
            && $before[0] == $after[0]
            && $before[1] == $after[1]
            && $before[7] == $after[7]
            && $before[9] == $after[9]
            && $before[10] == $after[10];
        $same &&= _digest($source) eq _digest($tmp) if $same;
        if ($same) {
            unlink $target if -e $target or -l $target;
            rename $tmp,
                $target
                or refuse( 'cannot publish copied file %s : %s',
                $target, $OS_ERROR );
            utime $before[8], $before[9], $target;
            $stable = TRUE;
            last;
        }
        unlink $tmp    if -e $tmp    or -l $tmp;
        unlink $target if -e $target or -l $target;
        if ( $attempt == 3 ) {
            write_new_file_stream(
                $target,
                sub {
                    my $out = shift;
                    sysopen( my $in, $source, O_RDONLY | O_NOFOLLOW )
                        or die "cannot open $source : $OS_ERROR\n";
                    binmode $in;
                    while (1) {
                        my $got = sysread( $in, my $buf, 1048576 );
                        die "read $source : $OS_ERROR\n" if not defined $got;
                        last                             if $got == 0;
                        print {$out} $buf
                            or die "write $target : $OS_ERROR\n";
                    }
                    close $in;
                },
                $before[2] & 07777
            );
        }
    }
    $UNSTABLE++ if not $stable;
    return $stable;
}

sub _copy_verify {
    my ( $source, $target ) = @ARG;
    my @st = lstat $source
        or refuse( 'snapshot source vanished [ %s ]', $source );
    if ( -l _ ) {
        my $link = readlink $source;
        symlink $link, $target
            or refuse( 'cannot copy symlink %s : %s', $source, $OS_ERROR );
        return TRUE;
    }
    if ( -d _ ) {
        mkdir $target,
            $st[2] & 07777
            or refuse( 'cannot create staging directory %s : %s',
            $target, $OS_ERROR );
        opendir( my $dh, $source )
            or refuse( 'cannot read source %s : %s', $source, $OS_ERROR );
        my @names = sort grep { $ARG ne '.' and $ARG ne '..' } readdir $dh;
        closedir $dh;
        my $stable = TRUE;
        foreach my $name (@names) {
            my $one = _copy_verify( "$source/$name", "$target/$name" );
            $stable &&= $one;
        }
        chmod $st[2] & 07777, $target;
        utime $st[8], $st[9], $target;
        return $stable;
    }
    refuse( 'snapshot source is not a regular file [ %s ]', $source )
        if not -f _;
    return _copy_file( $source, $target );
}

sub _take_local {
    my ( $method, $source, $target, $previous, $stamp, $export ) = @ARG;
    if ( $method eq qw| cmd | ) {
        my @cmd = split m|\s+|, $export // '';
        refuse('snapshot -method cmd needs -snapshot-cmd') if not @cmd;
        _run( @cmd, $target );
        refuse('snapshot export produced no staging directory')
            if not -d $target;
    } elsif ( $method eq qw| reflink | ) {
        _run(
            $ENV{'N7FS_CP'} // 'cp',
            qw| -a --reflink=always -- |,
            "$source/.", $target
        );
    } elsif ( $method eq qw| hardlink | ) {
        _run( $ENV{'N7FS_CP'} // 'cp', qw| -al -- |, "$source/.", $target );
    } else {
        _copy_verify( $source, $target );
    }
    return;
}

sub _take {
    my ( $method, $source, $target, $previous, $stamp, $export ) = @ARG;
    if ( $source->{'kind'} eq qw| local | ) {
        _take_local( $method, $source->{'path'}, $target, $previous, $stamp,
            $export );
        return;
    }
    my $remote = $source->{'path'};
    if ( $method eq qw| cmd | ) {
        refuse('snapshot -method cmd needs -snapshot-cmd')
            if not defined $export or not length $export;
        $remote = "$source->{'path'}.n7fs-$stamp";
        my $ssh = $ENV{'N7FS_SSH'} // 'ssh';
        _run( $ssh, $source->{'alias'}, split( m|\s+|, $export ), $remote );
    }
    my @rsync = ( $ENV{'N7FS_RSYNC'} // 'rsync', qw| -a | );
    push @rsync, "--link-dest=$previous" if defined $previous;
    push @rsync, '--', "$source->{'alias'}:$remote/", "$target/";
    _run(@rsync);
    return;
}

sub _unstable_count {
    return $UNSTABLE;
}

sub _manifest_previous {
    my ( $id, $state, $replay, $prefix ) = @ARG;
    my ($tree) = sort { $b->{'created'} cmp $a->{'created'} }
        grep { index( $ARG->{'name'}, $prefix ) == 0 }
        values $replay->{'trees'}->%*;
    return undef if not defined $tree;
    my ( $fh, $head ) = manifest_open( $id, $state, $tree );
    close $fh;
    return $head->{'snapshot'};
}

sub _sidecar {
    my ( $staging, $stamp ) = @ARG;
    return "$staging/$stamp.snapshot";
}

sub _write_sidecar {
    my ( $staging, $stamp, $snapshot ) = @ARG;
    my $path = _sidecar( $staging, $stamp );
    write_new_file_stream(
        $path,
        sub {
            my $fh = shift;
            foreach
                my $key (qw| method begin end origin unstable files bytes |) {
                printf {$fh} "%-9s = %s\n", $key, $snapshot->{$key}
                    or die "write $path : $OS_ERROR\n";
            }
        },
        0600
    );
    return;
}

sub _read_sidecar {
    my ( $staging, $stamp ) = @ARG;
    my $bytes = read_file( _sidecar( $staging, $stamp ) )
        // refuse( 'complete staging %s has no snapshot metadata', $stamp );
    my %snapshot;
    foreach my $line ( split m|\n|, $bytes ) {
        next if not length $line;
        my ( $key, $value ) = $line =~ m|\A([a-z]+)\s*=\s*(.*)\z|;
        refuse( 'bad snapshot staging metadata [ %s ]', $line )
            if not defined $value;
        $snapshot{$key} = $value;
    }
    return \%snapshot;
}

sub _capture {
    my (%opt)  = @ARG;
    my $name   = "$opt{'prefix'}$opt{'snapshot'}{'begin'}";
    my $report = assimilate(
        %opt,
        qw| paths |          => ["$opt{'staging'}/$opt{'snapshot'}{'begin'}"],
        qw| tree |           => $name,
        qw| snapshot |       => $opt{'snapshot'},
        qw| keep |           => TRUE,
        qw| remove |         => FALSE,
        qw| dry_run |        => FALSE,
        qw| category_rules | => $opt{'category_rules'} // [],
    );
    if ( $report->{'tree'}{'skipped'}->@* ) {
        tree_drop( %opt, qw| name | => $name );
        refuse(
            'snapshot : %d files changed inside '
                . 'staging ; tree dropped, staging kept',
            scalar $report->{'tree'}{'skipped'}->@*
        );
    }
    fault(qw| snapshot:after-assimilate |);
    return { qw| tree | => $name, qw| report | => $report };
}

sub _cleanup {
    my ( $staging, $keep ) = @ARG;
    my @dirs = _previous_staging($staging);
    while ( @dirs > $keep ) {
        my $old = shift @dirs;
        remove_tree("$staging/$old")
            or refuse( 'cannot remove old staging %s', $old );
        unlink _sidecar( $staging, $old );
    }
    return;
}

sub snapshot_run {
    my %opt    = @ARG;
    my $method = $opt{'method'} // 'copy-verify';
    refuse( 'snapshot : unknown method [ %s ]', $method )
        if not $METHOD{$method};
    my $prefix = $opt{'tree'} // 'snap';
    refuse( 'snapshot : tree names refuse / [ %s ]', $prefix )
        if $prefix =~ m|/|;
    refuse( 'snapshot : bad tree prefix [ %s ]', $prefix )
        if not length $prefix or $prefix =~ m|\x00|;
    $prefix =~ s|:+\z||;
    $prefix .= ':';
    my $limit = $opt{'shrink_limit'} // 30;
    refuse('snapshot : shrink limit must be between 0 and 100')
        if $limit !~ m|\A(?:\d+(?:\.\d+)?)\z|
        or $limit < 0
        or $limit > 100;
    my $keep = $opt{'keep_staging'} // 1;
    refuse('snapshot : keep-staging must be at least 1')
        if $keep !~ m|\A[1-9]\d*\z|;
    my $source = _source( $opt{'source'} );
    $source->{'origin'} //= $opt{'source'};
    my $staging = $opt{'staging'}
        // host_dir(%opt) . "/snapshots/$opt{'disk'}/$prefix";
    $staging =~ s|/+\z||;

    if ( $source->{'kind'} eq qw| local | ) {
        $source->{'path'} = abs_path( $source->{'path'} )
            // refuse( 'snapshot source is not a directory [ %s ]',
            $source->{'path'} );
        refuse( 'snapshot source is not a directory [ %s ]',
            $source->{'path'} )
            if not -d $source->{'path'};
        refuse('snapshot staging cannot be inside its source')
            if index( $staging, "$source->{'path'}/" ) == 0;
    }
    return {
        qw| dry_run | => TRUE,
        qw| prefix |  => $prefix,
        qw| method |  => $method,
        qw| staging | => $staging
        }
        if $opt{'dry_run'};

    make_dirs( host_dir(%opt), 0700 );
    my $lock_path = host_dir(%opt) . "/snapshot-$opt{'disk'}.lock";
    open( my $lock_fh, '>>', $lock_path )
        or refuse( 'cannot open snapshot lock : %s', $OS_ERROR );
    flock( $lock_fh, 2 | 4 )
        or refuse('another snapshot for this disk is still running');
    make_dirs( $staging, 0700 );
    opendir( my $dh, $staging )
        or refuse( 'cannot read staging %s : %s', $staging, $OS_ERROR );
    my @entries = grep { $ARG ne '.' and $ARG ne '..' } readdir $dh;
    closedir $dh;
    remove_tree("$staging/$ARG")
        for grep {m|\A\d{14}\.incomplete\z|} @entries;

    my $id     = disk_read_id(%opt);
    my $state  = state_read( $id->{'path'}, $id->{'store_pub'} );
    my $replay = journal_replay($id);
    foreach my $stamp ( _previous_staging($staging) ) {
        my $name = "$prefix$stamp";
        next if $replay->{'trees'}{$name};
        my $snapshot = _read_sidecar( $staging, $stamp );
        my $previous = _manifest_previous( $id, $state, $replay, $prefix );
        _shrink_guard(
            %opt,
            qw| prefix |       => $prefix,
            qw| tree |         => $name,
            qw| previous |     => $previous,
            qw| shrink_limit | => $limit,
            qw| end |          => $snapshot->{'end'},
            qw| files |        => $snapshot->{'files'},
            qw| bytes |        => $snapshot->{'bytes'},
        );
        _capture(
            %opt,
            qw| prefix |   => $prefix,
            qw| staging |  => $staging,
            qw| snapshot | => $snapshot
        );
        $replay = journal_replay($id);
    }

    my @previous_dirs = _previous_staging($staging);
    my $previous_dir
        = @previous_dirs
        ? "$staging/$previous_dirs[-1]"
        : undef;
    my $begin = ntime_now();
    my $stamp = ntime14($begin);
    my $tmp   = "$staging/$stamp.incomplete";
    my $final = "$staging/$stamp";
    refuse( 'snapshot staging already exists [ %s ]', $stamp )
        if -e $tmp or -e $final;
    warn "n7fs : warning : hardlink snapshots share in-place source writes "
        . "; use only when every source file is replaced by rename\n"
        if $method eq qw| hardlink |;
    local $UNSTABLE = 0;
    _take( $method, $source, $tmp, $previous_dir, $stamp,
        $opt{'snapshot_cmd'} );
    fault(qw| snapshot:after-take |);
    my $end = ntime_now();
    $end = $begin + 1 if $end <= $begin;
    my $stats    = _stats($tmp);
    my $snapshot = {
        qw| method |   => $method,
        qw| begin |    => $stamp,
        qw| end |      => ntime14($end),
        qw| origin |   => $source->{'origin'},
        qw| unstable | => _unstable_count($tmp),
        %{$stats}
    };
    _write_sidecar( $staging, "$stamp.incomplete", $snapshot );
    publish_dir( $tmp, $final );
    rename _sidecar( $staging, "$stamp.incomplete" ),
        _sidecar( $staging, $stamp )
        or refuse('cannot publish snapshot staging metadata');
    fault(qw| snapshot:after-rename |);

    my $previous = _manifest_previous( $id, $state, $replay, $prefix );
    my $shrunk   = _shrink_guard(
        %opt,
        qw| prefix |       => $prefix,
        qw| tree |         => "$prefix$stamp",
        qw| previous |     => $previous,
        qw| shrink_limit | => $limit,
        qw| end |          => $end,
        %{$stats}
    );
    my $captured = _capture(
        %opt,
        qw| prefix |   => $prefix,
        qw| staging |  => $staging,
        qw| snapshot | => $snapshot
    );
    _cleanup( $staging, $keep );
    return {
        %{$captured}, %{$snapshot},
        qw| staging |      => $final,
        qw| shrunk |       => $shrunk,
        qw| previous |     => $previous,
        qw| shrink_limit | => $limit,
        qw| prefix |       => $prefix,
    };
}

1;

#,,,.,..,,.,.,.,,,.,.,.,,,..,,.,.,.,,,,,,,..,,..,,...,...,.,,,.,.,...,.,.,,,.,
#JQ3DD3RC2KKSULFHOPALLN6HTG6CDCERRQXHXBFN5VNT4E72JKMRFTYFQ3F5K53IOUFI5DWYZDEY2
#\\\|N5DX3CFPNDO34RAOVYIZ2NHA2LG3BUARGB2SQWU3R4JZ6O75JEB \ / AMOS7 \ YOURUM ::
#\[7]FW2DDJYUYEXWAFMSBGPMFFTD4KO63XPBUH6RQ3GVAZIB6WZL3EBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
