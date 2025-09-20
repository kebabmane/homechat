# Repository Guidelines

## Project Structure & Module Organization
- App code lives in `app/` with Rails MVC layout: `controllers/`, `models/`, `views/`, plus assets in `app/assets/` and JS controllers under `app/javascript/controllers/`.
- Configuration files are in `config/`; update `config/routes.rb` for new endpoints and use encrypted credentials in `config/credentials.yml.enc`.
- Database schema and migrations reside in `db/`; run migrations through Rails tasks rather than editing `schema.rb` manually.
- Executables live in `bin/`; start local workflows with `bin/dev` and automate setup via `bin/setup`.

## Build, Test, and Development Commands
- `bin/setup` — Install gems, prepare the database, and optionally launch the dev server.
- `bin/dev` — Run the Rails server with Tailwind watcher via Foreman (see `Procfile.dev`).
- `bin/rails db:prepare` — Create, migrate, and seed the database when schemas change.
- `bin/rubocop` and `bundle exec erblint --lint-all` — Lint Ruby and ERB templates before pushing.
- `bin/brakeman` — Perform static security scans when touching sensitive logic.

## Coding Style & Naming Conventions
- Ruby code uses 2-space indentation and UTF-8 encoding; follow Rails conventions for callbacks and validations.
- Name classes with CamelCase and files with snake_case (e.g., `Channel`, `channel.rb`).
- Keep complex view logic out of ERB; move to helpers or presenters in `app/helpers/`.
- Rely on `rubocop-rails-omakase`; auto-correct with `bin/rubocop -A` when safe.

## Testing Guidelines
- Use Rails Minitest under `test/`; match filenames to the class under test (`channel_test.rb`).
- Keep fixtures consistent and deterministic; avoid external API calls in tests.
- Run suites with `bin/rails test` or narrow paths like `bin/rails test test/models` before opening a PR.

## Commit & Pull Request Guidelines
- Follow Conventional Commits (`feat:`, `fix:`, `chore:`) with imperative summaries and minimal scope.
- PRs include motivation, screenshots for UI tweaks, linked issues, and note migrations or config changes.
- Ensure lint (`bin/rubocop`, ERB lint) and tests pass locally; share failure context if something cannot be run.

## Security & Configuration Tips
- Do not commit secrets; manage service keys via Rails credentials or Kamal secrets.
- Review `config/storage.yml` and environment configs before enabling third-party services.
- Treat migrations and seeds as production-affecting changes; call them out explicitly in PRs.
