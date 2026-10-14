# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow
[Semantic Versioning](https://semver.org/).

## [Unreleased]

## [0.3.0] - 2026-10-14

### Added

- `unbind()` cancels every binding on a view, and `unbindRecursively()` on a view and every view below it.
- DocC documentation catalog.

### Changed

- The control and gesture publishers must be subscribed to and cancelled on the main thread; doing either on another thread stops with a runtime error.

## [0.2.0] - 2026-10-01

### Added

- macOS support: the binding modifiers work on any `NSView`.
- AppKit publishers for controls, text fields, text views, scroll views and gestures.
- macOS example app.

## [0.1.0] - 2026-10-01

First release.

[Unreleased]: https://github.com/nothingsh/DeclarativeCombine/compare/0.3.0...HEAD
[0.3.0]: https://github.com/nothingsh/DeclarativeCombine/compare/0.2.0...0.3.0
[0.2.0]: https://github.com/nothingsh/DeclarativeCombine/compare/0.1.0...0.2.0
[0.1.0]: https://github.com/nothingsh/DeclarativeCombine/releases/tag/0.1.0
