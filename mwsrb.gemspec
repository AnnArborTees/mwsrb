# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'mwsrb/version'

Gem::Specification.new do |spec|
  spec.name          = "mwsrb"
  spec.version       = Mwsrb::VERSION
  spec.authors       = ["Nigel Baillie"]
  spec.email         = ["devteam@annarbortees.com"]

  spec.summary       = %q{Amazon MWS Ruby Client}
  spec.description   = %q{Provides a reasonably one-to-one mapping to Amazon's MWS API: http://docs.developer.amazonservices.com/en_ES/dev_guide/DG_IfNew.html}
  spec.homepage      = "https://github.com/AnnArborTees/mwsrb"
  spec.license       = "MIT"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = "TODO: Set to 'http://mygemserver.com'"
  else
    raise "RubyGems 2.0 or newer is required to protect against " \
      "public gem pushes."
  end

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency 'multi_xml'
  spec.add_runtime_dependency 'httparty'
  spec.add_runtime_dependency 'activesupport', ">= 4.0"
  spec.add_runtime_dependency "ruby-hmac"

  spec.add_development_dependency "bundler", ">= 2.2.33"
  spec.add_development_dependency "rake", ">= 12.3.3"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "byebug"
end
