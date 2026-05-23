# Repository Guidelines

## Project Structure & Module Organization
- App code lives in `app/` with Rails MVC layout: `controllers/`, `models/`, `views/`, plus assets in `app/assets/` and JS controllers under `app/javascript/controllers/`.
- Configuration files are in `config/`; update `config/routes.rb` for new endpoints and use encrypted credentials in `config/credentials.yml.enc`.
- Database schema and migrations reside in `db/`; run migrations through Rails tasks rather than editing `schema.rb` manually.
- Executables live in `bin/`; start local workflows with `bin/dev` and automate setup via `bin/setup`.

## Build, Test, and Development Commands
- `bin/setup` — Install gems, prepare the database, and optionally launch the dev server.
- `bin/dev` — Run the Rails server with Tailwind watcher via Foreman (see `Procfile.dev`).
- `bin/docker-dev` — Run the entire dev environment inside Docker (no local Ruby needed). See [Docker Development](#docker-development) below.
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

## Technology Stack & Minimum Versions
- **Ruby:** 4.0.1+ (defined in `.ruby-version` and `Gemfile`)
- **Rails:** 8.1.3+ (defined in `Gemfile`)
- **Puma:** 8.x (web server)
- **Database:** SQLite 3
- **Node.js:** Not required (uses Importmap + Propshaft, no JS bundler)

### Ruby Version Manager Setup
This project uses **rbenv** with Ruby 4.0.1. Ensure your shell profile initializes rbenv:

```bash
eval "$(rbenv init - zsh)"
```

This must run **before** RVM in your `.zshrc` so rbenv's shims take precedence in PATH. With rbenv active, `cd` into the project and the `.ruby-version` file auto-switches to 4.0.1:

```bash
cd /Users/rhysevans/Projects/homeChat/homechat
ruby -v   # should print 4.0.1
```

If RVM is also loaded and causes conflicts, unset its environment variables:

```bash
unset GEM_HOME GEM_PATH
eval "$(rbenv init -)"
```

Update `.ruby-version`, `Gemfile`, `Dockerfile`, `Dockerfile.dev`, `config/deploy.yml`, and CI workflows together when bumping Ruby or Rails.

## Docker Development
The project includes a containerized dev environment so you never need to manage local Ruby versions. The SQLite database at `storage/development.sqlite3` is persisted on the host via a volume mount, so it survives container rebuilds.

### Docker Dev Commands
- `bin/docker-dev setup` — Build the image and prepare the database (run once).
- `bin/docker-dev up` — Start the Rails server with Tailwind watcher on [http://localhost:3000](http://localhost:3000).
- `bin/docker-dev build` — Rebuild the image after `Dockerfile` or `Gemfile` changes.
- `bin/docker-dev bash` — Drop into a shell inside the running container.
- `bin/docker-dev down` — Stop and remove containers.
- `bin/docker-dev logs` — Tail container logs.
- `bin/docker-dev exec <command>` — Run a one-off command (e.g., `bin/docker-dev exec bin/rails console`).
- `bin/docker-dev test` — Run the full test suite inside the container.

### Manual Docker Compose (without the wrapper)
If you prefer raw commands:
```bash
docker compose -f docker-compose.yml build
docker compose -f docker-compose.yml run --rm web ./bin/rails db:prepare
docker compose -f docker-compose.yml up
```

## Security & Configuration Tips
- Do not commit secrets; manage service keys via Rails credentials or Kamal secrets.
- Review `config/storage.yml` and environment configs before enabling third-party services.
- Treat migrations and seeds as production-affecting changes; call them out explicitly in PRs.
- Run `bin/brakeman` before pushing; address or document any new warnings in `config/brakeman.ignore`.
