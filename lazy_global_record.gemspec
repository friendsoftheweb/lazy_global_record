$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "lazy_global_record/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "lazy_global_record"
  s.version     = LazyGlobalRecord::VERSION
  s.authors     = ["Friends of the Web"]
  s.email       = ["shout@friendsoftheweb.com"]
  s.homepage    = "https://github.com/friendsoftheweb/lazy_global_record"
  s.summary     = "Lazy loading of 'interesting' ActiveRecord model id's, thread-safely and with easy cache reset and lazy creation in testing"
  s.description = "TODO: Description of LazyGlobalRecord."
  s.license     = "MIT"

  s.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  s.test_files = Dir["test/**/*"]

  s.add_dependency "rails", ">= 4.0"
  s.add_dependency "concurrent-ruby", "~> 1.0"

  s.add_development_dependency "sqlite3"
end
