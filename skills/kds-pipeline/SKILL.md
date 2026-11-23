---
name: kds-pipeline
description: Runs a Killer Dev Squad pipeline (onboard, spec, feature, bugfix, review, measure, security-audit, release, docs) as an Orca Run with a fresh worker per step, and returns the result and the reports.
---

# Running a pipeline

A pipeline is a list of steps in `pipelines/<name>.yaml`. Each step runs in a
new Orca worker (fresh context) and ends in a report. You are the coordinator:
you never do a step's work yourself.

| Pipeline | Writes code | Use it for |
|---|---|---|
| `onboard` | yes | Give a project its profile, `.kds/project.md`. Once per project, before anything else |
| `spec` | yes | Turn a request into a spec with testable requirements and tasks, challenged by a second reader |
| `feature` | yes | Build what a brief asks, test it, then score and fix up to the target |
| `bugfix` | yes | Prove a bug with a failing test, fix it, then score and fix |
| `review` | no | Findings plus a verified score for a branch or commit range |
| `measure` | no | The score alone |
| `verify` | no | Audits and scores settled by one consensus; closes `feature` and `bugfix` |
| `security-audit` | no | Security, dependency and secrets audits of a repository or a range |
| `release` | no | Release readiness, blockers, proposed version and draft notes |
| `docs` | yes | Find docs that drifted from the code, fix them, and re-audit |

Before you start, load Orca's guide: `orca skills get orchestration`.

## Ground rule: a worker stays in its workspace

A worker must not read or write outside its workspace. Nothing enforces this: it holds because every spec says so and gives the worker no reason to leave. So:

- Its spec carries, **pasted in**, everything it needs from this skill (role and rubric) and the brief. Never a path into this folder.
- The project profile lives in the project's repo: `.kds/project.md`.
- Reports go inside the workspace: `.kds/runs/<run_id>/reports/<step>.md` (the project git-ignores `.kds/runs/`).
- You learn the result from each step's `worker_done`, not by reading its workspace or the project: the report comes in its body.

## Inputs you need

- The pipeline to run and the project (its id comes from `orca repo list`).
- The brief. For `review` and `measure`, also the commit range or branch to look at. For `security-audit`, `release` and `docs`, the range is the whole repository unless your owner names one.

If one is missing, ask before creating anything. A step that finds no `.kds/project.md` fails and says so: run `onboard` first.
After `onboard`, the profile lives on that run's branch until your owner merges it. Say so in your answer; until it is merged, start other runs on this project with `--base-branch <that branch>`.
A request for a job is the yes for the pipeline that does that job: "onboard this project" approves `onboard`, "fix this bug" approves `bugfix`. Before a pipeline that writes code and that nobody asked for, or that changes more than was asked, say which pipeline, which project and what it will change, and wait for a yes from whoever asked for the work.

## Steps

`<run_id>` is the id `run-create` returns (`run_603bcfc8acc9`), used as it is everywhere below.
Pass `--environment local --run <run_id>` to every `task-create`, `task-list` and `worker-start`.

1. Create the Run: `orca orchestration run-create --environment local --objective "<pipeline> · <project>"`.
2. For each step in the YAML, build its spec with `compose-spec.sh` (in this folder; run it with no
   arguments for usage), save it as `runs/<run_id>/specs/<step>.md` in your home, and create the Task with
   `task-create --spec-file`, passing the Tasks of its `deps` in `--deps`.
   A `use: <pipeline>` entry stands for that pipeline's steps, in place. A step's `workOrder` is its work order: save that text to a file and pass it.
   For a pipeline that only reads a branch that already exists, write the range as that branch's name, not `HEAD`; the first step records the tip's commit hash in its report.
3. Start the Tasks `task-list --ready` shows, never more at once than `parallel` in `agent.yaml`, with
   `worker-start --task <id> --agent <agent> [--model <model>] [--effort <effort>]`.
   The values come from `agent.yaml` in this folder. Each step names a `tier`; look that tier up under `tiers`:
   - `--agent`: the tier's `agent`, or the file's top-level `agent` when the tier has none.
   - `--model`: the tier's `model`. Empty or missing: leave `--model` out.
   - `--effort`: the tier's `effort`, only when it also has a `model`.
   Your owner chose these in that file: always pass them as written there.
   - Start the first Task alone. It creates the workspace: `--worktree new-top-level --repo id:<repoId> --name kds-<run_id>`.
     To work on, review or score a branch that already exists, add `--base-branch <branch>`: without it the workspace starts from the project's base branch and will not hold that work.
     Every run gets its own new workspace, read-only pipelines too: a workspace is not a change to the project, and one that other runs used holds their reports.
   - Take the workspace's path from that start's receipt. Every later step reuses it (`--worktree id:<repoId>::<path>`); start the other ready Tasks together once you have it.
   - Steps that write run one at a time: each depends on the one before it.
   - On the start that creates the workspace, pass `--setup skip`: each step runs the profile's setup commands itself.
4. End your turn. Orca wakes you with each `worker_done`; on every wake, start whatever became ready.
5. If the pipeline has a `goal`, run the goal loop below once its steps are done.
6. At the end, answer with:
   - what the last step's `worker_done` brought (for a scored pipeline: score, verdict, `mustFix`);
   - the branch that holds the work: the run's own branch for a pipeline that writes, the branch you were asked to look at for one that only reads;
   - the run's workspace and the reports' path inside it. The reports exist only there, so leave the workspace in place: removing it is your owner's call.
   A pipeline with no `goal` ends with its last step. If that step leaves findings open, report them and stop: another run is your owner's call.

## When a run is interrupted

A run can stop halfway: a worker hits its usage limit, its agent exits, Orca restarts, or you are woken with no memory of where you were. None of these is a failed step. The Run and its Tasks are kept by Orca, so the run can go on from where it stopped.

1. Find the run. Your runs are the folders in `runs/` in your home; the one to resume is the newest whose Tasks are not all completed.
2. Read its state: `orca orchestration task-list --environment local --run <run_id>` and `orca orchestration worker-list --environment local --run <run_id>`. Act only on what they show.
3. Completed Tasks stay completed: never run a step again because you do not remember its result. Ask the worker for it instead (`orca orchestration worker-read --dispatch <dispatch_id>`).
4. A worker that is still alive is still working: wait for it. If `worker-list` gives it a `next`, follow that.
5. A Task whose worker is gone gets one new attempt on the same Task, in the same workspace: `worker-start --task <task_id> --retry-of <dispatch_id>` with the agent, model and effort of its tier. Every spec tells the worker to continue from what an interrupted attempt left.
6. Then carry on with the pipeline's steps as usual.

A usage limit: start no more workers, tell your requester the run is paused, at which step, and that it continues when the limit lifts. When Orca wakes you again, resume from step 2.

If the same step is interrupted twice, or Orca refuses a retry, stop and report the run id, the step and what `worker-list` shows. Do not start a new Run or a new Task to get around it. For anything else, load Orca's own guide: `orca skills get orchestration --reference references/recovery-and-cleanup.md`.

## The goal loop

The target is the project profile's target score (90 when it names none).
The range to score is the run branch's base to its head.

1. **Measure.** Create and run the steps of the pipeline the goal names in `measure` (`verify` for `feature` and `bugfix`). The first round keeps the step names as they are; later rounds add the round number (`score-a-1`, `audit-bugs-1`).
2. **Stop** when any of these is true, and say which:
   - the score reached the target and `mustFix` is empty;
   - the last fix round raised the score by fewer than `plateau` points;
   - `maxIterations` fix rounds are used up;
   - a step failed or the consensus brought no `quality-score` block.
3. **Fix.** Otherwise create one `fix-<n>` Task with the `goal.fix` role. Its work order is the `mustFix` and `gaps` of the last consensus, pasted in, and nothing else. Then measure again.

Scorers and auditors never see an earlier score or an earlier report: a new round's steps get only the rubric, the brief and the range.
A loop that stops below the target is not a failure: report the last score and what is still missing.

## What each step's spec carries

`compose-spec.sh` builds it. In this order:

1. One line: which step it is, of which pipeline and which run.
2. The full content of `roles/<role>.md`, and the step's `focus` if it has one.
3. If the role scores or audits, the full content of `rubric.md`. For the profiler, the profile template.
4. The full brief. For a fixer, its work order.
5. The range to work on.
6. The reports it may read (the step's `reports`), by path inside the workspace, and no others.
7. Where to write its own: `.kds/runs/<run_id>/reports/<step>.md`.
8. What proves it is done, and what its `worker_done` must carry: the report path, the commit it made if it writes, and the full `quality-score` block if it scores.

## Limits

- A failed step is never marked completed. Retry once; if it fails again, report it.
- Never commit to a project's base branch: every change, the profile included, goes on a run's own branch.
- Never push and never merge: deliver the branch ready to merge. Orcastrator merges it locally once your owner says yes. Open a pull request only when your owner asks for one.
