package AMOS7::deps::root_runner;
our $VERSION = qw| AMOS7::deps::root_runner-VERSION.B5O7BRA |;

use strict;
use warnings;
use English;

## generic ROOT RUNNER : a child process forked as root before a zenka     ##
## drops its privileges, answering install requests of the unprivileged    ##
## parent over a line protocol on stdin \ stdout. the os family is         ##
## detected HERE [ AMOS7::deps::os_package::detect_os ], the parent is     ##
## never asked for it ; installs go through                                ##
## AMOS7::deps::backend::<family>::install. nothing here names an os.      ##
##                                                                         ##
## trust : spawn_argv runs in the still-root parent [ lib root, denied     ##
## uid, label come from root's own config ] ; every line read later comes  ##
## from the unprivileged parent and is checked again here. no shell        ##
## anywhere, nothing from a line becomes a path.                           ##
##                                                                         ##
## only core perl at compile time : everything from the lib tree is loaded ##
## at runtime through the checking @INC hook [ inc_hook ]                  ##
##                                                                         ##
## wire format [ child -> parent ] :                                       ##
##   start   '+ ready family=<f> install=yes'                              ##
##           '+ ready family=<f> install=no : <reason>'                     ##
##           '- refused : <reason>' [ then the child exits ]               ##
##   install '> <output line>' .. , '= ok=<a,b> failed=<c> manual=<d>',    ##
##           '< N' [ 0 : every package ok, 1 : anything else ]             ##
##   cpan    '> <output line>' .. , '< N' [ cpanm exit code ]              ##
## [ parent -> child ] : 'install <pkgs>', 'cpan <mods>', 'exit'           ##

my $FAMILY_NAME_RE = qr|\A[a-z0-9_]+\z|;
my $PKG_NAME_RE    = qr|\A[a-z0-9][a-z0-9.+\-~]*\z|;
my $MOD_NAME_RE    = qr|\A[A-Za-z_][A-Za-z0-9_]*(?:::[A-Za-z0-9_]+)*\z|;
my $LABEL_RE       = qr|\A[a-z0-9][a-z0-9_\-]*\z|;

## files the hook serves : plain module paths below the lib root only ##
my $REL_FILE_RE = qr|\A[A-Za-z0-9_]+(?:/[A-Za-z0-9_]+)*\.pm\z|;

## test-only family override : honoured ONLY when neither the real nor the ##
## effective uid is root [ bin/test-scripts/test-root-runner.pl ]          ##
my $TEST_FAMILY_ENV = qw| P7_ROOT_RUNNER_TEST_FAMILY |;

## test-only : every group counts as shared [ same root rule ] ##
my $TEST_SHARED_ENV = qw| P7_ROOT_RUNNER_TEST_SHARED_GROUPS |;

my $RUNNER_FILE = qw| AMOS7/deps/root_runner.pm |;

## the fixed process start, shared by the zenka and the test : the runner ##
## file is loaded by absolute path                                        ##
## [ checked by the root parent before the spawn ], everything after that ##
## through the checking hook                                              ##
my $BOOTSTRAP = <<~'EOT';
    use strict; use warnings;
    $| = 1;
    my $lib_root = $ARGV[0] // '';
    if ( $lib_root !~ m|\A/| ) { print "- refused : no lib root\n"; exit 1 }
    if ( not eval { require $lib_root . '/AMOS7/deps/root_runner.pm' } ) {
        my $err = $@ // 'unknown error';
        $err =~ s|\s+| |g;
        print "- refused : cannot load the root runner [ $err ]\n";
        exit 1;
    }
    exit AMOS7::deps::root_runner::main(@ARGV);
    EOT

## environment entries that would change what the child perl loads ##
my @PERL_ENV = qw| PERL5LIB PERL5OPT PERLLIB PERL5DB |;

sub perl_env_names { return @PERL_ENV }

##[ spawn_argv ]##############################################################

## the exec list for the child -- the caller removes perl_env_names from ##
## the environment for the spawn                                         ##
sub spawn_argv {
    my ( $perl_bin, $lib_root, $deny_uid, $label ) = @ARG;

    return ( $perl_bin, qw| -e |, $BOOTSTRAP, $lib_root, $deny_uid, $label );
}

##[ check_path ]##############################################################

## ( 'ok' | 'absent' | 'unsafe', reason, file stat ) for <lib root>/<rel>.  ##
## lib root : a real directory [ no symlink ], not owned by the denied uid, ##
## not group \ world writable -- its owner is the TREE OWNER. every dir     ##
## below it and the file itself : no symlink, owned by root or the tree     ##
## owner, not by the denied uid, not group \ world writable. group write is ##
## fine for a PRIVATE group [ _private_group ]. every dir above the lib     ##
## root up to '/' the same, world write there only with the sticky bit      ##
## [ /tmp ] -- else whoever can write an ancestor swaps in a tree it owns   ##
## and becomes the tree owner                                               ##
sub check_path {
    my ( $lib_root, $rel, $deny_uid ) = @ARG;

    return ( qw| unsafe |, 'no lib root' )
        if not defined $lib_root or $lib_root !~ m|\A/|;
    return ( qw| unsafe |, sprintf( "invalid file name '%s'", $rel // '' ) )
        if not defined $rel or $rel !~ $REL_FILE_RE;

    my @root_st = lstat $lib_root;
    return ( qw| unsafe |, "lib root '$lib_root' not found" )
        if not @root_st;
    return ( qw| unsafe |, "lib root '$lib_root' is not a real directory" )
        if -l _ or not -d _;

    my $tree_uid = $root_st[4];
    my $why = _unsafe_reason( $lib_root, \@root_st, $tree_uid, $deny_uid );
    return ( qw| unsafe |, $why ) if defined $why;

    ## the dirs above the lib root ##
    ( my $above = $lib_root ) =~ s|/+\z||;
    while ( length $above ) {
        $above =~ s|/[^/]*\z||;
        $above = '/' if not length $above;
        my @st = lstat $above;
        return ( qw| unsafe |, "'$above' not found" )    if not @st;
        return ( qw| unsafe |, "'$above' is a symlink" ) if -l _;
        $why = _unsafe_reason( $above, \@st, $tree_uid, $deny_uid, 1 );
        return ( qw| unsafe |, $why ) if defined $why;
        last                          if $above eq '/';
    }

    my $path  = $lib_root;
    my @parts = split m|/|, $rel;
    my $last  = pop @parts;

    foreach my $dir (@parts) {
        $path .= "/$dir";
        my @st = lstat $path;
        return ( qw| absent |, "'$path' not found" )          if not @st;
        return ( qw| unsafe |, "'$path' is a symlink" )       if -l _;
        return ( qw| absent |, "'$path' is not a directory" ) if not -d _;
        $why = _unsafe_reason( $path, \@st, $tree_uid, $deny_uid );
        return ( qw| unsafe |, $why ) if defined $why;
    }

    $path .= "/$last";
    my @st = lstat $path;
    return ( qw| absent |, "'$path' not found" )           if not @st;
    return ( qw| unsafe |, "'$path' is a symlink" )        if -l _;
    return ( qw| unsafe |, "'$path' is not a plain file" ) if not -f _;
    $why = _unsafe_reason( $path, \@st, $tree_uid, $deny_uid );
    return ( qw| unsafe |, $why ) if defined $why;

    return ( qw| ok |, $path, \@st );
}

## $above : a dir above the lib root -- world write allowed with sticky bit ##
sub _unsafe_reason {
    my ( $path, $st, $tree_uid, $deny_uid, $above ) = @ARG;

    my ( $mode, $uid, $gid ) = @{$st}[ 2, 4, 5 ];

    ## sticky : nobody renames or removes an entry it does not own ##
    $mode &= ~022 if $above and $mode & 01000;
    ## group write of a group nobody else is in ##
    $mode &= ~020
        if $mode & 020
        and not $mode & 002
        and _private_group( $gid, $tree_uid );

    return sprintf( "'%s' is owned by the " . "zenka user [ uid %d ]",
        $path, $uid )
        if defined $deny_uid and $uid == $deny_uid;
    return
        sprintf( "'%s' is owned by uid %d [ expected "
            . "root or the tree owner, uid %d ]",
        $path, $uid, $tree_uid )
        if $uid != 0 and $uid != $tree_uid;
    return sprintf( "'%s' is group\\world writable [ mode %04o ]",
        $path, $mode & 07777 )
        if $mode & 022;

    return undef;
}

## a group with no member besides root and the tree owner : none listed in ##
## the group file, none with it as primary group                           ##
## [ the umask 002 per-user group ]. a gid without an entry is not private ##
sub _private_group {
    my ( $gid, $tree_uid ) = @ARG;

    return 0
        if defined $ENV{$TEST_SHARED_ENV}
        and $UID != 0
        and $EUID != 0;

    my @group = getgrgid $gid;
    return 0 if not @group;

    foreach my $name ( split m|\s+|, $group[3] // '' ) {
        next if not length $name;
        my $uid = ( getpwnam $name )[2];
        return 0 if not defined $uid or $uid != 0 and $uid != $tree_uid;
    }

    my $private = 1;
    setpwent();
    while ( my @user = getpwent() ) {
        next if $user[3] != $gid or $user[2] == 0 or $user[2] == $tree_uid;
        $private = 0;
        last;
    }
    endpwent();

    return $private;
}

##[ inc_hook ]################################################################

## @INC coderef : a module file present below the lib root is served only ##
## after check_path passed                                                ##
## [ an unsafe one DIES, it never falls through to another copy ] ; the   ##
## open handle must be the checked inode                                  ##
sub inc_hook {
    my ( $lib_root, $deny_uid ) = @ARG;

    return sub {
        my ( undef, $rel ) = @ARG;

        return if not defined $rel or $rel !~ $REL_FILE_RE;

        my ( $state, $what, $st ) = check_path( $lib_root, $rel, $deny_uid );
        return                  if $state eq qw| absent |;
        die "refused : $what\n" if $state ne qw| ok |;

        open( my $fh, '<', $what )
            or die "refused : cannot read '$what' : $OS_ERROR\n";
        my @fh_st = stat $fh;
        die "refused : '$what' changed while loading\n"
            if not @fh_st
            or $fh_st[0] != $st->[0]
            or $fh_st[1] != $st->[1];

        $INC{$rel} = $what;
        return $fh;
    };
}

##[ read_status ]#############################################################

## the child's start-up line [ '+ ready ..' \ '- refused ..' ] within  ##
## $timeout seconds, undef on timeout \ eof. sysread only : the caller ##
## keeps reading the same pipe unbuffered afterwards                   ##
sub read_status {
    my ( $fh, $timeout ) = @ARG;

    require IO::Select;
    my $select   = IO::Select->new($fh);
    my $deadline = time + ( $timeout // 20 );
    my $line     = '';

    while ( time <= $deadline ) {
        my $left = $deadline - time;
        $left = 0 if $left < 0;
        ## a signal [ SIGCHLD in the zenka ] is no timeout : wait on ##
        local $OS_ERROR = 0;
        if ( not $select->can_read( $left || 0.2 ) ) {
            next if $!{'EINTR'};
            last;
        }
        my $got = sysread( $fh, my $char, 1 );
        next         if not defined $got and $!{'EINTR'};
        last         if not $got;
        return $line if $char eq "\n";
        $line .= $char;
        last if length $line > 4096;
    }

    return undef;
}

##[ parse_result ]############################################################

## '= ok=<a,b> failed=<c> manual=<d>' -> { ok, failed, manual } \ undef ##
sub parse_result {
    my ($line) = @ARG;

    return undef if not defined $line;
    return undef
        if $line !~ m|\A= ok=(\S*) failed=(\S*) manual=(\S*)\z|;

    my @lists = ( ${^CAPTURE}[0], ${^CAPTURE}[1], ${^CAPTURE}[2] );
    my %result;
    @result{qw| ok failed manual |} = map {
        [ grep {length} split m|,|, $ARG ]
    } @lists;

    return \%result;
}

sub _result_line {
    my ($result) = @ARG;

    return sprintf "= ok=%s failed=%s manual=%s\n", map {
        join ',',
            grep { $ARG =~ $PKG_NAME_RE }
            @{ $result->{$ARG} }
    } qw| ok failed manual |;
}

##[ main ]####################################################################

## the child process : returns its exit code ##
sub main {
    my ( $lib_root, $deny_uid, $label ) = @ARG;

    $OUTPUT_AUTOFLUSH = 1;

    my $refuse = sub {
        my $why = shift // q|unknown error|;
        $why = ( split m|\n|, $why )[0] // q|unknown error|;
        $why =~ s|\Arefused : ||;
        $why =~ s|\s+\z||;
        print "- refused : $why\n";
        return 1;
    };

    return $refuse->('invalid lib root')
        if not defined $lib_root
        or $lib_root !~ m|\A/|
        or $lib_root =~ m{/\.\.?(?:/|\z)};
    return $refuse->('invalid zenka uid')
        if not defined $deny_uid or $deny_uid !~ m|\A[0-9]+\z|;
    return $refuse->('invalid label')
        if not defined $label or $label !~ $LABEL_RE;

    local $PROGRAM_NAME = "$label\[root-runner:start]";

    my $is_root = ( $UID == 0 or $EUID == 0 ) ? 1 : 0;

    ## nothing of the lib tree loads around the hook : no plain lib root, ##
    ## no relative entries                                                ##
    @INC = grep { not ref $ARG and m|\A/| and $ARG ne $lib_root } @INC;
    unshift @INC, inc_hook( $lib_root, $deny_uid );

    ## the runner file itself                                          ##
    ## [ already loaded by the bootstrap, after the parent's check ] : ##
    ## checked again here, refusing on a change                        ##
    my ( $self_state, $self_why )
        = check_path( $lib_root, $RUNNER_FILE, $deny_uid );
    return $refuse->($self_why) if $self_state ne qw| ok |;

    eval { require AMOS7::deps::os_package; 1 }
        or return $refuse->( $EVAL_ERROR || 'cannot load os_package' );

    my $family = AMOS7::deps::os_package::detect_os();
    if ( not $is_root and defined $ENV{$TEST_FAMILY_ENV} ) {
        $family = $ENV{$TEST_FAMILY_ENV};
    }
    delete $ENV{$TEST_FAMILY_ENV};

    ## the backend : family name checked before any file name is built ##
    my ( $install, $no_install, $no_install_list );
    if ( not defined $family or $family !~ $FAMILY_NAME_RE ) {
        $family          = 'invalid';
        $no_install      = 'invalid family name';
        $no_install_list = qw| failed |;
    } else {
        my $rel = "AMOS7/deps/backend/$family.pm";
        my ( $state, $why ) = check_path( $lib_root, $rel, $deny_uid );
        if ( $state eq qw| unsafe | ) {
            return $refuse->($why);
        } elsif ( $state eq qw| absent | ) {
            $no_install      = "no backend for family '$family'";
            $no_install_list = qw| manual |;
        } elsif ( not eval { require $rel; 1 } ) {
            ## an unsafe file among the backend's own loads lands here too ##
            return $refuse->( $EVAL_ERROR
                    || "cannot load " . "backend '$family'" );
        } else {
            my $mod        = "AMOS7::deps::backend::$family";
            my $needs_root = $mod->can('needs_root');
            $install = $mod->can('install');
            if ( not defined $install ) {
                $no_install      = "backend '$family' has no install";
                $no_install_list = qw| failed |;
            } elsif ( not $needs_root or not $needs_root->() ) {
                ## a backend that does not need root is not run as root ##
                $install         = undef;
                $no_install      = "backend '$family' does not need root";
                $no_install_list = qw| failed |;
            }
        }
    }

    if ( defined $install ) {
        print "+ ready family=$family install=yes\n";
    } else {
        print "+ ready family=$family install=no : $no_install\n";
    }

    _serve( $label, $family, $install, $no_install, $no_install_list );

    return 0;
}

##[ _serve ]##################################################################

sub _serve {
    my ( $label, $family, $install, $no_install, $no_install_list ) = @ARG;

    my $idle = "$label\[root-runner:idle]";
    $PROGRAM_NAME = $idle;

    ## cpanm : fixed locations only, never a path from the parent ##
    my ($cpanm) = grep { -x $ARG } qw| /usr/bin/cpanm /usr/local/bin/cpanm |;

    my $out_line = sub {
        my $text = shift // '';
        foreach my $line ( split m|\n|, $text ) {
            print "> $line\n";
        }
    };

    ## command list -> '> ' output lines, '< N' exit code ##
    my $run = sub {
        my $pid = open( my $fh, '-|' );
        if ( not defined $pid ) { print "< 1\n"; return }
        if ( $pid == 0 ) {
            open( STDERR, '>&', \*STDOUT );
            exec { $ARG[0] } @ARG;
            exit 127;
        }
        while ( my $out = <$fh> ) { print "> $out" }
        close($fh);
        printf "< %d\n", $CHILD_ERROR >> 8;
    };

    while ( my $line = <STDIN> ) {
        chomp $line;
        last if not length $line;

        if ( $line =~ m|\Ainstall (.+)\z| ) {
            my @pkgs = split m|\s+|, ${^CAPTURE}[0];
            if ( grep { $ARG !~ $PKG_NAME_RE } @pkgs ) {
                print "> refused : invalid package name\n";
                print _result_line(
                    { ok => [], failed => [@pkgs], manual => [] } );
                print "< 1\n";
                next;
            }
            if ( not defined $install ) {
                print "> refused : $no_install\n";
                my %result = ( ok => [], failed => [], manual => [] );
                $result{$no_install_list} = [@pkgs];
                print _result_line( \%result ), "< 1\n";
                next;
            }

            $PROGRAM_NAME = sprintf '%s[root-runner:%s install %s]', $label,
                $family, join( ' ', @pkgs );

            my $result = eval {
                local $SIG{'__WARN__'} = sub { $out_line->( $ARG[0] ) };
                $install->( $out_line, @pkgs );
            };
            if ( not defined $result ) {
                $out_line->( 'backend error ' . ': '
                        . ( $EVAL_ERROR || 'no result' ) );
                $result = { ok => [], failed => [@pkgs] };
            } elsif ( ref $result ne 'HASH' ) {
                $out_line->('backend error : result is not a hash');
                $result = { ok => [], failed => [@pkgs] };
            }

            my %clean;
            foreach my $key (qw| ok failed manual |) {
                my $list = $result->{$key};
                $clean{$key} = ref $list eq 'ARRAY' ? [@$list] : [];
            }

            ## every package ok, nothing failed \ left to the admin : 0 ##
            my $exit
                = (     @{ $clean{'ok'} }
                    and not @{ $clean{'failed'} }
                    and not @{ $clean{'manual'} } ) ? 0 : 1;

            print _result_line( \%clean ), "< $exit\n";
            $PROGRAM_NAME = $idle;

        } elsif ( $line =~ m|\Acpan (.+)\z| ) {
            my @mods = split m|\s+|, ${^CAPTURE}[0];
            if ( grep { $ARG !~ $MOD_NAME_RE } @mods ) {
                print "> refused : invalid module name\n< 1\n";
                next;
            }
            if ( not defined $cpanm ) {
                print "> refused : no cpanm [ apt : cpanminus ]\n< 1\n";
                next;
            }
            $PROGRAM_NAME = sprintf '%s[root-runner:cpan %s]', $label,
                join( ' ', @mods );
            $run->( $cpanm, qw| --quiet --notest |, @mods );
            $PROGRAM_NAME = $idle;

        } elsif ( $line eq qw| exit | ) {
            last;
        } else {
            print "< 1\n";    ## unknown command ##
        }
    }

    return;
}

1;

#,,..,,,,,,..,.,,,..,,,.,,..,,,.,,...,.,,,,,,,..,,...,...,,..,.,.,,..,,..,.,.,
#E7Q575CLWQZ35QW555527BDYTMT5BBFLUK7Y4QMO55TMOBWD6VK5BV6ZRN55WRJCLSIA6TGSQG6Q2
#\\\|DJZLSZZI4NHOQB567L3KOTGFSPINUF2EUGYXH2V3XWJY55WFNGF \ / AMOS7 \ YOURUM ::
#\[7]T76GMTUPMQOLA3Q3YN5DW7P23EHKBKFXXJAJ653OU4T6V6HA5CBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
