# OSX Skills for Claude and Codex

Production skills for reviewing and shipping Apple platform applications (macOS + iOS/iPadOS).

## Included Skills

- `osx-compliance`: audits Apple-platform release/compliance infrastructure (macOS + iOS/iPad companion gates).
- `osx-review`: deep release-focused code review for App Store and desktop/mobile delivery.
- `osx-models`: model/framework selection guidance for native Apple-platform AI features.
- `osx-ios`: end-to-end iOS/iPad distribution preparation for TestFlight and App Store.

Skill source files:

- `skills/osx-compliance/SKILL.md`
- `skills/osx-review/SKILL.md`
- `skills/osx-models/SKILL.md`
- `skills/osx-ios/SKILL.md`

## Installation

Use the installer scripts from this repository root.

### Claude Code

```bash
./scripts/install-claude.sh
```

This installs a symlink at:

```text
~/.claude/skills/osxskills -> <repo>/skills
```

### Codex

```bash
./scripts/install-codex.sh
```

This installs a symlink at:

```text
~/.agents/skills/osxskills -> <repo>/skills
```

### Manual install (optional)

Claude:

```bash
mkdir -p ~/.claude/skills
ln -sfn "$(pwd)/skills" ~/.claude/skills/osxskills
```

Codex:

```bash
mkdir -p ~/.agents/skills
ln -sfn "$(pwd)/skills" ~/.agents/skills/osxskills
```

## Usage

### Claude Code

Invoke directly, for example:

```text
/osx-review
```

Or for mobile distribution:

```text
/osx-ios
```

### Codex

Use natural language, for example:

```text
Use the osx-review skill on this macOS app before release.
```

Or:

```text
Use the osx-ios skill to prepare iOS and iPad distribution for TestFlight.
```

## Update

```bash
git pull
```

No reinstall is needed when using symlinks.

## Uninstall

```bash
rm ~/.claude/skills/osxskills
rm ~/.agents/skills/osxskills
```

## License

MIT. See `LICENSE`.
