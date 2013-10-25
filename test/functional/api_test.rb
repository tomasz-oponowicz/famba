require_relative '../../famba.rb'
require 'test/unit'
require 'rack/test'

class ApiTest < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def test_trackAndSuggest_applicationIdUndefined_unauthorized
    get '/t'
    assert_equal 401, last_response.status
  end
end
