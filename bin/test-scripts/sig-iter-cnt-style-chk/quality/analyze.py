#!/usr/bin/env python3
## part 3 : correlation analysis across all scorers ##
## A : iter-counter-study 9B blind scores [ n=234 ]                      ##
## B : iter-quality k2.7 blind scores [ partial sample ]                 ##
## C : iter-quality scripted metrics [ full corpus n=5055 ]              ##
## D : scorer agreement on overlapping files                             ##

import csv
import os
import re
from scipy import stats

ROOT = "/data/projects/protocol-7"
ICS = f"{ROOT}/data/tasks/iter-counter-study"
IQ = f"{ROOT}/data/tasks/iter-quality"


def spearman(x, y, label):
    rho, p = stats.spearmanr(x, y)
    pr, pp = stats.pearsonr(x, y)
    print(f"{label:55s} n={len(x):4d}  spearman rho={rho:+.4f} "
          f"p={p:.3e}   pearson r={pr:+.4f} p={pp:.3e}")
    return rho, p


## --- A : 9B scores ---
sample = {r["id"]: r for r in csv.DictReader(open(f"{ICS}/sample.tsv"),
                                             delimiter="\t")}
scores = {}
for r in csv.DictReader(open(f"{ICS}/scores.tsv"), delimiter="\t"):
    if r["total"]:
        scores[r["id"]] = int(r["total"])
common = [sid for sid in scores if sid in sample]
taken = [int(sample[s]["used"]) for s in common]
total = [scores[s] for s in common]
print("## A : local 9B blind scorer [ iter-counter-study ]")
spearman(taken, total, "taken vs 9B total score")
# per-criterion
sc_rows = {r["id"]: r for r in csv.DictReader(open(f"{ICS}/scores.tsv"),
                                              delimiter="\t") if r["total"]}
for key in ("style", "comments", "structure"):
    vals = [int(sc_rows[s][key]) for s in common if s in sc_rows]
    tk = [int(sample[s]["used"]) for s in common if s in sc_rows]
    spearman(tk, vals, f"taken vs 9B {key}")

## --- B : k2.7 scores ---
print("\n## B : k2.7 blind scorer [ iter-quality, partial sample ]")
samp = {r["path"]: int(r["taken"])
        for r in csv.DictReader(
            (l for l in open(f"{IQ}/sample.tsv") if "\t" in l),
            delimiter="\t")
        if r.get("taken", "").isdigit()}
k27 = {}
for fn in sorted(os.listdir(f"{IQ}/scores")):
    for line in open(f"{IQ}/scores/{fn}"):
        line = line.strip()
        m = re.match(r"^(modules/\S+)\|(\d)\|(\d)\|(\d)\|(\d)\|(\d)$", line)
        if m:
            path = m.group(1)
            nums = [int(m.group(i)) for i in range(2, 7)]
            k27[path] = sum(nums)
common_b = [p for p in k27 if p in samp]
if common_b:
    spearman([samp[p] for p in common_b], [k27[p] for p in common_b],
             "taken vs k2.7 total score")
print(f"k2.7 scored files: {len(k27)}")

## --- C : scripted full-corpus ---
print("\n## C : scripted metrics [ full corpus ]")
rows = [r for r in csv.DictReader(
        (l for l in open(f"{IQ}/metrics.tsv") if "\t" in l),
        delimiter="\t")
    if r.get("taken", "").isdigit()]
spearman([int(r["taken"]) for r in rows],
         [float(r["scripted_score"]) for r in rows],
         "taken vs scripted_score [ n=5055 ]")

## --- D : agreement on overlap ---
print("\n## D : scorer agreement [ overlapping sampled files ]")
ics_by_file = {sample[s]["file"]: scores[s] for s in common}
overlap = [p.replace("modules/", "") for p in common_b
           if p.replace("modules/", "") in ics_by_file]
if overlap:
    a = [ics_by_file[f] for f in overlap]
    b = [k27[f"modules/{f}"] for f in overlap]
    spearman(a, b, "9B total vs k2.7 total [ same files ]")
    print(f"overlap files: {len(overlap)}")

#,,,.,,,,,,,,,,.,,...,.,,,..,,...,,..,.,,,.,.,..,,...,...,.,.,.,.,,.,,,.,,...,
#7FKQ4CJVCGKAMTHDE2V6NQMIAU6OUN5TZNCODCXG7EWZS75LR42IKWSWHFN7KTCUIUCAVZAKGJCFW
#\\\|FXXXOKRYXIQS5MF7S33QOIHODGRUT5BSRJ7766IL4KIYRMMVHZX \ / AMOS7 \ YOURUM ::
#\[7]CYVHSIONAKGGIIWCT5NLDFTABDJ25RSWNZMWFCAYXBOSZIK55ECY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
