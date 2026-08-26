## [:< ##

# name  = task: screenshot — complete write_png command implementation
# descr = remove stub return and wire Imager PNG output

## context

commit `44ca50f9f` (2020-02-14) added the `screenshot.write_png` command as a
stub. the first line returns `"not implemented yet"`, making the rest of the
module dead code. however, the supporting modules (`screenshot.grab_region`,
`screenshot.scale_image`, `screenshot.pixel_color`) were fully implemented in
the same commit.

analysis reference: `data/md/development/DEGRADED-FEATURES-AUDIT.md`

## signatures note

do not add signature stubs. do not run `bin/Protocol-7 sourcecode update-signatures` —
the human will run it manually. do not add or modify subroutine whitelists.

---

## fix 1: remove stub return

file: `src/screenshot.cmd.write_png`

remove the early return:
```perl
return {
    'mode' => qw| false |,
    'data' => "not implemented yet"
};    # <-- << ! >>
```

the code below it already parses coordinates, calls `screenshot.grab_region`,
and validates the Imager object. keep that logic.

note from direct inspection: the module currently stops after the error check —
the PNG write call itself was never written. so this is fix 1 + fix 2 together.

## fix 2: add PNG write path

after the error check for `$err_str`, add:

```perl
my $output_path = <screenshot.cfg.output_path> // '/tmp/screenshot.png';
my $write_ok = $image->write(
    'file' => $output_path,
    'type' => 'png'
);

return {
    'mode' => qw| false |,
    'data' => "unable to write PNG [ " . Imager->errstr . " ]"
} if not $write_ok;

return {
    'mode' => qw| true |,
    'data' => $output_path
};
```

from reading `src/screenshot.init_code`: no `cfg.output_dir` or output
path default exists. add to init_code alongside existing display defaults:
```perl
<screenshot.cfg.output_dir> //= '/var/protocol-7/screenshot/';
```
then construct the path in the command:
```perl
my $out_dir  = <screenshot.cfg.output_dir>;
<[base.file.make_path]>->($out_dir) unless -d $out_dir;
my $out_path = sprintf '%s/screenshot_%d_%d.png', $out_dir, time, $$;
```

## fix 3: test with live X11 display

```bash
## verify the module loads and the command is reachable:
./bin/Protocol-7 screenshot cmd.write_png '0 0 100 100'
```

check that a PNG file is created at the expected path and contains the
captured region.

## success criteria

- [ ] early `"not implemented yet"` return removed
- [ ] `Imager->write('type' => 'png')` wired into the success path
- [ ] output path is configurable or derived from arguments
- [ ] command returns `{ mode => 'true', data => $path }` on success
- [ ] test run produces a valid PNG file
- [ ] no signature stubs added, no subroutine whitelist changes made

#,,..,..,,,..,.,.,...,.,.,...,,..,.,.,,..,,..,..,,...,...,.,.,..,,.,.,...,,,.,
#UM3DILKQNT3AB7GLSUZFF7GHKTRCQSCIN5ML5UJHK5VOYXZDXEUNHEMSD7RCUZX2UOS3SZJD3EIMG
#\\\|2HOOBC4OX4GBPMOHTFJANE46HW75QFV2VIJ52GFTLIATUKDR6H4 \ / AMOS7 \ YOURUM ::
#\[7]JHIT7ESZVQECY7ISG3O6EBEMNZSHYVJXX7NE3EBD4W5GDLQBF2BI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
