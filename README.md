# Killer Dev Squad

The experimental dev team of [111x](https://111x.co): a crew of [Orca](https://orca.dev)
bots that works on its own across several projects.

**Website:** https://111x-sas.github.io/killer-dev-squad/

The name comes from the orca (the *killer whale*), which hunts in a pod with
coordination and precision. *Killer* is also slang for "excellent", *Dev* is
software development, and *Squad* says we are one tight team.

## How it works

- **Bots** with a fixed role. Each one is a folder holding its identity (`SOUL.md`) and its skills.
- **Pipelines**: lists of steps. Each step runs in a new Orca worker, with fresh context and its own worktree, and ends in a report.
- **Scoring**: two independent scorers grade the change against a six-dimension rubric and a consensus verifies their claims. A change is ready at 90/100.
- **People** approve specs, answer what the crew cannot decide, and approve every merge.

The crew is set up for Claude Code. It can run on any agent Orca supports for bots, such as Codex, Cursor, GitHub Copilot or Gemini CLI, each on your own plan with that provider.

## The crew

| Bot | Post | What it does | Pipelines |
|---|---|---|---|
| **Orcastrator [LEAD]** | Captain | Takes every request, briefs it, gives it to the right bot, reports back, and merges on your yes | none: it coordinates |
| **Chartbeard [SPEC]** | Navigator | Onboards projects; turns vague requests into specs | `onboard`, `spec` |
| **ShipItFinn [DEV]** | Shipwright | Builds features and changes | `feature` |
| **Blamebeard [REV]** | Quartermaster | Reviews and scores changes | `review`, `measure` |
| **Fluke [QA]** | Barnacle scraper | Proves bugs with a failing test, then fixes them | `bugfix` |
| **DavyLocker [SEC]** | Master-at-arms | Audits security, dependencies and secrets | `security-audit` |
| **LandHo [REL]** | Bosun | Says whether a branch can be released; drafts the notes | `release` |
| **Polly [DOCS]** | Ship's parrot | Keeps documentation in step with the code | `docs` |

The code in brackets says what each bot does at a glance. You talk to Orcastrator. It asks you before any
pipeline that writes code, and every question from the crew reaches you through it. Every bot answers in
the language you write to it in.

## Layout

```
bots/<bot>/SOUL.md       each bot's identity and rules
skills/kds-pipeline/     the engine: how to run a pipeline, rubric, roles, pipelines, agent and models, crew list, spec composer, project profile template
scripts/install.sh       copies a bot's SOUL.md and the skill into its Orca home
site/index.html          the landing page, one static file
```

Each project carries its own profile in `.kds/project.md` (stack, check commands, target score).
Each run's reports stay in the run's workspace, under `.kds/runs/<run_id>/reports/`.

## Pipelines

| Pipeline | Writes code | What it does |
|---|---|---|
| `onboard` | yes | Write and commit a project's profile, with check commands that were actually run |
| `spec` | yes | Draft a spec with testable requirements and tasks, then challenge it independently |
| `feature` | yes | Implement a brief, protect it with tests, then verify and fix up to the target |
| `bugfix` | yes | Reproduce a bug with a failing test, fix it, then verify and fix |
| `review` | no | Three focused audits and an independent score, merged into one page |
| `measure` | no | Two scorers on different models, or different agents, and a verified consensus |
| `verify` | no | Three audits and two scorers, settled by one consensus; the check that closes `feature` and `bugfix` |
| `security-audit` | no | Security, dependency and secrets audits merged into one page |
| `release` | no | Release readiness, blockers, proposed version and draft release notes |
| `docs` | yes | Audit the docs against the code, fix what drifted, then re-audit |

Pipelines that write code commit on the run's own branch. The crew never pushes. When a branch is ready,
Orcastrator asks you; on your yes it merges the branch locally and runs the project's checks.

## Requirements

- [Orca](https://orca.dev) 1.4.271 or later, with orchestration turned on (Settings → Experimental).
- A coding agent Orca can run, installed and signed in. Claude Code is the default; `orca agent installed` lists what you have.
- macOS or Linux for `scripts/install.sh` (on Windows, run it in WSL).
- Every bot and every worker runs on your own plan with that agent's provider.

## Install

You start with one bot. The others are added the first time a job needs them.

1. Clone this repository.
2. In Orca, create a bot named **Orcastrator [LEAD]** with your agent: Bots → + → New bot → Start from scratch.
3. Wait until Orcastrator has written its first message in its chat: that is Orca's first-run setup, and it can rewrite the bot's soul. Then, from the repository, run `scripts/install.sh orcastrator`. It gives Orcastrator its soul and the pipeline skill.
4. Give Orcastrator a job in its chat. When the job needs a bot you don't have yet, Orcastrator says which one and shows a card to create it. Press **Create bot**, wait for the new bot's first message in its own chat, then run `scripts/install.sh <name>`, for example `scripts/install.sh chartbeard`. Orcastrator waits until the bot is there.
5. Your first job on a project is always onboarding: "Onboard `<project>`". Chartbeard writes the project's profile, `.kds/project.md`, on a branch. Review it, then tell Orcastrator to merge it.

To install the whole crew at once, create the eight bots with the names in the table above, codes included, and run `scripts/install.sh` with no arguments. It skips any bot that doesn't exist yet.

### Updating

Pull the repository and run `scripts/install.sh` again. It replaces each bot's soul and skill; the first
install keeps the soul a bot had before as `SOUL.md.bak`. Memory, items and chats are not touched.

A bot picks up the new rules on its next turn. Update while the crew is idle: a job already running
finishes under the rules it started with.

## Before you point it at a real project

The crew runs your project's own commands: install, tests, typecheck, and whatever the profile says.

- **Review `.kds/project.md` before you merge it.** Check every command listed there. A build, a dev server or a preview can reach live services even with fake environment variables, for example when the code has a production URL written into it. Anything that does belongs under *Do not touch*.
- **Start with a copy you can throw away**, with no git remote and its deploy scripts removed, until you trust the profile.
- **The crew never pushes or deploys; only Orcastrator merges, locally, after your yes**, and reads only its own workspace. These are rules every task carries, not sandboxing: an agent can still break them, so keep the first runs where a mistake costs nothing.

## Using another agent

Claude Code is the default. To change it, edit `skills/kds-pipeline/agent.yaml` before running `scripts/install.sh`:

```yaml
agent: codex                       # the agent every pipeline step runs on
tiers:
  strong: { model: <model id>, effort: high }   # judging: scoring, consensus, reports, specs
  fast:   { model: <model id> }                 # doing: building, testing, fixing, audits
  light:  {}                                    # mechanical checks; empty means the agent's default model
  second: { agent: claude, model: sonnet }      # the second scorer, here on a different provider
```

A pipeline step asks for a tier, never for a model. Each tier may set a model, a reasoning effort and
its own agent; whatever it leaves out falls back to the agent's default. Create the bots with the agent
named at the top.

Putting `second` on a different agent makes the two scorers come from different providers, which is
the strongest check the crew has. By default all four tiers run on Claude Code.

## Roadmap to a public release

1. **Clean install test.** Delete the bots and install them again following only this README; fix whatever is unclear. Then repeat on a machine with a fresh Orca.
2. **Publish.** Squash the history into one commit, create the GitHub repository, deploy `site/`.
3. **Optional quick start link.** Share Orcastrator from Orca (its settings → Sharing → Share bot) and put that one link on the landing page and here, next to the repository install. Its link stays the same; after a change, share the bot again so the link serves the new version. The other bots keep coming from the repository, or from their own links in `skills/kds-pipeline/crew.yaml` if those are ever filled in.

## Pending

- **Run a whole pipeline on a second agent.** The second scorer has run on Codex next to a Claude scorer, with no change to its task. No step that writes code has run outside Claude Code yet.

- **Create the bot group automatically.** A group (one room where the eight bots take turns) can only be made by hand today: in Orca, Bots → + → New bot or group. Orca's CLI has no group command and blocks opening that menu in the background. Revisit when Orca adds one, and make it a step of `scripts/install.sh`.

- **Share links from the command line.** Orca can share a bot by link only from its interface, so links are made and refreshed by hand. Revisit when Orca adds a command.

## License

[MIT](LICENSE). Copy it, change it, use it commercially; keep the copyright notice, which names
111x and links back to this repository.
