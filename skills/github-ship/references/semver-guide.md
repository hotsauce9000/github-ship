# Semantic Versioning Quick Reference

## Format: MAJOR.MINOR.PATCH

- **PATCH** (0.1.0 -> 0.1.1): Bug fixes, typo corrections, small tweaks. No new features. Nothing breaks.
- **MINOR** (0.1.1 -> 0.2.0): New features added. Existing features still work. Safe to upgrade.
- **MAJOR** (0.2.0 -> 1.0.0): Breaking changes. Existing behavior changed or removed. Users must adapt.

## Pre-1.0 Convention

While version is 0.x.y, the project is considered "initial development":
- Breaking changes can happen in MINOR bumps
- Use 0.1.0 as starting version for new projects
- Move to 1.0.0 when the project is stable and used in production

## Decision Tree for Version Bump

1. Did you remove or rename something that was working before? -> MAJOR
2. Did you add a new feature, script, or capability? -> MINOR
3. Did you fix a bug, update docs, or refactor without changing behavior? -> PATCH

## VERSION File

Store version as plain text in a `VERSION` file at project root:
```
0.1.0
```

No quotes, no prefix, no trailing newline needed. Just the version number.
