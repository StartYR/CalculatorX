# CalculatorX Project Instructions

## Documentation

Read only the documentation relevant to the task.

- Source code changes: follow `docs/code-style.md`.
- Architecture, module boundaries, or major data-flow changes: read `docs/architecture.md` and the relevant document under `docs/architecture/`.
- EventHub, AppStorage, Preferences, RDB, or persistent state changes: read `docs/architecture/state-and-storage.md`.
- UI, calculator modules, keyboard, or shell changes: read `docs/architecture/modules-and-ui.md`.
- Commit, PR, and contribution workflow: follow `docs/CONTRIBUTING.md`.
- Branch change notes: follow `docs/changes/README.md`.

For new `.ets`, `.cpp`, `.c`, and `.h` files, use the complete file header required by `docs/code-style.md`.

Add comments where required by `docs/code-style.md`, especially for non-obvious algorithms, numeric or bit-level behavior, boundary conditions, compatibility workarounds, and important implementation constraints. Do not add comments that merely restate the code.

## Scope

Keep changes focused on the requested task.

Do not modify, reformat, rename, or refactor unrelated code. Reuse existing project patterns instead of introducing duplicate components, utilities, state mechanisms, or abstractions.

## Verification

Do NOT run builds by default.

Use the smallest relevant verification first, such as `git diff --check`, lint, static analysis, or targeted tests.

Run a build when the user explicitly asks, or when changes affect build configuration, dependencies, public APIs, N-API boundaries, routing, resources, or build output.

Report only checks and tests that were actually performed.