# frozen_string_literal: true

# Based on:
# https://github.com/ruby/rubygems/blob/master/bundler/lib/bundler/minestrone.rb
# and https://github.com/minestrone/bundler

load 'deploy' unless defined?(try_sudo)

set_if_empty :bundle_env, ''
set_if_empty :bundle_cmd, 'bundle'
set_if_empty(:bundle_path) { "#{shared_path}/bundle" }
set_if_empty :bundle_without, [:development, :test]
set_if_empty :bundle_flags, '--quiet'

set(:rake) { "#{bundle_cmd} exec rake" }

before "deploy:finalize_update", "bundle:install"
before "bundle:install", "bundle:config"

namespace :bundle do
  desc <<-DESC
    Sets up the Bundler configuration appropriate for a production environment.
    You can customize the settings using the following variables:

      set :bundle_cmd,     'bundle'   # e.g. '/usr/local/bin/bundle
      set(:bundle_path)    { shared_path + "/bundle" }
      set :bundle_without, [:development, :test]
  DESC

  task :config do    
    bundle_cmd = fetch(:bundle_cmd)
    bundle_path = fetch(:bundle_path)

    without = fetch(:bundle_without)
    without = [without] unless without.is_a?(Array)

    settings = [
      ['deployment', 'true'],
      ['path', bundle_path],
      ['without', without.map(&:to_s).join(' ')],
    ]

    settings.each do |key, value|
      run "cd #{release_path} && #{bundle_cmd} config set --local #{key} '#{value}'"
    end
  end

  desc <<-DESC
    Installs the gems required by the app. By default, gems are installed to
    \"\#{shared_path}/bundle\", with :development and :test groups skipped.

    You can customize the settings using the following variables:

      set :bundle_env,     ''         # e.g. 'SOME_LIBRARY_PATH=/usr/local' 
      set :bundle_cmd,     'bundle'   # e.g. '/usr/local/bin/bundle
      set(:bundle_path)    { shared_path + "/bundle" }
      set :bundle_without, [:development, :test]
      set :bundle_flags,   '--quiet'
  DESC

  task :install do
    bundle_env = fetch(:bundle_env)
    bundle_cmd = fetch(:bundle_cmd)
    bundle_flags = fetch(:bundle_flags)

    bundle_env += " " unless bundle_env.to_s.empty?

    run "cd #{release_path} && #{bundle_env}#{bundle_cmd} install #{bundle_flags}"
  end

  desc <<-DESC
    Cleans up older versions of gems in the shared bundle folder. This removes all
    gems that aren't currently referenced by the Gemfile.lock.
  DESC

  task :clean do
    bundle_cmd = fetch(:bundle_cmd, "bundle")

    run "cd #{current_path} && #{bundle_cmd} clean"
  end
end
