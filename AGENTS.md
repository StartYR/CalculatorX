# CalculatorX Project Instructions

## Verification

Do NOT run builds by default. Skip build/typecheck for trivial edits (text, comments, styles, font-size, colors, spacing, docs, test names). Verify with lint, single-file checks, or relevant tests instead.

Only build when: the user explicitly asks, or you changed build config, dependencies, public API, routing, global styles, or anything affecting build output.

## Documentation & i18n

- The project maintains bilingual documentation (`docs/zh-CN/` and `docs/en/`).
- **Canonical Source of Truth**: `docs/zh-CN/` is the primary and authoritative documentation. When researching codebase architecture, development guides, or technical details, always prioritize and read files under `docs/zh-CN/`.
- **Avoid Context Duplication**: Do not read counterpart documents under `docs/en/` unless specifically tasked with translating, proofreading, or explicitly requested by the user.
