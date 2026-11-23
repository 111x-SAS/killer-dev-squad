# <project name>

- **Repo in Orca:** `<name in orca repo list>`
- **Base branch:** `main`
- **Stack:** <languages, framework, version>
- **Target score:** 90

## Setup commands

What a fresh checkout needs before the checks can run. Everything here must stay inside the workspace.

```bash
<install dependencies>
```

## Check commands

What must pass before a change counts as good.

```bash
<tests>
<lint / typecheck>
<build>
```

## Conventions

- <commits, branches, style, what a newcomer needs to know>

## Do not touch

- <files, folders or actions that are off limits>
