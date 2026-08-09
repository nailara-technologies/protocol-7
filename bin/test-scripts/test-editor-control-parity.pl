#!/usr/bin/perl
## parity test : editor.control.* [ char offsets, semantics-only ] vs
## AMOS7::TERM::editor_process_key [ byte offsets ] — same keystrokes, same
## observable editing state after EVERY key.
##
## old path state is byte-based ; compared after decoding to characters [
## incl. multi-byte UTF-8 cases so the char-offset conversion is proven, not
## coincidentally matching on ASCII ].

use v5.28;
use strict;
use warnings;
use English qw| -no_match_vars |;
use FindBin qw| $RealBin |;

BEGIN { unshift( @INC, "$RealBin/../../data/lib-path/pm" ) }

use AMOS7;
use AMOS7::TERM;
use AMOS7::Protocol::P7Syntax qw| p7_syntax__translate |;

use constant TRUE    => 5;
use constant FALSE   => 0;
use constant UNKNOWN => 2;

our ( %data, %code, %colors, %keys );
%colors = ( 'p7_fg_0003' => '', 'p7_fg_0004' => '' );

my $module_dir = "$RealBin/../../modules";

my @module_files = qw|
    editor.buffer.memory.create
    editor.buffer.memory.load
    editor.buffer.memory.save
    editor.buffer.memory.insert
    editor.buffer.memory.delete
    editor.buffer.memory.get_line
    editor.buffer.memory.get_text
    editor.buffer.memory.length
    editor.control.create
    editor.control.active_buffer
    editor.control.process_key
    editor.control.commands.insert
    editor.control.commands.delete
    editor.control.commands.move_cursor
    editor.control.load_field
    editor.control.get_value
    editor.control.get_cursor
    editor.control.reset
    editor.control.submit
    |;

for my $file (@module_files) {
    open( my $fh, '<', "$module_dir/$file" ) or die "open $file : $!";
    my $src = do { local $/; <$fh> };
    close($fh);
    $src =~ s{\n#,[^\n]*\n#[A-Z2-7]{40,}[^\n]*\n#\\\\\\\|.*\z}{}s;
    my $translated = p7_syntax__translate($src);
    my $cref = eval( "sub {\n# line 1 \"$file\"\n" . $translated . "\n}" );
    die "compile $file : $@" if ref $cref ne 'CODE';
    $code{$file} = $cref;
}

##[ helpers ]#################################################################

my ( $pass, $fail ) = ( 0, 0 );

sub check {
    my ( $cond, $label ) = @_;
    if ($cond) { $pass++; return }
    $fail++;
    print "FAIL : $label\n";
    return;
}

sub decoded {    ## copy + decode byte string to characters ##
    my $s = shift // '';
    utf8::decode($s) if not utf8::is_utf8($s);
    return $s;
}

sub old_state {    ## old path observable state, in CHARACTERS ##
    my ($ed) = @_;
    my $buf_chars = decoded( $ed->{'buffer'} );
    my $cur_chars
        = length decoded( substr( $ed->{'buffer'}, 0, $ed->{'cursor_pos'} ) );
    return ( $buf_chars, $cur_chars, decoded( $ed->{'kill_buffer'} ) );
}

sub new_state {    ## new path observable state ##
    my ($st) = @_;
    return (
        $code{'editor.control.get_value'}->( $st, 'command' ),
        $code{'editor.control.get_cursor'}->( $st, 'command' ),
        $st->{'kill_buffer'},
    );
}

##[ dual-path driver ]########################################################

my $old_ed = AMOS7::TERM::editor_init();
my $schema = {
    'fields'    => [ { 'name' => 'command', 'type' => 'freeform_line' } ],
    'submit_on' => 'enter',
};
my $new_st = $code{'editor.control.create'}->($schema);
die "editor.control.create failed" if not defined $new_st;

my $step = 0;

sub feed_key {
    my ($key) = @_;
    $step++;

    my $old_res = AMOS7::TERM::editor_process_key( $old_ed, $key, %colors );
    my $new_res = $code{'editor.control.process_key'}->( $new_st, $key );

    ## action parity [ old 'newline' == new 'submit' ]
    my $old_action = $old_res->{'action'} // 'none';
    my $new_action = $new_res->{'action'} // 'none';
    my $expected   = $old_action eq 'newline' ? 'submit' : $old_action;
    check(
        $new_action eq $expected,
        "step $step key="
            . key_desc($key)
            . " action : new='$new_action' expected='$expected'"
    );

    ## signal parity
    if ( $old_action eq 'signal' ) {
        check( ( $new_res->{'signal'} // '' ) eq 'INT',
            "step $step signal value" );
    }

    ## newline/submit : submit BOTH paths, compare submitted text + reset
    if ( $old_action eq 'newline' ) {
        my $old_text = AMOS7::TERM::editor_submit($old_ed);
        my $sub      = $code{'editor.control.submit'}->($new_st);
        check( $sub->{'ok'} == 1, "step $step submit ok" );
        check(
            decoded($old_text) eq $sub->{'values'}{'command'},
            "step $step submitted text : '"
                . $sub->{'values'}{'command'}
                . "' vs '"
                . decoded($old_text) . "'"
        );
    }

    ## full observable state parity after EVERY key
    my ( $ob, $oc, $ok ) = old_state($old_ed);
    my ( $nb, $nc, $nk ) = new_state($new_st);
    check( $nb eq $ob,
        "step $step key=" . key_desc($key) . " buffer : '$nb' vs '$ob'" );
    check( $nc == $oc,
        "step $step key=" . key_desc($key) . " cursor : $nc vs $oc" );
    check(
        $nk eq $ok,
        "step $step key="
            . key_desc($key)
            . " kill_buffer : "
            . "'$nk' vs '$ok'"
    );
    return;
}

sub key_desc {
    my ($k) = @_;
    return $k =~ m{^[\x20-\x7e]+$}
        ? "'$k'"
        : join( ' ', map { sprintf '%02x', ord } split //, $k );
}

sub feed {
    my ( $label, @keys ) = @_;
    print ".. $label\n";
    feed_key($ARG) for @keys;
    return;
}

##[ keystroke script ]########################################################

feed( 'ascii typing', split //, 'echo hello world' );
feed( 'left x2, backspace, delete, right',
    "\e[D", "\e[D", "\x7f", "\e[3~", "\e[C" );
feed( 'ctrl-a ctrl-e', "\x01", "\x05" );
feed( 'ctrl-w yank',   "\x17", "\x19" );
feed( 'ctrl-k yank',   "\x0b", "\x19" );
feed( 'ctrl-u yank',   "\x15", "\x19" );
feed( 'submit',        "\n" );

## multi-byte utf-8 fed as raw byte sequences [ as the terminal sends them ]
feed( 'utf-8 typing', 'h', "\xc3\xa9", 'l', 'l', 'o' );
feed( 'left x3, backspace [ deletes the 2-byte é as ONE char ]',
    "\e[D", "\e[D", "\e[D", "\x7f" );
feed( 'right over multibyte + ctrl-d',   "\xc3\xa9", "\x01", "\e[C", "\x04" );
feed( 'home, delete-key over multibyte', "\x01",     "\e[C", "\e[3~" );
feed( 'submit utf-8',                    "\n" );

feed( 'word ops with spaces',              split //, 'foo  bar  ' );
feed( 'ctrl-w x2 [ trailing-space skip ]', "\x17",   "\x17" );
feed(
    'mid-line multibyte insert', "\x01",
    "\e[C",                      "\xc3\xa9",
    "\e[D",                      "\x7f"
);
feed( 'ctrl-c signal [ advisory, no kill ]', "\x03" );
feed( 'buffer survives signal, submit',      "\n" );

feed( 'unclaimed keys pass through', "\e[A", "\e[B", "\x0f", "\x12" );
feed( 'double yank',             split //, 'ab' );
feed( 'ctrl-k at end [ no-op ]', "\x0b" );
feed( 'ctrl-a ctrl-k yank yank', "\x01", "\x0b", "\x19", "\x19" );
feed( 'final submit',            "\n" );

##[ accessor / command API checks [ new path only ] ]#########################

print ".. accessor api\n";

## load_field cursor placement : 'end' default / 'start' / int offset
$code{'editor.control.load_field'}->( $new_st, 'command', "h\xc3\xa9llo" );
check(
    $code{'editor.control.get_cursor'}->( $new_st, 'command' ) == 5,
    'load_field default cursor=end [ chars, not bytes ]'
);
$code{'editor.control.load_field'}->( $new_st, 'command', 'abc', 'start' );
check( $code{'editor.control.get_cursor'}->( $new_st, 'command' ) == 0,
    'load_field cursor=start' );
$code{'editor.control.load_field'}->( $new_st, 'command', 'abcdef', 3 );
check( $code{'editor.control.get_cursor'}->( $new_st, 'command' ) == 3,
    'load_field cursor=int offset' );

## load_field clears kill buffer [ matches editor_load ]
$new_st->{'kill_buffer'} = 'x';
$code{'editor.control.load_field'}->( $new_st, 'command', 'q' );
check( $new_st->{'kill_buffer'} eq '', 'load_field clears kill_buffer' );

## active_buffer resolves name vs index correctly
my $ab = $code{'editor.control.active_buffer'}->($new_st);
check( ref $ab eq 'HASH' and $ab == $new_st->{'fields'}{'command'},
    'active_buffer resolves active field buffer' );

## buffer contract direct checks
check( $code{'editor.buffer.memory.length'}->($ab) == 1,
    'buffer.length in characters' );
check( $code{'editor.buffer.memory.get_line'}->( $ab, 0 ) eq 'q',
    'buffer.get_line line 0' );
check(
    !defined $code{'editor.buffer.memory.get_line'}->( $ab, 1 ),
    'buffer.get_line line 1 undef [ single-line field ]'
);
my $saved;
check(
    $code{'editor.buffer.memory.save'}->( $ab, \$saved ) == TRUE
        and $saved eq 'q',
    'buffer.save to scalarref'
);

## reset gate : validator failure keeps input, success resets
my $v_schema = {
    'fields' => [
        {   'name'      => 'command',
            'type'      => 'freeform_line',
            'validator' => sub { length( $ARG[0] ) ? undef : 'empty' },
        }
    ],
};
my $v_st = $code{'editor.control.create'}->($v_schema);
my $r    = $code{'editor.control.submit'}->($v_st);
check( $r->{'ok'} == 0 and $r->{'errors'}{'command'} eq 'empty',
    'submit ok=0 on validator failure' );
$code{'editor.control.load_field'}->( $v_st, 'command', 'kept' );
$code{'editor.control.submit'}->($v_st);
check( $code{'editor.control.get_value'}->( $v_st, 'command' ) eq '',
    'submit resets fields only on ok=1' );

## reset : per-field vs all
$code{'editor.control.load_field'}->( $new_st, 'command', 'xyz' );
$new_st->{'kill_buffer'} = 'k';
$code{'editor.control.reset'}->( $new_st, 'command' );
check(
    $code{'editor.control.get_value'}->( $new_st, 'command' ) eq ''
        and $new_st->{'kill_buffer'} eq 'k',
    'per-field reset keeps kill_buffer'
);
$code{'editor.control.load_field'}->( $new_st, 'command', 'xyz' );
$new_st->{'kill_buffer'} = 'k';
$code{'editor.control.reset'}->($new_st);
check( $new_st->{'kill_buffer'} eq '', 'full reset clears kill_buffer' );

##[ result ]##################################################################

printf "\n%d checks : %d passed, %d failed\n", $pass + $fail, $pass, $fail;
exit( $fail ? 1 : 0 );

#,,..,...,,,,,.,,,,,.,,..,,,,,.,.,,,.,,,,,,..,..,,...,...,...,...,..,,,.,,.,.,
#P3WC4ICB3WUS6PLWZV2SHKCBMFW3OXAMINICAQXHKBXNGIF3YUYTQAZZLZWFBNR4U44IZ2LQDSZK6
#\\\|3ZRWHJ2GKCN46CKOV34U2PKWWZJDO7ERVBBDL6MQQACHCLABJ2M \ / AMOS7 \ YOURUM ::
#\[7]IC6GVARVVNEVPDYYJ7GB5YLR25GTKUBDKO7KN4KU737ZG2R2GCCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
