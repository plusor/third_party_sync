require File.expand_path('../lib/third_party_sync/version',__FILE__)

Gem::Specification.new do |gem|
  gem.authors               = "ZhouBin"
  gem.email                 = 'zhoubin@networking.io'
  gem.description           = '同步第三方API数据'
  gem.summary               = '同步第三方API数据'
  gem.homepage              = 'https://github.com/intridea/hashie'
  gem.files                 = `git ls-files`.split("\n")
  gem.test_files            = `git ls-files -- {test,spec,features}/*`.split("\n")
  gem.name                  = "third_party_sync"
  gem.require_paths         = ['lib']
  gem.version               = ThirdPartySync::VERSION
  gem.license               = "MIT"
  gem.add_development_dependency 'rake', '~> 0.9.2'
  gem.add_development_dependency 'rspec', '~> 2.5'
  gem.add_development_dependency 'guard'
  gem.add_development_dependency 'guard-rspec'
  gem.add_development_dependency 'growl'
  gem.add_development_dependency 'debugger'
  gem.add_development_dependency 'active_support'
end