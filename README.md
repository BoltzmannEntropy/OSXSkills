# OSX Skills for Claude and Codex

Production skills for reviewing and shipping Apple platform applications (macOS + iOS/iPadOS), plus targeted Flutter Windows packaging workflows.

## Included Skills

- `osx-compliance`: audits Apple-platform release/compliance infrastructure (macOS + iOS/iPad companion gates).
- `osx-review`: deep release-focused code review for App Store and desktop/mobile delivery.
- `osx-models`: model/framework selection guidance for native Apple-platform AI features.
- `osx-ios`: end-to-end iOS/iPad distribution preparation for TestFlight and App Store.
- `osx-flutter-auth0-login`: Auth0 login implementation for Flutter macOS apps with PKCE, Keychain storage, and backend JWT verification.
- `windows-flutter-exe`: builds and packages Flutter Windows executable bundles with runtime dependencies.

Skill source files:

- `skills/osx-compliance/SKILL.md`
- `skills/osx-review/SKILL.md`
- `skills/osx-models/SKILL.md`
- `skills/osx-ios/SKILL.md`
- `skills/osx-flutter-auth0-login/SKILL.md`
- `skills/windows-flutter-exe/SKILL.md`

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

Or for Flutter Windows executable packaging:

```text
/windows-flutter-exe
```

Or for Auth0 login in Flutter macOS:

```text
/osx-flutter-auth0-login
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

Or:

```text
Use the windows-flutter-exe skill to package a Flutter Windows release with all dependencies.
```

Or:

```text
Use the osx-flutter-auth0-login skill to add Auth0 login to my Flutter macOS app.
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
