# Minestrone 🍲

Minestrone is a simplified fork of old [Capistrano](https://github.com/minestrone/minestrone) 2.x. A kind of… mini-capistrano.


## Project description

Minestrone is a tool for deploying Ruby applications to a server, based on the code of the classic deploy tool Capistrano, the older 2.x version, but simplified and cleaned up, with various features removed that I decided I'm never going to need myself. The focus is on deploying Ruby apps to a single host from Git over SSH. It keeps the core deploy DSL with compatibility maintained where possible, the git remote cache and copy strategies, release rotation with rollbacks, and the logging/formatting code.


### What is removed

* server roles, multiple servers and "primary" server designation – you only define a single server hostname and everything happens there
* support for any parallel execution
* multiple stages
* SSH gateways
* password authentication for SSH and Git
* Windows support
* REPL shell
* legacy SCMs – only `:git` and `:none` are left
* most deploy strategies – only `:remote_cache` and `:copy` are left
* maintenance page tasks
* normalizing asset timestamps
* `deploy:cold`, `deploy:start` and `deploy:stop` tasks
* any legacy/deprecated code from Capistrano 1.x era or for ancient versions of Ruby or Rails


### Other API changes

* default deploy path is `/var/www/#{application}`
* `server` method in the DSL only accepts a single string + options
* `:use_sudo` is false by default
* `deploy:cleanup` runs automatically, with 5 last releases
* `deploy/bundler` recipe handles Bundler integration
* migration & asset tasks set a `RACK_ENV` instead of `RAILS_ENV` (which Rails also accepts), unless `:rails_env` is explicitly defined
* added `upload_file` as alias for `upload`
* Ruby 3.0+ is required


### Project status

> [!WARNING]
> This project is an early, untested alpha version. Most of the work stripping out various parts from the old codebase was done using Codex AI coding agent (with manual code reviews to some degree). Use with caution.
