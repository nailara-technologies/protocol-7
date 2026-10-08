#!/usr/bin/env perl
use v5.24;
use strict;
use English;
use warnings;

## host-edit lane B2c-ui : the 'host actions' DETAIL TAB [                  ##
## plugin.host-edit.actions.* ] driven through its key handling with the    ##
## add-host FLOW stubbed -- a live flow would write REAL pins into the      ##
## user's pin store, so host-edit.flow.* NEVER run here : start /           ##
## passphrase / cancel are replaced with recording stubs, and the record is ##
## an in-memory stub.  the editor.control.prompt.* family is stubbed too,   ##
## faithfully to its documented contract [ spec keys, $editor_state         ##
## {'prompt'} shape, busy guard, %code-resolved on_submit ] -- the units    ##
## under test are the plugin modules themselves, compiled from src/.        ##

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

my ( $test_count, $fail_count ) = ( 0, 0 );

sub ok ($;$) {
    my ( $cond, $label ) = @ARG;
    $test_count++;
    if ($cond) { say "  ok   : $label"; return 1 }
    $fail_count++;
    say "  FAIL : $label";
    return 0;
}

my $runtime_pragmas
    = q{no bytes; use File::stat; use open qw| :encoding(UTF-8) |;};

sub compile_module {
    my ($module_name) = @ARG;
    my $src_path
        = File::Spec->catfile( $main::root_path, 'src', $module_name );
    open( my $fh, '<', $src_path ) or die "cannot read $src_path : $!";
    my $src = join( '', <$fh> );
    close($fh);
    my $cref = eval "$runtime_pragmas sub {\n# line 1 \"$module_name\"\n"
        . p7_syntax__translate($src) . "\n}";
    die "compile failed for $module_name : $EVAL_ERROR" if not defined $cref;
    $code{$module_name} = $cref;
    return $cref;
}

## --- the flow NEVER runs : recording stubs --------------------------- ##

my @flow_calls;
my $flow_state = {};    ## stands in for <host-edit.flow> per record ##

$code{'host-edit.flow.start'} = sub {
    my ($name) = @ARG;
    push @flow_calls, [ qw| start |, $name ];
    $flow_state->{$name} = {
        qw| step |   => qw| connect |,
        qw| status | => 'starting',
    };
    return TRUE;
};

$code{'host-edit.flow.passphrase'} = sub {
    my ( $name, $value ) = @ARG;
    push @flow_calls, [ qw| passphrase |, $name, $value ];
    return FALSE if not ref $flow_state->{$name};
    $flow_state->{$name}{'step'}   = qw| certify |;
    $flow_state->{$name}{'status'} = "certifying with '$value' ..";
    return TRUE;
};

$code{'host-edit.flow.cancel'} = sub {
    my ($name) = @ARG;
    push @flow_calls, [ qw| cancel |, $name ];
    delete $flow_state->{$name};
    return TRUE;
};

## the client pin store NEVER gets read here either : fixed columns ##
$code{'host-edit.trust.pin_state'} = sub {
    return {
        qw| trust | =>
            sprintf( q|key %s · %s · since %s|, qw| YB25FNI test-leaf 0 | ),
        qw| owner_trust | => q|no owner configured|,
    };
};

$code{'form.chrome.set_status'} = sub {
    push @flow_calls, [ qw| status |, shift // '' ];
    return TRUE;
};

## --- editor.control.prompt.* : contract-faithful stubs ---------------    ##
## same $editor_state->{'prompt'} shape the real prompt.open builds, same   ##
## %code-resolved on_submit, same busy guard, same 'cancelled' result, same ##
## masked rendering into the anchoring row                                  ##

$code{'editor.control.prompt.open'} = sub {
    my ( $editor_state, $spec ) = @ARG;
    return FALSE if ref $editor_state ne 'HASH';
    return FALSE if ref $spec ne 'HASH';
    return FALSE if not length( $spec->{'field'} // '' );
    return FALSE if not length( $spec->{'label'} // '' );
    my $type = $spec->{'type'} // 'freeform_line';
    $type = 'freeform_line' if $type ne 'masked';
    $editor_state->{'prompt'} = {
        qw| field |     => $spec->{'field'},
        qw| label |     => $spec->{'label'},
        qw| type |      => $type,
        qw| buffer |    => { qw| text | => '', qw| cursor | => 0 },
        qw| on_submit | => $spec->{'on_submit'},
        qw| on_cancel | => $spec->{'on_cancel'},
        qw| data |      => $spec->{'data'} // {},
        qw| busy |      => FALSE,
    };
    return TRUE;
};

$code{'editor.control.prompt.render'} = sub {
    my ( $editor_state, $field ) = @ARG;
    my $prompt = $editor_state->{'prompt'} // return undef;
    return undef if ref $prompt ne 'HASH';
    return undef if ( $prompt->{'field'} // '' ) ne $field;
    my $text = $prompt->{'buffer'}{'text'} // '';
    $text = ( '*' x length $text )
        if ( $prompt->{'type'} // '' ) eq 'masked';
    return sprintf( "<%s> %s\x01", $prompt->{"label"}, $text );
};

$code{'editor.control.prompt.cursor_char'} = sub {
    my ( $editor_state, $field ) = @ARG;
    my $prompt = $editor_state->{'prompt'} // return '';
    return '' if ref $prompt ne 'HASH';
    return '' if ( $prompt->{'field'} // '' ) ne $field;
    my $text   = $prompt->{'buffer'}{'text'}   // '';
    my $cursor = $prompt->{'buffer'}{'cursor'} // 0;
    return '' if $cursor >= length $text;
    return substr( $text, $cursor, 1 );
};

$code{'editor.control.prompt.cancel'} = sub {
    my ($editor_state) = @ARG;
    delete $editor_state->{'prompt'}
        if ref $editor_state eq 'HASH';
    return TRUE;
};

$code{'editor.control.prompt.handler.key'} = sub {
    my ( $editor_state, $key ) = @ARG;
    my $prompt = $editor_state->{'prompt'};
    return FALSE if ref $prompt ne 'HASH';
    return TRUE  if $prompt->{'busy'};

    if ( $key eq "\x03" ) {    ## Ctrl-C : unconditional cancel ##
        $code{'editor.control.prompt.cancel'}->($editor_state);
        return qw| cancelled |;
    }

    if ( $key eq "\e[D" or $key eq "\x1b[D" ) {    ## Left ##
        if ( length( $prompt->{'buffer'}{'text'} // '' ) > 0 ) {
            $prompt->{'buffer'}{'cursor'}--;
            return TRUE;
        }
        $code{'editor.control.prompt.cancel'}->($editor_state);
        return qw| cancelled |;
    }

    if ( $key eq "\n" or $key eq "\r" ) {          ## Enter : submit ##
        my $submit_sub = $prompt->{'on_submit'}      // '';
        my $value      = $prompt->{'buffer'}{'text'} // '';
        if ( length $submit_sub and exists $code{$submit_sub} ) {
            $prompt->{'busy'} = TRUE;
            $code{$submit_sub}->( $editor_state, $value, $prompt );
            $prompt->{'busy'} = FALSE;
        }
        return TRUE;
    }

    if ( $key eq "\x7f" or $key eq "\x08" ) {      ## Backspace ##
        my $cursor = $prompt->{'buffer'}{'cursor'} // 0;
        if ( $cursor > 0 ) {
            substr( $prompt->{'buffer'}{'text'}, $cursor - 1, 1, '' );
            $prompt->{'buffer'}{'cursor'}--;
        }
        return TRUE;
    }

    if ( $key !~ m|[\x00-\x1f\x7f]| and $key !~ m|^\e| ) {
        my $cursor = $prompt->{'buffer'}{'cursor'} // 0;
        substr( $prompt->{'buffer'}{'text'}, $cursor, 0, $key );
        $prompt->{'buffer'}{'cursor'} += length $key;
        return TRUE;
    }

    return TRUE;
};

## --- the modules under test, compiled from src/ ---------------------- ##

compile_module($ARG) for qw| plugin.host-edit.actions.tab_info
    plugin.host-edit.actions.build_field
    plugin.host-edit.actions.render
    plugin.host-edit.actions.render_state
    plugin.host-edit.actions.cursor_char
    plugin.host-edit.actions.handler.key
    plugin.host-edit.actions.submit_passphrase
    form.schema_from_record |;

## --- stub schema_from_record's own helpers : never the record ------ ##

$code{'base.logs'}         = sub { return TRUE };
$code{'base.reverse-sort'} = sub {
    my ($href) = @ARG;
    return sort { length($b) <=> length($a) or $b cmp $a } keys %$href;
};
$code{'form.multiline_field_names'}        = sub {return};
$code{'form.collapse_summary_field_names'} = sub {return};
$code{'form.build_user_keys_field'}        = sub { return {} };

## --- fixture : a stubbed host record --------------------------------- ##

my $record = {
    qw| name |   => qw| zz-test |,
    qw| fields | => {
        qw| ssh |       => '',
        qw| owner_key | => '',
    },
};

## <a.b> translates to $data{'a'}{'b'} -- the harness fills the same nested ##
## shape the runtime's init_code autovivifies                               ##
$data{'form'} = {
    qw| username | => qw| zz-test |,
    qw| record |   => $record,
    qw| source |   =>
        { qw| synth_fields | => qw| plugin.host-edit.actions.build_field |, },
};
$data{'host-edit'} = { qw| flow | => $flow_state };

sub editor_stub {
    return {
        qw| mode |   => 'insert',
        qw| fields | => { qw| host_actions | => {} },
    };
}

sub last_call {
    my ($op) = @ARG;
    my @found = grep { $ARG->[0] eq $op } @flow_calls;
    return @found ? $found[-1] : undef;
}

## === 1 : tab_info ===================================================== ##

my $tab_info = $code{'plugin.host-edit.actions.tab_info'}->();

ok( ref $tab_info eq 'HASH', 'tab_info returns a hashref' );
ok( ( $tab_info->{'label'} // '' ) eq q| host actions |,
    'tab_info label is "host actions"' );
ok( ref $tab_info->{'pinned_keys'} eq 'ARRAY'
        && $tab_info->{'pinned_keys'}[0] eq 'host_actions',
    'tab_info pins the synthesised host_actions key'
);

## === 2 : schema push [ the generic hook ] ============================ ##

my $schema = $code{'form.schema_from_record'}->( $record, qw| enter | );

ok( ref $schema eq 'HASH', 'schema built for the stub record' );

my ($host_actions_def)
    = grep { ( $ARG->{'name'} // '' ) eq qw| host_actions | }
    @{ $schema->{'fields'} // [] };

ok( ref $host_actions_def eq 'HASH',
    'synthesised host_actions field present in the schema' );
ok( ( $host_actions_def->{'plugin'} // '' ) eq qw| plugin.host-edit.actions |,
    'host_actions field def carries the plugin name'
);
ok( $host_actions_def->{'readonly'} eq TRUE,
    'host_actions field def is readonly'
);
ok( ref $host_actions_def->{'display_override'} eq 'CODE',
    'host_actions field def carries a display_override coderef'
);

## the flow state has a row of its own, directly under host_actions ##
my @schema_names
    = map { $ARG->{'name'} // '' } @{ $schema->{'fields'} // [] };
my ($actions_at)
    = grep { $schema_names[$ARG] eq qw| host_actions | } 0 .. $#schema_names;
my ($action_state_def)
    = grep { ( $ARG->{'name'} // '' ) eq qw| action_state | }
    @{ $schema->{'fields'} // [] };
ok( ref $action_state_def eq 'HASH'
        && $action_state_def->{'readonly'} eq TRUE
        && !defined $action_state_def->{'plugin'}
        && ref $action_state_def->{'display_override'} eq 'CODE',
    'action_state : readonly row with a display_override, no plugin'
);
ok( defined $actions_at
        && ( $schema_names[ $actions_at + 1 ] // '' ) eq qw| action_state |,
    'action_state sits directly under host_actions'
);

## user-edit output stays identical : no synth_fields registered -> no      ##
## host_actions, and the self-record synthesised fields are untouched [ the ##
## stub record is not the invoking user's own record here ]                 ##

{
    local $data{'form'}{'source'} = {};
    my $plain_schema
        = $code{'form.schema_from_record'}->( $record, qw| enter | );
    my ($unexpected)
        = grep { ( $ARG->{'name'} // '' ) eq qw| host_actions | }
        @{ $plain_schema->{'fields'} // [] };
    ok( !defined $unexpected,
        'no synth_fields source key -> no host_actions field [user-edit path]'
    );
}

## === 3 : render per flow step ========================================= ##

my $editor_state = editor_stub();

my $render_out = $host_actions_def->{'display_override'}
    ->( $editor_state, qw| host_actions | );

my $fixed_row = $render_out;
ok( defined $render_out
        && $render_out eq q{'->  add host [Enter] .:. [c]ancel},
    'actions row is fixed : add host + cancel only, no pin \ flow text'
);

my $state_out = $action_state_def->{'display_override'}
    ->( $editor_state, qw| action_state | );
ok( defined $state_out && $state_out eq '',
    'action state ' . 'empty with no flow'
);

## tab mode wraps and stars the hint ##
$editor_state->{'mode'} = qw| plugin:host_actions |;
my $tab_render = $host_actions_def->{'display_override'}
    ->( $editor_state, qw| host_actions | );
ok( ( $tab_render =~ m|\A<<< .* >>>\z| ) && $tab_render =~ m|\*add host\*|,
    'render in tab mode wraps with <<< >>> and stars the hint'
);
$editor_state->{'mode'} = qw| insert |;

## a running flow : step + status show, and repaint-freely -- the render ##
## reads <host-edit.flow> live, nothing cached in the field def          ##
$flow_state->{qw| zz-test |} = {
    qw| step |   => qw| probe |,
    qw| status | => 'probing the host-root ..',
};
$render_out = $host_actions_def->{'display_override'}
    ->( $editor_state, qw| host_actions | );
$state_out = $action_state_def->{'display_override'}
    ->( $editor_state, qw| action_state | );
ok( $render_out eq $fixed_row
        && $state_out eq q{probe : probing the host-root ..},
    'running flow : actions row unchanged, step + status in action state'
);

## probed but not yet pinned : the next key hint appears ##
$flow_state->{qw| zz-test |}{'key_id'}    = 'A' x 77;
$flow_state->{qw| zz-test |}{'leaf_name'} = qw| zz-test.root |;
$state_out = $action_state_def->{'display_override'}
    ->( $editor_state, qw| action_state | );
ok( $state_out =~ m|next key zz-test\.root \[ AAAAAAA\.\. \]|
        && length($state_out) <= 60,
    'action state shows the next key hint, capped at 60 characters'
);

## finished : no next key hint, and an error points at the status line ##
$flow_state->{qw| zz-test |}{'step'}   = qw| done |;
$flow_state->{qw| zz-test |}{'status'} = qw| pinned |;
$state_out = $action_state_def->{'display_override'}
    ->( $editor_state, qw| action_state | );
ok( $state_out eq q{done : pinned}, 'flow done : no next key hint' );

$flow_state->{qw| zz-test |}{'step'}   = qw| error |;
$flow_state->{qw| zz-test |}{'status'} = '<< ' . ( 'x' x 200 ) . ' >>';
$state_out = $action_state_def->{'display_override'}
    ->( $editor_state, qw| action_state | );
ok( $state_out eq q{error : see status line},
    'flow error : short pointer, not the long message'
);
$flow_state->{qw| zz-test |}{'step'}   = qw| probe |;
$flow_state->{qw| zz-test |}{'status'} = 'probing the host-root ..';

## === 4 : Enter -> flow.start ========================================== ##

@flow_calls        = ();
$flow_state        = {};
$data{'host-edit'} = { qw| flow | => $flow_state };

ok( $code{'plugin.host-edit.actions.handler.key'}
        ->( $editor_state, qw| host_actions |, "\n" ) eq TRUE,
    'handler.key claims Enter'
);
my $started = last_call(qw| start |);
ok( ref $started eq 'ARRAY' && $started->[1] eq qw| zz-test |,
    'Enter with no flow calls host-edit.flow.start(zz-test)'
);

## done / error restart the flow ##
foreach my $done_step (qw| done error |) {
    $flow_state->{qw| zz-test |} = {
        qw| step |   => $done_step,
        qw| status | => 'pinned',
    };
    @flow_calls = ();
    $code{'plugin.host-edit.actions.handler.key'}
        ->( $editor_state, qw| host_actions |, "\r" );
    ok( ref last_call(qw| start |) eq 'ARRAY',
        "Enter with step '$done_step' restarts the flow"
    );
}

## a mid-run step does NOT restart ##
$flow_state->{qw| zz-test |} = {
    qw| step |   => qw| pin |,
    qw| status | => 'pinning ..',
};
@flow_calls = ();
$code{'plugin.host-edit.actions.handler.key'}
    ->( $editor_state, qw| host_actions |, "\n" );
ok( !defined last_call(qw| start |),
    'Enter with a running step does not restart the flow' );

## === 5 : need_passphrase -> masked prompt -> submit =================== ##

$flow_state->{qw| zz-test |} = {
    qw| step |   => qw| need_passphrase |,
    qw| status | => "passphrase for owner key 'own.key' ?",
};

@flow_calls = ();
$code{'plugin.host-edit.actions.handler.key'}
    ->( $editor_state, qw| host_actions |, "\n" );

ok( !defined last_call(qw| start |),
    'Enter at need_passphrase does not start a new flow' );
ok( ref $editor_state->{'prompt'} eq 'HASH',
    'need_passphrase opens the in-frame prompt'
);
ok( $editor_state->{'prompt'}{'type'} eq qw| masked |,
    'the passphrase prompt is masked' );
ok( ( $editor_state->{'prompt'}{'field'} // '' ) eq qw| host_actions |,
    'the prompt anchors to the host_actions row' );
ok( ( $editor_state->{'prompt'}{'on_submit'} // '' ) eq
        qw| plugin.host-edit.actions.submit_passphrase |,
    'the prompt submits to plugin.host-edit.actions.submit_passphrase'
);

## while the prompt is open, keys belong to it : typed through the PLUGIN's ##
## own handler, the same delegation a live terminal key takes               ##
foreach my $chr ( split '', qw| sekrit-pass | ) {
    $code{'plugin.host-edit.actions.handler.key'}
        ->( $editor_state, qw| host_actions |, $chr );
}
my $typed = $editor_state->{'prompt'}{'buffer'}{'text'} // '';
ok( $typed eq qw| sekrit-pass |,
    'typed passphrase chars land in the prompt buffer via the plugin handler'
);

## render IS the prompt while it is open ##
$render_out = $host_actions_def->{'display_override'}
    ->( $editor_state, qw| host_actions | );
## random star masking [ editor.buffer.mask_star_count ] : the star run is ##
## the buffer's own mask_stars total, never the passphrase length [ a      ##
## buffer without mask_stars falls back to one star per character ]        ##
my @mask  = @{ $editor_state->{'prompt'}{'buffer'}{'mask_stars'} // [] };
my $stars = 0;
$stars += $ARG for @mask;
$stars = length $typed if not @mask;
ok( defined $render_out
        && $render_out =~ m|owner key passphrase|
        && $stars >= 11
        && $render_out =~ m|\*{$stars}\x01|,
    'render shows the masked prompt while it is open [ random star run ]'
);

## Enter submits : the plugin handler delegates to the prompt handler, ##
## whose on_submit calls flow.passphrase and CLOSES the prompt         ##
@flow_calls = ();
$code{'plugin.host-edit.actions.handler.key'}
    ->( $editor_state, qw| host_actions |, "\n" );

my $pass_call = last_call(qw| passphrase |);
ok( ref $pass_call eq 'ARRAY'
        && $pass_call->[1] eq qw| zz-test |
        && $pass_call->[2] eq qw| sekrit-pass |,
    'submit hands the typed value to host-edit.flow.passphrase(zz-test, ..)'
);
ok( ref $flow_state->{qw| zz-test |} eq 'HASH'
        && $flow_state->{qw| zz-test |}{'step'} eq qw| certify |,
    'the stub flow resumed at certify'
);
ok( !exists $editor_state->{'prompt'},
    'the prompt is closed after its submit'
);

## === 6 : prompt cancel leaves plugin mode ============================= ##

$flow_state->{qw| zz-test |} = {
    qw| step |   => qw| need_passphrase |,
    qw| status | => 'waiting',
};
$editor_state->{'mode'} = qw| plugin:host_actions |;
$code{'plugin.host-edit.actions.handler.key'}
    ->( $editor_state, qw| host_actions |, "\n" );
ok( ref $editor_state->{'prompt'} eq 'HASH', 'second prompt opened' );

$code{'plugin.host-edit.actions.handler.key'}
    ->( $editor_state, qw| host_actions |, "\x03" );

ok( !exists $editor_state->{'prompt'}, 'Ctrl-C cancels the prompt' );
ok( ( $editor_state->{'mode'} // '' ) eq qw| insert |
        && $editor_state->{'fields'}{qw| host_actions |}{'readonly'} eq TRUE,
    'prompt cancel restores insert mode + readonly, still in the frame'
);

## === 7 : 'c' -> flow.cancel =========================================== ##

@flow_calls = ();
$code{'plugin.host-edit.actions.handler.key'}
    ->( $editor_state, qw| host_actions |, qw| c | );
my $cancel_call = last_call(qw| cancel |);
ok( ref $cancel_call eq 'ARRAY' && $cancel_call->[1] eq qw| zz-test |,
    "'c' calls host-edit.flow.cancel(zz-test)" );

## === 8 : Left leaves plugin mode, other keys are no-ops =============== ##

ok( $code{'plugin.host-edit.actions.handler.key'}
        ->( $editor_state, qw| host_actions |, "\e[D" ) eq FALSE,
    'Left declines with FALSE [leave-plugin-mode signal]'
);
ok( $code{'plugin.host-edit.actions.handler.key'}
        ->( $editor_state, qw| host_actions |, qw| x | ) eq TRUE,
    'unclaimed keys are swallowed as handled no-ops'
);
@flow_calls = ();
ok( $code{'plugin.host-edit.actions.handler.key'}
        ->( $editor_state, qw| host_actions |, qw| x | ) eq TRUE
        && !@flow_calls,
    'a no-op key touches neither flow nor status'
);

## === summary ========================================================== ##

say '';
if ($fail_count) {
    say "  $fail_count of $test_count checks FAILED";
    exit 1;
}
say "  all $test_count checks passed";
exit 0;

#,,.,,,.,,,,,,.,,,,..,,.,,..,,...,,..,..,,,.,,..,,...,...,..,,,,,,.,.,..,,.,.,
#3CKNJ6VIFUK4WDMQ27CYJSJSLYCFAQAYNLELVWH3XZTPJEMSSGGRTY5RDRRYJLHQDVH2LRBQ7PHTG
#\\\|XBJHLZCB6C75UXQPQEWNJH4NWRRN6Y2OJSOFTC35AGCIIVQ4IEH \ / AMOS7 \ YOURUM ::
#\[7]B3RHOE3QABFFACGZOHSFF6MOZADB74RMJ2ASQD66H3J27YOV4OAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
