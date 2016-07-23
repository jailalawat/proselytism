# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'proselytism/version'

Gem::Specification.new do |gem|
  gem.name          = "proselytism"
  gem.version       = Proselytism::VERSION
  gem.authors       = ["Itkin"]
  gem.email         = ["nicolas.papon@webflows.fr"]
  gem.description   = %q{document converter and plain text extractor}
  gem.summary       = %q{document converter and plain text extractor}
  gem.homepage      = "https://github.com/itkin/proselytism.git"

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]

  gem.add_dependency "activesupport", "~> 4.2.6"
  gem.add_development_dependency "rspec"
  gem.add_development_dependency "pry"

end
