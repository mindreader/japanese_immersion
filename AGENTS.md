# Elixir Phoenix Project Guidelines

## Build, Lint, and Test

- **Build & Deps:** `mix setup`
- **Run All Tests:** `mix test`
- **Run Single Test File:** `mix test path/to/file_test.exs`
- **Run Single Test:** `mix test path/to/file_test.exs:line_number`
- **Format Code:** `mix format`
- **Lint Code:** `mix credo` (assuming credo is a dependency, which is standard)
- **Type Checking:** `mix dialyzer`

## Code Style

- **Formatting:** Adhere to `.formatter.exs`. Run `mix format` before committing.
- **Imports:** Group `alias` and `import` statements. Keep them alphabetized.
- **Types:** Use `@spec` to define typespecs for all public functions.
- **Naming:**
    - Modules: `PascalCase` (e.g., `Japanese.Corpus.Page`)
    - Functions & Variables: `snake_case` (e.g., `list_pages`)
    - Test files end with `_test.exs`.
- **Error Handling:** Return `{:ok, value}` for success and `{:error, reason}` for failures.
- **Pattern Matching:** Use pattern matching in function heads and case statements for clarity.
- **Pipelines:** Use the `|>` operator to chain functions and improve readability.
