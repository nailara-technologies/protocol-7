#!/usr/bin/env python3
"""offline calibration gates for the module-catalog embedding domain

  gate A -- retrieval hit-rate : query = a real commit message, ground truth
            = the src/ modules that commit actually touched. does the domain
            surface any of them in top-K ?

  gate B -- false-injection calibration : cosine always returns something.
            compare top-1 similarity on relevant queries against queries whose
            correct answer is "nothing here", and find whether any similarity
            floor separates them.

  both replicate coding.tools.handler.embedding_search's query semantics
  EXACTLY by default [ whitespace split, exact lookup with a lowercase
  fallback, unnormalized sum of in-vocab token vectors, cosine against every
  other vocab token ] so the numbers describe what actually ships. --clean-tok
  re-runs with punctuation stripped, to price the tokenizer ceiling rather
  than assume it.

  thresholds are pre-registered in data/tasks/coding-module-catalog-embedding.md
  and are NOT to be adjusted after seeing the output.
"""

import argparse
import json
import re
import subprocess
import sys

import numpy as np

GATE_A_THRESHOLD = 0.40  ## >=40% of commits land >=1 touched module in top-K
GATE_A_TOPK = 10
GATE_B_MIN_J = 0.30  ## Youden's J = TPR - FPR at the best floor

## queries whose correct answer is "nothing in this codebase is relevant".
## deliberately a mix : plain general knowledge, other-domain technical text,
## and P7-adjacent-sounding prose that still names nothing real.
IRRELEVANT = [
    "what is the boiling point of water at sea level",
    "who won the world cup in 1998 and what was the score",
    "explain the difference between a sonnet and a haiku",
    "best way to caramelize onions without burning them",
    "summarize the plot of the great gatsby in three sentences",
    "how do tides work and why are there two per day",
    "recommend a good beginner acoustic guitar under 300 dollars",
    "what causes inflation to rise during a supply shock",
    "translate good morning into portuguese and japanese",
    "how long should i marinate chicken before grilling it",
    "configure kubernetes ingress with cert manager and helm",
    "write a react hook that debounces a search input field",
    "optimize this postgres query with a partial index on created_at",
    "set up a github actions matrix build for windows and macos",
    "explain gradient descent momentum versus adam optimizer",
    "what is the airspeed velocity of an unladen swallow",
    "describe the rules of cricket to someone who knows baseball",
    "when should i repot a monstera and what soil mix works best",
]


def load_vec(path):
    """load a fasttext .vec exactly the way embedding_search does"""
    tokens, mat = [], []
    with open(path, encoding="utf-8", errors="replace") as handle:
        handle.readline()  ## "<vocab> <dim>"
        for line in handle:
            parts = line.rstrip("\n").split(" ")
            name, comps = parts[0], parts[1:]
            comps = [c for c in comps if c]
            if not comps:
                continue
            tokens.append(name)
            mat.append(np.asarray(comps, dtype=np.float32))
    mat = np.vstack(mat)
    norms = np.linalg.norm(mat, axis=1)
    index = {tok: i for i, tok in enumerate(tokens)}
    return tokens, mat, norms, index


def query_tokens(text, clean_tok=False):
    """default: whitespace split only -- what the shipping tool does"""
    if clean_tok:
        text = re.sub(r"[^\w\s.-]+", " ", text)
    return [t for t in text.split() if t]


def neighbors(query, tokens, mat, norms, index, top=10, clean_tok=False):
    """returns (list of (token, score), n_hit_tokens)"""
    hits, qvec = set(), None
    for tok in query_tokens(query, clean_tok):
        idx = index.get(tok)
        if idx is None:
            idx = index.get(tok.lower())
        if idx is None:
            continue
        hits.add(tokens[idx])
        qvec = mat[idx].copy() if qvec is None else qvec + mat[idx]

    if qvec is None:
        return [], 0

    qnorm = float(np.linalg.norm(qvec))
    if qnorm == 0.0:
        return [], len(hits)

    scores = (mat @ qvec) / (norms * qnorm + 1e-12)
    for tok in hits:  ## the tool excludes query tokens from its own results
        scores[index[tok]] = -np.inf

    order = np.argpartition(-scores, min(top, len(scores) - 1))[:top]
    order = order[np.argsort(-scores[order])]
    return [(tokens[i], float(scores[i])) for i in order], len(hits)


def commit_samples(limit):
    """(message, {touched module names}) for recent src/-touching commits"""
    sep = "@@@COMMIT@@@"
    out = subprocess.run(
        ["git", "log", f"-n{limit}", f"--format={sep}%s%n%b", "--name-only",
         "--", "src/"],
        capture_output=True, text=True, check=True,
    ).stdout

    samples = []
    for chunk in out.split(sep):
        if not chunk.strip():
            continue
        lines = chunk.strip().split("\n")
        msg, touched = [], set()
        for line in lines:
            if line.startswith("src/") and "/" not in line[4:]:
                touched.add(line[4:])
            elif not line.startswith("src/"):
                msg.append(line)
        if touched:
            samples.append((" ".join(msg).strip(), touched))
    return samples


def external_samples(path):
    """(query, {touched module names}, leak_flag|None) from an external
    JSONL file -- one query per line, e.g. LLM-synthesized queries for a
    query-shape arm [ see data/tasks/coding-catalog-retrieval-phase2.md,
    arm T, 2026-09-10 ] instead of live-derived commit messages. accepts
    either 'query' or 'task_summary' as the text key, and an optional
    'leak_flag' for a leakage-audited arm -- if present on any record,
    main() reports the leak_flag=true/false split separately, since a
    query-shape arm's whole point can be undone by a query that leaks the
    answer via a literal module name/identifier."""
    samples = []
    with open(path, encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            if not line:
                continue
            rec = json.loads(line)
            query = rec.get("query", rec.get("task_summary"))
            modules = rec.get("modules")
            if not query or not modules:
                continue
            samples.append((query, set(modules), rec.get("leak_flag")))
    return samples


def gate_a(vec, samples, clean_tok, topk=GATE_A_TOPK):
    tokens, mat, norms, index = vec
    vocab = set(tokens)

    eligible, hit, no_tok, ranks = 0, 0, 0, []
    for msg, touched in samples:
        in_vocab = touched & vocab
        if not in_vocab:  ## no vocab-eligible ground truth -- excluded
            continue
        eligible += 1
        res, n_hit = neighbors(msg, tokens, mat, norms, index, topk, clean_tok)
        if n_hit == 0:
            no_tok += 1
            continue
        names = [t for t, _ in res]
        for rank, name in enumerate(names, 1):
            if name in in_vocab:
                hit += 1
                ranks.append(rank)
                break

    return {
        "total": len(samples), "eligible": eligible, "hit": hit,
        "rate": hit / eligible if eligible else 0.0,
        "no_query_token": no_tok,
        "median_rank": float(np.median(ranks)) if ranks else None,
    }


def gate_b(vec, samples, clean_tok):
    tokens, mat, norms, index = vec

    def top1(text):
        res, n_hit = neighbors(text, tokens, mat, norms, index, 1, clean_tok)
        ## no in-vocab token at all = the tool refuses to answer = a
        ## correct rejection, scored as zero similarity rather than dropped
        return res[0][1] if res else 0.0

    pos = np.array([top1(m) for m, _ in samples])
    neg = np.array([top1(q) for q in IRRELEVANT])

    best = {"j": -1.0, "floor": None, "tpr": 0.0, "fpr": 0.0}
    for floor in np.unique(np.concatenate([pos, neg])):
        tpr = float((pos >= floor).mean())
        fpr = float((neg >= floor).mean())
        if tpr - fpr > best["j"]:
            best = {"j": tpr - fpr, "floor": float(floor),
                    "tpr": tpr, "fpr": fpr}

    return {
        "pos_n": len(pos), "neg_n": len(neg),
        "pos_median": float(np.median(pos)), "neg_median": float(np.median(neg)),
        "pos_mean": float(pos.mean()), "neg_mean": float(neg.mean()),
        "neg_no_answer": int((neg == 0.0).sum()),
        **best,
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--vec", required=True)
    ap.add_argument("--commits", type=int, default=400)
    ap.add_argument("--queries",
                     help="external JSONL of {query|task_summary, modules"
                          "[, leak_flag]} records, e.g. a synthesized "
                          "query-shape arm -- replaces live commit_samples()")
    ap.add_argument("--clean-tok", action="store_true",
                    help="strip punctuation before lookup [ ceiling probe ]")
    ap.add_argument("--label", default="")
    args = ap.parse_args()

    vec = load_vec(args.vec)
    leak_flags = None
    if args.queries:
        ext = external_samples(args.queries)
        samples = [(q, m) for q, m, _ in ext]
        leak_flags = [lf for _, _, lf in ext]
    else:
        samples = commit_samples(args.commits)

    tag = args.label or args.vec
    tok = "clean-tok" if args.clean_tok else "tool-exact"
    print(f".:[ {tag} : {tok} ]:.")
    src = args.queries if args.queries else f"commit samples {len(samples)}"
    print(f"vocab {len(vec[0])} · dim {vec[1].shape[1]} · {src}"
          + (f" ({len(samples)})" if args.queries else ""))

    a = gate_a(vec, samples, args.clean_tok)
    verdict = "PASS" if a["rate"] >= GATE_A_THRESHOLD else "FAIL"
    print(f"\ngate A [ top-{GATE_A_TOPK}, threshold {GATE_A_THRESHOLD:.0%} ]")
    print(f"  eligible commits   {a['eligible']} / {a['total']}")
    print(f"  hits               {a['hit']}")
    print(f"  hit-rate           {a['rate']:.1%}   -> {verdict}")
    print(f"  no in-vocab token  {a['no_query_token']}")
    print(f"  median hit rank    {a['median_rank']}")

    if leak_flags and any(lf is not None for lf in leak_flags):
        ## leak_flag was carried per-record but gate_a doesn't see it --   ##
        ## re-run on the two subsets so a query-shape arm can't silently   ##
        ## report a number inflated by exactly the failure mode this      ##
        ## thread has already been burned by twice [ see phase2.md ]      ##
        clean = [s for s, lf in zip(samples, leak_flags) if not lf]
        leaky = [s for s, lf in zip(samples, leak_flags) if lf]
        print(f"\n  leak_flag breakdown [ {len(leaky)}/{len(samples)} "
              f"flagged ] :")
        for name, subset in (("leak_flag=false", clean),
                              ("leak_flag=true ", leaky)):
            if not subset:
                continue
            sub_a = gate_a(vec, subset, args.clean_tok)
            print(f"    {name}  {sub_a['hit']}/{sub_a['eligible']} "
                  f"= {sub_a['rate']:.1%}")

    b = gate_b(vec, samples, args.clean_tok)
    verdict_b = "PASS" if b["j"] >= GATE_B_MIN_J else "FAIL"
    print(f"\ngate B [ Youden J threshold {GATE_B_MIN_J} ]")
    print(f"  relevant   n={b['pos_n']}  median top-1 {b['pos_median']:.4f}"
          f"  mean {b['pos_mean']:.4f}")
    print(f"  irrelevant n={b['neg_n']}  median top-1 {b['neg_median']:.4f}"
          f"  mean {b['neg_mean']:.4f}")
    print(f"  irrelevant with no answerable token: {b['neg_no_answer']}"
          f" / {b['neg_n']}")
    print(f"  best floor {b['floor']:.4f} -> TPR {b['tpr']:.1%} "
          f"FPR {b['fpr']:.1%}  J {b['j']:.3f}   -> {verdict_b}")

    return 0 if (verdict == "PASS" and verdict_b == "PASS") else 1


if __name__ == "__main__":
    sys.exit(main())
