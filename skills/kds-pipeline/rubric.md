# Quality rubric (v1)

The fixed contract every change is scored against. Scorers do not invent their
own criteria: they apply this one.

## Dimensions

Each one is scored 0–100. The final score is the weighted average.

| Dimension | Weight | What it measures |
|---|---|---|
| `requirements` | 30% | The change does everything the brief asks, including the awkward cases: empty input, bad input, failures. |
| `tests` | 20% | Whether the tests would catch a regression. A test only counts if it fails when the behavior it covers is taken away; lines executed do not count. |
| `security` | 15% | The code this change touches, and only that: is input checked, is access checked, can it be injected, does it leak a secret, does it fail safely. |
| `maintainability` | 15% | The change looks like it belongs in this repo: it follows what the repo already does (cite where), stays simple, repeats nothing, names things clearly, leaves nothing unused. |
| `operational` | 10% | The project's checks pass: tests, lint, typecheck, build. No leftover debugging and no stray edits. |
| `scope` | 10% | The diff contains what was asked for and nothing else: no side refactors, no dependencies the brief did not need. |

## Severity

Judge each finding against these definitions, never against the other findings
in the same review.

- **critical (−15):** the change does not do what it was asked to do, opens a hole someone could exploit, or damages data.
- **major (−8):** something the brief asks for breaks in a case that will really happen, or a central behavior has no test guarding it.
- **minor (−2):** anything smaller.

Each finding takes its points off its own dimension. When every finding is
minor, the score stays at 80 or above.

## Evidence

A score is only as good as what backs it. Give `file:line`, or the command you
ran and what it printed, so a maintainer can check it. A finding you cannot
back up is left out. Report the coverage percentage if the project has one,
but do not turn it into points.

## Verdict

`ready` (≥90) · `ready-with-caveats` (75–89) · `not-ready` (60–74) · `failing` (<60)

`ready` also needs an empty `mustFix`: a change of 90 or more with an open `mustFix` is `ready-with-caveats`.

## Output block

Every score report ends with this block, and only one. `mustFix` lists every
critical and major finding and no minor ones; a change with an open `mustFix`
is not done, whatever its score.

````markdown
```quality-score
{
  "score": 87,
  "dimensions": { "requirements": 92, "tests": 70, "security": 95, "maintainability": 88, "operational": 90, "scope": 85 },
  "verdict": "ready-with-caveats",
  "mustFix": ["tests: no test protects the cancellation path (major) — src/x.ts:42"],
  "gaps": { "tests": "Add a regression test that fails when cancellation is removed" },
  "confidence": "high"
}
```
````
