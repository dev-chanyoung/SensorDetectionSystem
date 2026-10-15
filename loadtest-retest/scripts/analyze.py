"""SafeCar 재측정 결과 집계.

사용법: python analyze.py <결과 폴더>
결과 폴더에는 run-case.ps1이 만든 results.jtl, app.log, monitor-host.csv, meta.json이 있다.
집계 결과는 같은 폴더의 summary.md에 쓰고, 화면에도 출력한다.
"""
import csv
import json
import re
import statistics
import sys
from collections import Counter, defaultdict
from pathlib import Path

# 2월 측정값 (부하테스트 정리.xlsx). 키: (jar, tomcat, consumers, prefetch, threads, ramp, loops)
FEB_REFERENCE = {
    ("retest-sync", 0, 0, 0, 5000, 5, 10): ("52.10%", "2497.0/s"),
    ("retest-mq", 7, 2, 50, 5000, 5, 10): ("17.79%", "2336.7/s"),
    ("retest-mq", 15, 2, 10, 5000, 5, 10): ("48.64%", "2841.6/s"),
    ("retest-mq", 12, 1, 10, 5000, 5, 10): ("56.67%", "4857.63/s"),
    ("retest-mq", 0, 0, 0, 5000, 5, 10): ("56.67%", "4857.63/s"),
    ("retest-mq", 12, 1, 10, 2000, 5, 10): ("0.00%", "2060.2/s"),
    ("retest-mq", 0, 0, 0, 2000, 5, 10): ("0.00%", "2060.2/s"),
    ("retest-mq", 12, 1, 10, 3000, 5, 10): ("21.07%", "2395.8/s"),
    ("retest-mq", 0, 0, 0, 3000, 5, 10): ("21.07%", "2395.8/s"),
}


def pct(values, p):
    if not values:
        return 0
    values = sorted(values)
    k = max(0, min(len(values) - 1, round(p / 100 * (len(values) - 1))))
    return values[k]


def load_jtl(path):
    with open(path, encoding="utf-8", errors="replace", newline="") as f:
        return list(csv.DictReader(f))


def summarize_jtl(rows, lines):
    starts = [int(r["timeStamp"]) for r in rows]
    ends = [int(r["timeStamp"]) + int(r["elapsed"]) for r in rows]
    t0, t1 = min(starts), max(ends)
    duration = (t1 - t0) / 1000
    total = len(rows)
    ok = sum(1 for r in rows if r["success"] == "true")
    err = total - ok
    lines.append("## JMeter 결과")
    lines.append(f"- 요청 {total:,}건, 실행 시간 {duration:.1f}초")
    lines.append(f"- 에러 {err:,}건 (**에러율 {err / total * 100:.2f}%**)")
    lines.append(f"- Throughput(전체) {total / duration:,.1f}/s, **성공 요청 처리량 {ok / duration:,.1f}/s**")
    lines.append("")

    groups = defaultdict(list)
    for r in rows:
        key = (r["responseCode"], (r.get("responseMessage") or "")[:120], r["success"])
        groups[key].append(int(r["elapsed"]))
    lines.append("## 응답 종류별")
    lines.append("| 응답 코드 | 메시지 | 성공 | 건수 | 비율 | 평균 ms | 중앙값 ms | p95 ms | 최대 ms |")
    lines.append("|---|---|---|---:|---:|---:|---:|---:|---:|")
    for (code, msg, success), els in sorted(groups.items(), key=lambda kv: -len(kv[1])):
        lines.append(
            f"| {code} | {msg} | {success} | {len(els):,} | {len(els) / total * 100:.2f}% | "
            f"{statistics.mean(els):,.0f} | {statistics.median(els):,.0f} | {pct(els, 95):,} | {max(els):,} |"
        )
    lines.append("")

    # 초 단위 타임라인 (요청 시작 시각 기준)
    per_sec = defaultdict(lambda: [0, 0])
    for r in rows:
        sec = (int(r["timeStamp"]) - t0) // 1000
        per_sec[sec][0 if r["success"] == "true" else 1] += 1
    lines.append("## 초 단위 타임라인 (요청 시작 시각 기준)")
    lines.append("| 초 | 성공 | 실패 |")
    lines.append("|---:|---:|---:|")
    for sec in range(0, max(per_sec) + 1):
        s, f = per_sec.get(sec, [0, 0])
        lines.append(f"| {sec} | {s:,} | {f:,} |")
    lines.append("")
    return {"total": total, "ok": ok, "err": err, "duration": duration, "t0": t0}


def summarize_app_log(path, lines):
    text = Path(path).read_text(encoding="utf-8", errors="replace")
    unhandled = Counter()
    other_errors = Counter()
    monitor = []
    for line in text.splitlines():
        m = re.search(r"UNHANDLED #\d+ \[(.+?)\] (.*)$", line)
        if m:
            unhandled[(m.group(1), m.group(2)[:160])] += 1
            continue
        m = re.search(r"MONITOR active=(\d+) idle=(\d+) pending=(\d+) total=(\d+) heapUsedMB=(\d+) heapMaxMB=(\d+)", line)
        if m:
            ts = line[:23]
            monitor.append((ts, *map(int, m.groups())))
            continue
        if " ERROR " in line or " WARN " in line:
            m = re.search(r"(ERROR|WARN)\s+\d+\s+---\s+\[.*?\]\s+(\S+)\s*:\s*(.*)$", line)
            if m:
                other_errors[(m.group(1), m.group(2), re.sub(r"\d+", "N", m.group(3))[:160])] += 1
    lines.append("## 서버 로그: 처리되지 않은 예외 (500의 실제 원인)")
    if unhandled:
        lines.append("| 예외 (바깥 <- 근본 원인) | 메시지 | 건수 |")
        lines.append("|---|---|---:|")
        for (key, msg), n in unhandled.most_common(30):
            lines.append(f"| {key} | {msg} | {n:,} |")
    else:
        lines.append("- 없음")
    lines.append("")
    lines.append("## 서버 로그: 그 밖의 ERROR/WARN")
    if other_errors:
        lines.append("| 레벨 | 로거 | 메시지(숫자는 N) | 건수 |")
        lines.append("|---|---|---|---:|")
        for (lvl, logger, msg), n in other_errors.most_common(20):
            lines.append(f"| {lvl} | {logger} | {msg} | {n:,} |")
    else:
        lines.append("- 없음")
    lines.append("")
    lines.append("## 커넥션 풀·힙 모니터 (1초 간격)")
    if monitor:
        lines.append(f"- 최대 active {max(m[1] for m in monitor)}, 최대 pending(커넥션 대기 스레드) "
                     f"{max(m[3] for m in monitor)}, 최대 heap {max(m[5] for m in monitor)}MB / {monitor[0][6]}MB")
        lines.append(f"- pending > 0 이었던 측정 시점: {sum(1 for m in monitor if m[3] > 0)}회")
        lines.append("")
        lines.append("| 시각 | active | idle | pending | total | heapMB |")
        lines.append("|---|---:|---:|---:|---:|---:|")
        for m in monitor:
            lines.append(f"| {m[0][11:19]} | {m[1]} | {m[2]} | {m[3]} | {m[4]} | {m[5]} |")
    else:
        lines.append("- 모니터 로그 없음")
    lines.append("")


def summarize_host_monitor(path, lines):
    if not Path(path).exists():
        return
    with open(path, encoding="utf-8", errors="replace", newline="") as f:
        rows = list(csv.DictReader(f))
    if not rows:
        return
    cpu = [float(r["cpu_percent"]) for r in rows if r["cpu_percent"]]
    q = [int(r["queue_messages"]) for r in rows if r["queue_messages"]]
    lines.append("## PC CPU·RabbitMQ 큐 (1초 간격)")
    if cpu:
        lines.append(f"- CPU 최대 {max(cpu):.0f}%, 평균 {statistics.mean(cpu):.0f}%")
    if q:
        lines.append(f"- 큐 적재 최대 {max(q):,}건, 마지막 {q[-1]:,}건")
    lines.append("")
    lines.append("| 시각 | CPU % | 큐 메시지 | ready | unacked |")
    lines.append("|---|---:|---:|---:|---:|")
    for r in rows:
        lines.append(f"| {r['time'][11:19]} | {r['cpu_percent']} | {r['queue_messages']} | "
                     f"{r['queue_ready']} | {r['queue_unacked']} |")
    lines.append("")


def main():
    out = Path(sys.argv[1])
    meta = json.loads((out / "meta.json").read_text(encoding="utf-8-sig"))
    lines = [f"# {meta['name']}", ""]
    lines.append(f"- jar: `{meta['jar']}`, 부하: {meta['threads']}/{meta['ramp']}/{meta['loops']}, "
                 f"JMeter {meta.get('jmeterMode', 'CLI')} 모드")
    lines.append(f"- Tomcat {meta['tomcatThreads'] or '기본'}, Consumer {meta['consumers'] or '기본'}, "
                 f"Prefetch {meta['prefetch'] or '기본'}")
    lines.append(f"- JMeter {meta['jmeterStart']} ~ {meta['jmeterEnd']}")
    ref = FEB_REFERENCE.get((meta["jar"], meta["tomcatThreads"], meta["consumers"], meta["prefetch"],
                             meta["threads"], meta["ramp"], meta["loops"]))
    if ref:
        lines.append(f"- 2월 측정값(엑셀): 에러율 {ref[0]}, Throughput {ref[1]}")
    lines.append("")

    stats = summarize_jtl(load_jtl(out / "results.jtl"), lines)
    lines.append("## DB 대조")
    lines.append(f"- 성공 응답 {stats['ok']:,}건 / DB `vehicle_log` 행 {meta['dbRowsLoadTest']:,}건"
                 f" / `alert` 행 {meta['dbAlertsLoadTest']:,}건 (요청마다 2건 예상)")
    lines.append("")
    summarize_app_log(out / "app.log", lines)
    summarize_host_monitor(out / "monitor-host.csv", lines)
    lines.append(f"- 환경: RabbitMQ {meta.get('rabbitmqVersion')}, {meta.get('redisVersion')}")

    text = "\n".join(lines) + "\n"
    (out / "summary.md").write_text(text, encoding="utf-8")
    head = text.split("## 초 단위 타임라인")[0]
    sys.stdout.reconfigure(encoding="utf-8")
    print(head)
    print(f"(전체 결과: {out / 'summary.md'})")


if __name__ == "__main__":
    main()
