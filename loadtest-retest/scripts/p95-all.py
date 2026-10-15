"""Post-hoc latency percentiles from every results\*\results.jtl (no new measurement).
Writes p95-all.csv next to this script: one row per result folder with error %, and p50/p95/p99 of the elapsed time
for successful samples and for all samples.  Usage: python p95-all.py
"""
import csv, glob, os, statistics as st

here = os.path.dirname(os.path.abspath(__file__))


def pct(sorted_vals, p):
    if not sorted_vals:
        return ""
    k = (len(sorted_vals) - 1) * p / 100.0
    lo, hi = int(k), min(int(k) + 1, len(sorted_vals) - 1)
    return round(sorted_vals[lo] + (sorted_vals[hi] - sorted_vals[lo]) * (k - lo), 1)


rows = []
for d in sorted(glob.glob(os.path.join(here, "results", "*"))):
    jtl = os.path.join(d, "results.jtl")
    if not os.path.isfile(jtl):
        continue
    ok, allv, n, err = [], [], 0, 0
    try:
        with open(jtl, encoding="utf-8", newline="") as f:
            for r in csv.DictReader(f):
                try:
                    e = int(r["elapsed"])
                except (KeyError, ValueError):
                    continue
                n += 1
                allv.append(e)
                if r.get("success") == "true":
                    ok.append(e)
                else:
                    err += 1
    except OSError:
        continue
    ok.sort()
    allv.sort()
    rows.append([os.path.basename(d), n, round(err / n * 100, 2) if n else "",
                 pct(ok, 50), pct(ok, 95), pct(ok, 99), pct(allv, 50), pct(allv, 95), pct(allv, 99)])

out = os.path.join(here, "p95-all.csv")
with open(out, "w", encoding="utf-8", newline="") as f:
    w = csv.writer(f)
    w.writerow(["dir", "samples", "error_pct", "ok_p50_ms", "ok_p95_ms", "ok_p99_ms", "all_p50_ms", "all_p95_ms", "all_p99_ms"])
    w.writerows(rows)
print("folders:", len(rows), "->", out)
