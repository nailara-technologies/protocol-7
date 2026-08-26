# task: DATA + TREE reply modes for base.callback.cmd_reply

## context

`base.callback.cmd_reply` currently supports: TRUE, FALSE, WAIT, SIZE,
CHRSIZE, TERM. this task adds DATA (streaming content) and TREE (structural
control) as two new complementary reply modes.

DATA and TREE are complements that share the stream_id. they oscillate —
the same node is simultaneously a TREE position and a DATA source. the `11`
pivot is the interpretation swap moment.

see `data/md/design/DATA-PROTOCOL-SYNC.md` for full DATA specification.
see `data/md/design/TREE-PROTOCOL.md` for full TREE specification.

## file to modify

`src/base.callback.cmd_reply`

add TWO new branches after the existing CHRSIZE branch (around line 85).

## DATA mode

```perl
} elsif ( uc($reply_mode) eq qw| DATA | ) {

    my $stream_id = $reply->{'stream_id'} // '';
    my $total     = $reply->{'total'}     // qw| STREAM |;

    ## encode total if numeric ##
    my $total_enc = ( $total =~ m|^\d+$| )
        ? <[base.encode_b32r]>->( \$total )
        : $total;    ## 'STREAM' | 'DELTA ...' passed through ##

    ## open frame ##
    $output->$* .= sprintf "%sDATA %s %s\n",
        $_cmd_id, $stream_id, $total_enc;

    ## chunk lines: 47 raw bytes = 76 base32 chars per line ##
    my $data  = $reply->{'data'} // '';
    my $chunk = 47;
    while ( length $data ) {
        my $slice = substr( $data, 0, $chunk, '' );
        $output->$* .= <[base.encode_b32r]>->( \$slice ) . "\n";
    }

    ## close frame with AMOS checksum ##
    my $chksum_fn = $code{'chk-sum.amos'} // $code{'base.chk-sum.amos'};
    my $checksum  = $chksum_fn->( \$reply->{'data'} );
    $output->$* .= sprintf "%sDATA END %s %s\n",
        $_cmd_id, $stream_id, $checksum;
```

reply hash fields for DATA mode:
```perl
{
    mode      => 'DATA',
    stream_id => $amos_checksum_of_source,   ## node_id or session anchor
    data      => $raw_bytes,                 ## content to stream
    total     => $byte_count,               ## optional; 'STREAM' if unknown
}
```

## TREE mode

```perl
} elsif ( uc($reply_mode) eq qw| TREE | ) {

    my $tree_id = $reply->{'tree_id'} // '';
    my $root    = $reply->{'root'}    // '';

    ## open frame ##
    $output->$* .= sprintf "%sTREE %s %s\n",
        $_cmd_id, $tree_id, $root;

    ## node lines — sorted by ref_count descending (base.reverse-sort) ##
    my @nodes = <[base.reverse-sort]>->( @{ $reply->{'nodes'} // [] } );

    for my $node ( @nodes ) {
        my $meta_b32 = $node->{'meta_b32'} // '';

        $output->$* .= sprintf "%s %s %s\n",
            $node->{'id'},
            $node->{'parent'} // 'ROOT',
            $meta_b32;

        ## emit REF line if DATA stream registered ##
        if ( my $stream_id = $node->{'stream_id'} ) {
            $output->$* .= sprintf "TREE REF %s %s %s\n",
                $tree_id, $node->{'id'}, $stream_id;
        }
    }

    ## close frame with AMOS checksum of all node IDs ##
    my $chksum_fn = $code{'chk-sum.amos'} // $code{'base.chk-sum.amos'};
    my $all_ids   = join ' ', map { $ARG->{'id'} } @nodes;
    my $checksum  = $chksum_fn->( \$all_ids );
    $output->$* .= sprintf "%sTREE END %s %s\n",
        $_cmd_id, $tree_id, $checksum;
```

reply hash fields for TREE mode:
```perl
{
    mode    => 'TREE',
    tree_id => $amos_checksum_id,
    root    => $root_node_id,
    nodes   => [
        {
            id        => $node_id,       ## AMOS checksum
            parent    => $parent_id,     ## or 'ROOT'
            meta_b32  => $b32_metadata,  ## name:refcount:face:child_count
            stream_id => $stream_id,     ## optional DATA stream reference
        },
        ...
    ],
}
```

## TREE/DATA duality notes

- both share the `stream_id` — the same identifier for same resource
- TREE is persistent control channel; DATA is ephemeral content flow
- TREE REF line declares DATA availability without opening the stream
- the `11` pivot: when a TREE session becomes DATA, the stream_id persists
- dump-keys:dump analogy — TREE:DATA = structure:content

## additional: SIZE mode with empty data guard

while editing the file, also verify the existing SIZE mode handles the
case where `$reply->{'data'}` is defined but zero-length (currently
guarded by `$reply->{'mode'} ne 'size'` check — ensure this still works).

## success criteria

- [ ] DATA mode emits: open frame + B32 chunks (47 bytes each) + END+AMOS
- [ ] DATA mode correctly handles empty data (empty chunk sequence)
- [ ] TREE mode emits: open + node lines + optional REF lines + END+AMOS
- [ ] TREE node lines sorted by ref_count descending (base.reverse-sort)
- [ ] both modes use AMOS swap-boundary for checksum
- [ ] module passes ptd
- [ ] no signature stubs
- [ ] existing SIZE/CHRSIZE/TRUE/FALSE modes unaffected

## dispatch note

isolated module edit — no dependencies on other tasks.
parallel-safe with all space-engine-*.md and branch-calc-*.md tasks.

#,,,.,...,..,,.,,,,..,.,.,,..,,..,..,,.,.,,,.,..,,...,..,,.,.,,,,,.,.,.,,,.,,,
#VBDFJF5N3ATWMKQOCU2ACV3XMPUYLKA6YYRNRBKOTKBEAX6SSSTPSMX5JC4MD63MP56QRTTFU5RXE
#\\\|LEOSMMEEUTHMC2SBNTWWMXH3MSVU35J22NIJTPCGPLRMUKVLEJ2 \ / AMOS7 \ YOURUM ::
#\[7]ZI5IBNIGRBSE3LUZMRGFNQ2O3VDEHMDFMTAO4B3HTZHBMHKQPKAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
