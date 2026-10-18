#!/usr/bin/env perl
use v5.24;
use strict;
use English;
use warnings;

## the production runtime [ bin/Protocol-7 : use utf8 + Encode ] loads the ##
## bytes pragma transitively ; keep it so compiled modules resolve it.     ##
use bytes;

## shared web-auth session store : drives the REAL store modules on a temp  ##
## var dir :                                                                ##
## - store.set-up creates/re-asserts <var>/shared/web-auth/                 ##
## {active,expired} as owner <amos-user> : group web.auth.group, mode 2770  ##
## [ setgid ]                                                               ##
## - session.write produces 0660 session files [ umask-proof ]              ##
## - group fallback + old-store notice + fail-closed lines  NOTE : the test ##
## runs WITHOUT root -- creation with a foreign owner [ protocol-7 ] cannot ##
## be exercised here ; the wrong/ missing branches assert the exact         ##
## owner/group/mode plan the set-up enforces, and correct pre-existing dirs ##
## pass through                                                             ##

use File::Spec;
use Cwd        qw| abs_path |;
use FindBin    qw| $RealBin |;
use File::Temp qw| tempdir |;

BEGIN {
    my $up_dir    = File::Spec->updir;
    my $root_path = abs_path(
        File::Spec->rel2abs(
            File::Spec->catdir( $RealBin, $up_dir, $up_dir )
        )
    );
    my $local_lib_path
        = File::Spec->catdir( $root_path, qw| data lib-path pm | );
    die "not found : $local_lib_path" if !-d $local_lib_path;
    unshift( @INC, $local_lib_path );
    $main::root_path = $root_path;
}

use AMOS7::Protocol::P7Syntax qw| p7_syntax__translate |;

use constant TRUE    => 5;
use constant FALSE   => 0;
use constant UNKNOWN => 2;

our %code;
our %data;

$OUTPUT_AUTOFLUSH = 1;

my $fail_count = 0;
my $pass_count = 0;

sub ok ($;$) {
    my ( $cond, $label ) = @ARG;
    if ($cond) { $pass_count++; say "  ok   : $label"; return }
    $fail_count++;
    say "  FAIL : $label";
    return;
}

my $runtime_pragmas = q{no bytes; use English; use File::stat; use File::Spec;
    use File::Spec::Functions qw| catfile |; use YAML::XS ();
    use open qw| :encoding(UTF-8) |;};
my $module_prefix = q{use constant TRUE => 5; use constant FALSE => 0;};

sub compile_module {
    my ( $module_name, $prefix ) = @ARG;
    $prefix //= $module_prefix;
    my $src_path
        = File::Spec->catfile( $main::root_path, 'src', $module_name );
    open( my $fh, '<', $src_path ) or die "cannot read $src_path : $!";
    my $src = join( '', <$fh> );
    close($fh);
    my $translated = p7_syntax__translate($src);
    my $cref
        = eval "$runtime_pragmas sub {\n$prefix\n# "
        . "line 1 \"$module_name\"\n$translated\n}";
    die "compile failed for $module_name : $EVAL_ERROR"
        if not defined $cref;
    $code{$module_name} = $cref;
    return $cref;
}

## ---------------------------------------------------------------------- ##
## stubs + identity                                                       ##

my @logged;

$code{'base.logs'} = sub { push @logged, [@ARG]; return };
$code{'base.log'}  = sub { push @logged, [@ARG]; return };
$code{'base.s_warn'}
    = sub { push @logged, [ 'warn', sprintf( shift, @ARG ) ]; return };
$code{'base.str.os_err'} = sub { return $OS_ERROR };
$code{'file.open'}       = sub {
    my ( $file, $layer, $mode, $lock, $perm ) = @ARG;
    open( my $fh, '>', $file ) or return undef;
    return $fh;
};
$code{'file.make_path'} = sub {
    my ( $path, $mode, $owner, $group ) = @ARG;
    require File::Path;
    umask 0;    ## test double honors the requested mode exactly ##
    File::Path::make_path($path);
    chmod oct( sprintf '%o', $mode ), $path if defined $mode;
    if ( defined $owner ) {
        my ( $uid, $gid ) = ( getpwnam $owner )[ 2, 3 ];
        $gid = ( getgrnam $group )[2] if defined $group;
        chown $uid, $gid, $path if defined $uid;
    }
    return -d $path ? TRUE : FALSE;
};

my $tmp = tempdir( 'p7-web-auth-store-XXXXXXXX', TMPDIR => 1, CLEANUP => 1 );

my ( $my_name, $my_uid, $my_gid ) = ( getpwuid $REAL_USER_ID )[ 0, 2, 3 ];
my $my_group = ( getgrgid $my_gid )[0];

$data{'system'}{'path'}{'zenka-dirs'} = { 'var_P7' => $tmp };
$data{'system'}{'zenka'}{'name'}      = qw| httpd |;
$data{'system'}{'amos-zenka-user'}    = $my_name;

my $store = "$tmp/shared/web-auth";

my @perl_warnings;
local $SIG{__WARN__} = sub { push @perl_warnings, @ARG };

compile_module($_) for qw|
    plugin.web.auth.session.path
    plugin.web.auth.store.group
    plugin.web.auth.store.set-up
    plugin.web.auth.session.write
    |;

sub logged_clear { @logged = (); return }

sub logged_grep {
    my $re = shift;
    return grep {
        join( ' ', map { $_ // '' } $ARG->@* ) =~ $re
    } @logged;
}

sub make_store_dirs {    ## simulate the root-created state ##
    my ($mode) = @_;
    require File::Path;
    umask 0;
    File::Path::make_path("$store/active");
    File::Path::make_path("$store/expired");
    chmod $mode, $store, "$store/active", "$store/expired";
    return;
}

## ---------------------------------------------------------------------- 1 ##
## : path + group resolution                                                ##

say "\n :. store path + group resolution";

ok( $code{'plugin.web.auth.session.path'}->() eq $store,
    'session path is <var_P7>/shared/web-auth'
);

$data{'web'}{'auth'}{'group'} = $my_group;
my $resolved = $code{'plugin.web.auth.store.group'}->();
ok( $resolved eq $my_group, 'configured group name resolves verbatim' );

delete $data{'plugin'}{'web'}{'auth'}{'store'};
delete $data{'web'}{'auth'}{'group'};
$data{'system'}{'zenka-group'}{'current'} = $my_group;
$resolved = $code{'plugin.web.auth.store.group'}->();
if ( defined getgrnam qw| httpd | ) {
    ok( $resolved eq qw| httpd |, 'default group is httpd when it exists' );
} else {
    ok( $resolved eq $my_group,
        'missing default httpd group falls back to zenka group [ dev host ]'
    );
    ok( ( scalar logged_grep qr|does not exist| ) == 1,
        'group fallback logs exactly one level-1 line'
    );
}

delete $data{'plugin'}{'web'}{'auth'}{'store'};
$data{'web'}{'auth'}{'group'} = 'no-such-group-xyz';
logged_clear();
$resolved = $code{'plugin.web.auth.store.group'}->();
ok( $resolved eq $my_group,
    'nonexistent configured group falls back to zenka group' );
ok( ( scalar logged_grep qr|does not exist : using|sm ) == 1
        && ( scalar logged_grep qr|no-such-group-xyz|sm ) == 1,
    'fallback names both groups in one line'
);

$data{'web'}{'auth'}{'group'} = $my_group;
delete $data{'plugin'}{'web'}{'auth'}{'store'};

## ---------------------------------------------------------------------- 2 ##
## : set-up against a correct [ root-created ] store                        ##

say "\n :. set-up [ pass-through on correct store ]";

make_store_dirs(02770);
logged_clear();
my $ok = $code{'plugin.web.auth.store.set-up'}->();
ok( $ok == TRUE, 'set-up accepts a correct store' );
ok( ( scalar logged_grep qr|fail closed|sm ) == 0,
    'no fail-closed log on a correct store'
);

## idempotent reinit : a second run changes nothing
$ok = $code{'plugin.web.auth.store.set-up'}->();
my $stat = File::stat::stat($store);
ok( $ok == TRUE && ( $stat->mode & 07777 ) == 02770,
    'reinit is idempotent [ still 2770 ]'
);

my $dir_stat = File::stat::stat("$store/active");
ok( ( $dir_stat->mode & 07777 ) == 02770 && ( $dir_stat->mode & 02000 ),
    'active dir mode 2770 with setgid bit' );
ok( $dir_stat->uid == $my_uid && $dir_stat->gid == $my_gid,
    'active dir owned by amos-user : resolved group'
);

## ---------------------------------------------------------------------- 3 ##
## : fail-closed when not root                                              ##

say "\n :. fail-closed paths [ test runs unprivileged ]";

chmod 0755, "$store/active";
logged_clear();
$ok = $code{'plugin.web.auth.store.set-up'}->();
ok( $ok == FALSE, 'wrong-mode dir refused without root' );
ok( ( scalar logged_grep qr|wrong owner/| ) == 1,
    'one clear log line for the wrong-dir case'
);

unlink "$store/active", "$store/expired";
rmdir "$store/active"  if -d "$store/active";
rmdir "$store/expired" if -d "$store/expired";
rmdir $store;
logged_clear();
$ok = $code{'plugin.web.auth.store.set-up'}->();
ok( $ok == FALSE, 'missing store refused without root' );
ok( ( scalar logged_grep qr|missing and not root| ) == 1,
    'one clear log line for the missing-dir case'
);

## ---------------------------------------------------------------------- 4 ##
## : session files are 0660 [ umask-proof ]                                 ##

say "\n :. session.write file mode";

make_store_dirs(02770);
umask 0027;    ## a restrictive umask must not leak into the file mode ##
my $written
    = $code{'plugin.web.auth.session.write'}
    ->( '0123456789ABC', { 'token_hash' => '0123456789ABC' } );
my $session_file = "$store/active/0123456789ABC/session.yaml";
my $file_stat    = File::stat::stat($session_file);
ok( $written == TRUE   && -f $session_file, 'session file written' );
ok( defined $file_stat && ( $file_stat->mode & 07777 ) == 0660,
    'session file mode 0660 despite umask 0027' );
my $token_dir_stat = File::stat::stat("$store/active/0123456789ABC");
ok( ( $token_dir_stat->mode & 02000 ),
    'token dir carries the setgid bit [ group inheritance ]' );
umask 0022;

## ---------------------------------------------------------------------- 5 ##
## : old per-zenka store notice                                             ##

say "\n :. old store notice [ no migration, re-mint ]";

require File::Path;
File::Path::make_path("$tmp/web/sessions/active");
open my $ofh, '>', "$tmp/web/sessions/active/leftover.yaml"
    or die $OS_ERROR;
close $ofh;
logged_clear();
$code{'plugin.web.auth.store.set-up'}->();
ok( ( scalar logged_grep qr|not migrated| ) == 1,
    'leftover sessions in the old store get one notice line'
);
logged_clear();
$code{'plugin.web.auth.store.set-up'}->();
ok( ( scalar logged_grep qr|not migrated| ) == 0, 'notice logged once only' );

## ---------------------------------------------------------------------- ##
## summary                                                                ##

my @struct_warnings
    = grep {m{uninitialized|Use of|ref\(\) on|Not an? \w+ ref}i}
    @perl_warnings;
ok( scalar @struct_warnings == 0,
    'no perl warnings from the compiled modules' );

say '';
say "passed : $pass_count  failed : $fail_count";
say 'note   : store CREATION with foreign owner [ protocol-7:httpd '
    . '] needs root -- exercised here up to the plan assertions above';
exit( $fail_count ? 1 : 0 );

#,,,.,...,.,,,.,,,...,...,.,.,,.,,.,.,,,.,.,,,..,,...,...,,.,,.,.,.,.,...,,..,
#34GRE36JDEBXHFT6SYKFVC3EJXFSQ37USLR2KZ7Y72DOAACBEBLDZESLPNACAJ333OXC4OHBFR77S
#\\\|GGCQ6PU5LY4YEJOWZSXAKJBLTQWWSE3G32KMW4TNOBT6LGEG75T \ / AMOS7 \ YOURUM ::
#\[7]B5BY3EGICRHJI3LWIDRAJY6AMQK6OYLM6NEHPC5SQA22Z5CAQWAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
