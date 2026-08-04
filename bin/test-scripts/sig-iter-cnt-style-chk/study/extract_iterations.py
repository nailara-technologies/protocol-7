#!/usr/bin/env python3
## [:< ##  extract amos-iterations-remaining from all signed module footers
##
## reimplements modules/amos7.decode_octal_bit_header in standalone form :
## footer line 1 = '#' + 19 octal digits, each digit = 3 chars [ ','=0
## '.'=1 ] followed by a ',' separator. digits 0..10 = amos payload chksum,
## digit 11 = endline-state, digits 12..18 = amos-iterations-remaining
## [ octal ]. inverted mode [ '#,(,,,.)x19' ] = all-zero payload, which
## requires iterations-remaining 0 = harmonization loop exhausted.
##
## iterations_used = 0o7777777 - remaining + 1
## [ source.create_harmonic_footer : encodes $iterations_left-- per attempt,
##   starting at 07777777 ]

import os
import re
import sys

NORMAL = re.compile(r"^#,(([,.]{3},){19})$")
INVERTED = re.compile(r"^#,(,,,\.){19}$")

MAX_ITER = 0o7777777


def decode_line(line):
    line = line.rstrip("\n")
    if INVERTED.match(line):
        return {"inverted": True, "endline": 0, "remaining": 0, "used": MAX_ITER + 1}
    m = NORMAL.match(line)
    if not m:
        return None
    digits = []
    for grp in re.findall(r"([,.]{3}),", m.group(1)):
        bits = grp.replace(",", "0").replace(".", "1")
        digits.append(int(bits, 2))  # 3-bit binary == octal digit
    endline = digits[11]
    remaining = int("".join(str(d) for d in digits[12:19]), 8)
    return {
        "inverted": False,
        "endline": endline,
        "remaining": remaining,
        "used": MAX_ITER - remaining + 1,
        "checksum_oct": "".join(str(d) for d in digits[0:11]),
    }


def find_footer_line(path):
    ## footer lives at end of file ; scan last lines only
    try:
        with open(path, "rb") as fh:
            data = fh.read()
    except OSError:
        return None, "unreadable"
    lines = data.decode("utf-8", errors="replace").splitlines()
    for line in reversed(lines[-12:]):
        if line.startswith("#,") or line.startswith("#."):
            return line, None
    return None, "no-footer"


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else "modules"
    rows = []
    skipped = []
    for name in sorted(os.listdir(root)):
        path = os.path.join(root, name)
        if not os.path.isfile(path):
            continue
        line, err = find_footer_line(path)
        if err:
            skipped.append((name, err))
            continue
        dec = decode_line(line)
        if dec is None:
            skipped.append((name, "undecodable:" + line[:40]))
            continue
        rows.append((name, dec["remaining"], dec["used"], dec["endline"],
                     dec["inverted"]))

    with open("iterations.tsv", "w") as out:
        out.write("file\tremaining\tused\tendline\tinverted\n")
        for r in rows:
            out.write("\t".join(str(x) for x in r) + "\n")

    used_vals = sorted(r[2] for r in rows)
    n = len(used_vals)
    print(f"decoded: {n}  skipped: {len(skipped)}")
    for name, err in skipped[:20]:
        print(f"  SKIP {name}: {err}")
    if n:
        print(f"used  min={used_vals[0]}  median={used_vals[n//2]}  "
              f"p90={used_vals[int(n*0.9)]}  max={used_vals[-1]}")
        print(f"inverted [ loop exhausted ]: {sum(1 for r in rows if r[4])}")
        hist = {}
        for v in used_vals:
            b = min(v, 1000) // 50 * 50
            hist[b] = hist.get(b, 0) + 1
        for b in sorted(hist):
            print(f"  {b:>5}-{b+49:<5} {'#' * (hist[b] * 60 // n)} {hist[b]}")


if __name__ == "__main__":
    main()

#,,..,.,.,.,,,,,.,,..,,..,.,,,.,,,,..,...,...,..,,...,...,...,.,.,.,.,,,.,...,
#RNOMNG2MVPFWWRT4PAY423K3PHASQJNLPX3K4MUMJN2NSJHLG7RAMW2WROOUVTLB24OFB3KUWEYXO
#\\\|SPTEDWT23DRQKDICGPIERVGWKH6NKGF6ZBCCOA67DQB22TQEPNJ \ / AMOS7 \ YOURUM ::
#\[7]N3EXDGCSAFLA2RILWNQSOLRXBJO4GTV46K5K6LFXP3PZN27BTGAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
