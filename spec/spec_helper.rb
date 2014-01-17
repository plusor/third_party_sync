$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

require 'third_party_sync'
require 'rspec'
require 'rspec/autorun'
require 'taobao_query'
RSpec.configure do |config|
end