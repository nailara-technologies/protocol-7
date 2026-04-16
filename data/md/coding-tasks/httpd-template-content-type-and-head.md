# task: fix template content-type and HEAD support for .tmpl files

## context

template-based vhosts like `space.v7.ax` use `index.tmpl` files that are
processed by the web zenka and return HTML. two issues exist:

1. browser displays rendered HTML as plain text because content-type is
   `text/plain` instead of `text/html`
2. HEAD requests return 404 for template-only vhosts because `httpd.http_head`
   only checks for `index.html`, not `index.tmpl`

## modules to fix

### 1. httpd.process_template (content-type detection)

**file**: `modules/httpd.process_template`

line 14-15 currently:
```perl
my $content_type    = 'text/plain';
$content_type = 'text/html' if $template_path =~ /\.html/;
```

the template file is `index.tmpl` (not `index.html.tmpl`), so it stays
`text/plain`. `.tmpl` files produce HTML output by definition.

**fix**: also match `.tmpl` extension as `text/html`:
```perl
my $content_type    = 'text/plain';
$content_type = 'text/html' if $template_path =~ /\.(html|tmpl)$/;
```

### 2. httpd.http_head (index.tmpl resolution)

**file**: `modules/httpd.http_head`

lines 33-36 currently only check for `index.html` in directories:
```perl
if ( -d $file_path ) {    # LLL: support !html index
    $file_path .= qw| /index.html |
        if -f join( qw| / |, $file_path, qw| index.html | );
}
```

**fix**: add `index.tmpl` fallback matching `httpd.serve_static` priority
order [ index.html first, then index.tmpl ]:
```perl
if ( -d $file_path ) {
    if ( -f join( qw| / |, $file_path, qw| index.html | ) ) {
        $file_path .= qw| /index.html |;
    } elsif ( -f join( qw| / |, $file_path, qw| index.tmpl | ) ) {
        $file_path .= qw| /index.tmpl |;
    }
}
```

for `.tmpl` files the content-type in HEAD response should be `text/html`
[ not mimetype() which won't know `.tmpl` ]. add after the existing
`mimetype()` call on line 88:
```perl
$content_type //= 'text/html' if $file_path =~ /\.tmpl$/;
```

## P7 module rules — MUST follow

- do NOT add signature stub lines (`#,,.,,,...`) — leave files clean
- lowercase comments only: `## check for template index ##` not `## Check For Template ##`
- use `$ARG` not `$_` in map/grep
- use qw| word | style for barewords

## verification

after modifying both modules:

1. `ptd -c` both modified module files
2. confirm no `$_` usage (should be `$ARG`)

#,,..,...,.,.,,,.,..,,,,.,,.,,,.,,..,,,..,,.,,..,,...,...,,..,,,.,,.,,,,,,,.,,
#44OURNNQ4PT5VXHLUG2REXT6BO7JCTJOJJ3RXZTUWK74UW5FEFUMKIM2BDSCCC3QSPEVIUEYSJCIM
#\\\|EVKLSMJSKHIWF6KZWM5ESO2LNBB7YKNC36DYTWHIUTMDZH6PMTS \ / AMOS7 \ YOURUM ::
#\[7]RWWFNRBO532MKUFZ6ZVFNMJSUMMOROPKKVQGCK3EN6HOEILRHECI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
