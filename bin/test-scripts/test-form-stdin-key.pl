#!/usr/bin/env perl
## test : form.handler.stdin_key key handling [ no tty, stubbed host ]
##
## covers the plugin-mode key routing of src/form.handler.stdin_key [ shared
## by the user-edit and host-edit zenki ] : Enter / Right entry triggers,
## per-key delegation to <plugin>.handler.key, Left's two-way contract, Ctrl-C
## with and without an open in-frame prompt, and the ordinary-row submit /
## signal paths.  keys are fed the same way form.cmd.char-add injects them in
## no-tty mode : appended to <form.input_buffer>, which the REAL
## editor.input.next_key then decodes.  no terminal, no zenka, no network.

use v5.28;
use strict;
use warnings;
use English qw| -no_match_vars |;
use File::Spec;
use Cwd     qw| abs_path |;
use FindBin qw| $RealBin |;

BEGIN {
    my $up = File::Spec->updir;
    my $root
        = abs_path(
        File::Spec->rel2abs( File::Spec->catdir( $RealBin, $up, $up ) ) );
    unshift( @INC, File::Spec->catdir( $root, qw| data lib-path pm | ) );
    $main::root_path = $root;
}

use AMOS7::Protocol::P7Syntax qw| p7_syntax__translate |;

use constant TRUE    => 5;
use constant FALSE   => 0;
use constant UNKNOWN => 2;

our %code;
our %data;
our %keys;

my ( $pass, $fail ) = ( 0, 0 );

sub ok {
    my ( $cond, $label ) = @ARG;    ## local ok(), prototype-free ($;$)
    if ($cond) { $pass++; return }
    $fail++;
    print "FAIL : $label\n";
    return;
}

my $runtime_pragmas
    = q{no bytes; use File::stat; use open qw| :encoding(UTF-8) |;};

my $src_dir = $ENV{'P7_TEST_SRC_DIR'}
    // File::Spec->catdir( $main::root_path, qw| src | );

sub compile_module {
    my ($module_name) = @ARG;
    my $src_path = File::Spec->catfile( $src_dir, $module_name );
    open( my $fh, '<', $src_path ) or die "cannot read $src_path : $!";
    my $src = do { local $INPUT_RECORD_SEPARATOR; <$fh> };
    close($fh);
    ## strip the AMOS7 signature footer [ base64 could confuse <..> parsing ]
    $src =~ s{\n#,[^\n]*\n#[A-Z2-7]{40,}[^\n]*\n#\\\\\\\|.*\z}{}s;
    my $cref = eval "$runtime_pragmas sub {\n# line 1 \"$module_name\"\n"
        . p7_syntax__translate($src) . "\n}";
    die "compile failed for $module_name : $EVAL_ERROR" if not defined $cref;
    $code{$module_name} = $cref;
    return $cref;
}

##[ modules under test + their real dependency chain, compiled from src/ ]####

compile_module($ARG) for qw|
    form.handler.stdin_key
    editor.input.next_key
    editor.control.process_key
    editor.control.active_buffer
    editor.control.get_value
    editor.control.get_cursor
    editor.buffer.memory.length
    editor.buffer.memory.get_text
    editor.control.commands.move_cursor
    editor.control.commands.insert
    editor.control.commands.delete
    editor.buffer.memory.insert
    editor.buffer.memory.delete
    |;

##[ stubs : exactly what stdin_key calls outside that chain ]#################

my %stub_log;

$code{'base.logs'} = sub { return TRUE };

$code{'form.quit'} = sub {
    my (@args) = @ARG;
    push @{ $stub_log{'quit'} }, [@args];
    return TRUE;
};

$code{'form.submit'} = sub {
    push @{ $stub_log{'submit'} }, [];
    return TRUE;
};

$code{'form.removable_field'} = sub { return undef };

## the plugin standing in for plugin.user-edit.* / plugin.host-edit.* :
## records every key and returns a controllable value
$code{'test.plugin.handler.key'} = sub {
    my ( $state, $field, $key ) = @ARG;
    push @{ $stub_log{'plugin_key'} }, [ $field, $key ];
    return $stub_log{'plugin_result'} // TRUE;
};

##[ fixture : minimal editor state with one ordinary and one tab row ]########

sub reset_state {
    %stub_log = ();
    delete $data{'form'};
    $data{'form'}{'mode'}   = { qw| no_tty_debug | => TRUE };
    $data{'form'}{'schema'} = { qw| fields |       => [ {}, {} ] };
    $data{'form'}{'plugin'}{'registry'}{'by_key'}
        = { qw| tab_f | => qw| test.plugin | };
    $data{'form'}{'state'} = fresh_state();
    return;
}

sub fresh_state {
    return {
        qw| mode |         => qw| insert |,
        qw| active_field | => 1,
        qw| schema |       => {
            qw| fields | => [
                { qw| name | => qw| ordinary |, qw| readonly | => FALSE },
                {   qw| name |     => qw| tab_f |,
                    qw| plugin |   => qw| test.plugin |,
                    qw| readonly | => TRUE
                },
            ]
        },
        qw| fields | => {
            qw| ordinary | => {
                qw| text |     => qw| val |,
                qw| cursor |   => 3,
                qw| readonly | => FALSE
            },
            qw| tab_f | => {
                qw| text |     => qw| ab |,
                qw| cursor |   => 0,
                qw| readonly | => TRUE
            },
        },
    };
}

## no-tty key feed : the same buffer form.cmd.char-add appends to
sub feed_keys {
    my (@keys) = @ARG;
    $data{'form'}{'input_buffer'} .= join '', @keys;
    return $code{'form.handler.stdin_key'}->();
}

sub ed_state { return $data{'form'}{'state'} }

##[ 1 : Enter on a tab row enters plugin mode in one press ]##################

reset_state();
feed_keys("\n");

ok( ( ed_state()->{'mode'} // '' ) eq qw| plugin:tab_f |,
    'Enter on tab row : mode is plugin:tab_f'
);
ok( !ed_state()->{'fields'}{qw| tab_f |}{'readonly'},
    'Enter on tab row : readonly flipped to FALSE'
);
ok( !defined $stub_log{'submit'},
    'Enter on tab row : ' . 'form.submit NOT called' );
ok( !defined $stub_log{'plugin_key'},
    'Enter on tab row : the entering key never reaches the plugin handler' );
ok( ( $data{'form'}{'dirty'} // 0 ) > 0,
    'Enter on tab row : <form.dirty> bumped [ repaint ]' );
ok( length( $data{'form'}{'input_buffer'} ) == 0,
    'feed buffer fully drained by the real next_key decoder'
);

##[ 2 : Enter on an ordinary row submits ]####################################

reset_state();
ed_state()->{'active_field'} = 0;
feed_keys("\r");

ok( ref $stub_log{'submit'} eq 'ARRAY'
        && scalar @{ $stub_log{'submit'} } == 1,
    'Enter on ordinary row : form.submit called once'
);
ok( ( ed_state()->{'mode'} // '' ) eq qw| insert |,
    'Enter on ordinary row : no plugin mode'
);

##[ 3 : Right's two-stage entry trigger ]#####################################

## 3a : cursor at 0 on a NON-empty field -> first Right only moves

reset_state();
feed_keys("\e[C");

ok( ( ed_state()->{'mode'} // '' ) eq qw| insert |,
    'Right at cursor 0 [non-empty] : still insert mode [ first stage ]' );
ok( ed_state()->{'fields'}{qw| tab_f |}{'cursor'} == 1,
    'Right at cursor 0 : the ordinary cursor move stands [ now at 1 ]' );
ok( !defined $stub_log{'plugin_key'},
    'Right at cursor 0 : plugin handler not called' );

## 3b : cursor already past 0 -> Right enters

feed_keys("\e[C");

ok( ( ed_state()->{'mode'} // '' ) eq qw| plugin:tab_f |,
    'Right at cursor > 0 : enters plugin mode'
);
ok( !ed_state()->{'fields'}{qw| tab_f |}{'readonly'},
    'Right entry : readonly flipped to FALSE'
);

## 3c : EMPTY field -> the FIRST Right already enters

reset_state();
ed_state()->{'fields'}{qw| tab_f |}
    = { qw| text | => '', qw| cursor | => 0, qw| readonly | => TRUE };
feed_keys("\e[C");

ok( ( ed_state()->{'mode'} // '' ) eq qw| plugin:tab_f |,
    'Right on an EMPTY field : first press already enters'
);

##[ 4 : in plugin mode every key reaches the plugin's handler.key ]###########

reset_state();
feed_keys("\n");    ## enter plugin mode ##
$stub_log{'plugin_key'} = ();
feed_keys('c');

ok( ref $stub_log{'plugin_key'} eq 'ARRAY'
        && scalar @{ $stub_log{'plugin_key'} } == 1
        && $stub_log{'plugin_key'}[0][0] eq qw| tab_f |
        && $stub_log{'plugin_key'}[0][1] eq 'c',
    "in plugin mode : 'c' reaches test.plugin.handler.key (state, tab_f, c)"
);

feed_keys("\n");

ok( scalar @{ $stub_log{'plugin_key'} // [] } == 2
        && ( $stub_log{'plugin_key'}[1][1] // '' ) eq "\n",
    'in plugin mode : Enter reaches the plugin too [ no form-level submit ]'
);
ok( !defined $stub_log{'submit'},
    'in plugin mode : form.submit not called for the plugin keys' );
ok( ( ed_state()->{'mode'} // '' ) eq qw| plugin:tab_f |,
    'in plugin mode : mode unchanged after handled keys'
);

##[ 5 : Left in plugin mode : TRUE stays, FALSE leaves ]######################

$stub_log{'plugin_result'} = TRUE;
feed_keys("\e[D");

ok( scalar @{ $stub_log{'plugin_key'} // [] } == 3
        && $stub_log{'plugin_key'}[2][1] eq "\e[D",
    'Left in plugin mode : offered to the plugin handler FIRST'
);
ok( ( ed_state()->{'mode'} // '' ) eq qw| plugin:tab_f |,
    'Left while the plugin returns TRUE : stays in plugin mode'
);
ok( !ed_state()->{'fields'}{qw| tab_f |}{'readonly'},
    'Left while TRUE : readonly stays FALSE'
);

$stub_log{'plugin_result'} = FALSE;
feed_keys("\e[D");

ok( ( ed_state()->{'mode'} // '' ) eq qw| insert |,
    'Left while the plugin returns FALSE : leaves plugin mode'
);
ok( ed_state()->{'fields'}{qw| tab_f |}{'readonly'} == TRUE,
    'Left while FALSE : readonly restored to TRUE'
);

##[ 6 : Ctrl-C in plugin mode without a prompt -> quit, plugin untouched ]####

reset_state();
feed_keys("\n");    ## enter plugin mode ##
$stub_log{'plugin_key'} = ();
feed_keys("\x03");

ok( ref $stub_log{'quit'} eq 'ARRAY'
        && scalar @{ $stub_log{'quit'} } == 1
        && $stub_log{'quit'}[0][0] eq qw| cancelled |
        && $stub_log{'quit'}[0][1] eq qw| no-op |,
    'Ctrl-C in plugin mode, no prompt : form.quit (cancelled, no-op)'
);
ok( !defined $stub_log{'plugin_key'},
    'Ctrl-C in plugin mode, no prompt : plugin handler NOT called' );

##[ 7 : Ctrl-C in plugin mode WITH an open prompt -> plugin first ]###########

reset_state();
feed_keys("\n");    ## enter plugin mode ##
ed_state()->{'prompt'} = { qw| field | => qw| tab_f | };
$stub_log{'plugin_key'} = ();
feed_keys("\x03");

ok( ref $stub_log{'plugin_key'} eq 'ARRAY'
        && scalar @{ $stub_log{'plugin_key'} } == 1
        && $stub_log{'plugin_key'}[0][1] eq "\x03",
    'Ctrl-C with a prompt open : goes to the plugin handler [ cancels it ]'
);
ok( !defined $stub_log{'quit'},
    'Ctrl-C with a prompt open : form.quit NOT called' );

##[ 8 : Ctrl-C outside plugin mode -> the signal action quits ]###############

reset_state();
ed_state()->{'active_field'} = 0;
feed_keys("\x03");

ok( ref $stub_log{'quit'} eq 'ARRAY'
        && scalar @{ $stub_log{'quit'} } == 1
        && $stub_log{'quit'}[0][0] eq qw| cancelled |
        && $stub_log{'quit'}[0][1] eq qw| no-op |,
    'Ctrl-C outside plugin mode : process_key '
        . 'signal -> form.quit (cancelled, no-op)'
);
ok( !defined $stub_log{'submit'}, 'Ctrl-C : no submit' );

##[ summary ]#################################################################

print "\n$pass passed, $fail failed\n";
exit( $fail ? 1 : 0 );

#,,,,,..,,.,,,.,,,..,,,,.,.,,,..,,.,,,..,,.,,,..,,...,..,,.,,,,.,,...,..,,...,
#5CQLO3L6FJX6TPTENGDP72FVTLOWKWVCPHNCEAEKSWFVDA64JYAZK3MDJ4GKBXUHEKAUID6X3PTHI
#\\\|2WJEEQCNQIBQZ3GRYUOPABPSQQMCUL426V3FL3E4VO63JDF5QU5 \ / AMOS7 \ YOURUM ::
#\[7]5QQDPBMPINURDDFTWELCVCWLT7G42Y2J5RSBHSLGY7S42MROH4DI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
