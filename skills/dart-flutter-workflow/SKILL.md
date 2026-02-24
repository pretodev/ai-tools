---
name: dart-flutter-workflow
description: >-
  Operational workflow for Dart and Flutter projects. Covers safe execution via
  LLMs, mandatory FVM usage when available, MCP tool preference, quality
  validation (analyzer, format, fix), before/after testing, hot reload/restart
  rules, and modern API enforcement. Use when implementing, reviewing, or
  validating changes in any Dart or Flutter project. Triggers on pubspec.yaml,
  .dart files, flutter/dart commands, or Flutter architecture discussions.
---

# Dart/Flutter Workflow

## Tool execution priority

When MCP Dart/Flutter tools are available, **always prefer them over shell commands**.
MCP tools provide structured output, better error reporting, and direct integration
with the running Flutter session.

| Task         | Prefer (MCP)   | Fallback (shell)        |
| ------------ | -------------- | ----------------------- |
| Analyze code | `dart_analyze` | `dart analyze`          |
| Format code  | `dart_format`  | `dart format .`         |
| Apply fixes  | `dart_fix`     | `dart fix --apply`      |
| Run tests    | `dart_test`    | `dart test`             |
| Add package  | `pub_add`      | `dart pub add <pkg>`    |
| Get packages | `pub_get`      | `dart pub get`          |
| Hot reload   | `hot_reload`   | — (no shell equivalent) |
| Hot restart  | `hot_restart`  | — (no shell equivalent) |

If an MCP tool call fails or is unavailable, fall back to the shell equivalent and
note the fallback in your response.

---

## Identify project type

1. Check `pubspec.yaml` for `flutter` SDK dependency, or look for `android/`, `ios/`,
   `web/`, or `lib/main.dart`.
2. Pure Dart projects (CLI, package, server) can be executed by the LLM directly.
3. **Never** run `flutter run` or `flutter build` — leave interactive execution to the user.

---

## Detect and apply FVM

1. Look for `.fvm/`, `.fvmrc`, or `fvm_config.json`.
2. If FVM exists, prefix **all** shell fallback commands with `fvm`:
   - `fvm flutter pub get`, `fvm dart analyze`, `fvm dart format .`
3. MCP tools that accept a `sdk` or `fvm` flag should use it when FVM is detected.
4. If FVM does not exist, use standard `dart`/`flutter` commands.

---

## Read the environment first

Before writing any code, read `pubspec.yaml` to determine:

- **Dart SDK constraint** (`environment.sdk`) — defines which language features and APIs are available.
- **Flutter SDK constraint** (if present) — defines which framework APIs are available.
- **Dependencies already in use** — avoid adding duplicates or conflicting packages.

Use the resolved SDK version as the source of truth for which APIs are current and
which are deprecated.

---

## Avoid deprecated APIs

Always prefer the modern replacement. When touching existing code that uses a
deprecated API, migrate it proactively.

| Deprecated                     | Modern replacement                          |
| ------------------------------ | ------------------------------------------- |
| `Color.withOpacity(x)`         | `Color.withValues(alpha: x)`                |
| `WillPopScope`                 | `PopScope`                                  |
| `MaterialStateProperty`        | `WidgetStateProperty`                       |
| `MaterialState` (and variants) | `WidgetState` (and variants)                |
| `OverlayEntry` (imperative)    | `OverlayPortal` + `OverlayPortalController` |

If `dart_analyze` or `dart analyze` surfaces additional deprecation warnings, fix
them using the same principle: check the deprecation message for the recommended
replacement.

---

## Prefer modern layout APIs

- **Spacing**: Use the `spacing` property on `Row`, `Column`, `Wrap`, `Flex`
  (Flutter 3.27+) or `padding`/`margin` instead of `SizedBox` for whitespace.
  Reserve `SizedBox` for explicit fixed-size constraints on a child.
- **Slivers**: Prefer `SliverMainAxisGroup` and `SliverCrossAxisGroup` over
  manual sliver composition.
- **Overlays**: Use `OverlayPortal` with `OverlayPortalController` for declarative
  overlay management. Avoid imperative `OverlayEntry` insertion/removal.

---

## Design system tokens via Theme Extensions

Design tokens (colors, spacing, typography, radii, etc.) must be accessed through
`ThemeExtension<T>` on the app's `ThemeData`, not hardcoded or accessed via global
constants.

```dart
// Access a custom token
final tokens = Theme.of(context).extension<AppTokens>()!;
```

When creating new components, always check whether relevant tokens already exist in
the project's theme extensions before introducing new values.

---

## Add packages

1. Prefer the `pub_add` MCP tool when available.
2. Shell fallback: `flutter pub add <pkg>` or `dart pub add <pkg>` — do not edit
   `pubspec.yaml` by hand.
3. Run `pub_get` (MCP) or `pub get` after adding packages.

---

## Run Dart commands

- Run binaries via the `dart_run` MCP tool when available, or `dart run <target>` in shell.
- For `build_runner`: `dart run build_runner build -d` (no MCP tool — use shell).

---

## Validate quality before concluding

Run this sequence on **every task** — do not skip steps:

1. `dart_fix` MCP tool (or `dart fix --apply`) — auto-fix what is possible.
2. `dart_format` MCP tool (or `dart format .`) — format all modified files.
3. `dart_analyze` MCP tool (or `dart analyze`) — catch remaining issues.
4. Fix any **errors and warnings introduced by your changes**. Do not conclude with new issues.

---

## Hot reload vs. hot restart

After applying changes, trigger the appropriate live-update tool to make the result
immediately visible. **Do not ask the user to reload manually** — always call the
tool as the last step of the workflow.

### Use `hot_reload` when

The change is limited to widget `build` methods, styling, layout, or other UI logic
that does not alter application state or the widget tree structure:

- Widget UI updates (colors, text, padding, layout)
- Business logic changes that do not affect static state
- Adding or updating stateless widget subtrees

```
→ Call: hot_reload
```

### Use `hot_restart` when

The change affects the app's initialization, state, or structure in a way that
requires a full restart to take effect:

| Scenario                                        | Reason                                  |
| ----------------------------------------------- | --------------------------------------- |
| Changes in `main()` or app entry point          | Re-runs initialization                  |
| Static variable additions or mutations          | State is reset on restart               |
| `InheritedWidget`, `Provider`, or DI changes    | Rebuilds the dependency graph           |
| `pubspec.yaml` changes (assets or packages)     | Assets/packages must be re-registered   |
| Enum additions or modifications                 | Const values are compiled at startup    |
| `StatelessWidget` ↔ `StatefulWidget` conversion | Changes the widget identity             |
| Constructor `const` additions or removals       | Affects widget canonicalization         |
| New or changed `initState` / `dispose` logic    | Lifecycle hooks require fresh instances |

```
→ Call: hot_restart
```

> **Rule of thumb**: if in doubt, prefer `hot_restart`. It is always safe; it just
> takes slightly longer than `hot_reload`.

---

## Testing strategy

1. If `test/` exists, run tests **before** starting to establish a baseline
   (`dart_test` MCP tool or `dart test`).
2. Run tests again **after** finishing.
3. Report which tests broke due to the change.
4. Offer to fix broken tests, but **wait for explicit user confirmation** before doing so.

---

## Final delivery

1. Provide a short, objective summary of what changed (behavior, not file list).
2. State which live-update action was triggered: `hot_reload` or `hot_restart`.
3. If there are test failures, include the failing test names.
4. If deprecated APIs were migrated, mention them briefly.
