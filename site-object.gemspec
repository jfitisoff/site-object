# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "site-object/version"

Gem::Specification.new do |s|
  s.name              = "site-object"
  s.version           = SiteObject::VERSION
  s.platform          = Gem::Platform::RUBY
  s.authors           = ["John Fitisoff"]
  s.email             = ["jfitisoff@yahoo.com"]
  s.homepage          = "https://github.com/jfitisoff/site-object"
  s.summary           = %q{Wraps page objects up into a site object, which provides some introspection and navigation capabilities that page objects don't provide. Works with Watir and Selenium.}
  s.description       = s.summary
  s.license           = 'MIT'
  s.rubyforge_project = "site-object"
  s.require_paths     = ["lib"]
  s.files             = [
    "lib/site-object.rb",
    "lib/site-object/exceptions.rb",
    "lib/site-object/element_container.rb",
    "lib/site-object/page.rb",
    "lib/site-object/page_feature.rb",
    "lib/site-object/site.rb",
    "lib/site-object/version.rb"
  ]
  s.required_ruby_version = '>= 1.9.3'
  s.add_runtime_dependency "activesupport"
  s.add_runtime_dependency "addressable"
end
