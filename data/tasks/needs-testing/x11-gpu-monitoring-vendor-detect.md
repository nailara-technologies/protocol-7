## [:< ##

# name  = task: X-11 — vendor-agnostic GPU load monitoring
# descr = replace Intel-only gpu_top with auto-detecting backend:
#         nvidia-smi / intel_gpu_top / none — same stats interface above

## context

the X-11 zenka has GPU load monitoring for animation throttling (used by
tile-groups zenka to slow down animations under load). it was built for
Intel kiosk hardware exclusively. on systems with NVIDIA or no Intel GPU,
it just logs "binary not found" and runs without GPU monitoring.

the internal stats namespace (`X-11.gpu_top.stats.load_average`,
`X-11.gpu_top.stats.secs`, `X-11.gpu_top.stats.sample`) is a clean abstraction
boundary — `X-11.cmd.gpu_load` and alert logic above it need no changes.
only the detection, startup, and parser need to become vendor-aware.

## signatures note

do not add signature stubs. do not run `bin/Protocol-7 sourcecode update-signatures`.
do not add or modify subroutine whitelists — these are managed separately.

---

## what to read first

```bash
cat modules/X-11.init_code           ## binary detection loop (lines ~35-45)
cat modules/X-11.start_gpu_top       ## intel-specific startup
cat modules/X-11.handler.read_gpu_top ## intel JSON parser + stats update
cat modules/X-11.cmd.gpu_load        ## stats consumer — should need no changes
configuration/zenki/X-11/start       ## cfg.collect_intel_gpu_stats setting
```

---

## phase 1: vendor detection in init_code

file: `modules/X-11.init_code`

replace the Intel-only binary entries in the detection loop with a broader set,
and add vendor auto-detection logic after the loop:

```perl
## detect gpu vendor and available monitoring tool
## priority: nvidia-smi > intel_gpu_top > none
for my $bin_name ( qw[
    nvidia-smi
    intel_gpu_top
    intel_gpu_frequency
    ...other existing bins...
] ) {
    <X-11.bin_path>->{$bin_name} //= <[base.required_bin_path]>->($bin_name);
}

## auto-detect gpu vendor
my $nvidia_bin = <X-11.bin_path>->{'nvidia-smi'};
my $intel_bin  = <X-11.bin_path>->{'intel_gpu_top'};

if ( -x $nvidia_bin ) {
    <X-11.gpu_vendor> //= 'nvidia';
    <[base.log]>->( 1, "gpu monitoring: nvidia [ nvidia-smi ]" );
} elsif ( -x $intel_bin ) {
    <X-11.gpu_vendor> //= 'intel';
    <[base.log]>->( 1, "gpu monitoring: intel [ intel_gpu_top ]" );
} else {
    <X-11.gpu_vendor> //= 'none';
    <[base.log]>->( 2, "gpu monitoring: no supported tool found" );
}
```

also check: the config key `X-11.collect_intel_gpu_stats` — rename concept to
`X-11.collect_gpu_stats` or keep the old key as alias for backward compatibility.
read the start config file to see how it is currently set.

---

## phase 2: vendor-aware startup in start_gpu_top

file: `modules/X-11.start_gpu_top`

replace the Intel-only logic with a vendor branch:

```perl
my $vendor = <X-11.gpu_vendor> // 'none';

return <[base.log]>->( 2, 'gpu monitoring disabled [ no supported tool ]' )
    if $vendor eq 'none';

if ( $vendor eq 'nvidia' ) {
    ## nvidia-smi: poll at 1s intervals, output utilization %
    ## nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits -l 1
    my $nvidia_bin = <X-11.bin_path>->{'nvidia-smi'};

    <[base.log]>->( 1, "starting 'nvidia-smi' gpu monitor .," );

    <X-11.gpu_top.pid> = open3(
        undef, my $out_fh, undef,
        $nvidia_bin,
        qw| --query-gpu=utilization.gpu |,
        qw| --format=csv,noheader,nounits |,
        qw| -l 1 |
    );
    ## ... same pid/kill_list/event.add_io pattern as intel path ...
    ## handler: X-11.handler.read_gpu_nvidia

} elsif ( $vendor eq 'intel' ) {
    ## existing intel_gpu_top logic — keep as-is
    ## handler: X-11.handler.read_gpu_top (unchanged)
    ...
}
```

---

## phase 3: new handler for nvidia output

new file: `modules/X-11.handler.read_gpu_nvidia`

`nvidia-smi -l 1 --query-gpu=utilization.gpu --format=csv,noheader,nounits`
outputs one integer per second: `42\n67\n51\n...`

parse and update the same stats namespace as the intel handler:

```perl
## [:< ##

# name = X-11.handler.read_gpu_nvidia

## read available data from nvidia-smi pipe
my $read_fh = $data{'X-11'}{'gpu_nvidia.read_fh'};
my $data_ref = \$data{'X-11'}{'gpu_nvidia.output_buffer'};

my $bytes_read = sysread $read_fh, $$data_ref, 4096, length($$data_ref);

## process complete lines
while ( $$data_ref =~ s/^(\d+)\s*\n// ) {
    my $load_pct = 0 + $LAST_PAREN_MATCH;

    ## update sample ring + rolling averages
    ## use same logic as X-11.handler.read_gpu_top for stats update
    ## target namespace: X-11.gpu_top.stats.* (same as intel — shared interface)
}
```

look at `X-11.handler.read_gpu_top` for the exact stats update pattern to reuse.

---

## phase 4: rename cfg key (backward-compatible)

file: `modules/X-11.init_code` and `configuration/zenki/X-11/start`

`X-11.collect_intel_gpu_stats` → accept both old and new key:
```perl
<X-11.collect_gpu_stats> //= <X-11.collect_intel_gpu_stats> // 0;
```

update `configuration/zenki/X-11/start` to use `X-11.collect_gpu_stats` with
the old key commented as deprecated alias.

---

## test sequence

```bash
## verify vendor detection logs correctly on startup:
## on nvidia system: "gpu monitoring: nvidia [ nvidia-smi ]"
## on intel system:  "gpu monitoring: intel [ intel_gpu_top ]"
## on neither:       "gpu monitoring: no supported tool found"

## verify stats are populated after 5 seconds:
p7 X-11.cmd.gpu_load 5
## expected: integer percentage, not error

## verify no startup errors on WSL2 (no GPU tools):
## expected: "gpu monitoring: no supported tool found" — clean, no crash
```

## success criteria

- [ ] `nvidia-smi` detected and used when present
- [ ] `intel_gpu_top` used as fallback when present
- [ ] clean "no supported tool" log when neither present (no crash, no error)
- [ ] `X-11.handler.read_gpu_nvidia` parses nvidia-smi output into same stats namespace
- [ ] `X-11.cmd.gpu_load` unchanged and working with both backends
- [ ] `X-11.gpu_vendor` set correctly at init time
- [ ] `collect_intel_gpu_stats` config key still accepted (backward compat)
- [ ] no signature stubs added, no subroutine whitelist changes made

#,,..,,..,.,.,..,,,,,,,,,,,..,.,.,,,.,,.,,.,.,..,,...,...,.,.,.,.,,,.,,.,,.,,,
#GEDMDXDHQNPGSDB4HMZ7MSTD47DPLZVQ56OPZHJICLRY2JQU2C7N2PZ6EAH5UANOXMB7YRYKY2KZY
#\\\|ESKFSQPJUBU5WZ4RUJDRCI6EZPUXHFLKFX44P2RSCSRY5W3GK72 \ / AMOS7 \ YOURUM ::
#\[7]XTMPZE2MIVBPV7AZQQRZC4E3S3L77KCR4NJZQ7NBFANFQHSXO4CQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
