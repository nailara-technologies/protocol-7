## task: extract inline subs from jobsite.util.fix_encoding

### context

`src/jobsite.util.fix_encoding` has two inline sub definitions that cause
"Subroutine redefined" warnings on `jobsite.reload` because the module is
loaded twice per reload cycle (source pass + plugins pass). extract them to
their own modules, following the same pattern used for
`plugin.web.space.orbital.synthetic-zenka-node`.

---

### sub 1 : _build_mojibake_table (lines 47–62)

```perl
sub _build_mojibake_table {
    my $enc   = shift;
    my %table = ();
    for my $byte ( 0x80 .. 0xFF ) {
        my $uni
            = eval { Encode::decode( $enc, chr($byte), Encode::FB_CROAK ) };
        next unless defined $uni and not $@;
        my $utf8_bytes = Encode::encode( 'UTF-8', $uni );
        my $as_latin1  = eval {
            Encode::decode( 'ISO-8859-1', $utf8_bytes, Encode::FB_CROAK );
        };
        next unless defined $as_latin1 and not $@;
        $table{$as_latin1} = $uni if $as_latin1 ne $uni;
    }
    return \%table;
}
```

called at line 87 as: `_build_mojibake_table($enc)`

extract to: `src/jobsite.util.fix_encoding.mojibake-table`

new module header:
```
# name  = jobsite.util.fix_encoding.mojibake-table
# descr = build mojibake replacement table for a given encoding
```

the module takes `my $enc = shift;` and returns `\%table`.
uses `Encode` (already autoloaded by caller; no need to re-autoload).

call site replacement:
```perl
my $table = <[jobsite.util.fix_encoding.mojibake-table]>->($enc);
```

---

### sub 2 : _score_candidate (lines 67–77)

```perl
sub _score_candidate {
    my ( $candidate, $prev, $next, $bigrams ) = @_;
    my $score = 1;    ## base: any special char is a candidate ##
    return $score unless defined $bigrams->{$candidate};
    my $lc_candidate = lc($candidate);
    my $spec         = $bigrams->{$lc_candidate} // $bigrams->{$candidate};
    return $score unless $spec;
    $score++ if defined $prev and $spec->{'prev'} =~ /\Q$prev\E/i;
    $score++ if defined $next and $spec->{'next'} =~ /\Q$next\E/i;
    return $score;
}
```

called at line 163 as: `_score_candidate( $candidate, $prev, $next, $bigrams )`

extract to: `src/jobsite.util.fix_encoding.score-candidate`

new module header:
```
# name  = jobsite.util.fix_encoding.score-candidate
# descr = score a unicode candidate char by bigram context (0..3)
```

the module takes `my ( $candidate, $prev, $next, $bigrams ) = @_;`
and returns `$score`.

call site replacement:
```perl
my $score = <[jobsite.util.fix_encoding.score-candidate]>->(
    $candidate, $prev, $next, $bigrams );
```

---

### changes to src/jobsite.util.fix_encoding

1. remove the inline sub blocks entirely (lines 47–62 and lines 67–77),
   including the `##[ BUILD MOJIBAKE TABLE ]` and `##[ SCORE FFFD CANDIDATE ]`
   section headers that precede them.

2. replace call at line 87:
   - before: `my $table = _build_mojibake_table($enc);`
   - after:  `my $table = <[jobsite.util.fix_encoding.mojibake-table]>->($enc);`

3. replace call at line 163:
   - before: `my $score = _score_candidate( $candidate, $prev, $next, $bigrams );`
   - after:  `my $score = <[jobsite.util.fix_encoding.score-candidate]>->($candidate, $prev, $next, $bigrams);`

---

### subroutine whitelist

do NOT edit the whitelist file manually. after creating the two new modules,
run: `./bin/dev/gen-sub-whitelist jobsite` — this regenerates the whitelist
automatically from the loaded module set.

---

### verification

after changes, `p7c jobsite.reload` should show:
```
      reload source  [ success ]
```
with no "Subroutine redefined" warnings.

---

## signatures note

this codebase uses AMOS7 data signatures at the end of each module file
(4-line footer starting with `#,,.,,,...`). do NOT manually write or edit
signature lines. existing signatures on modified files will be regenerated
by the signing system. do not add fake/stub signatures to new files.

## dispatch

#,,,.,,..,,.,,,,.,..,,,.,,,,.,,.,,.,.,,.,,.,.,..,,...,...,..,,..,,,,,,,.,,,,.,
#DK7IEZSWRY3PV4SUWXFNWZD6OKLNP4LW5NOKR27A4F5WJ2TH6W3ZJOZZPVWXTRNTPJNQEMPZ23WE6
#\\\|OFQW76HWOVR3SK74Q3TBA3CJYD753RIJM5DK576TJMJI7QCQWNM \ / AMOS7 \ YOURUM ::
#\[7]3EE27Z6WRKCLWHBUFHIWUZOCNEUX3QPJ5D2EEZH66L2D6GLHUABQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
