# encoding: utf-8

Gem::Specification.new do |s|
  s.name = "prosto_cache"
  s.version = "0.2.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Olek Poplavsky"]
  s.date = "2011-05-23"
  s.description = "Use this gem if you want a simple 'enum-like' cache for your models that does not restrict updates, but will stay current with them."
  s.email = "olek@woodenbits.com"
  s.extra_rdoc_files = [
    "LICENSE.txt",
    "README.rdoc"
  ]
  s.files = [
    ".rspec",
    "Gemfile",
    "Gemfile.lock",
    "LICENSE.txt",
    "README.rdoc",
    "Rakefile",
    "lib/prosto_cache.rb",
    "prosto_cache.gemspec",
    "spec/prosto_cache_spec.rb",
    "spec/spec_helper.rb",
  ]
  s.homepage = "http://github.com/olek/prosto_cache"
  s.licenses = ["MIT"]
  s.require_paths = ["lib"]
  s.rubygems_version = "1.8.11"
  s.summary = "Very simple caching for your ActiveRecord models."

  if s.respond_to? :specification_version then
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_development_dependency(%q<rspec>, ["~> 2.3"])
      s.add_development_dependency(%q<bundler>, ["~> 1.1"])
      s.add_development_dependency(%q<rake>)
    else
      s.add_dependency(%q<rspec>, ["~> 2.3"])
      s.add_dependency(%q<bundler>, ["~> 1.1"])
      s.add_dependency(%q<rake>)
    end
  else
    s.add_dependency(%q<rspec>, ["~> 2.3"])
    s.add_dependency(%q<bundler>, ["~> 1.1"])
    s.add_dependency(%q<rake>)
  end
end
