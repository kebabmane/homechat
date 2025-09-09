# Repository Guidelines

## Project Structure & Module Organization
- App code lives in `app/`:
  - `controllers/` (e.g., `channels_controller.rb`), `models/` (e.g., `channel.rb`), `views/` (e.g., `views/channels/index.html.erb`).
  - Frontend assets in `app/assets/` and JS controllers in `app/javascript/controllers/`.
- Configuration in `config/` (routes in `config/routes.rb`, credentials in `config/credentials.yml.enc`).
- Database schema and migrations in `db/` (SQLite by default).
- Executables in `bin/` (e.g., `bin/dev`, `bin/rails`, `bin/setup`).
- Static files in `public/`; background and storage in `storage/`, temp in `tmp/`.

## Build, Test, and Development Commands
- `bin/setup` — Install gems, prepare DB, and boot dev server unless `--skip-server`.
- `bin/dev` — Run app locally via Foreman (Rails server + Tailwind watcher; see `Procfile.dev`).
- `bin/rails db:prepare` — Create, migrate, and seed DB as needed.
- `bin/rubocop` — Ruby/Rails lint (uses `rubocop-rails-omakase`).
- `bundle exec erblint --lint-all` — Lint ERB templates.
- `bin/brakeman` — Static security scan.
- Docker: `docker-compose up --build` for containerized dev; deploy via Kamal (`bin/kamal ...`).

## Coding Style & Naming Conventions
- Ruby: 2-space indentation, UTF-8, freeze magic not required.
- Names: classes `CamelCase` (`Channel`), files `snake_case.rb` (`channels_controller.rb`), partials start with `_` (`_form.html.erb`).
- Controllers are RESTful; routes use `resources` (see `config/routes.rb`).
- Keep views dumb; move logic to helpers or presenters.
- Run `bin/rubocop` and ERB lint before PRs; auto-correct with `bin/rubocop -A` where safe.

## Testing Guidelines
- Preferred: Rails’ built-in Minitest. Place tests under `test/` with `*_test.rb` (e.g., `test/models/channel_test.rb`).
- Use fixtures or factories consistently; keep tests deterministic.
- Run all tests with `bin/rails test` (or narrower paths like `bin/rails test test/models`).

## Commit & Pull Request Guidelines
- Commits: use Conventional Commits style — `feat:`, `fix:`, `chore:`, `docs:`, `refactor:`; keep scope small and messages imperative.
- PRs: include summary, motivation, screenshots for UI, and linked issues. Note migrations and any config changes.
- CI hygiene: lint and tests must pass locally (`bin/rubocop`, ERB lint, `bin/rails test`) before requesting review.

## Security & Configuration Tips
- Do not commit secrets. Use Rails credentials (`config/credentials.yml.enc` + `config/master.key`) and Kamal `.kamal/secrets` for deployments.
- Review `config/storage.yml` and `config/environments/*` before enabling third‑party services.
