# Installing OSXSkills for Claude Code

## Quick install

From the repository root:

```bash
./scripts/install-claude.sh
```

## What it does

- Creates `~/.claude/skills` if missing.
- Symlinks this repo's `skills/` to `~/.claude/skills/osxskills`.

## Verify

```bash
ls -la ~/.claude/skills/osxskills
```

## Update

```bash
cd <your-osxskills-clone>
git pull
```

## Uninstall

```bash
rm ~/.claude/skills/osxskills
```
