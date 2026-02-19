# Installing OSXSkills for Codex

Codex discovers skills from `~/.agents/skills`.

## Quick install

From the repository root:

```bash
./scripts/install-codex.sh
```

## What it does

- Creates `~/.agents/skills` if missing.
- Symlinks this repo's `skills/` to `~/.agents/skills/osxskills`.

## Verify

```bash
ls -la ~/.agents/skills/osxskills
```

## Update

```bash
cd <your-osxskills-clone>
git pull
```

## Uninstall

```bash
rm ~/.agents/skills/osxskills
```
