# Testing (agents)

Ruby on Rails app; **RSpec** is the primary unit/integration test runner.

## Commands

| Goal | Command |
|------|---------|
| Full suite (matches main CI) | `bundle exec parallel_rspec` |
| One file / quick loop | `bundle exec rspec spec/path/to/foo_spec.rb` |
| Prepare DBs after clone or schema change | `RAILS_ENV=test bundle exec rake parallel:create parallel:load_schema` |

Rake tasks come from the **`parallel_tests`** gem (`require "parallel_tests/tasks"` in `Rakefile`).

## How parallel tests work

- `config/database.yml` **test** database name includes `<%= ENV["TEST_ENV_NUMBER"] %>` so each process uses `voice_assistant_test`, `voice_assistant_test2`, etc.
- **`config/environments/test.rb`** removes `DATABASE_URL` when `TEST_ENV_NUMBER` is set (parallel workers). Otherwise Rails would merge a single URL and every worker would hit the same DB.
- **Main CI** (`.github/workflows/ci.yml`) uses the GitHub Actions **Postgres service**, not Neon, so `parallel:create` can create sibling databases on that instance.
- **Preview / Neon** (`.github/workflows/preview.yml`) uses a **single** `DATABASE_URL` and **`bin/rails test`** — not `parallel_rspec`. Do not assume Neon CI jobs can run parallel RSpec without extra DB provisioning.

## Lint / security

- `bin/rubocop --parallel`
- `bin/brakeman --no-pager -q`

See `.github/workflows/ci.yml` for the exact CI steps.
