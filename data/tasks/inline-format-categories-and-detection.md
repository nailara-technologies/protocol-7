# inline format : category names, sections, base32 detection

status : brief, not dispatched [ 2026-11-18 ] ; loader in bin/Protocol-7 [ ~5266-5480 ],
decoder AMOS7::B32::decode_b32r. vision : data/ai-mem/claude/vision-inline-filesystem-self-contained-protocol-7.md

## frame [ unchanged ]

`.:[ name ]:.` opens an entry, content lines start with `:`, `:.` closes ; meta is a
`:` line told apart by its form [ `: <chksum:lines:words:bytes>` ].

## changes

1. entry names : header pattern `[\w\d\-\_\.]+` also takes `/` -- a bare dotted name
   is a subroutine [ src/ ], a name with `/` is a category path [ `cfg/..`, `data/..` ]
2. sections : `.: prefix :.` [ no brackets ] scopes the entries after it, children drop
   the prefix ; the loader resolves full names [ end of a section : next section header
   or `.: :.` -- decide when building ]
3. first-line check `[02-9A-Z]{76}` -> also allow `1` [ the decoder strips `[01]` anyway ]
4. encoding detection after the whole entry is read :
   a. known compression start [ 7U3XU xz, D6FQQ gzip, EMRSAWZ2HQQCGIYK none ] -> as today
   b. else, with a meta line, a coherent base32 body -> raw BASE32 data :
      only `A-Z2-7` after stripping `0` \ `1` ; L chars give floor[ 5L/8 ] bytes ;
      meta byte count N >= that ; N - floor[ 5L/8 ] zero bytes appended [ stripped `A`s ] ;
      leftover bits [ 5L mod 8 ] non-zero -> N must exceed the lower bound ;
      checksum verifies the padded result
   c. else plain [ plain subroutines keep `## [:< ##`, never base32-shaped ]
   no meta line : assume no trailing zero bytes [ N = floor( 5L/8 ) ] ; then the leftover
   bits must all be zero, else the body is not base32 -> plain. the writer adds the byte
   count only when the data ends in zero bytes. a short plain body that is all
   `A-Z2-7` and passes this would read as base32 : the writer gives such plain entries
   a meta line [ or plain text never is meta-less and base32-shaped ]
5. check whether the loader already pads to the byte count for xz \ gzip entries

## rules

every existing inline entry must load unchanged [ compare the loaded %code checksums
before \ after ] ; style per CLAUDE.md ; perl 5.32 ; format-code -c on bin/Protocol-7.

#,,..,,,,,,,,,.,,,...,..,,,.,,,..,,.,,...,...,..,,...,...,.,,,,,,,,,.,,..,,,,,
#RKWFA3S7CZOIUQKSFPNH3FNCCDJJQRYCOQKMLKLWM7KXBT5IMDSP2Z5LLS5ID5QP3QXGSA32B55TW
#\\\|QKMGRRVIA544KWX7OZ34MUU6ZDQHBMN4E5KMZ5ON2PWE6YFAO54 \ / AMOS7 \ YOURUM ::
#\[7]VGNMJ7DWGBWLGW3CZWPLJYM57QGIUU4ZINLHNRCYUBC4WZKDPOBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
