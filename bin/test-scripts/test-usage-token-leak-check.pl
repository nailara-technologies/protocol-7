#!/usr/bin/env perl
use v5.32;
use strict;
use English;
use warnings;

## usage.token-leak-check : the real src modules, the real scan helper and ##
## stream_child, FAKE tokens in credential files of a temp home. only      ##
## explicit temp paths are searched                                        ##
## [ the default list is checked with a fake child ]. usage.home_dir is    ##
## replaced : the real home is not read                                    ##

use File::Spec;
use File::Spec::Functions qw| catfile |;
use File::Temp            qw| tempdir |;
use File::Path            qw| make_path |;
use List::Util            qw| uniq |;
use Cwd                   qw| abs_path |;
use FindBin               qw| $RealBin |;
use IO::Select;
use POSIX        ();
use JSON::XS     ();
use Data::Dumper ();

BEGIN {
    my $root = abs_path(
        File::Spec->rel2abs(
            File::Spec->catdir(
                $RealBin, File::Spec->updir, File::Spec->updir
            )
        )
    );
    $main::root_path = $root;
    unshift @INC, "$root/data/lib-path/pm";
}

use constant TRUE  => 5;
use constant FALSE => 0;

my $root_path = $main::root_path;

our %data;
our %code;
our $call;

my ( $pass, $fail ) = ( 0, 0 );

sub ok {
    my ( $cond, $name ) = @ARG;
    if   ($cond) { $pass++; say "ok   - $name" }
    else         { $fail++; say "FAIL - $name" }
    return $cond;
}
## module loading : the same <..> translation the zenka loader does ##

sub translate_code {
    my $code = shift;
    $code =~ s|<\[(\$[A-Za-z]\w*)\]>(?=\s*->)|"\$code{$1}"|eg;
    $code =~ s|<\[(\$[A-Za-z]\w*)\]>|"\$code{$1}->()"|eg;
    $code =~ s{<\[([A-Za-z][-\w.]*)\]>(?=\s*->)}{chr(36).qq|code{'$1'}|}eg;
    $code =~ s{<\[([A-Za-z][-\w.]*)\]>}{chr(36).qq|code{'$1'}->()|}eg;
    $code =~ s{<([a-z][-\w.]*)>}{
        my @keys = split m|\.|, $1;
        chr(36).qq|data{'| . join( "'}{'", @keys ) . qq|'}|
    }ge;
    return $code;
}

sub compile_source {
    my $src = shift;
    $src =~ s{\n#[^\n]*\z}{\n} while $src =~ m{\n#[,\[\\|:][^\n]*\z};
    my @seg = split m{('(?:[^'\\]|\\.)*'|"(?:[^"\\]|\\.)*"|\#[^\n]*)}x,
        $src, -1;
    for ( my $i = 0; $i < @seg; $i += 2 ) {
        $seg[$i] = translate_code( $seg[$i] );
    }
    my $translated = join '', @seg;
    my $sub        = eval "sub { $translated }";
    die "compile error : $EVAL_ERROR" if $EVAL_ERROR;
    return $sub;
}

sub read_file {
    my $path = shift;
    open my $fh, '<:encoding(UTF-8)', $path
        or die "cannot read $path : $OS_ERROR";
    local $INPUT_RECORD_SEPARATOR = undef;
    my $src = <$fh>;
    close $fh;
    return $src;
}

sub load_module {
    my $name = shift;
    $code{$name}
        = compile_source(
        read_file( File::Spec->catfile( $root_path, 'src', $name ) ) );
}

## stubs : log, sender, timers, io watchers ##

my @sent;      ## "command | args" ##
my @timers;    ## armed timers ##

$code{'base.log'}                      = sub {TRUE};
$code{'base.logs'}                     = sub {TRUE};
$code{'protocol-7.command.send.local'} = sub {
    my $c = shift;
    push @sent, join ' | ', $c->{'command'}, $c->{'call_args'}{'args'} // '-';
    return TRUE;
};

{

    package FakeIO;
    my @all;

    sub new {
        my $s = bless { %{ $_[1] }, 'active' => 1 }, $_[0];
        push @all, $s;
        $s;
    }
    sub w         { $_[0] }
    sub data      { $_[0]{'data'} }
    sub fd        { $_[0]{'fd'} }
    sub cancel    { $_[0]{'active'} = 0 }
    sub is_active { $_[0]{'active'} }

    sub active {
        @all = grep { $_->{'active'} } @all;
        @all;
    }
}
$code{'event.add_io'}    = sub { FakeIO->new(shift) };
$code{'event.add_timer'} = sub {
    my $t = bless { %{ +shift }, 'active' => 1 }, 'FakeIO::Timer';
    push @timers, $t;
    return $t;
};
{

    package FakeIO::Timer;
    sub w      { $_[0] }
    sub data   { $_[0]{'data'} }
    sub cancel { $_[0]{'active'} = 0 }
}

## one select round over the active watchers, until $until is true ##
sub pump {
    my ( $until, $max ) = @ARG;
    my $end = time + ( $max // 8 );
    while ( time <= $end ) {
        return TRUE if $until->();
        my @w = FakeIO::active();
        last if not @w;
        my ( $r, $wr ) = ( IO::Select->new, IO::Select->new );
        foreach my $x (@w) {
            ( $x->{'poll'} =~ m{w} ? $wr : $r )->add( $x->{'fd'} );
        }
        my ( $rr, $ww ) = IO::Select->select( $r, $wr, undef, 0.1 );
        foreach my $x (@w) {
            next if not $x->is_active;
            my $hit = grep { $_ == $x->{'fd'} }
                ( $x->{'poll'} =~ m{w} ? @{ $ww // [] } : @{ $rr // [] } );
            $code{ $x->{'handler'} }->($x) if $hit;
        }
    }
    return $until->();
}

## fire the armed timers [ active ones, or every one with $all ] ##
sub fire {
    my $all = shift;
    my @due = grep { $all or $_->{'active'} } @timers;
    @timers = ();
    foreach my $t (@due) {
        $t->{'active'} = 0;
        $code{ $t->{'handler'} }->($t);
    }
    return scalar @due;
}

## everything the command could emit is collected and searched at the end ##
my ( @log, @replies, @requests );
$code{'base.log'}  = sub { push @log, join ' ', @ARG; TRUE };
$code{'base.logs'} = sub {
    my ( undef, $format, @arg ) = @ARG;
    push @log, sprintf $format, @arg;
    TRUE;
};
$code{'base.callback.cmd_reply'}
    = sub { push @replies, { 'id' => $ARG[0], %{ $ARG[1] } } };
my ( $paused, $resumed ) = ( 0, 0 );
$code{'base.zenki.pause_ondemand_timeout'}  = sub { $paused++ };
$code{'base.zenki.resume_ondemand_timeout'} = sub { $resumed++ };

load_module($ARG) foreach qw|
    usage.provider_list usage.credential_load
    usage.cmd.token-leak-check usage.leak_check.line usage.leak_check.gone
    usage.leak_check.report usage.leak_check.end_code
    plugin.usage.claude.credential_files plugin.usage.claude.secrets
    plugin.usage.kimi.credential_files plugin.usage.kimi.secrets
    plugin.usage.kimi.read_credential
    |;
## the real stream_child and interval modules ##
opendir my $dh, "$root_path/src" or die;
my @mods = grep {m{\A(?:stream_child\.|base\.interval\.)}} readdir $dh;
closedir $dh;
load_module($ARG) foreach @mods;

## provider_list finds plugin.usage.<name> : the dispatch subs ##
$code{"plugin.usage.$ARG"} = sub { }
    foreach qw| claude kimi |;
$code{'format.json.decode'} = sub { JSON::XS->new->utf8->decode( $ARG[0] ) };

my $tmp  = tempdir( 'leak-check-XXXXXX', 'TMPDIR' => 1, 'CLEANUP' => 1 );
my $home = "$tmp/home";
my $tree = "$tmp/tree";
END { system 'chmod', '-R', 'u+rwX', $tmp if defined $tmp }
$code{'usage.home_dir'} = sub {$home};

sub fake_token {
    return "FAKE-$ARG[0]-" . join '',
        map { ( 'a' .. 'z', 0 .. 9 )[ rand 36 ] } 1 .. 40;
}
my %token = map { $ARG => fake_token($ARG) }
    qw| claude-at claude-rt kimi-at kimi-rt kimi-old |;

sub put {
    my ( $path, $content ) = @ARG;
    ( my $dir = $path ) =~ s{/[^/]+\z}{};
    make_path($dir);
    open my $fh, '>:raw', $path or die "$path : $OS_ERROR";
    print {$fh} $content;
    close $fh;
}

my $json = JSON::XS->new->utf8->canonical;
put("$home/.claude/.credentials.json",
    $json->encode(
        {   'claudeAiOauth' => {
                'accessToken'  => $token{'claude-at'},
                'refreshToken' => $token{'claude-rt'}
            }
        }
    )
);
put("$home/.kimi/credentials/kimi-code.json",
    $json->encode(
        {   'access_token'  => $token{'kimi-at'},
            'refresh_token' => $token{'kimi-rt'},
            'token_type'    => 'Bearer-type',
            'expires_at'    => 2000
        }
    )
);
put("$home/.kimi-code/credentials/kimi-code-old.json",
    $json->encode(
        { 'access_token' => $token{'kimi-old'}, 'expires_at' => 1000 }
    )
);

$data{'usage'}{'provider'} = {
    'claude' => { 'cred_rel'     => '.claude/.credentials.json' },
    'kimi'   => { 'cred_rel_dir' => '.kimi-code/credentials' },
};
$data{'usage'}{'cfg'}{'leak_check_chunk'}       = 64;
$data{'system'}{'root_path'}                    = $root_path;
$data{'system'}{'path'}{'zenka-dirs'}{'var_P7'} = "$tmp/fake-var";
foreach my $type (qw| usage-leak-stop usage-leak-reap |) {
    $data{'base'}{'interval'}{'cfg'}{'type'}{$type}
        = { 'start' => 1, 'factor' => 1.6, 'cap' => 3, 'cap_jitter' => 0 };
}

my @cred = (
    $code{'plugin.usage.claude.credential_files'}->(),
    $code{'plugin.usage.kimi.credential_files'}->()->{'files'}->@*
);
die "credential lookup left the temp home\n"
    if grep { index( $ARG, "$home/" ) != 0 } @cred;
ok( @cred == 3, 'credential paths : three files, all in the temp home' );
my $current = $code{'plugin.usage.kimi.read_credential'}->();
ok( $current->{'token'} eq $token{'kimi-at'} && !length $current->{'error'},
    'kimi read_credential still picks the longest valid token'
);

## the tree : plain, binary, across chunk borders, in a file name ##
put( "$tree/plain.log", "a $token{'claude-at'} b\n$token{'claude-at'}\n" );
put( "$tree/sub/blob.bin",
    "\0\xff\0$token{'kimi-rt'}\0\n\0" . ( "\xfe" x 200 ) );
put( "$tree/sub/border",
    ( 'x' x 50 ) . $token{'claude-rt'} . ( 'y' x 200 ) . $token{'kimi-old'} );
put( "$tree/sub/dense",             $token{'kimi-at'} x 5 );
put( "$tree/sub/clean",             "Bearer-type FAKE-claude-at- only\n" );
put( "$tree/n-$token{'kimi-at'}",   $token{'kimi-at'} );
put( "$home/.n/private-notes/note", $token{'claude-at'} );
put( "$tree/locked",                $token{'claude-at'} );
chmod 0, "$tree/locked";
my $as_root = -r "$tree/locked";
make_path("$tree/closed");
chmod 0, "$tree/closed";
symlink( "$tree/plain.log", "$tree/link" )     or die $OS_ERROR;
symlink( "$home/.n",        "$tree/dir-link" ) or die $OS_ERROR;
POSIX::mkfifo( "$tree/fifo", 0600 ) or die $OS_ERROR;

my $command = sub {
    local $call = { 'args' => $ARG[0], 'reply_id' => 7 };
    return $code{'usage.cmd.token-leak-check'}->();
};
my $finish = sub {
    my $before = @replies;
    pump( sub { @replies > $before }, 20 );
    return $replies[-1] // {};
};

##[ a full run ]##

my $r = $command->("$tree $tree/sub $home");
ok( $r->{'mode'} eq 'deferred', 'the command answers deferred' );
my $second = $command->($tree);
ok( $second->{'mode'} eq 'false' && $second->{'data'} =~ m{\Arunning since },
    'a second call : running since ..'
);
my $dump = sub {
    local $Data::Dumper::Sortkeys = 1;
    return Data::Dumper::Dumper( \%data );
};
my $dump_running = $dump->();
my $reply        = $finish->();
my $report       = $reply->{'data'} // '';
print $report =~ s{^}{    | }mgr;

ok( ( $reply->{'mode'} // '' ) eq 'size' && $reply->{'id'} == 7,
    'the deferred reply : size mode, the caller reply id'
);
ok( $report =~ m{^secrets checked : 5 \[ claude access 1, claude refresh 1, }
        . qr{kimi access 2, kimi refresh 1 \]$}m,
    'secrets counted by kind, every kimi credential file'
);
ok( $report =~ m{^  \Q$tree\E/plain\.log : claude access x2$}m,
    'plain file : path, kind, count' );
ok( $report =~ m{^  \Q$tree\E/sub/blob\.bin : kimi refresh x1$}m,
    'binary file : hit' );
ok( $report
        =~ m{^  \Q$tree\E/sub/border : claude refresh x1, kimi access x1$}m,
    'hits across chunk borders, counted once'
);
ok( $report =~ m{^  \Q$tree\E/sub/dense : kimi access x5$}m,
    'adjacent hits : counted exactly, overlapping roots once'
);
ok( $report =~ m{^  \Q$tree\E/n-\[redacted\] : kimi access x1$}m,
    'a token in a file name is redacted' );
ok( $report =~ m{^files with a hit : 5$}m || $as_root,
    'no other hits : credential files, private notes, links excluded' );
ok( $as_root || ( $report =~ m{^skipped as unreadable : 2$}m
        && $report =~ m{^  \Q$tree\E/locked$}m
        && $report =~ m{^  \Q$tree\E/closed$}m ),
    'unreadable file and directory : counted and named'
);
ok( $report =~ m{^time taken : \d+\.\ds$}m, 'time taken' );
ok( !defined $data{'usage'}{'leak_check'}{'run'}
        && $paused == 1
        && $resumed == 1,
    'run state cleared, ondemand timeout paused and resumed'
);

##[ arguments ]##

$r = $command->("$tmp/no-such-$token{'claude-at'}");
ok( $r->{'mode'} eq 'false' && $r->{'data'} =~ m{path argument 1 : not found},
    'a missing path is refused, not echoed'
);
$r     = $command->("$home/.n/private-notes");
$reply = $finish->();
ok( ( $reply->{'data'} // '' ) =~ m{^files with a hit : 0$}m,
    'private notes stay out of scope when named'
);

## more unreadable files than are listed ##
foreach my $n ( 1 .. 8 ) {
    put( "$tmp/many/f$n", 'x' );
    chmod 0, "$tmp/many/f$n";
}
$command->("$tmp/many");
$reply = $finish->();
ok( $as_root || ( $reply->{'data'} =~ m{^skipped as unreadable : 8$}m
        && $reply->{'data'} =~ m{^  \.\. 3 more$}m ),
    'unreadable : the count and the first few paths'
);

##[ failures never read as clean ]##

put( "$tmp/dies.pl",
    "my \@in = <STDIN>; print STDERR \@in; print \@ARGV; exit 3;\n" );
$data{'usage'}{'cfg'}{'leak_check_helper'} = "$tmp/dies.pl";
$command->($tree);
$reply = $finish->();
ok( $reply->{'mode'} eq 'false' && $reply->{'data'} =~ m{incomplete},
    'a child that ends early : FALSE, incomplete' );

## the default places, and what the child is given [ a recording child ] ##
put( "$tmp/record.pl",
    "open my \$f, '>', '$tmp/request' or die; print {\$f} <STDIN>;\n" );
$data{'usage'}{'cfg'}{'leak_check_helper'} = "$tmp/record.pl";
$command->('');
my $cmdline = join ' ',
    $data{'usage'}{'leak_check'}{'run'}{'handle'}{'cmd'}->@*;
$finish->();
open my $req_fh, '<', "$tmp/request" or die $OS_ERROR;
my @request = <$req_fh>;
close $req_fh;
unlink "$tmp/request";
my @default
    = map { m{\Aroot (\w+)$} ? pack( 'H*', $1 ) : () } @request;
ok( "@default" eq "$tmp/fake-var $root_path/data/state "
        . "$root_path/data/development/chat $root_path",
    'default places : var dir, data/state, chat, the repo'
);
ok( !grep( { index( $cmdline, $ARG ) >= 0 } values %token ),
    'no token on the child command line' );

delete $data{'usage'}{'cfg'}{'leak_check_helper'};
{
    local $data{'usage'}{'provider'}{'claude'}{'cred_rel'} = 'none';
    local $code{'plugin.usage.kimi.secrets'};
    $r = $command->($tree);
    ok( $r->{'mode'} eq 'false' && $r->{'data'} =~ m{nothing was checked},
        'no secrets read : an error, not a clean report' );
}

## a broken credential file : nothing of it is logged ##
put( "$tmp/broken.json", "{ \"access_token\" : \"$token{'kimi-at'}\" oops" );
ok( !defined $code{'usage.credential_load'}->("$tmp/broken.json"),
    'a broken credential file : undef' );

##[ no token anywhere in what the command produced ]##

my $produced = join "\n", @log, ( map { $ARG->{'data'} } @replies ),
    $second->{'data'}, $r->{'data'}, @sent, $dump_running, $dump->();
## the request carries them as hex : that form must not stay either ##
ok( !grep( { index( $produced, $ARG ) >= 0 }
        map { ( $ARG, unpack 'H*', $ARG ) } values %token ),
    'no token in replies, log lines, sent commands or %data'
);

chmod 0700, "$tree/closed";

say "\n# $pass passed, $fail failed";
exit( $fail ? 1 : 0 );

#,,,.,,.,,,,,,.,,,,,.,.,,,...,,,.,.,.,,.,,...,..,,...,...,...,,.,,.,,,...,...,
#FLZ7O7Q6CO4AH2IWSEHKJRESDNTBNO32EXNATZB2MPGKUX4A4VD6UKNU2BNZU3EVDHMM6SOGIYELM
#\\\|4HW7UDYVXZIBA3JGELXBZZ4HUCP32HRONMLOIMLQPM4XNHQMRNV \ / AMOS7 \ YOURUM ::
#\[7]36DVIME6EPPGJYWKMPNILUVPEHTIKZWRVYQFAIGPEG67MIZ722CQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
