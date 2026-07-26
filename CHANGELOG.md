## [0.0.2] - 2026-07-26

- added `upload_file` as an alias for `upload` (which in deploy tasks is shadowed by the `deploy:upload` task)
- added `append` & `remove` for adding/removing to array variables (from Capistrano 3)
- renamed `_cset` to `set_if_empty` and make it a public API (also from Capistrano 3)
- in migration and assets tasks, use `RACK_ENV` instead of `RAILS_ENV`, unless `rails_env` is explicitly defined (Rails also accepts `RACK_ENV`, but Sinatra/Rack doesn't accept `RAILS_ENV`)
- `:use_sudo` is now disabled by default
- renamed `version_dir` to `releases_dir` for consistency
- removed `:maintenance_basename`, `:maintenance_template_path` and the maintenance page tasks `deploy:web:disable` / `deploy:web:enable`
- removed `deploy:cold`, `deploy:start` and `deploy:stop` tasks
- removed `:normalize_asset_timestamps` and `:public_children`


## Minestrone 0.0.1 - 2026-05-25

Changes from Capistrano 2.15.11:

Removed:

* server roles, multiple servers and "primary" server designation – you only define a single server hostname and everything happens there (`server` method in the DSL only accepts a single string + options, `role` is gone)
* support for any parallel execution
* multiple stages
* SCM handlers other than `:git` and `:none`
* most deploy strategies – only `:remote_cache` and `:copy` are left
* support for SSH gateways
* password authentication for SSH and Git
* REPL shell
* code supporting ancient versions of Ruby, Rails or Rake, or very old Capistrano API
* Windows support code

Changed:

* project name
* default deploy path is `/var/www/#{application}`
* `deploy:cleanup` now runs automatically, with 5 last releases
* bumped up minimum Ruby version to 3.0
* various refactoring and formatting changes

Added:

* `ENV['SERVER']` for overriding the host the tasks run on (`HOSTS` still works, but only accepts one hostname)
* set up CI on GitHub
* added `frozen_string_literal` directives everywhere
* added `benchmark` and `logger` to dependencies in gemspec
* added `deploy/bundler` recipe for Bundler integration


## Capistrano 2.15.11 - 2023-06-17

Previous changelog available [here](https://github.com/capistrano/capistrano/blob/v2.15.11/CHANGELOG).
