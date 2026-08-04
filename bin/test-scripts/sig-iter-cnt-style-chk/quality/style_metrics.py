#!/usr/bin/env python3
## deterministic style metrics for protocol-7 module files               ##
## criteria from data/yaml/code-style/CONVENTIONS.yaml +                 ##
## data/ai-mem/kimi/coding-style.md -- fully blind to iteration counters ##

import os
import re
import sys

FOOTER_LINE_RES = [
    re.compile(r"^#,(([,\.]{3},){19})$"),
    re.compile(r"^#,(,,,\.){19}$"),
    re.compile(r"^#[A-Z2-7]{70,}$"),                    ## b32 payload line
    re.compile(r"^#\\\\\|[A-Z2-7]{40,} .*AMOS7.*::$"),  ## \ / AMOS7 \ .. ::
    re.compile(r"^#\\\[7\][A-Z2-7]{40,} .*SIGNATURE ::$"),
    re.compile(r"^#:{20,}$"),
    re.compile(r"^#unsigned\b"),
]


def is_footer_line(line):
    return any(r.match(line) for r in FOOTER_LINE_RES)


def metrics_for(path):
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as fh:
            raw_lines = fh.read().split("\n")
    except OSError:
        return None

    body = [l for l in raw_lines if not is_footer_line(l)]
    code_lines = [l for l in body if l.strip() and not l.lstrip().startswith("#")]
    comment_lines = [
        l for l in body
        if re.match(r"^\s*##(?! \[:< ##)", l)  ## real comments, skip marker
    ]

    m = {}
    m["n_lines"] = len(body)
    m["n_code"] = len(code_lines)
    m["n_comments"] = len(comment_lines)

    ## header block : '## [:< ##' + '# name  =' + '# descr =' ##
    head = "\n".join(body[:12])
    m["has_header"] = int("## [:< ##" in raw_lines[:3]
                          or "## [:< ##" in head)
    m["has_name"] = int(re.search(r"^# name\s*=", head, re.M) is not None)
    m["has_descr"] = int(re.search(r"^# descr\s*=", head, re.M) is not None)

    ## 78-column violations [ body lines only ] ##
    m["col78_viol"] = sum(1 for l in body if len(l) > 78)

    ## comment style : lowercase start ##
    starts = []
    for l in comment_lines:
        c = re.sub(r"^\s*#+\s*", "", l)
        if c and c[0].isalpha():
            starts.append(c[0])
    m["comment_upper_frac"] = (
        sum(1 for c in starts if c.isupper()) / len(starts) if starts else 0.0
    )

    ## '( word )' annotations inside comments [ should be '[ word ]' ] ##
    m["paren_annotations"] = sum(
        len(re.findall(r"\(\s*[a-z][a-z0-9 -]{1,24}\s*\)", l))
        for l in comment_lines
    )

    ## regex delimiter style : m// and s/// forms [ project uses m| | ] ##
    m["slash_regex"] = sum(
        len(re.findall(r"=~\s*(?:m|s|tr)/", l)) for l in code_lines
    )

    ## interpolated log format strings [ '<[base.log...]>->( N, "...$var"' ] ##
    m["log_interp"] = sum(
        1 for l in code_lines
        if re.search(r"base\.logs?[^\n]*->\(\s*\d+\s*,\s*\"[^\"]*\$", l)
    )

    ## undef-unsafe bare data reads : '<path>' assigned without '//' guard  ##
    ## [ heuristic : my $x = <a.b.c>; with no // on the line ]              ##
    m["unguarded_data_reads"] = sum(
        1 for l in code_lines
        if re.search(r"=\s*<[a-z0-9_.-]+>\s*;", l) and "//" not in l
    )

    ## composite score 0..10                                              ##
    ## +2 header complete, +1 descr, -col78 [ capped ], -uppercase frac,  ##
    ## -paren annotations, -slash regex, -log interp, -unguarded reads    ##
    score = 4.0
    score += 2.0 * m["has_header"] + 1.0 * m["has_name"] + 1.0 * m["has_descr"]
    score -= min(2.0, m["col78_viol"] * 0.25)
    score -= 2.0 * m["comment_upper_frac"]
    score -= min(1.5, m["paren_annotations"] * 0.5)
    score -= min(1.5, m["slash_regex"] * 0.5)
    score -= min(1.5, m["log_interp"] * 0.75)
    score -= min(1.5, m["unguarded_data_reads"] * 0.25)
    m["scripted_score"] = round(max(0.0, min(10.0, score)), 3)
    return m


def main():
    tsv = sys.argv[1]
    out = sys.argv[2]
    fields = ["n_lines", "n_code", "n_comments", "has_header", "has_name",
              "has_descr", "col78_viol", "comment_upper_frac",
              "paren_annotations", "slash_regex", "log_interp",
              "unguarded_data_reads", "scripted_score"]
    with open(out, "w") as oh:
        oh.write("taken\tpath\t" + "\t".join(fields) + "\n")
        for line in open(tsv):
            taken, _rem, _end, path = line.rstrip("\n").split("\t")
            m = metrics_for(path)
            if m is None:
                continue
            oh.write(taken + "\t" + path + "\t"
                     + "\t".join(str(m[f]) for f in fields) + "\n")


if __name__ == "__main__":
    main()

#,,..,,.,,,..,..,,,,.,..,,..,,.,,,...,..,,,,.,..,,...,...,...,,.,,,,.,.,,,,,,,
#LCBPBCBWBD3DXOEVZUTOK5KO2HDQOIFZXAQQ2DPEWVUAUNCNPE75VLUXHA2LECFSH7QKXGHLG423A
#\\\|I3MFLKGNNCSY4YRKA46KSATHTUHEHWPT2T32QDASB3LQG6DFKSC \ / AMOS7 \ YOURUM ::
#\[7]GZJ5OVCBHBLQYSXBFU2FZQE2BXOGVXKC7W3DPBBUOIJUDDAGLKDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
