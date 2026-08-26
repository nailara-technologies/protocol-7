package Git::Native::Diff;

## native libgit2 diff-text bindings for Protocol-7 [ in-tree extension ]
##
## attaches the diff output functions Git::Libgit2::FFI 0.006 left
## unbound [ git_diff_to_buf, git_diff_get_stats, git_diff_stats_to_buf,
## git_diff_stats_free, git_buf_dispose ] against the same singleton
## FFI::Platypus instance, and exposes four class methods returning plain
## diff text [ patch or --stat ] for a Git::Native::Repository.
##
## note: reaches through the soft-private Moo accessor ->_handle on
## Git::Native::{Repository,Index,Tree,Reference} at the FFI boundary,
## same pointer shape those wrappers themselves hand to libgit2.

use strict;
use warnings;
use 5.034;

use Git::Native::Error qw( check_rc );
use Git::Libgit2 qw( GIT_OBJECT_TREE );
use Git::Libgit2::FFI;
use FFI::Platypus::Buffer qw( scalar_to_buffer );
use Try::Tiny;

use constant {
    GIT_DIFF_OPTIONS_VERSION     => 1,
    GIT_DIFF_OPTIONS_STRUCT_SIZE => 512,    ## over-alloc; CLONE_OPTIONS_SIZE
                                            ## tactic, Git/Native.pm:25
    GIT_DIFF_FORMAT_PATCH          => 1,
    GIT_DIFF_FORMAT_PATCH_HEADER   => 2,
    GIT_DIFF_FORMAT_RAW            => 3,
    GIT_DIFF_FORMAT_NAME_ONLY      => 4,
    GIT_DIFF_FORMAT_NAME_STATUS    => 5,
    GIT_DIFF_FORMAT_PATCH_ID       => 6,
    GIT_DIFF_STATS_NONE            => 0,
    GIT_DIFF_STATS_FULL            => 1,
    GIT_DIFF_STATS_SHORT           => 2,
    GIT_DIFF_STATS_NUMBER          => 4,
    GIT_DIFF_STATS_INCLUDE_SUMMARY => 8,
};

## _to_string_and_dispose( $ffi, $filler_coderef ) -- returns the string
## extracted from a git_buf produced by whatever libgit2 call $filler makes.
## the filler receives the buffer pointer and must check_rc its own call.
## git_buf_dispose runs unconditionally, even on die or empty result.
sub _to_string_and_dispose {
    my ( $ffi, $filler ) = @_;
    my $buf = "\0" x 24;
    my ($buf_p) = scalar_to_buffer($buf);    ## $buf kept in scope below

    my $out = '';
    my $err;
    try {
        $filler->($buf_p);
        my ( $ptr, undef, $size ) = unpack 'Q Q Q', $buf;
        if ( $ptr && $size ) {
            $out = $ffi->cast( 'opaque', "string($size)", $ptr );
        }
    } catch {
        $err = $_;
    } finally {
        Git::Libgit2::FFI::git_buf_dispose($buf_p);
    };
    die $err if defined $err;
    return $out;
}

## shared prologue: attached symbols, ffi singleton, init'd options struct
## [ caller must keep the returned $opts scalar in scope -- $opts_p
##   points into its PV and dangles once $opts is freed ]
sub _ffi_and_opts {
    Git::Native::Diff::FFI::_ensure_attached();
    my $ffi  = Git::Libgit2::FFI::ffi();
    my $opts = "\0" x GIT_DIFF_OPTIONS_STRUCT_SIZE;
    my ($opts_p) = scalar_to_buffer($opts);
    check_rc Git::Libgit2::FFI::git_diff_options_init(
        $opts_p, GIT_DIFF_OPTIONS_VERSION,
    );
    return ( $ffi, $opts, $opts_p );
}

## shared stats-rendering filler for the two --stat methods
sub _stats_filler {
    my ($diff_ptr) = @_;
    return sub {
        my ($buf_p) = @_;
        my $stats_ptr;
        check_rc Git::Libgit2::FFI::git_diff_get_stats( \$stats_ptr,
            $diff_ptr );
        my $rc = Git::Libgit2::FFI::git_diff_stats_to_buf(
            $buf_p, $stats_ptr, GIT_DIFF_STATS_FULL, 80,
        );
        Git::Libgit2::FFI::git_diff_stats_free($stats_ptr);
        check_rc $rc;
    };
}

## `git diff --cached` -- HEAD tree vs index, full unified patch text.
## unborn HEAD: undef old_tree, libgit2 diffs empty-tree vs index.
sub staged_patch {
    my ( $class, $repo ) = @_;
    my ( $ffi, $opts, $opts_p ) = _ffi_and_opts();

    my $head_ref = $repo->head;
    my $head_tree_ptr;
    if ( defined $head_ref ) {
        check_rc Git::Libgit2::FFI::git_reference_peel(
            \$head_tree_ptr, $head_ref->_handle, GIT_OBJECT_TREE,
        );
    }

    my $index = $repo->index;

    my $diff_ptr;
    my $rc = Git::Libgit2::FFI::git_diff_tree_to_index(
        \$diff_ptr, $repo->_handle, $head_tree_ptr, $index->_handle,
        $opts_p,
    );
    if ( $rc < 0 ) {
        Git::Libgit2::FFI::git_tree_free($head_tree_ptr) if $head_tree_ptr;
        check_rc $rc;    ## throws
    }

    my $text;
    try {
        $text = _to_string_and_dispose( $ffi, sub {
            my ($buf_p) = @_;
            check_rc Git::Libgit2::FFI::git_diff_to_buf(
                $buf_p, $diff_ptr, GIT_DIFF_FORMAT_PATCH,
            );
        });
    } finally {
        Git::Libgit2::FFI::git_diff_free($diff_ptr);
        Git::Libgit2::FFI::git_tree_free($head_tree_ptr) if $head_tree_ptr;
    };
    return $text;
}

## `git diff` [ unstaged ] -- index vs workdir, full unified patch text.
sub workdir_patch {
    my ( $class, $repo ) = @_;
    my ( $ffi, $opts, $opts_p ) = _ffi_and_opts();

    my $index = $repo->index;

    my $diff_ptr;
    check_rc Git::Libgit2::FFI::git_diff_index_to_workdir(
        \$diff_ptr, $repo->_handle, $index->_handle, $opts_p,
    );

    my $text;
    try {
        $text = _to_string_and_dispose( $ffi, sub {
            my ($buf_p) = @_;
            check_rc Git::Libgit2::FFI::git_diff_to_buf(
                $buf_p, $diff_ptr, GIT_DIFF_FORMAT_PATCH,
            );
        });
    } finally {
        Git::Libgit2::FFI::git_diff_free($diff_ptr);
    };
    return $text;
}

## `git diff --stat` [ unstaged ] -- index vs workdir, --stat summary.
sub workdir_stat {
    my ( $class, $repo ) = @_;
    my ( $ffi, $opts, $opts_p ) = _ffi_and_opts();

    my $index = $repo->index;

    my $diff_ptr;
    check_rc Git::Libgit2::FFI::git_diff_index_to_workdir(
        \$diff_ptr, $repo->_handle, $index->_handle, $opts_p,
    );

    my $text;
    try {
        $text = _to_string_and_dispose( $ffi, _stats_filler($diff_ptr) );
    } finally {
        Git::Libgit2::FFI::git_diff_free($diff_ptr);
    };
    return $text;
}

## `git diff --stat <rev>` -- <rev>'s tree vs workdir, --stat summary.
sub tree_to_workdir_stat {
    my ( $class, $repo, $rev ) = @_;
    my ( $ffi, $opts, $opts_p ) = _ffi_and_opts();

    my $obj_ptr;
    check_rc Git::Libgit2::FFI::git_revparse_single( \$obj_ptr,
        $repo->_handle, $rev );
    my $tree_ptr;
    my $rc = Git::Libgit2::FFI::git_object_peel( \$tree_ptr, $obj_ptr,
        GIT_OBJECT_TREE );
    if ( $rc < 0 ) {
        Git::Libgit2::FFI::git_object_free($obj_ptr);
        check_rc $rc;    ## throws
    }

    my $diff_ptr;
    $rc = Git::Libgit2::FFI::git_diff_tree_to_workdir(
        \$diff_ptr, $repo->_handle, $tree_ptr, $opts_p,
    );
    if ( $rc < 0 ) {
        Git::Libgit2::FFI::git_object_free($tree_ptr);
        check_rc $rc;    ## throws
    }

    my $text;
    try {
        $text = _to_string_and_dispose( $ffi, _stats_filler($diff_ptr) );
    } finally {
        Git::Libgit2::FFI::git_diff_free($diff_ptr);
        Git::Libgit2::FFI::git_object_free($tree_ptr);
    };
    return $text;
}

package Git::Native::Diff::FFI;

## attaches the diff output symbols missing from Git::Libgit2::FFI 0.006
## [ plus git_object_peel, needed to resolve revspecs to trees ] on the
## same singleton FFI::Platypus instance. attached once, lazily.
my $attached = 0;

sub _ensure_attached {
    return if $attached;
    my $ffi = Git::Libgit2::FFI::ffi();

    $ffi->type( 'opaque' => 'git_diff_stats' );

    ## attach into the upstream Git::Libgit2::FFI package so the new
    ## symbols are reachable as Git::Libgit2::FFI::git_diff_* alongside
    ## the ones _attach_all already bound there
    {
        package Git::Libgit2::FFI;

        $ffi->attach(
            git_diff_to_buf => [ 'opaque', 'git_diff', 'int' ] => 'int' );
        $ffi->attach(
            git_diff_get_stats => [ 'opaque*', 'git_diff' ] => 'int' );
        $ffi->attach(
            git_diff_stats_to_buf => [ 'opaque', 'git_diff_stats', 'int',
                'size_t' ] => 'int' );
        $ffi->attach(
            git_diff_stats_free => [ 'git_diff_stats' ] => 'void' );
        $ffi->attach( git_buf_dispose => [ 'opaque' ] => 'void' );
        $ffi->attach(
            git_object_peel => [ 'opaque*', 'git_object', 'int' ] => 'int'
        );
    }

    $attached = 1;
    return;
}

1;

#,,.,,,,,,,..,,..,,..,...,.,.,,..,..,,...,..,,..,,...,...,.,,,,,,,,..,.,,,...,
#GPFB2YLY6EWMTEBJWZV2O66PAR4PELK5CMFJ2DWSBCBUZTX2MTNPFL2ZZQRTF6V3GJUS6W3OG33RU
#\\\|QAXIITUCDEEE4H3TGSNWFP5SLHQF7WUJJWPRS4CK53XYEZZ2FUX \ / AMOS7 \ YOURUM ::
#\[7]AMRCBFCXRZFCOSKOJA2JP2KXDSLV6L2RPFZN5GP6IVIVT4MLXOCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
