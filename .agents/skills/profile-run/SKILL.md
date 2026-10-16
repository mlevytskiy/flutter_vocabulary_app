---
name: profile-run
description: >
  Profile where the time went in this session's work (usually an /sdd:implement run) and
  recommend improvements. Use when the owner says "profile what you did", "profile the run",
  "where did the time go", "why was it slow", "профілюй що ти зробив", "де витратили час".
---

# Profile the run

1. Run `python3 -I tool/sdd_profile.py --current` (this session and its subagents). If the
   owner names a start time or a session, use `--since "YYYY-MM-DD HH:MM"` or `--session <prefix>`
   instead. If the work happened in an earlier session, ask which one rather than guessing.
2. Report in this order, short:
   - **What was done:** the task commits from the timeline (task id, title, minutes per task),
     and which agents ran (role, count).
   - **Where the time went:** the share table for subagents, plus anything big in the main
     session. Name the top 3 time sinks in minutes.
   - **Compared with the baseline** in the script's header (10-07: 6-36 min per task, Worker full
     suite 62 %, model 13 %). Say plainly whether it got better or worse.
   - **Slowest commands:** call out any that repeat or look wrong.
3. Recommend at most 3 improvements, each tied to a number from the report. Check these first:
   - `test FULL` or plain `worker test` time inside tasks → AGENTS.md rule 7 was not followed
     (tasks should use `tool/test.sh smoke` / `changed`; full only when the owner asks).
   - `waiting` time → agents blocked on each other's test runs (parallel agents in one tree).
   - The same test command run 3+ times in one agent → flaky test or retry loop; name the test.
   - `model` is the biggest share → agents read too much up front (whole sad.md/spec.md, a
     growing handoff.md); suggest reading only the task's linked sections.
   - Main session wall time far above the subagents' → time went to waiting for the owner
     (questions, permission prompts); suggest allowlist entries for the repeated commands.
   - Task commits without an `SDD-Task:` trailer → per-task timing is lost; say so.
4. Do not change code, settings or the plugin; only report and recommend. Offer to apply a
   recommendation if the owner wants it.
