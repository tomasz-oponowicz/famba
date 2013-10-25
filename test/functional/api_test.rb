require_relative '../../famba.rb'
require 'test/unit'
require 'rack/test'

class ApiTest < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def setup
    @applicationFactory = ApplicationFactory.new(app.settings.database['applications'])
  end

  def teardown
    
    # clean all collections
    app.settings.database['applications'].remove()
    app.settings.database['events'].remove()
    app.settings.database['transitions'].remove()
  end

  def test_trackAndSuggest_undefinedApplicationId_unauthorized

    # when
    get '/t'

    # then
    assert_equal 401, last_response.status
  end

  def test_trackAndSuggest_tooShortApplicationId_unauthorized

    # when
    get '/t', :app_id => '1234'

    # then
    assert_equal 401, last_response.status
  end

  def test_trackAndSuggest_validApplicationId_authorized

    # given
    @applicationFactory.create({ :_id => BSON::ObjectId("513dfad9e779892946000048") })

    # when
    get '/t', :app_id => '513dfad9e779892946000048'

    # then
    assert_equal 400, last_response.status
  end  

  def test_trackAndSuggest_undefinedPreviousUrl_badRequest

    # given
    application = @applicationFactory.create

    # when

    # all parameteres except previous url
    get '/t', :app_id => application[:_id], :url => 'bar', :supported => true, :prerendered => true, :load_speed => 100

    # then
    assert_equal 400, last_response.status    
  end  

  def test_trackAndSuggest_undefinedUrl_badRequest

    # given
    application = @applicationFactory.create

    # when

    # all parameteres except url    
    get '/t', :app_id => application[:_id], :previous_url => 'foo', :supported => true, :prerendered => true, :load_speed => 100

    # then
    assert_equal 400, last_response.status    
  end    

  def test_trackAndSuggest_undefinedSupported_badRequest

    # given
    application = @applicationFactory.create

    # when

    # all parameteres except supported
    get '/t', :app_id => application[:_id], :previous_url => 'foo', :url => 'bar', :prerendered => true, :load_speed => 100

    # then
    assert_equal 400, last_response.status    
  end

  def test_trackAndSuggest_undefinedPrerendered_badRequest

    # given
    application = @applicationFactory.create

    # when

    # all parameteres except prerendered
    get '/t', :app_id => application[:_id], :previous_url => 'foo', :url => 'bar', :supported => true, :load_speed => 100

    # then
    assert_equal 400, last_response.status    
  end

  def test_trackAndSuggest_undefinedLoadSpeed_badRequest

    # given
    application = @applicationFactory.create

    # when

    # all parameteres except load speed
    get '/t', :app_id => application[:_id], :previous_url => 'foo', :url => 'bar', :supported => true, :prerendered => true

    # then
    assert_equal 400, last_response.status    
  end  

  def test_trackAndSuggest_undefinedUserId_userIdGenerated

    # given
    application = @applicationFactory.create
    # user_id isn't defined in cookies

    # when    
    get '/t', :app_id => application[:_id], :previous_url => 'foo', :url => 'bar', :supported => true, :prerendered => true, :load_speed => 100

    assert last_response.headers['Set-Cookie'].start_with?("user_id=")
  end

  def test_trackAndSuggest_validRequest_eventCreated

    # given
    application = @applicationFactory.create

    # when    
    get '/t', :app_id => application[:_id], :previous_url => 'foo', :url => 'bar', :supported => true, :prerendered => true, :load_speed => 100

    # then    
    event = app.settings.database['events'].find_one

    assert_equal BSON::ObjectId("513dfad9e779892946000048"), event['application_id']
    assert_not_nil event['user_id']
    assert_equal "foo", event['previous_url']
    assert_equal "bar", event['url']
    assert_equal true, event['supported']
    assert_equal true, event['prerendered']
    assert_equal 100, event['load_speed']
  end  

  def test_trackAndSuggest_lackingEvents_withoutSuggestion

    # given
    application = @applicationFactory.create

    # when    
    get '/t', :app_id => application[:_id], :previous_url => 'foo', :url => 'bar', :supported => true, :prerendered => true, :load_speed => 100

    # then    
    assert_equal 204, last_response.status
  end   

  class ApplicationFactory
    def initialize(collection)
      @collection = collection
    end

    def create(fields = {})
      application = build(fields)
      @collection.insert(application)
      application
    end

    def build(fields = {})
      { :_id => BSON::ObjectId("513dfad9e779892946000048"), :name => "Sample website" }.merge(fields)     
    end
  end
end
