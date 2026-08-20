## [:< ##

# name  = task: web-browser — native get_snapshot command via WebKit2GTK
# descr = implement web-browser.cmd.get_snapshot using webkit_web_view_get_snapshot()

## context

WebKit2GTK 4.1 provides `webkit_web_view_get_snapshot()` which captures the
rendered WebView directly to a GdkPixbuf (PNG-saveable), with no external tools.

this eliminates the Xvfb + scrot/chromium-headless pipeline previously planned
for the visual-feedback capture system. the web-browser zenka screenshots itself
on P7 command — cleaner, faster, no process spawning overhead.

analysis reference: `data/md/development/WEB-BROWSER-WEBKIT2-UPGRADE-ANALYSIS.md`
section 4a (get_snapshot — native screenshot).

## signatures note

do not add signature stubs. do not run `bin/Protocol-7 sourcecode update-signatures` —
the human will run it manually after all fixes are applied (requires signing key passphrase).
do not add or modify subroutine whitelists — these are managed separately.

---

## what to read first

```bash
cat modules/web-browser.init_view
cat modules/web-browser.open_window
cat modules/web-browser.cmd.get_uri
cat cfg/zenki/web-browser/zenka-startup.v7
```

understand how `<web-browser.gtk_obj.view>` (the active foreground WebView) is
stored, and how existing async commands return deferred results, before implementing.

---

## implementation

### 1. add cfg defaults in init_code

file: `modules/web-browser.init_code`

add alongside other `cfg.*` defaults:
```perl
<web-browser.cfg.snapshot_dir>  //= '/var/protocol-7/visual-feedback/capture/';
<web-browser.cfg.snapshot_region> //= 'WEBKIT_SNAPSHOT_REGION_VISIBLE';
```

### 2. implement web-browser.cmd.get_snapshot

new file: `modules/web-browser.cmd.get_snapshot`

```perl
## [:< ##

# name = web-browser.cmd.get_snapshot

my $call = shift;

## get the active foreground view
my $view_index = <web-browser.overlay.index.fg> // 1;
my $view = <web-browser.gtk_obj.view>->{$view_index};

return 'no active view' unless defined $view;

## determine output path
my $snap_dir  = <web-browser.cfg.snapshot_dir>;
my $timestamp = time;
my $out_path  = "$snap_dir/snapshot_${timestamp}_$$.png";

## ensure output directory exists
<[base.file.make_path]>->($snap_dir) unless -d $snap_dir;

my $region = <web-browser.cfg.snapshot_region>;

## async snapshot — result delivered via handler
<web-browser.snapshot.pending_path> = $out_path;
<web-browser.snapshot.pending_call> = $call;

$view->get_snapshot(
    $region,
    'WEBKIT_SNAPSHOT_OPTIONS_NONE',
    undef,    ## cancellable
    $code{'web-browser.handler.snapshot_result'},
    undef     ## user_data
);

## return deferred — handler sends reply when snapshot completes
return undef;
```

### 3. implement web-browser.handler.snapshot_result

new file: `modules/web-browser.handler.snapshot_result`

```perl
## [:< ##

# name = web-browser.handler.snapshot_result

my ( $view, $async_result ) = @_;

my $out_path  = delete <web-browser.snapshot.pending_path>;
my $call      = delete <web-browser.snapshot.pending_call>;

my $pixbuf = eval { $view->get_snapshot_finish($async_result) };

if ( $@ or not defined $pixbuf ) {
    <[base.log]>->( 1, "snapshot failed: $@" );
    <[base.reply]>->( $call, 'snapshot failed' ) if defined $call;
    return;
}

## save to PNG
my $err;
$pixbuf->save( $out_path, 'png', \$err );

if ( defined $err ) {
    <[base.log]>->( 1, "snapshot save failed: $err" );
    <[base.reply]>->( $call, "save failed: $err" ) if defined $call;
    return;
}

<[base.log]>->( 2, "snapshot saved: $out_path" );
<[base.reply]>->( $call, $out_path ) if defined $call;
```

### 4. check reply pattern

look at how other deferred async commands (e.g. `web-browser.cmd.page_source`
or `web-browser.cmd.run_js`) return results via callback. adapt the reply
mechanism to match the existing pattern — the above uses `<[base.reply]>` but
the zenka may use a different mechanism (check `base.handler.cmd` dispatch pattern).

---

## test sequence

```bash
## 1. start web-browser zenka and load a page
p7 web-browser.cmd.load_uri 'https://space.v7.ax'

## 2. request snapshot
p7 web-browser.cmd.get_snapshot

## expected: path string like /var/protocol-7/visual-feedback/capture/snapshot_NNN.png

## 3. verify file exists and opens:
ls -la /var/protocol-7/visual-feedback/capture/snapshot_*.png
```

## success criteria

- [ ] `web-browser.cmd.get_snapshot` module exists
- [ ] `web-browser.handler.snapshot_result` module exists
- [ ] snapshot_dir created automatically if it doesn't exist
- [ ] `p7 web-browser.cmd.get_snapshot` returns a file path
- [ ] the returned path is a valid PNG file
- [ ] snapshot captures the visible viewport of the foreground view
- [ ] async callback pattern matches existing zenka reply conventions
- [ ] no signature stubs added, no subroutine whitelist changes made

#,,,,,.,.,.,,,...,.,,,,,.,,..,,.,,,..,.,.,.,,,..,,...,...,..,,..,,,,,,..,,,.,,
#GMTPI2FQPLOZKCPRGLP5AJB5T4KPXBKMGOIEXVSQFUKORKRT77H55D42ZEEELCK5QGTCHOZS2EUFM
#\\\|V5I6UMH4PAR6WIMJ5FTV5QI7MGYGB5SW7SW6BD27MCHCMH6WA7S \ / AMOS7 \ YOURUM ::
#\[7]JA2YKWCBPOW663OMD2VJNNO73CWY2Q7QLU4EL5FIM3R2BIOHD4CA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
