# OSX Skills for Claude and Codex

Production skills for reviewing and shipping macOS applications.

## Included Skills

- `osx-app-compliance-check`: audits macOS project release/compliance infrastructure.
- `app-store-code-review`: deep release-focused code review for App Store and desktop delivery.
- `native-ai-model-selection`: model/framework selection guidance for native macOS AI features.

Skill source files:

- `skills/osx-app-compliance-check/SKILL.md`
- `skills/app-store-code-review/SKILL.md`
- `skills/native-ai-model-selection/SKILL.md`

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
/app-store-code-review
```

### Codex

Use natural language, for example:

```text
Use the app-store-code-review skill on this macOS app before release.
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
