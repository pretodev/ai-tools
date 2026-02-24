---
name: dart-flutter-workflow
description: >-
  Operational workflow for Dart and Flutter projects. Covers safe execution via
  LLMs, mandatory FVM usage when available, quality validation (analyzer, format,
  fix), before/after testing, and modern API enforcement. Use when implementing,
  reviewing, or validating changes in any Dart or Flutter project. Triggers on
  pubspec.yaml, .dart files, flutter/dart commands, or Flutter architecture
  discussions.
---

# Dart/Flutter Workflow

## Identify project type

1. Check `pubspec.yaml` for `flutter` SDK dependency, or look for `android/`, `ios/`, `web/`, or `lib/main.dart`.
2. Pure Dart projects (CLI, package, server) can be executed by the LLM.
3. **Never** run `flutter run` or `flutter build` — leave interactive execution to the user.

## Detect and apply FVM

1. Look for `.fvm/`, `.fvmrc`, or `fvm_config.json`.
2. If FVM exists, prefix **all** commands with `fvm`:
   - `fvm flutter pub get`, `fvm dart analyze`, `fvm dart format .`
3. If FVM does not exist, use standard `dart`/`flutter` commands.

## Read the environment first

Before writing any code, read `pubspec.yaml` to determine:

- **Dart SDK constraint** (`environment.sdk`) — this defines which language features and APIs are available.
- **Flutter SDK constraint** (if present) — this defines which framework APIs are available.
- **Dependencies already in use** — avoid adding duplicates or conflicting packages.

Use the resolved SDK version as the source of truth for which APIs are current and which are deprecated.

## Avoid deprecated APIs

Always prefer the modern replacement. When touching existing code that uses a deprecated API, migrate it.

| Deprecated | Modern replacement |
|---|---|
| `Color.withOpacity(x)` | `Color.withValues(alpha: x)` |
| `WillPopScope` | `PopScope` |
| `MaterialStateProperty` | `WidgetStateProperty` |
| `MaterialState` (and variants) | `WidgetState` (and variants) |
| `OverlayEntry` (imperative) | `OverlayPortal` + `OverlayPortalController` |

If you encounter other deprecation warnings during `dart analyze`, fix them using the same principle: check the deprecation message for the recommended replacement.

## Prefer modern layout APIs

- **Spacing**: Use `spacing` property on `Row`, `Column`, `Wrap`, `Flex` (Flutter 3.27+) or `padding`/`margin` instead of `SizedBox` for whitespace. Use `SizedBox` only for explicit fixed-size constraints (e.g., constraining a child to a specific width/height).
- **Slivers**: When composing slivers, prefer `SliverMainAxisGroup` and `SliverCrossAxisGroup` over manual sliver composition.
- **Overlays**: Use `OverlayPortal` with `OverlayPortalController` for declarative overlay management. Avoid imperative `OverlayEntry` insertion/removal.

## Design system tokens via Theme Extensions

Design tokens (colors, spacing, typography, radii, etc.) must be accessed through `ThemeExtension<T>` on the app's `ThemeData`, not hardcoded or accessed via global constants.

```dart
// Access a custom token
final tokens = Theme.of(context).extension<AppTokens>()!;
```

When creating new components, always check whether relevant tokens already exist in the project's theme extensions before introducing new values.

## Add packages

1. Use `flutter pub add <pkg>` or `dart pub add <pkg>` — do not edit `pubspec.yaml` by hand.
2. Run `pub get` (with or without `fvm` prefix) after adding packages.

## Run Dart commands

- Run binaries via `dart run <target>` (or `fvm dart run <target>`).
- For `build_runner`: `dart run build_runner build -d`.

## Validate quality before concluding

Run this sequence on every task — do not skip steps:

1. `dart fix --apply` — auto-fix what is possible.
2. `dart format .` — format all modified files.
3. `dart analyze` — catch remaining issues.
4. Fix any **errors and warnings introduced by your changes**. Do not conclude with new issues.

## Testing strategy

1. If `test/` exists, run tests **before** starting to establish a baseline.
2. Run tests again **after** finishing.
3. Report which tests broke due to the change.
4. Offer to fix broken tests, but **wait for explicit user confirmation** before doing so.

## Final delivery

1. Provide a short, objective summary of what changed (behavior, not file list).
2. If there are test failures, include the failing test names.
3. If deprecated APIs were migrated, mention them briefly.
