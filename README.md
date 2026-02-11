# OSX Skills for Claude Code

Production-ready skills for building and shipping macOS applications with Claude Code.

## Overview

These skills were developed by [Qneura.ai](https://qneura.ai) to systematically build, review, and ship desktop applications for macOS. They encode hard-won lessons from shipping real apps to the App Store and direct distribution.

**See our apps in action:** [https://qneura.ai/apps.html](https://qneura.ai/apps.html)

## Skills Included

### 1. `app-store-code-review`

A comprehensive code review checklist for preparing apps for App Store submission or direct distribution.

**Covers:**
- Crash prevention (lifecycle, memory, async safety)
- Resource management (memory leaks, file handling)
- Network & API resilience
- Security (input validation, auth, data protection)
- Platform compliance (Apple App Store, macOS)
- Product information (About page, version, legal pages)
- Project infrastructure (control scripts, installers, DMG builders)

### 2. `flutter-python-fullstack`

A complete pattern for building desktop applications with Flutter frontend and Python FastAPI backend.

**Covers:**
- Project structure and organization
- Flutter UI patterns (Material 3, dark mode, tabs)
- Backend API patterns
- Control scripts (`bin/appctl`)
- Installation and diagnostic scripts
- DMG build pipeline
- Licensing integration (Polar)

## Rationale

### Why Skills?

Building production-quality macOS apps involves hundreds of decisions and checklist items. Without systematic documentation:

1. **Knowledge gets lost** - Each project re-learns the same lessons
2. **Quality varies** - Different developers make different choices
3. **Shipping delays** - App Store rejections from missed requirements
4. **User complaints** - Crashes and bugs from incomplete testing

Skills encode this knowledge in a format that Claude Code can use consistently across projects.

### Why These Specific Skills?

**app-store-code-review** emerged from repeated App Store rejections and crash reports. Every checklist item represents a real bug or rejection we experienced.

**flutter-python-fullstack** emerged from building multiple apps with the same architecture. The patterns are battle-tested across production deployments.

### Design Principles

1. **Actionable checklists** - Not philosophy, but concrete items to verify
2. **Code examples** - Copy-paste ready patterns
3. **Common issues tables** - Quick fixes for frequent problems
4. **Red flags** - Immediate attention items
5. **Reference to real implementations** - Patterns from shipping apps

## Example: MimikaStudio

MimikaStudio is a local-first voice cloning and TTS application built using these skills.

![MimikaStudio Screenshot](images/mimikastudio-example.png)

**Key features demonstrated:**
- Flutter Material 3 UI with dark mode support
- Python FastAPI backend with multiple TTS engines
- About page with version, author (Qneura.ai), and credits
- DMG distribution with code signing
- Control scripts for easy development

## Installation

Copy the skills to your Claude Code skills directory:

```bash
# For Claude Code
cp -r skills/* ~/.claude/skills/
```

## Usage

Once installed, Claude Code will automatically suggest these skills when relevant:

- Starting a new macOS app project: `flutter-python-fullstack`
- Preparing for App Store submission: `app-store-code-review`
- Reviewing code quality before release: `app-store-code-review`

You can also invoke them directly:

```
/app-store-code-review
/flutter-python-fullstack
```

## Requirements

- Claude Code CLI
- Flutter SDK (for flutter-python-fullstack)
- Python 3.11+ (for flutter-python-fullstack)
- Xcode and macOS development tools

## Contributing

These skills are actively maintained. If you find issues or have improvements:

1. Fork this repository
2. Make your changes
3. Submit a pull request

## License

MIT License - See LICENSE file for details.

## Author

[Qneura.ai](https://qneura.ai) - Building intelligent applications for macOS.
