#!/usr/bin/env python3
"""Claude Code hook: aggregate token usage from a session transcript.

Wired to the Stop, SubagentStop and SessionEnd hook events. On each invocation
it reads the hook JSON payload from stdin, parses the referenced transcript
(JSONL), sums token usage per model (de-duping by message id), estimates cost,
and writes a snapshot file under .claude/metrics/sessions/.

The report (scripts/gen-usage-report.py) sums every snapshot file. Both the main
session transcript (<session_id>.jsonl) and each subagent transcript
(agent-<id>.jsonl) produce their own snapshot, so subagent tokens are captured.

Design rules:
- stdlib only, never crash the hook (always exit 0).
- Idempotent: re-parsing the same transcript overwrites its snapshot, so totals
  never double-count across turns.
"""
import json
import os
import sys
from datetime import datetime, timezone

# USD per single token = (price per million tokens) / 1_000_000.
# Rates are list prices; treat report figures as estimates.
RATES = {
    "opus":   {"input": 15.0, "output": 75.0, "cache_write": 18.75, "cache_read": 1.50},
    "sonnet": {"input": 3.0,  "output": 15.0, "cache_write": 3.75,  "cache_read": 0.30},
    "haiku":  {"input": 1.0,  "output": 5.0,  "cache_write": 1.25,  "cache_read": 0.10},
}
DEFAULT_RATE = RATES["sonnet"]


def rate_for(model: str):
    m = (model or "").lower()
    for key, rate in RATES.items():
        if key in m:
            return rate
    return DEFAULT_RATE


def cost_for(model, inp, out, cw, cr):
    r = rate_for(model)
    return (inp * r["input"] + out * r["output"]
            + cw * r["cache_write"] + cr * r["cache_read"]) / 1_000_000


def parse_transcript(path):
    """Return (by_model dict, message_count, first_ts, last_ts)."""
    by_model = {}
    seen = set()
    count = 0
    first_ts = last_ts = None
    with open(path, "r", encoding="utf-8", errors="replace") as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            try:
                rec = json.loads(line)
            except json.JSONDecodeError:
                continue
            if rec.get("type") != "assistant":
                continue
            msg = rec.get("message") or {}
            usage = msg.get("usage")
            if not usage:
                continue
            mid = msg.get("id")
            if mid and mid in seen:
                continue  # streaming dupes / repeated final frames
            if mid:
                seen.add(mid)
            model = msg.get("model", "unknown")
            inp = int(usage.get("input_tokens", 0) or 0)
            out = int(usage.get("output_tokens", 0) or 0)
            cw = int(usage.get("cache_creation_input_tokens", 0) or 0)
            cr = int(usage.get("cache_read_input_tokens", 0) or 0)
            slot = by_model.setdefault(model, {
                "input": 0, "output": 0, "cache_write": 0, "cache_read": 0,
                "messages": 0, "cost_usd": 0.0,
            })
            slot["input"] += inp
            slot["output"] += out
            slot["cache_write"] += cw
            slot["cache_read"] += cr
            slot["messages"] += 1
            slot["cost_usd"] += cost_for(model, inp, out, cw, cr)
            count += 1
            ts = rec.get("timestamp")
            if ts:
                first_ts = first_ts or ts
                last_ts = ts
    return by_model, count, first_ts, last_ts


def main():
    try:
        payload = json.load(sys.stdin)
    except Exception:
        return
    transcript = payload.get("transcript_path")
    if not transcript or not os.path.isfile(transcript):
        return
    project_dir = os.environ.get("CLAUDE_PROJECT_DIR") or payload.get("cwd") or os.getcwd()
    metrics_dir = os.path.join(project_dir, ".claude", "metrics", "sessions")
    os.makedirs(metrics_dir, exist_ok=True)

    by_model, count, first_ts, last_ts = parse_transcript(transcript)
    totals = {"input": 0, "output": 0, "cache_write": 0, "cache_read": 0, "cost_usd": 0.0}
    for slot in by_model.values():
        for k in ("input", "output", "cache_write", "cache_read", "cost_usd"):
            totals[k] += slot[k]
    totals["tokens"] = totals["input"] + totals["output"] + totals["cache_write"] + totals["cache_read"]

    # Snapshot key = transcript basename → main session and each subagent get a row.
    key = os.path.splitext(os.path.basename(transcript))[0]
    safe = "".join(c if c.isalnum() or c in "-_" else "_" for c in key)
    snapshot = {
        "key": key,
        "session_id": payload.get("session_id"),
        "agent_id": payload.get("agent_id"),
        "agent_type": payload.get("agent_type"),
        "hook_event": payload.get("hook_event_name"),
        "transcript_path": transcript,
        "messages": count,
        "first_ts": first_ts,
        "last_ts": last_ts,
        "updated_at": datetime.now(timezone.utc).isoformat(),
        "totals": totals,
        "by_model": by_model,
    }
    out_path = os.path.join(metrics_dir, safe + ".json")
    tmp = out_path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as fh:
        json.dump(snapshot, fh, indent=2)
    os.replace(tmp, out_path)

    rollup(os.path.join(project_dir, ".claude", "metrics"))


def rollup(metrics_dir):
    """Sum every per-transcript snapshot into one usage-summary.json.

    This is the single file /gen-summary reads. Grouped both by model and by
    session so the summary can show a project total and a per-session breakdown.
    """
    sessions_dir = os.path.join(metrics_dir, "sessions")
    if not os.path.isdir(sessions_dir):
        return
    grand = {"input": 0, "output": 0, "cache_write": 0, "cache_read": 0, "cost_usd": 0.0, "tokens": 0}
    by_model = {}
    by_session = {}
    snap_count = 0
    for name in os.listdir(sessions_dir):
        if not name.endswith(".json"):
            continue
        try:
            with open(os.path.join(sessions_dir, name), encoding="utf-8") as fh:
                snap = json.load(fh)
        except Exception:
            continue
        snap_count += 1
        t = snap.get("totals", {})
        for k in grand:
            grand[k] += t.get(k, 0)
        for model, slot in (snap.get("by_model") or {}).items():
            agg = by_model.setdefault(model, {"input": 0, "output": 0, "cache_write": 0, "cache_read": 0, "cost_usd": 0.0, "messages": 0})
            for k in agg:
                agg[k] += slot.get(k, 0)
        sid = snap.get("session_id") or snap.get("key")
        sess = by_session.setdefault(sid, {"input": 0, "output": 0, "cache_write": 0, "cache_read": 0, "cost_usd": 0.0, "tokens": 0, "transcripts": 0, "last_ts": None})
        for k in ("input", "output", "cache_write", "cache_read", "cost_usd", "tokens"):
            sess[k] += t.get(k, 0)
        sess["transcripts"] += 1
        if snap.get("last_ts"):
            sess["last_ts"] = max(sess["last_ts"] or "", snap["last_ts"])

    summary = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "snapshots": snap_count,
        "sessions": len(by_session),
        "totals": grand,
        "cost_usd_estimate": round(grand["cost_usd"], 4),
        "by_model": by_model,
        "by_session": by_session,
        "note": "Token totals are exact (from transcripts); cost is a list-price estimate.",
    }
    out = os.path.join(metrics_dir, "usage-summary.json")
    tmp = out + ".tmp"
    with open(tmp, "w", encoding="utf-8") as fh:
        json.dump(summary, fh, indent=2)
    os.replace(tmp, out)


if __name__ == "__main__":
    try:
        main()
    except Exception:
        pass  # never break the hook chain
    sys.exit(0)
