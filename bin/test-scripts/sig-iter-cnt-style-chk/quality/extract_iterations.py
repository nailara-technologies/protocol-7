#!/usr/bin/env python3
## extract amos-iterations-remaining from AMOS7-signed files ##
## standalone reimplementation of amos7.decode_octal_bit_header logic     ##
## [ matches bin/dev/iter-rank's extract_iter_remaining ]                 ##

import os
import re
import sys

MAX_REMAINING = 0o7777777  ## octal limit from source.create_harmonic_footer

NORMAL_RE = re.compile(r"^#,(([,\.]{3},){19})$")
INVERTED_RE = re.compile(r"^#,(,,,\.){19}$")


def decode_first_footer_line(line):
    line = line.rstrip("\n")
    if INVERTED_RE.match(line):
        ## all-zero payload [ chksum 0, endline 0, iterations 0 ] ##
        return {"inverted": True, "remaining": 0, "endline": 0}
    m = NORMAL_RE.match(line)
    if not m:
        return None
    groups = re.findall(r"([,\.]{3}),", m.group(1))
    if len(groups) != 19:
        return None

    def group_to_digit(g):
        bits = g.replace(",", "0").replace(".", "1")
        return int(bits, 2)

    digits = [group_to_digit(g) for g in groups]
    endline = digits[11]
    remaining = int("".join(str(d) for d in digits[12:19]), 8)
    return {"inverted": False, "remaining": remaining, "endline": endline}


def extract(path):
    try:
        with open(path, "rb") as fh:
            size = os.fstat(fh.fileno()).st_size
            if size > 1024:
                fh.seek(-1024, os.SEEK_END)
            buf = fh.read().decode("utf-8", errors="replace")
    except OSError:
        return None
    for line in buf.split("\n"):
        if line.startswith("#,") and set(line[2:]) <= {",", "."}:
            result = decode_first_footer_line(line)
            if result is not None:
                return result
    return None


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else "modules"
    rows = []
    skipped = 0
    for dirpath, _dirs, files in os.walk(root):
        for name in files:
            path = os.path.join(dirpath, name)
            if not os.path.isfile(path) or os.path.islink(path):
                continue
            result = extract(path)
            if result is None:
                skipped += 1
                continue
            taken = MAX_REMAINING - result["remaining"]
            rows.append((path, result["remaining"], taken, result["endline"]))
    rows.sort(key=lambda r: r[2])
    for path, remaining, taken, endline in rows:
        print(f"{taken}\t{remaining}\t{endline}\t{path}")
    print(f"## signed: {len(rows)}  skipped/unsigned: {skipped}", file=sys.stderr)


if __name__ == "__main__":
    main()

#,,.,,..,,...,,..,...,...,,.,,,.,,.,.,.,,,,,,,..,,...,...,,.,,.,.,.,,,.,,,,,.,
#3D2DRQSGOUG2WWW5CD3UXRH2YKLZKQCBKPH6ZE4GFHY7TYRIE6R53QA2ELH5OC7ZVCLNSBEADMYSI
#\\\|XAOPRMGQFBZZIIUM557U6XOCG7TYCNULGLFFMX56ZYWLWSUY6GP \ / AMOS7 \ YOURUM ::
#\[7]O2AI7ABEFTQA54T2NAZ6JIHR66235N325W34CXOUIK6DQQONPWBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
