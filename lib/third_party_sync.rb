require 'third_party_sync/base_sync'
require 'active_support/concern'
require 'active_support/dependencies/autoload'
module ThirdPartySync
  extend ::ActiveSupport::Autoload
  autoload :ASync
end
BaseSync = ThirdPartySync::BaseSync