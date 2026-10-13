#!/usr/bin/env python3
"""Where did the time go in a Claude Code implement run?

Reads the Claude Code transcripts (main session + its subagents) for this repo and
prints, per agent, how many minutes went to model work, each kind of test run,
analyze and other shell work, then the slowest single commands and the per-task
commit timeline from `SDD-Task:` trailers.

  python3 tool/sdd_profile.py --since "2026-10-12 23:00"   # every session since then
  python3 tool/sdd_profile.py --session 9ff03ab4             # one session (id prefix)
  python3 tool/sdd_profile.py --current                      # the session running this command

Baseline (10-07, before the test tiers): 36 task agents, 405 min; Worker full
suite 62 %, model 13 %, flutter test 10 %; 6-36 min per task.
"""
import argparse, collections, glob, json, os, re, subprocess
from datetime import datetime

PROJECTS = os.path.expanduser("~/.claude/projects")
# Sessions started in the repo, plus ones started from the home folder.
DIRS = ["-Users-max-CascadeProjects-flutter-vocabulary-app", "-Users-max"]
REPO_MARK = "flutter_vocabulary_app"
KINDS = ["model", "test smoke", "test changed/feature", "test FULL", "worker test",
         "flutter test", "typecheck", "analyze/codegen", "git", "other shell", "waiting"]


def ts(s):
    return datetime.fromisoformat(s.replace("Z", "+00:00")).timestamp()


def kind(cmd):
    if re.search(r"test\.sh\s+smoke", cmd): return "test smoke"
    if re.search(r"test\.sh\s+(changed|feature)", cmd): return "test changed/feature"
    if re.search(r"test\.sh\s+full|test:full|test:long", cmd): return "test FULL"
    if re.search(r"vocab-photo-api (run )?test|npm test|scripts/test\.mjs|node --test", cmd): return "worker test"
    if "flutter test" in cmd: return "flutter test"
    if "typecheck" in cmd or re.search(r"\btsc\b", cmd): return "typecheck"
    if re.search(r"flutter analyze|build_runner", cmd): return "analyze/codegen"
    if re.search(r"pgrep|sleep \d|while .*sleep", cmd): return "waiting"
    if re.match(r"\s*(cd [^;&]+[;&]+\s*)?git ", cmd): return "git"
    return "other shell"


def profile(path):
    pend, out, slow = {}, collections.defaultdict(float), []
    first = last = last_result = None
    for line in open(path, errors="ignore"):
        try:
            d = json.loads(line)
        except ValueError:
            continue
        t = d.get("timestamp")
        content = (d.get("message") or {}).get("content")
        if not t:
            continue
        t = ts(t)
        first, last = first or t, t
        if not isinstance(content, list):
            continue
        if d.get("type") == "assistant":
            if last_result and t - last_result < 900:  # longer gaps = the user was away
                out["model"] += t - last_result
            last_result = None
        for x in content:
            if x.get("type") == "tool_use":
                cmd = (x.get("input") or {}).get("command", "") if x["name"] == "Bash" else ""
                pend[x["id"]] = (t, x["name"], cmd)
            elif x.get("type") == "tool_result" and x.get("tool_use_id") in pend:
                start, name, cmd = pend.pop(x["tool_use_id"])
                last_result = t
                if name == "Bash":
                    out[kind(cmd)] += t - start
                    slow.append((t - start, cmd.replace("\n", " ")[:120]))
    return first, last, out, slow


def sessions(args):
    for d in DIRS:
        for main in glob.glob(os.path.join(PROJECTS, d, "*.jsonl")):
            sid = os.path.basename(main)[:-6]
            if args.session and not sid.startswith(args.session):
                continue
            if d == "-Users-max" and REPO_MARK not in open(main, errors="ignore").read():
                continue
            first, *_ = profile(main)
            if not first or (args.since and first < args.since):
                continue
            yield sid, main


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--since", help='"YYYY-MM-DD HH:MM" local time')
    p.add_argument("--session", help="session id prefix")
    p.add_argument("--current", action="store_true", help="the most recently active session")
    args = p.parse_args()
    if args.current:
        mains = [f for d in DIRS for f in glob.glob(os.path.join(PROJECTS, d, "*.jsonl"))]
        args.session = os.path.basename(max(mains, key=os.path.getmtime))[:-6]
    if args.since:
        args.since = datetime.strptime(args.since, "%Y-%m-%d %H:%M").timestamp()

    total, wall_total, slow_all, n = collections.defaultdict(float), 0.0, [], 0
    print(f"{'agent':24}{'wall':>6} " + " ".join(f"{k[:9]:>9}" for k in KINDS) + "   (minutes)")
    first_seen = None
    for sid, main in sessions(args):
        first_seen = min(filter(None, [first_seen, profile(main)[0]]))
        files = [(sid[:8] + " main", main)]
        for f in sorted(glob.glob(main[:-6] + "/subagents/*.jsonl"), key=os.path.getmtime):
            meta = f[:-6] + ".meta.json"
            role = json.load(open(meta)).get("agentType", "?") if os.path.exists(meta) else "?"
            files.append(("  " + role.replace("sdd:", "")[:14], f))
        for label, f in files:
            first, last, out, slow = profile(f)
            if not first:
                continue
            wall = (last - first) / 60
            print(f"{label:24}{wall:6.1f} " + " ".join(f"{out[k] / 60:9.1f}" for k in KINDS))
            if "main" not in label:  # the main session's wall time includes waiting for you
                wall_total += wall; n += 1
                for k in KINDS: total[k] += out[k]
            slow_all += slow

    if n:
        print(f"\nSubagents: {n}, {wall_total:.0f} min wall. Share of that time:")
        for k in KINDS:
            if total[k]:
                print(f"  {100 * total[k] / 60 / wall_total:5.1f} %  {total[k] / 60:6.1f} min  {k}")
    print("\nSlowest commands:")
    for dur, cmd in sorted(slow_all, reverse=True)[:10]:
        print(f"  {dur:6.0f} s  {cmd}")

    if args.since:
        since = f"--since=@{int(args.since)}"
    elif first_seen:
        since = f"--since=@{int(first_seen)}"
    else:
        since = "--since=2 days ago"
    log = subprocess.run(["git", "log", since, "--reverse", "--date=format:%m-%d %H:%M",
                          "--format=%ad|%at|%(trailers:key=SDD-Task,valueonly,separator=+)|%s"],
                         capture_output=True, text=True).stdout.splitlines()
    print("\nTask commits (minutes since the previous commit):")
    prev = None
    for row in log:
        date, at, task, subject = row.split("|", 3)
        gap = f"{(int(at) - prev) / 60:5.0f}" if prev else "    -"
        prev = int(at)
        print(f"  {date} {gap}  {task or '--':5} {subject[:80]}")


if __name__ == "__main__":
    main()
