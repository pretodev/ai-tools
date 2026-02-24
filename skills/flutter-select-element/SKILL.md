---
name: dart-context-action
description: >-
  Performs context-aware actions on any Dart or Flutter element at the current
  cursor position: refactoring, bug fixes, improvements, documentation, and
  code generation. Use this skill whenever the user asks to refactor, fix,
  improve, explain, or document a specific widget, class, method, variable, or
  any symbol in a Dart/Flutter file — especially phrases like "fix this",
  "refactor this widget", "document this method", "what does this do",
  "improve this code", or "explain this parameter". Always triggers when the
  request implies acting on something the developer is currently looking at in
  the editor.
---

# Dart Context Action

Performs context-aware actions on the element at the current cursor position
by combining hover introspection, live widget inspection, and signature
analysis — then executing the action the user requested.

---

## Parameters

| Parameter  | Source                       | Required | Description                                                                                                    |
| ---------- | ---------------------------- | -------- | -------------------------------------------------------------------------------------------------------------- |
| `action`   | User message                 | ✅       | What to do: `refactor`, `fix`, `improve`, `document`, `explain`, `generate_test`, or any free-form instruction |
| `file_uri` | `get_active_location` result | auto     | Absolute URI of the file under the cursor                                                                      |
| `line`     | `get_active_location` result | auto     | 0-based line number of the cursor                                                                              |
| `column`   | `get_active_location` result | auto     | 0-based column number of the cursor                                                                            |

`file_uri`, `line`, and `column` are **resolved automatically** in step 1 —
never ask the user to provide them.

---

## Workflow

### Step 1 — Resolve cursor location

Call `get_active_location` to obtain the current file URI, line, and column.
This is the anchor for all subsequent tool calls.

```
tool: get_active_location
→ { uri, line, column }
```

If the tool returns no active location (e.g., no file is open), stop and ask
the user to place the cursor on the element they want to act on.

---

### Step 2 — Gather element context

Run the following tools **in parallel** using the coordinates from step 1:

**`hover`** — primary source of truth for the element:

```
tool: hover
input: { uri, line, column }
→ documentation, type, deprecation notice, declared location
```

**`get_selected_widget`** — supplemental; only available when a Flutter app
is running in debug mode:

```
tool: get_selected_widget
→ live widget type, properties, and state
```

If `get_selected_widget` is unavailable or returns nothing, continue with
hover data alone — do not block the workflow.

---

### Step 3 — Deepen understanding when needed

Use `signature_help` and `resolve_workspace_symbol` selectively to fill gaps:

- **`signature_help`**: Call when the cursor is inside a function/constructor
  call and you need parameter names, types, and documentation for each
  argument.

  ```
  tool: signature_help
  input: { uri, line, column }
  → active parameter, overloads, docs per parameter
  ```

- **`resolve_workspace_symbol`**: Call when you need to confirm a symbol
  exists elsewhere in the workspace, find its declaration, or check for
  spelling variants.
  ```
  tool: resolve_workspace_symbol
  input: { symbol_name }
  → element kind, declared URI, documentation
  ```

Only invoke these tools when the information from steps 1–2 is insufficient
to confidently execute the requested action.

---

### Step 4 — Analyse the element

Before writing any code, synthesise everything collected:

- **Element identity**: name, kind (class / method / widget / variable / enum
  value / etc.), declared package and file.
- **Type signature**: full type, generic parameters, return type if applicable.
- **Documentation**: summary, parameters, return value, edge cases.
- **Live state** (if `get_selected_widget` succeeded): current property values,
  active constraints, scroll position, etc.
- **Issues and opportunities**: deprecations flagged by hover, mismatches
  between declared type and usage, missing null checks, or patterns that could
  be simplified.

This analysis informs the action but is **not** shown verbatim to the user
unless `action` is `explain`.

---

### Step 5 — Execute the requested action

Apply the action determined by the user's `action` parameter:

| `action`        | Behaviour                                                                                                                                     |
| --------------- | --------------------------------------------------------------------------------------------------------------------------------------------- |
| `refactor`      | Restructure code for clarity, maintainability, or idiomatic Dart/Flutter style. Preserve observable behaviour.                                |
| `fix`           | Correct the bug, deprecation, type error, or logic issue identified in the analysis.                                                          |
| `improve`       | Enhance performance, readability, or widget efficiency without changing semantics.                                                            |
| `document`      | Add or improve DartDoc comments covering purpose, parameters, return value, and notable edge cases.                                           |
| `explain`       | Return a clear, concise explanation of what the element does, its type, its parameters, and its role in the codebase. Do not modify any file. |
| `generate_test` | Scaffold a unit or widget test for the element using the project's existing test conventions.                                                 |
| _(free-form)_   | Interpret the instruction and act accordingly, applying the analysis from step 4 as context.                                                  |

Follow all rules from `dart-flutter-workflow` (modern APIs, no deprecated
usage, `dart_fix` → `dart_format` → `analyze_files` before concluding).

---

### Step 6 — Validate quality

After applying any code change (skip for `explain`):

1. `dart_fix` — auto-fix remaining lint issues.
2. `dart_format` — normalise formatting.
3. `analyze_files` — confirm zero new errors or warnings.

Fix any issues introduced. Do not deliver output that adds new diagnostics.

---

### Step 7 — Trigger live update

After a successful code change, trigger the appropriate update so the result
is immediately visible. Do not ask the user to reload manually.

| Condition                                                                 | Tool          |
| ------------------------------------------------------------------------- | ------------- |
| UI-only change (widget build, style, layout)                              | `hot_reload`  |
| Structural change (constructor, static, enum, DI, `main`, `pubspec.yaml`) | `hot_restart` |
| `explain` action (no code changed)                                        | _(skip)_      |

When in doubt, prefer `hot_restart` — it is always safe.

---

### Step 8 — Deliver the result

Respond with a concise, structured summary:

1. **Element**: name and kind (e.g., `MyWidget` — StatefulWidget).
2. **Action taken**: one sentence describing what was changed and why.
3. **Live update**: which tool was called (`hot_reload` / `hot_restart` / none).
4. **Remaining issues**: list only if `analyze_files` surfaces pre-existing
   warnings unrelated to the change — do not hide them, but make clear they
   are not introduced by this action.

For `explain`, return the analysis from step 4 formatted for the user.

---

## Error handling

| Situation                                                 | Response                                                                                                                                     |
| --------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------- |
| `get_active_location` returns nothing                     | Ask user to place cursor on the target element and retry.                                                                                    |
| `hover` returns no data                                   | Inform the user the element has no hover info (e.g., plain text, comment), then ask for the target file and symbol name to proceed manually. |
| `analyze_files` reports new errors after the change       | Fix before delivering. If not fixable, revert the change, explain why, and ask for guidance.                                                 |
| `hot_reload` / `hot_restart` unavailable (no running app) | Skip live update silently and note in the summary that the app is not running.                                                               |
