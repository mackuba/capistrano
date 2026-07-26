# frozen_string_literal: true

require "benchmark"
require "set"
require "shellwords"
require "yaml"
require "minestrone/recipes/deploy/scm"
require "minestrone/recipes/deploy/strategy"

# =========================================================================
# These variables MUST be set in the client capfiles. If they are not set,
# the deploy will fail with an error.
# =========================================================================

set_if_empty(:application) { abort "Please specify the name of your application, set :application, 'foo'" }
set_if_empty(:repository)  { abort "Please specify the repository that houses your application's code, set :repository, 'foo'" }

# =========================================================================
# These variables may be set in the client capfile if their default values
# are not sufficient.
# =========================================================================

set_if_empty(:scm) { scm_default }
set_if_empty :deploy_via, :remote_cache

set_if_empty(:deploy_to) { "/var/www/#{application}" }
set_if_empty(:revision)  { source.head }

set_if_empty :rack_env, "production"
set_if_empty :rake, "rake"

set_if_empty :keep_releases, 5

# =========================================================================
# These variables should NOT be changed unless you are very confident in
# what you are doing. Make sure you understand all the implications of your
# changes if you do decide to muck with these!
# =========================================================================

set_if_empty(:source)            { Minestrone::Deploy::SCM.new(scm, self) }
set_if_empty(:real_revision)     { source.local.query_revision(revision) { |cmd| with_env("LC_ALL", "C") { run_locally(cmd) } } }

set_if_empty(:strategy)          { Minestrone::Deploy::Strategy.new(deploy_via, self) }

# If overriding release name, please also select an appropriate setting for :releases below.
set_if_empty(:release_name)      { set :deploy_timestamped, true; Time.now.utc.strftime("%Y%m%d%H%M%S") }

set_if_empty :releases_dir,      "releases"
set_if_empty :shared_dir,        "shared"
set_if_empty :shared_children,   %w(public/system log tmp/pids)
set_if_empty :current_dir,       "current"

set_if_empty(:releases_path)     { File.join(deploy_to, releases_dir) }
set_if_empty(:shared_path)       { File.join(deploy_to, shared_dir) }
set_if_empty(:current_path)      { File.join(deploy_to, current_dir) }
set_if_empty(:release_path)      { File.join(releases_path, release_name) }

set_if_empty(:releases)          { capture("#{try_sudo} ls -x #{releases_path}").split.sort }
set_if_empty(:current_release)   { releases.length > 0 ? File.join(releases_path, releases.last) : nil }
set_if_empty(:previous_release)  { releases.length > 1 ? File.join(releases_path, releases[-2]) : nil }

set_if_empty(:current_revision)  { capture("#{try_sudo} cat #{current_path}/REVISION").chomp }
set_if_empty(:latest_revision)   { capture("#{try_sudo} cat #{current_release}/REVISION").chomp }
set_if_empty(:previous_revision) { capture("#{try_sudo} cat #{previous_release}/REVISION").chomp if previous_release }

set_if_empty(:run_method)        { fetch(:use_sudo, false) ? :sudo : :run }

# some tasks, like symlink, need to always point at the latest release, but
# they can also (occassionally) be called standalone. In the standalone case,
# the timestamped release_path will be inaccurate, since the directory won't
# actually exist. This variable lets tasks like symlink work either in the
# standalone case, or during deployment.
set_if_empty(:latest_release) { exists?(:deploy_timestamped) ? release_path : current_release }

# =========================================================================
# These are helper methods that will be available to your recipes.
# =========================================================================

# Checks known version control directories to set the version control in-use.
# If a .git directory exists in the project, it will set the :scm variable to
# :git. If no supported directory is found, it will default to :none.
def scm_default
  File.exist?('.git') ? :git : :none
end

# Auxiliary helper method for the `deploy:check' task. Lets you set up your own dependencies.
def depend(location, type, *args)
  deps = fetch(:dependencies, {})
  deps[location] ||= {}
  deps[location][type] ||= []
  deps[location][type] << args
  set :dependencies, deps
end

# Temporarily sets an environment variable, yields to a block, and restores the value when it is done.
def with_env(name, value)
  saved, ENV[name] = ENV[name], value
  yield
ensure
  ENV[name] = saved
end

def r_env
  if rails_env = fetch(:rails_env, nil)
    "RAILS_ENV=#{rails_env.to_s.shellescape}"
  else
    rack_env = fetch(:rack_env, "production")
    "RACK_ENV=#{rack_env.to_s.shellescape}"
  end
end

# Logs the command then executes it locally. Returns the command output as a string.
def run_locally(cmd)
  if dry_run
    return logger.debug "executing locally: #{cmd.inspect}"
  end

  logger.trace "executing locally: #{cmd.inspect}" if logger
  output_on_stdout = nil

  elapsed = Benchmark.realtime do
    output_on_stdout = `#{cmd}`
  end

  if $?.to_i > 0 # $? is command exit code (posix style)
    raise Minestrone::LocalArgumentError, "Command #{cmd} returned status code #{$?}"
  end

  logger.trace "command finished in #{(elapsed * 1000).round}ms" if logger
  output_on_stdout
end


# If a command is given, this will try to execute the given command, as
# described below. Otherwise, it will return a string for use in embedding in
# another command, for executing that command as described below.
#
# If :run_method is :sudo (or :use_sudo is true), this executes the given command
# via +sudo+. Otherwise is uses +run+. If :as is given as a key, it will be
# passed as the user to sudo as, if using sudo. If the :as key is not given,
# it will default to whatever the value of the :admin_runner variable is,
# which (by default) is unset.
#
# THUS, if you want to try to run something via sudo, and what to use the
# root user, you'd just to try_sudo('something'). If you wanted to try_sudo as
# someone else, you'd just do try_sudo('something', :as => "bob"). If you
# always wanted sudo to run as a particular user, you could do
# set(:admin_runner, "bob").

def try_sudo(*args)
  options = args.last.is_a?(Hash) ? args.pop : {}
  command = args.shift
  raise ArgumentError, "too many arguments" if args.any?

  as = options.fetch(:as, fetch(:admin_runner, nil))
  via = fetch(:run_method, :sudo)

  if command
    invoke_command(command, :via => via, :as => as)
  elsif via == :sudo
    sudo(:as => as)
  else
    ""
  end
end

# Same as sudo, but tries sudo with :as set to the value of the :runner variable (which defaults to "app").
def try_runner(*args)
  options = args.last.is_a?(Hash) ? args.pop : {}
  args << options.merge(:as => fetch(:runner, "app"))
  try_sudo(*args)
end

# =========================================================================
# These are the tasks that are available to help with deploying web apps,
# and specifically, Rails applications. You can have min give you a summary
# of them with `min -T'.
# =========================================================================

namespace :deploy do
  desc <<-DESC
    Deploys your project. This calls both `update' and `restart'.
  DESC

  task :default do
    update
    restart
    cleanup
  end

  desc <<-DESC
    Prepares the server for deployment. Before you can use any \
    of the Minestrone deployment tasks with your project, you will need to \
    make sure your server has been prepared with `min deploy:setup'. To \
    temporarily run setup against a different server, specify the SERVER \
    environment variable:

      $ min SERVER=new.server.com deploy:setup

    It is safe to run this task on a server that has already been set up; it \
    will not destroy any deployed revisions or data.
  DESC

  task :setup do
    dirs = [deploy_to, releases_path, shared_path]
    dirs += shared_children.map { |d| File.join(shared_path, d.split('/').last) }
    run "#{try_sudo} mkdir -p #{dirs.join(' ')}"
    run "#{try_sudo} chmod g+w #{dirs.join(' ')}" if fetch(:group_writable, true)
  end

  desc <<-DESC
    Copies your project and updates the symlink. It does this in a \
    transaction, so that if either `update_code' or `symlink' fail, all \
    changes made to the remote server will be rolled back, leaving your \
    system in the same state it was in before `update' was invoked. Usually, \
    you will want to call `deploy' instead of `update', but `update' can be \
    handy if you want to deploy, but not immediately restart your application.
  DESC

  task :update do
    transaction do
      update_code
      create_symlink
    end
  end

  desc <<-DESC
    Copies your project to the remote server. This is the first stage \
    of any deployment; moving your updated code and assets to the deployment \
    server. You will rarely call this task directly, however; instead, you \
    should call the `deploy' task (to do a complete deploy) or the `update' \
    task (if you want to perform the `restart' task separately).

    You will need to make sure you set the :scm variable to the source \
    control software you are using (it defaults to :git when a .git directory \
    is present, and :none otherwise), and the :deploy_via variable to the \
    strategy you want to use to deploy (it defaults to :remote_cache).
  DESC

  task :update_code do
    on_rollback { run "rm -rf #{release_path}; true" }
    strategy.deploy!
    finalize_update
  end

  desc <<-DESC
    [internal] Touches up the released code. This is called by update_code \
    after the basic deploy finishes. It assumes a Rails project was deployed, \
    so if you are deploying something else, you may want to override this \
    task with your own environment's requirements.

    This task will make the release group-writable (if the :group_writable \
    variable is set to true, which is the default) and will set up \
    symlinks to the shared directory for the log, system, and tmp/pids \
    directories.
  DESC

  task :finalize_update do
    escaped_release = latest_release.to_s.shellescape
    commands = []
    commands << "chmod -R -- g+w #{escaped_release}" if fetch(:group_writable, true)

    # mkdir -p is making sure that the directories are there for some SCM's that don't
    # save empty folders
    shared_children.map do |dir|
      d = dir.shellescape

      if (dir.rindex('/')) then
        commands += [
          "rm -rf -- #{escaped_release}/#{d}",
          "mkdir -p -- #{escaped_release}/#{dir.slice(0..(dir.rindex('/'))).shellescape}"
        ]
      else
        commands << "rm -rf -- #{escaped_release}/#{d}"
      end

      commands << "ln -s -- #{shared_path}/#{dir.split('/').last.shellescape} #{escaped_release}/#{d}"
    end

    run commands.join(' && ') if commands.any?
  end

  desc <<-DESC
    Updates the symlink to the most recently deployed version. Minestrone works \
    by putting each new release of your application in its own directory. When \
    you deploy a new version, this task's job is to update the `current' symlink \
    to point at the new version. You will rarely need to call this task \
    directly; instead, use the `deploy' task (which performs a complete \
    deploy, including `restart') or the 'update' task (which does everything \
    except `restart').
  DESC

  task :create_symlink do
    on_rollback do
      if previous_release
        run "#{try_sudo} rm -f #{current_path}; #{try_sudo} ln -s #{previous_release} #{current_path}; true"
      else
        logger.important "no previous release to rollback to, rollback of symlink skipped"
      end
    end

    run "#{try_sudo} rm -f #{current_path} && #{try_sudo} ln -s #{latest_release} #{current_path}"
  end

  desc <<-DESC
    Copy files to the currently deployed version. This is useful for updating \
    files piecemeal, such as when you need to quickly deploy only a single \
    file. Some files, such as updated templates, images, or stylesheets, \
    might not require a full deploy, and especially in emergency situations \
    it can be handy to just push the updates to production, quickly.

    To use this task, specify the files and directories you want to copy as a \
    comma-delimited list in the FILES environment variable. All directories \
    will be processed recursively, with all files being pushed to the \
    deployment server.

      $ min deploy:upload FILES=templates,controller.rb

    Dir globs are also supported:

      $ min deploy:upload FILES='config/apache/*.conf'
  DESC

  task :upload do
    files = (ENV["FILES"] || "").split(",").map { |f| Dir[f.strip] }.flatten
    abort "Please specify at least one file or directory to update (via the FILES environment variable)" if files.empty?

    files.each { |file| top.upload(file, File.join(current_path, file)) }
  end

  desc <<-DESC
    Blank task exists as a hook into which to install your own environment \
    specific behaviour.
  DESC

  task :restart do
    # Empty Task to overload with your platform specifics
  end

  namespace :rollback do
    desc <<-DESC
      [internal] Points the current symlink at the previous revision.
      This is called by the rollback sequence, and should rarely (if
      ever) need to be called directly.
    DESC

    task :revision do
      if previous_release
        run "#{try_sudo} rm #{current_path}; #{try_sudo} ln -s #{previous_release} #{current_path}"
      else
        abort "could not rollback the code because there is no prior release"
      end
    end

    desc <<-DESC
      [internal] Removes the most recently deployed release.
      This is called by the rollback sequence, and should rarely
      (if ever) need to be called directly.
    DESC

    task :cleanup do
      run "if [ `readlink #{current_path}` != #{current_release} ]; then #{try_sudo} rm -rf #{current_release}; fi"
    end

    desc <<-DESC
      Rolls back to the previously deployed version. The `current' symlink will \
      be updated to point at the previously deployed version, and then the \
      current release will be removed from the server. You'll generally want \
      to call `rollback' instead, as it performs a `restart' as well.
    DESC

    task :code do
      revision
      cleanup
    end

    desc <<-DESC
      Rolls back to a previous version and restarts. This is handy if you ever \
      discover that you've deployed a lemon; `min rollback' and you're right \
      back where you were, on the previously deployed version.
    DESC

    task :default do
      revision
      restart
      cleanup
    end
  end

  desc <<-DESC
    Run the migrate rake task. By default, it runs this in most recently \
    deployed version of the app. However, you can specify a different release \
    via the migrate_target variable, which must be one of :latest (for the \
    default behavior), or :current (for the release indicated by the \
    `current' symlink). Strings will work for those values instead of symbols, \
    too. You can also specify additional environment variables to pass to rake \
    via the migrate_env variable. Finally, you can specify the full path to the \
    rake executable by setting the rake variable. The defaults are:

      set :rake,           "rake"
      set :rack_env,       "production"
      set :migrate_env,    ""
      set :migrate_target, :latest
  DESC

  task :migrate do
    rake = fetch(:rake, "rake")
    migrate_env = fetch(:migrate_env, "")
    migrate_target = fetch(:migrate_target, :latest)

    directory = case migrate_target.to_sym
      when :current then current_path
      when :latest  then latest_release
      else raise ArgumentError, "unknown migration target #{migrate_target.inspect}"
    end

    run "cd #{directory} && #{r_env} #{migrate_env} #{rake} db:migrate"
  end

  desc <<-DESC
    Deploy and run pending migrations. This will work similarly to the \
    `deploy' task, but will also run any pending migrations (via the \
    `deploy:migrate' task) prior to updating the symlink. Note that the \
    update in this case it is not atomic, and transactions are not used, \
    because migrations are not guaranteed to be reversible.
  DESC

  task :migrations do
    set :migrate_target, :latest
    update_code
    migrate
    create_symlink
    restart
    cleanup
  end

  desc <<-DESC
    Clean up old releases. By default, the last 5 releases are kept on each \
    server (though you can change this with the keep_releases variable). All \
    other deployed revisions are removed from the server.
  DESC

  task :cleanup do
    if (count = fetch(:keep_releases)) && count != :all
      try_sudo "ls -1dt #{releases_path}/* | tail -n +#{count.to_i + 1} | #{try_sudo} xargs rm -rf"
    end
  end

  desc <<-DESC
    Test deployment dependencies. Checks things like directory permissions, \
    necessary utilities, and so forth, reporting on the things that appear to \
    be incorrect or missing. This is good for making sure a deploy has a \
    chance of working before you actually run `min deploy'.

    You can define your own dependencies, as well, using the `depend' method:

      depend :remote, :gem, "tzinfo", ">=0.3.3"
      depend :local, :command, "svn"
      depend :remote, :directory, "/u/depot/files"
  DESC

  task :check do
    dependencies = strategy.check!

    other = fetch(:dependencies, {})
    other.each do |location, types|
      types.each do |type, calls|
        if type == :gem
          dependencies.send(location).command(fetch(:gem_command, "gem")).or("`gem' command could not be found. Try setting :gem_command")
        end

        calls.each do |args|
          dependencies.send(location).send(type, *args)
        end
      end
    end

    if dependencies.pass?
      puts "You appear to have all necessary dependencies installed"
    else
      puts "The following dependencies failed. Please check them and try again:"

      dependencies.reject { |d| d.pass? }.each do |d|
        puts "--> #{d.message}"
      end

      abort
    end
  end

  namespace :pending do
    desc <<-DESC
      Displays the `diff' since your last deploy. This is useful if you want \
      to examine what changes are about to be deployed. Note that this might \
      not be supported on all SCM's.
    DESC

    task :diff do
      system(source.local.diff(current_revision))
    end

    desc <<-DESC
      Displays the commits since your last deploy. This is good for a summary \
      of the changes that have occurred since the last deploy. Note that this \
      might not be supported on all SCM's.
    DESC

    task :default do
      from = source.next_revision(current_revision)
      system(source.local.log(from))
    end
  end
end
