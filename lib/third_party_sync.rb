require 'third_party_sync/base_sync'
require 'active_support/concern'
require 'active_support/dependencies/autoload'
module ThirdPartySync
  require 'redis/namespace'
  def redis
    @redis ||= Redis::Namespace.new("third_party_sync",redis: Redis.current || Redis.new('redis://localhost:6379/0'))
  end

  module_function :redis
end
BaseSync = ThirdPartySync::BaseSync