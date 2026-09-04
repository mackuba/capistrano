# frozen_string_literal: true

require_relative 'lib/minestrone/version'

Gem::Specification.new do |spec|
  spec.name = "minestrone"
  spec.version = Minestrone::Version.to_s
  spec.platform = Gem::Platform::RUBY
  spec.authors = ["Jamis Buck", "Lee Hambley", "Kuba Suder"]

  spec.summary = "Simple deployment tool for Ruby apps (based on Capistrano)"
  spec.description = %(
    Minestrone is a simplified fork of old Capistrano from before the 3.0 rewrite. It retains most of the old, simpler API,
    while also removing some more advanced features, and focusing on the relatively simplest but common scenario of a single
    production server. It also removes a lot of old cruft, support for less commonly used or less recommended things,
    and modernizes some of the code.
  )

  spec.homepage = "https://github.com/mackuba/minestrone"
  spec.license = "MIT"

  spec.metadata = {
    "bug_tracker_uri"   => "https://github.com/mackuba/minestrone/issues",
    "changelog_uri"     => "https://github.com/mackuba/minestrone/blob/master/CHANGELOG.md",
    "source_code_uri"   => "https://github.com/mackuba/minestrone",
    "rubygems_mfa_required" => "true"
  }

  spec.files = `git ls-files`.split("\n")
  spec.executables = ['min', 'capify']
  spec.require_paths = ["lib"]
  spec.extra_rdoc_files = [
    "README.md"
  ]

  spec.required_ruby_version = ">= 3.0.0"

  spec.add_dependency 'benchmark', '~> 0.5'
  spec.add_dependency 'highline', '>= 0'
  spec.add_dependency 'net-ssh', '>= 7.2'
  spec.add_dependency 'net-sftp', '>= 3.0'
  spec.add_dependency 'net-scp', '>= 3.0'

  # used silently by net-ssh but undeclared
  spec.add_dependency 'logger'
end
