## task: models adapter export/import — step 4

create 2 modules implementing collection profile export/import for the invoke
adapter. this is the final step of the path adapter system.

p7 style: lowercase comments, [ brackets ], $ARG not $_, <[module]>->() syntax.
do NOT add #,,... stub lines. leave files clean for signing.
use $data{'models'}{'external.models.invokeai.path'} for config access (not cfg).


## read these files first

    src/models.storage.adapter.invoke.discover   (returns model records)
    src/models.storage.adapter.invoke.resolve    (resolves to disk path)
    src/models.registry.populate_from_yaml       (how yaml snapshots work)
    bin/scripts/invoke-ai/invoke-model-recover       lines 146-207 (dry_run + list logic)


## modules to create (2 files)

### src/models.storage.adapter.invoke.export

    # name  = models.storage.adapter.invoke.export
    # descr = export invoke model collection to portable yaml snapshot

    input:  $ARG = optional hashref:
        {
            output_path => '/path/to/snapshot.yaml',  # default: /tmp/invoke-models-YYYYMMDD.yaml
            records     => [ ... ],                    # optional pre-fetched records
        }

    logic:
        - if no records passed, call <[models.storage.adapter.invoke.discover]>
        - for each record, call <[models.storage.adapter.invoke.resolve]> to get abs path
        - for each resolved file: compute sha256 checksum (use Digest::SHA or sha256sum cli)
        - build yaml structure:
            ---
            generated: <ISO timestamp>
            adapter: invoke
            model_count: N
            models:
              - name: perfection-realistic-ilxl-v32-sdxl
                type: main
                base: sdxl
                format: diffusers
                path: 23cf4e5b-...     # as in db
                size: 4294967296
                source: https://...
                source_type: hf_repo_id
                sha256: abc123...      # of model.safetensors or dir manifest
                on_disk: 1             # 1 if resolved, 0 if missing
        - write yaml to output_path using YAML::PP or YAML::XS with :utf8
        - return hashref: { path => $output_path, total => N, on_disk => N, missing => N }


### src/models.storage.adapter.invoke.import

    # name  = models.storage.adapter.invoke.import
    # descr = restore invoke model collection from yaml snapshot

    input:  $ARG = hashref:
        {
            snapshot_path => '/path/to/snapshot.yaml',
            dry_run       => 0,
        }

    logic:
        - read and parse yaml snapshot
        - validate: check adapter field eq 'invoke'
        - for each model entry:
            - call <[models.storage.adapter.invoke.resolve]> to check if on disk
            - if on disk: skip (already have it), count as 'have'
            - if missing and not dry_run: log "would download [ name ]" (stub — actual
              download via install module is async, just queue here)
            - count: have, missing, queued
        - return hashref: { have => N, missing => N, queued => N }

    note: actual download triggering is stubbed — import identifies what's missing
    and logs it. wiring to async install is a follow-up task.


## also create cmd wrappers

### src/models.cmd.adapter-export

    # name  = models.cmd.adapter-export
    # descr = cmd: export model collection snapshot for a host adapter

    my ( $host, $output_path ) = split m|\s+|, $call->{'args'} // '', 2;
    $host //= 'invoke';

    my $result;
    if ( $host eq 'invoke' ) {
        $result = <[models.storage.adapter.invoke.export]>->(
            { output_path => $output_path }
        );
        my $out = sprintf "exported %d models (%d on disk, %d missing) → %s\n",
            $result->{'total'}, $result->{'on_disk'},
            $result->{'missing'}, $result->{'path'};
        return { mode => qw| size |, data => $out };
    }
    return { mode => qw| false | };


### src/models.cmd.adapter-import

    # name  = models.cmd.adapter-import
    # descr = cmd: restore model collection from snapshot

    my @tokens       = split m|\s+|, $call->{'args'} // '';
    my $host         = shift @tokens // 'invoke';
    my %flags        = map { $_ => 1 } @tokens;
    my $snapshot     = ( grep { !m|^:| } @tokens )[0] // '';
    my $dry_run      = $flags{':dry-run:'} ? 1 : 0;

    my $result;
    if ( $host eq 'invoke' ) {
        $result = <[models.storage.adapter.invoke.import]>->(
            { snapshot_path => $snapshot, dry_run => $dry_run }
        );
        my $out = sprintf "have=%d missing=%d queued=%d\n",
            $result->{'have'}, $result->{'missing'}, $result->{'queued'};
        return { mode => qw| size |, data => $out };
    }
    return { mode => qw| false | };


## wire into models zenka start

add to access.cmd.usr.cube: adapter-export adapter-import
(modules.load unchanged — models.* loads automatically)


## verify

ptd -c on all 4 files, report done.

#,,,.,...,.,,,,..,...,...,,,,,..,,,.,,.,,,,,.,..,,...,.,.,,,,,,,.,,,.,,,,,,,,,
#AHBFJJD4P5SRMMGAYN6ON7HF2DBM7ZO34SUBYJQ4RCKNQPMGPZ3HO555ZQS5VGOSNDNESS3I4QQ4W
#\\\|4MCXJ76LDFVS4B2LT7CADLI7KHL3CQO3NQZTEJ7SNBUOJ7LUVWK \ / AMOS7 \ YOURUM ::
#\[7]4NUS7DC3M4OGZQ2LKOITQOTT33TWIS5IUPXICKULKTUWCBCMESCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
