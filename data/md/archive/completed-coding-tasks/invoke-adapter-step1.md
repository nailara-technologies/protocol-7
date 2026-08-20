## task: models.storage.adapter.invoke — step 1 (module extraction)

extract proven invoke path logic into 6 p7 modules. zero new logic — this is
reorganization only. all code already exists in the two source scripts.

p7 code style: lowercase comments, [ brackets ] for annotations, no capitals
in comments. use :flag: not --flag. use $ARG not $_. closing ]> before -> in
module invocations: <[module.name]>->($args).


## source files to read first

    bin/scripts/invoke-ai/invoke-model-recover    (691 lines)
        — query_database() starts at line 76
        — get_filename() starts at line 427

    bin/scripts/invoke-ai/invoke-symlink-repair   (229 lines)
        — read fully; repair module is extracted from this whole script


## modules to create (6 files)

### modules/models.storage.adapter.invoke.discover

module header:
    # name  = models.storage.adapter.invoke.discover
    # descr = query invokeai.db and return list of model records

extract query_database() from invoke-model-recover (line 76).
adapt to p7 module style:
- no sub declaration — file IS the subroutine
- reads config key 'external.models.invokeai.db' (via $data{'models'}{'cfg'}
  or direct config lookup) for db path; falls back to
  ~/.invokeai/db/invokeai.db
- uses sqlite3 cli + JSON::PP (same as script)
- skips type IN (spandrel_image_to_image, unknown)
- skips path matching ^[A-Za-z]:[\\/] or ^/
- returns arrayref of model hashrefs:
  { name, type, base, format, path, size, source, source_type }

look at how other models.* modules access config (e.g. models.discover or
models.storage.discover) to get the right config access pattern.


### modules/models.storage.adapter.invoke.resolve

module header:
    # name  = models.storage.adapter.invoke.resolve
    # descr = resolve invoke model record to absolute on-disk path

input: $ARG = model record hashref
output: absolute path string if found on disk, undef if not

logic (from get_filename in invoke-model-recover + symlink-repair path logic):
    my $root = $data{'models'}{'cfg'}{'external.models.invokeai.path'}
               // '/mnt/ext-xfs-data/models-invoke';
    my $path = $ARG->{'path'} // return undef;

    ## bare uuid → diffusers directory ##
    if ( $path =~ /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i ) {
        return -d "$root/$path" ? "$root/$path" : undef;
    }

    ## uuid/filename → single file, try decoded and raw variants ##
    if ( $path =~ m{^([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})/(.+)$}i ) {
        my ( $uuid, $filename_raw ) = ( $1, $2 );
        my $filename_decoded = URI::Escape::uri_unescape($filename_raw);
        for my $fn ( $filename_decoded, $filename_raw ) {
            return "$root/$uuid/$fn" if -f "$root/$uuid/$fn";
        }
        return undef;
    }

    return undef;

use URI::Escape (autoload if not present).


### modules/models.storage.adapter.invoke.repair

module header:
    # name  = models.storage.adapter.invoke.repair
    # descr = create verbose-path symlinks for invoke model storage

this module IS invoke-symlink-repair, adapted to p7 module style.

input: $ARG may be a hashref with keys:
    dry_run  => 1 (if :dry-run: was passed)
    type     => 'main' (optional filter)
    records  => [ ... ] (optional pre-fetched records from discover)

if records not passed, call models.storage.adapter.invoke.discover to get them.

the full symlink creation logic from invoke-symlink-repair:
- %BASE_ALIASES: sd-1 → [sd-1, sd-1.5], sdxl → [sdxl], sd-2 → [sd-2], etc.
- for each record: determine link names (decoded + raw if different)
- resolve target via models.storage.adapter.invoke.resolve
- create {root}/{base_alias}/{type}/{link_name}[.ext] → target symlinks
- use File::Path::make_path for parent dirs
- skip if link already exists and points to same target
- count: created, skipped, missing, failed

return hashref: { created => N, skipped => N, missing => N, failed => N }

print summary line regardless of dry_run status.


### modules/models.cmd.adapter.discover

module header:
    # name  = models.cmd.adapter.discover
    # descr = cmd: list models from a host adapter

thin command wrapper:
    my $host = $call_args // 'invoke';
    if ( $host eq 'invoke' ) {
        my $records = <[models.storage.adapter.invoke.discover]>->();
        my $count   = scalar @{ $records // [] };
        <[base.logs]>->( 1, "adapter.discover [ invoke ] : %d models", $count );
        for my $rec ( @{ $records // [] } ) {
            printf "%-10s %-8s %-12s %s\n",
                $rec->{'type'}, $rec->{'base'}, $rec->{'format'}, $rec->{'name'};
        }
    } else {
        <[base.logs]>->( 0, "unknown adapter [ %s ]", $host );
    }


### modules/models.cmd.adapter.resolve

module header:
    # name  = models.cmd.adapter.resolve
    # descr = cmd: resolve a model name to its on-disk path

    my ( $host, $model_name ) = split m|\s+|, $call_args // '', 2;
    $host       //= 'invoke';
    $model_name //= '';
    if ( $host eq 'invoke' ) {
        my $records = <[models.storage.adapter.invoke.discover]>->();
        my ($rec)   = grep { $_->{'name'} eq $model_name } @{ $records // [] };
        if ($rec) {
            my $path = <[models.storage.adapter.invoke.resolve]>->($rec);
            if ($path) {
                print "$path\n";
            } else {
                <[base.logs]>->( 0, "model not found on disk [ %s ]", $model_name );
            }
        } else {
            <[base.logs]>->( 0, "model not in db [ %s ]", $model_name );
        }
    }


### modules/models.cmd.adapter.repair

module header:
    # name  = models.cmd.adapter.repair
    # descr = cmd: repair path structure for a host adapter

    my @tokens  = split m|\s+|, $call_args // '';
    my $host    = shift @tokens // 'invoke';
    my %flags   = map { $_ => 1 } @tokens;
    my $dry_run = $flags{':dry-run:'} ? 1 : 0;

    if ( $host eq 'invoke' ) {
        my $result = <[models.storage.adapter.invoke.repair]>->({
            dry_run => $dry_run,
        });
        <[base.logs]>->( 1,
            "adapter.repair [ invoke ] : created=%d skipped=%d missing=%d failed=%d",
            $result->{'created'}, $result->{'skipped'},
            $result->{'missing'}, $result->{'failed'}
        );
    } else {
        <[base.logs]>->( 0, "unknown adapter [ %s ]", $host );
    }


## wiring into models zenka

edit cfg/zenki/models/start:

1. add to modules.load line (after 'models'):
       storage.adapter.invoke cmd.adapter

2. add to access.cmd.usr.cube list:
       adapter.discover adapter.resolve adapter.repair


## verification after creating files

check each file with:  ptd -c modules/models.storage.adapter.invoke.discover
                       ptd -c modules/models.storage.adapter.invoke.resolve
                       ptd -c modules/models.storage.adapter.invoke.repair
                       ptd -c modules/models.cmd.adapter.discover
                       ptd -c modules/models.cmd.adapter.resolve
                       ptd -c modules/models.cmd.adapter.repair

do NOT add the #,,.,,... signature stub line. leave files clean — the signing
system adds the real 4-line AMOS7 footer.

when all 6 files pass ptd -c and the start file is updated, report done.

#,,..,,.,,...,,,,,,.,,,.,,,,,,,..,,.,,,.,,,.,,..,,...,..,,,.,,,,.,,.,,.,.,,,,,
#62RJCRKVK5H6KD5H4DOQ6JQ5W7KUZVSP2NP67Q4QCKF5QLR2MX2I4QZ7V4LBSJZALVPAGPHSJMEVA
#\\\|J6MLR2NVI3R5UU5NXSR2SKNXOJEROWNT24H4AJDUUVOPIXQONBE \ / AMOS7 \ YOURUM ::
#\[7]2GP2DLQELDIGQF2H5TZT2HKNHRN4CBGA2NCAICQZLH6NSGMTTUDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
