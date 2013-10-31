Gem::Specification.new do |spec|
  spec.name = "prosto_cache"
  spec.version = "0.2.2"

  spec.licenses = ["MIT"]
  spec.authors = ["Olek Poplavsky"]
  spec.email = "olek@woodenbits.com"

  spec.summary = "Very simple caching for your ActiveRecord models."
  spec.description = "Use this gem if you want a simple 'enum-like' cache for your models that does not restrict updates, but will stay current with them."
  spec.homepage = "http://github.com/olek/prosto_cache"

  spec.require_paths = ["lib"]

  require 'rake'
  spec.files = FileList['lib/**/*.rb', '[A-Z]*', 'spec/**/*', '.rspec'].to_a

  spec.test_files =
    spec.files.grep(%r{^spec/}) +
    spec.files.grep(%r{^app/})

  spec.required_ruby_version = ">= 1.9.3"
  spec.required_rubygems_version = ">= 1.3.6"

  spec.add_development_dependency(%q<rspec>, ["~> 2.13"])
  spec.add_development_dependency(%q<bundler>, ["~> 1.1"])
end
