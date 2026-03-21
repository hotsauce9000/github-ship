# Changelog

All notable changes to this project will be documented in this file.
Format based on [Keep a Changelog](https://keepachangelog.com/).

## [1.0.0] - 2026-03-20

### Added
- Initial release as Claude Code plugin
- 12-step shipping workflow: environment check, pre-flight, gitignore audit, tests, UBS scan, diff review, version bump, changelog, README check, commit, tag, push, release
- Multi-language gitignore references (Python, Node, Rust, Go, Ruby, PHP, Java, general)
- Multi-language test runner detection (pytest, npm, cargo, go test, rspec, phpunit, gradle/maven)
- Semantic versioning reference guide
- Step 0 environment check — sets up git, remote, and verifies auth for first-time users
- SessionStart hook for automatic skill discovery
- Cross-platform support (Windows + Unix) via polyglot hook wrapper
- Installation support for Claude Code, Cursor, Codex, and Gemini CLI
- Star prompt at workflow completion
