# task: screenshot zenka — code style and quality refresh

## context

the screenshot zenka is being used as the backend for X-11 window/region capture
commands. before expanding its role, the existing 5 modules need a style and
quality pass. the zenka is small so the scope is tight.

## style reference

read and follow: `data/ai-mem/kimi/coding-style.md`
also: `data/yaml/docs/protocol-7-coding-style.md`

## bugs to fix

### screenshot.cmd.get_region_color — triple `my $err_str` (critical)

lines 16, 19, and 22 each declare `my $err_str`, creating three distinct
lexicals in the same scope. perl silently shadows each previous one, so the
`defined $err_str` check at line 28 reads the third declaration (from the
`shift @RGB` branch), not the one set by `grab_region` or `scale_image`.

fix: declare once at the top, reassign without `my`:

```perl
my $err_str;
my $img = <[screenshot.grab_region]>->(@coords);
$err_str = $img if ref($img) ne qw| Imager |;

$img = <[screenshot.scale_image]>->( $img, 1, 1 ) if not defined $err_str;
$err_str = $img if not defined $err_str and ref($img) ne qw| Imager |;

my @RGB = <[screenshot.pixel_color]>->( $img, 0, 0 );
$err_str = shift @RGB if @RGB == 1;
```

## style fixes — all modules

### regex delimiters

replace all `/.../` and `s///` forms with `m||` and `s|||`:

```perl
## wrong
$param_str !~ /^(\d+ +){3}\d+$/
split( / +/, $param_str )

## correct
$param_str !~ m|^(\d+ +){3}\d+$|
split( m| +|, $param_str )
```

### $call pattern in cmd modules

the compiled-in `.cmd.` code header already declares and populates `$call`
before the module body runs (see bin/Protocol-7, "compiled-in .cmd. code
header"). do not redeclare it — that masks the real one:

```perl
## wrong — masks the header-provided $call, "my variable masks earlier
## declaration" warning
my $call      = shift // {};
my $param_str = $call->{'args'} // '';

## correct — use the already-declared $call directly
my $param_str = $call->{'args'} // '';
```

### internal module arg convention

`screenshot.grab_region`, `screenshot.pixel_color`, `screenshot.scale_image`
use `( my $x, my $y ) = @_` — replace with `@ARG`:

```perl
## wrong
( my $image, my $pos_x, my $pos_y ) = @_;

## correct
my ( $image, $pos_x, $pos_y ) = @ARG;
```

### die → warn + return

internal helpers (`pixel_color`, `scale_image`, `grab_region`) use `die` for
validation errors. replace with `warn` + undef return so callers can handle
gracefully:

```perl
## wrong
die "expected image as 'Imager' object" if ref( $image // '' ) ne 'Imager';

## correct
if ( ref( $image // '' ) ne qw| Imager | ) {
    warn 'expected image as Imager object <{C1}>';
    return undef;
}
```

### missing metadata headers

add `descr` to modules that lack it:

- `screenshot.grab_region`  — `descr = grab a screen region; returns Imager object or error string`
- `screenshot.pixel_color`  — `descr = return rgba values for a pixel in an Imager object`
- `screenshot.scale_image`  — `descr = scale an Imager object to given pixel dimensions`

### display env

`screenshot.grab_region` sets `$ENV{'DISPLAY'}` per-call. `init_code` already
sets `<x11.display>`. move the env assignment to `init_code` so grab_region
doesn't touch it:

in `screenshot.init_code`, after setting `<x11.display>`:
```perl
$ENV{'DISPLAY'} = <x11.display>;
```

remove the `$ENV{'DISPLAY'} = <x11.display>;` line from `screenshot.grab_region`.

### output filename

`write_png` generates filename with `time, $$`. use `<[base.ntime]>` for
higher resolution:

```perl
## wrong
my $out_path = sprintf '%s/screenshot_%d_%d.png', $out_dir, time, $$;

## correct
my $stamp    = <[base.ntime]>->(0) // time;
my $out_path = sprintf '%s/screenshot_%s.png', $out_dir, $stamp;
```

## acceptance

- `p7c screenshot.write_png "0 0 100 100"` succeeds and returns a path
- `p7c screenshot.get_region_color "0 0 100 100"` returns correct hex color
- no `my $err_str` re-declarations remain
- all regex uses `m||` or `m{}` delimiters
- `bin/ptd -c` passes on all 5 modules
- no `die` calls remain in any module

## dispatch

## kimi: apply the style and bug fixes above to all 5 screenshot zenka modules.
## start with the critical bug in get_region_color, then work through the
## style fixes. verify each module with bin/ptd -c before moving to the next.
## do not modify signature footer lines.

#,,..,..,,,.,,..,,,.,,,,.,,,,,,,,,,,.,,.,,.,,,..,,...,...,..,,.,.,...,,..,,,.,
#2ATEWVBBBQUGMT5G4V6JP4DPQ65XKMXZNLW4UMFL43BRR3HX6DXU3HI6ENPTHRZXUXFUGE2ZXI2EM
#\\\|LOAULFJZIRYMDVXYJAG4GCQLRDUYX6R2AGZKRG2FE5JJO2XVE2V \ / AMOS7 \ YOURUM ::
#\[7]SEZYEHOYN22XSWVX2QFFIZAD63JQWWSPE7DMXFI7NA3NYEVXDCCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
