# OSX Skills for Claude Code

Production-ready skills for verifying and shipping macOS applications with Claude Code.

## Overview

This repository currently ships one release skill:

- `app-store-code-review`

The skill is an operational review standard for apps targeting Apple App Store, Google Play, or desktop distribution. It is not a lightweight lint pass. It is a release gate focused on real failure modes: crashes, resource leaks, security defects, legal inconsistencies, platform non-compliance, and missing operational tooling.

Primary source of truth: `skills/app-store-code-review/SKILL.md`

## Rationale

Shipping desktop apps fails most often at integration boundaries, not in isolated feature code. This skill exists to prevent:

- App Store rejection from missing manifests, entitlements, legal pages, or metadata
- Production incidents caused by lifecycle misuse (`setState` after dispose, leaked timers/subscriptions, force unwraps)
- Security regressions (weak input validation, permissive CORS, secrets in source)
- Distribution defects (unsigned/unnotarized DMGs, missing hashes, missing bundled license files)
- Cross-repo drift between app code, website legal text, and README license language
- AI-integration gaps where macOS apps ship without MCP parity and testable tool contracts

## When to Use the Skill

Use `app-store-code-review`:

- Before App Store or Play Store submission
- Before any production release
- After major feature milestones
- When a request includes words like `ship`, `release`, `production`, `App Store`
- For Flutter, Swift, Kotlin, React Native, and Python-backend app stacks

## Mandatory Workspace Layout

For macOS app projects in this workspace, the skill enforces:

- `artifacts/code/<AppName>PRJ/<AppName>CODE` for source code
- `artifacts/code/<AppName>PRJ/<AppName>WEB` for the static website

Legal/compliance review must cover three surfaces:

- README surface: `<AppName>CODE/README.md`
- Flutter app surface: `<AppName>CODE/flutter_app/`
- Website surface: `<AppName>WEB/index.html`, `license.html`, `privacy.html`, `terms.html`, `privacy-consent.js`

Do not use `artifacts/all-web` for these macOS app sites.

## Review Flow

The skill requires a full sequential pass across ten categories:

1. Crash Prevention
2. Resource Management
3. Network and API
4. Security
5. Data Persistence
6. Platform Compliance
7. Error Handling
8. MCP Integration (Required for macOS apps)
9. Performance
10. Product Information and Legal Completeness

No category is optional in a release review.

## Severity Model

- `Critical`: crash, data loss, or rejection risk; must fix before submission
- `High`: likely user-facing failure under normal use; should fix before submission
- `Medium`: edge-case degradation; schedule for near-term release
- `Low`: code quality and best-practice improvements

## Detailed Coverage

### 1) Crash Prevention

Checks include:

- Flutter lifecycle safety (`mounted` checks, controller/subscription/timer disposal)
- Null-safety and bounds-safe access patterns
- Swift optional safety and retain-cycle prevention (`weak self`)
- Kotlin lifecycle/nullability safety
- Backend exception boundaries and thread safety

The skill also enforces modern Flutter UI hygiene used in production patterns:

- Material 3 via `ColorScheme.fromSeed()`
- System dark mode support
- Startup backend health handling
- `withValues(alpha:)` instead of deprecated `withOpacity()`

### 2) Resource Management

Checks include:

- Memory leaks (listeners, media, background tasks, handles)
- File system safety (existence, permissions, path sanitization, disk space)
- Audio/video lifecycle cleanup
- Voice-clone memory profiling and regression checks for long pipelines

### 3) Network and API Resilience

Checks include:

- Explicit request timeouts and timeout-specific UX
- Graceful handling for 4xx/5xx/malformed/empty responses
- Retry/backoff and cancellation on screen exit
- Configurable endpoints and versioning

### 4) Security

Checks include:

- Input validation and path traversal prevention
- Secure token storage and session handling
- HTTPS and production CORS restrictions
- No sensitive logging and no hardcoded secrets
- At-rest protection for sensitive data

### 5) Data Persistence

Checks include:

- Migration strategy and corruption recovery
- Thread-safe database access
- Settings defaults and migration safety
- Cache limits, expiration, and corruption handling

### 6) Platform Compliance

Checks include:

- Apple: privacy manifest, ATS, entitlements, icon matrix, launch assets
- Google Play: target SDK, permissions, data safety, 64-bit, App Bundle
- macOS App Store: sandboxing, hardened runtime, notarization readiness
- macOS direct distribution: DMG structure, signing, notarization, hash output, version extraction, license file embedding

Project operations are also enforced:

- `bin/appctl` for lifecycle management
- `install.sh` for setup
- `issues.sh` for diagnostics

### 7) Error Handling

Checks include:

- Actionable user-facing error states and loading/empty states
- Structured logging with no sensitive payload leakage
- Recovery paths, retries, and state preservation

### 8) MCP Integration (Mandatory for macOS Apps)

The skill treats MCP as required app surface for Claude interoperability:

- Server script with JSON-RPC 2.0 support
- Required methods: `initialize`, `tools/list`, `tools/call`
- Typed tool definitions (`name`, `description`, `inputSchema`)
- Minimum tool families: health check, status/info, list resources, primary action
- HTTP API parity with MCP actions
- Tests for schema validity, dispatch, and protocol/error handling
- Configurable host/port/backend URL and rotating logs

### 9) Performance

Checks include:

- Startup latency and main-thread blocking avoidance
- UI frame stability and background processing
- Long-session memory stability
- Battery behavior and polling discipline

### 10) Product Information and Legal Completeness

Checks include:

- Centralized version/build surfaced in app UI
- About screen with legal links, credits, license summary, ownership footer
- Privacy/Terms/License pages accessible in app and website
- Support/contact, accessibility, onboarding, and settings completeness
- Branded icon assets with canonical source management
- App Store metadata completeness

## Mandatory Release Gates

Release is blocked when any of the following are missing or inconsistent:

1. Three-surface licensing is incomplete (website + app + repo)
2. README and website license language diverge
3. `privacy-consent.js` is missing or incomplete on required website pages
4. macOS MCP server/tools/tests are missing for app functionality
5. About screen mandatory sections are absent
6. Flutter icons are default/reused across apps without approval

## Cross-Repo License Consistency Rule

The skill defines a canonical sentence for README/license consistency checks:

```text
License: Source code is licensed under Business Source License 1.1 (BSL-1.1), and binary distributions are licensed under the [APP_NAME] Binary Distribution License. See LICENSE, BINARY-LICENSE.txt, and the website License page.
```

It also requires explicit binary-availability wording:

```text
The codebase is cross-platform, but we currently provide macOS binaries only.
```

## Website Privacy Consent Requirements

Each app website must provide Mimika-style GDPR consent behavior:

- Script file: `<AppName>WEB/privacy-consent.js`
- Loaded on `index.html`, `license.html`, `privacy.html`, `terms.html`
- Both `Accept` and `Reject` actions
- Decision persisted with app-specific `localStorage` keys
- Links to that app's `privacy.html` and `terms.html`
- Analytics/tracking initialized only after explicit accept

## Built-In Legal Templates

`app-store-code-review` includes practical templates for:

- Terms of Service
- Privacy Policy
- Business Source License 1.1
- Binary Distribution License
- License Overview page
- README License section

Use them as starter text and parameterize placeholders for each app release.

## Report Format Required by the Skill

The expected report structure is:

- Executive Summary with issue totals by severity
- Critical Issues
- High Issues
- Medium Issues
- Low Issues
- Positive Observations
- Prioritized Recommendations

Each finding should include file path, severity, issue description, and recommended fix.

## Red Flags (Immediate Attention)

The skill marks these as release-risk patterns:

- Hardcoded `localhost`/`127.0.0.1` where not intended
- Open CORS (`allow_origins=["*"]`) in production
- Bare `except:` / swallowed exceptions
- Missing network timeouts
- Async UI updates without lifecycle guards
- Missing privacy policy or legal pages
- Missing `LICENSE` and `BINARY-LICENSE.txt`
- Missing or non-functional GDPR popup on website pages
- Missing MCP server/tool schemas/tests for macOS apps
- Deprecated Flutter API usage (`withOpacity()`)
- Missing dark mode support

## Installation

Install skills into Claude Code:

```bash
cp -r skills/* ~/.claude/skills/
```

## Usage

```text
/app-store-code-review
```

Typical follow-up commands after a report:

1. Fix all Critical issues
2. Fix Critical + High issues
3. Generate a fix plan

## References

- Skill definition: `skills/app-store-code-review/SKILL.md`
- Repository license: `LICENSE`

## Author

[Qneura.ai](https://qneura.ai)
