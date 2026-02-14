# OSX Skills for Claude Code

Production-ready skills for verifying and shipping macOS applications with Claude Code.

## Overview

This repository currently ships one skill:

- `app-store-code-review`

It is a systematic release-review framework for apps targeting Apple App Store, Google Play, and desktop distribution. The skill is designed to catch crash risks, security defects, compliance gaps, licensing inconsistencies, and release blockers before shipping.

## Included Skill

### `app-store-code-review`

Use this skill when you are:

- Preparing App Store or Play Store submissions
- Preparing a production release
- Performing final release QA
- Reviewing Flutter, Swift, Kotlin, or Python backend stacks
- Validating macOS app + website + repo legal consistency

Primary source: `skills/app-store-code-review/SKILL.md`

## What This Skill Enforces

The skill requires a full pass across all categories below.

1. Crash Prevention
2. Resource Management
3. Network and API Resilience
4. Security
5. Data Persistence
6. Platform Compliance
7. Error Handling
8. MCP Tool Integration (macOS required)
9. Performance
10. Product Information and Legal Surfaces

It also applies release blockers for:

- Missing or inconsistent source/binary license surfaces
- Missing website GDPR consent popup (`privacy-consent.js`) on required pages
- Missing MCP server/tooling for macOS app functionality
- Missing About screen compliance sections
- Reused/default Flutter icons or branding asset mismatches

## Mandatory Repository Layout (Workspace Convention)

For macOS app projects reviewed with this skill:

- `artifacts/code/<AppName>PRJ/<AppName>CODE` - source repository
- `artifacts/code/<AppName>PRJ/<AppName>WEB` - app website repository

Required legal surfaces:

- README surface: `<AppName>CODE/README.md`
- Flutter app surface: `<AppName>CODE/flutter_app/`
- Website surface: `<AppName>WEB/index.html`, `license.html`, `privacy.html`, `terms.html`, `privacy-consent.js`

Do not place new app sites under `artifacts/all-web` for these macOS app projects.

## Severity Model

- `Critical`: crash/data-loss/rejection risk; must fix before submission
- `High`: likely user impact; should fix before submission
- `Medium`: edge-case degradation; fix next release
- `Low`: quality/best-practice improvements

## Review Output Format

The skill expects reports in this structure:

- Executive Summary with issue totals and release recommendation
- Critical Issues (must fix)
- High Issues
- Medium Issues
- Low Issues
- Positive Observations
- Prioritized Recommendations

## Key Release Gates Captured in the Skill

### 1. License and Cross-Repo Consistency

The skill requires source and binary licensing to be explicit and consistent across:

- Repo files (`LICENSE`, `BINARY-LICENSE.txt`, overview doc)
- App UI legal screens
- Website legal pages
- README license references

It also enforces a canonical README licensing sentence pattern and a clear binary-availability statement.

### 2. Website Privacy Consent Popup

Every app site must implement Mimika-style consent behavior:

- `Accept` and `Reject` actions
- Decision persisted in `localStorage`
- Links to the app's own `privacy.html` and `terms.html`
- Tracking/analytics only after explicit acceptance
- Loaded on `index.html`, `license.html`, `privacy.html`, and `terms.html`

### 3. MCP Integration for macOS Apps

macOS apps are expected to expose functionality through MCP tools with:

- JSON-RPC methods (`initialize`, `tools/list`, `tools/call`)
- Valid tool schemas (`name`, `description`, `inputSchema`)
- HTTP API parity for all tool actions
- Logging, configurability, and tests

### 4. Product and Legal Completeness

The skill checks for:

- Version/build visibility
- About screen standards
- Privacy, Terms, and License accessibility
- Support/contact and accessibility readiness
- Store metadata completeness

### 5. Branding and Icon Compliance

The skill rejects release when apps reuse default Flutter icons or duplicate icon hashes across different apps without explicit approval.

## Built-In Templates in the Skill

`app-store-code-review` includes reusable templates for:

- Terms of Service
- Privacy Policy
- Business Source License 1.1
- Binary Distribution License
- License Overview page
- README License section

These templates are defined directly in `skills/app-store-code-review/SKILL.md`.

## Installation

Install into Claude Code skills directory:

```bash
cp -r skills/* ~/.claude/skills/
```

## Usage

Invoke directly in Claude Code:

```text
/app-store-code-review
```

Typical post-review follow-ups:

1. Fix all Critical issues
2. Fix Critical + High issues
3. Generate a fix plan

## References

- Skill definition: `skills/app-store-code-review/SKILL.md`
- License: `LICENSE`

## Author

[Qneura.ai](https://qneura.ai)
