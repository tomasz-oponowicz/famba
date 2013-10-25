require_relative '../../famba.rb'
require 'test/unit'
require 'rack/test'

class ApiTest < Test::Unit::TestCase
  include Rack::Test::Methods

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

  def test_trackAndSuggest_lackingEvents_urlNotSuggested

    # given
    application = @applicationFactory.create

    any_events # reset criteria
    diselect_last_events
    app.settings.suggestion.criteria.transition.all_events.min_count = 2

    @eventFactory.create({ :previous_url => 'foo', :url => 'bar' })

    # when    
    get '/t', :app_id => application[:_id], :previous_url => '', :url => 'foo', :supported => true, :prerendered => true, :load_speed => 100

    # then    
    assert_equal 204, last_response.status
  end

  def test_trackAndSuggest_enoughEvents_urlSuggested

    # given
    application = @applicationFactory.create

    any_events # reset criteria
    diselect_last_events
    app.settings.suggestion.criteria.transition.all_events.min_count = 2    

    @eventFactory.create({ :previous_url => 'foo', :url => 'bar' })
    @eventFactory.create({ :previous_url => 'foo', :url => 'bar' })

    # when    
    get '/t', :app_id => application[:_id], :previous_url => '', :url => 'foo', :supported => true, :prerendered => true, :load_speed => 100

    # then    
    assert_equal 200, last_response.status
    assert_equal 'bar', last_response.body
  end

  def test_trackAndSuggest_enoughEventsAndNotSupported_urlNotSuggested

    # given
    application = @applicationFactory.create

    any_events # reset criteria
    diselect_last_events
    app.settings.suggestion.criteria.transition.all_events.min_count = 2    

    @eventFactory.create({ :previous_url => 'foo', :url => 'bar' })
    @eventFactory.create({ :previous_url => 'foo', :url => 'bar' })

    # when    
    get '/t', :app_id => application[:_id], :previous_url => '', :url => 'foo', :supported => false, :prerendered => true, :load_speed => 100

    # then
    assert_equal 204, last_response.status
  end

  def test_trackAndSuggest_twoTransitionsAndFirstLessPopular_secondUrlSuggested

    # given
    application = @applicationFactory.create

    any_events # reset criteria    
    
    @eventFactory.create({ :previous_url => 'foo', :url => 'bar' })
    @eventFactory.create({ :previous_url => 'foo', :url => 'bar' })

    @eventFactory.create({ :previous_url => 'foo', :url => 'baz' })
    @eventFactory.create({ :previous_url => 'foo', :url => 'baz' })
    @eventFactory.create({ :previous_url => 'foo', :url => 'baz' })
    @eventFactory.create({ :previous_url => 'foo', :url => 'baz' })

    # when    
    get '/t', :app_id => application[:_id], :previous_url => '', :url => 'foo', :supported => true, :prerendered => true, :load_speed => 100

    # then    
    assert_equal 200, last_response.status
    assert_equal 'baz', last_response.body
  end

  def test_trackAndSuggest_twoTransitionsAndFirstLessPopularRecently_secondUrlSuggested

    # given
    application = @applicationFactory.create

    any_events # reset criteria    
    app.settings.suggestion.criteria.transition.last_events.past_hours = 1

    # past (foo -> bar is more pupular)

    @eventFactory.create({ :previous_url => 'foo', :url => 'bar', :timestamp => Time.at(0) })
    @eventFactory.create({ :previous_url => 'foo', :url => 'bar', :timestamp => Time.at(0) })
    @eventFactory.create({ :previous_url => 'foo', :url => 'bar', :timestamp => Time.at(0) })
    @eventFactory.create({ :previous_url => 'foo', :url => 'bar', :timestamp => Time.at(0) })

    @eventFactory.create({ :previous_url => 'foo', :url => 'baz', :timestamp => Time.at(0) })
    @eventFactory.create({ :previous_url => 'foo', :url => 'baz', :timestamp => Time.at(0) })

    # recently (foo -> baz is more pupular)

    @eventFactory.create({ :previous_url => 'foo', :url => 'bar', :timestamp => Time.now })
    @eventFactory.create({ :previous_url => 'foo', :url => 'bar', :timestamp => Time.now })

    @eventFactory.create({ :previous_url => 'foo', :url => 'baz', :timestamp => Time.now })
    @eventFactory.create({ :previous_url => 'foo', :url => 'baz', :timestamp => Time.now })
    @eventFactory.create({ :previous_url => 'foo', :url => 'baz', :timestamp => Time.now })
    @eventFactory.create({ :previous_url => 'foo', :url => 'baz', :timestamp => Time.now })

    # when    
    get '/t', :app_id => application[:_id], :previous_url => '', :url => 'foo', :supported => true, :prerendered => true, :load_speed => 100

    # then    
    assert_equal 200, last_response.status
    assert_equal 'baz', last_response.body
  end  

  def test_trackAndSuggest_twoTransitionsEquallyPopularRecentlyButFirstMorePopularAllTheTime_firstUrlSuggested

    # given
    application = @applicationFactory.create

    any_events # reset criteria    
    app.settings.suggestion.criteria.transition.last_events.past_hours = 1

    # past (foo -> bar is more pupular)

    @eventFactory.create({ :previous_url => 'foo', :url => 'bar', :timestamp => Time.at(0) })
    @eventFactory.create({ :previous_url => 'foo', :url => 'bar', :timestamp => Time.at(0) })
    @eventFactory.create({ :previous_url => 'foo', :url => 'bar', :timestamp => Time.at(0) })
    @eventFactory.create({ :previous_url => 'foo', :url => 'bar', :timestamp => Time.at(0) })

    @eventFactory.create({ :previous_url => 'foo', :url => 'baz', :timestamp => Time.at(0) })
    @eventFactory.create({ :previous_url => 'foo', :url => 'baz', :timestamp => Time.at(0) })

    # recently (foo -> baz and foo -> bar are equally pupular)

    @eventFactory.create({ :previous_url => 'foo', :url => 'bar', :timestamp => Time.now })
    @eventFactory.create({ :previous_url => 'foo', :url => 'bar', :timestamp => Time.now })

    @eventFactory.create({ :previous_url => 'foo', :url => 'baz', :timestamp => Time.now })
    @eventFactory.create({ :previous_url => 'foo', :url => 'baz', :timestamp => Time.now })

    # when    
    get '/t', :app_id => application[:_id], :previous_url => '', :url => 'foo', :supported => true, :prerendered => true, :load_speed => 100

    # then    
    assert_equal 200, last_response.status
    assert_equal 'bar', last_response.body
  end  

  # helpers

  def app
    Sinatra::Application
  end

  def setup

    # clean all collections
    app.settings.database['applications'].remove()
    app.settings.database['events'].remove()
    app.settings.database['transitions'].remove()    
     
    @applicationFactory = ApplicationFactory.new(app.settings.database['applications'])
    @eventFactory = EventFactory.new(app.settings.database['events'])    
  end

  def any_events
    app.settings.suggestion.criteria.transition.all_events.min_count = 0
    app.settings.suggestion.criteria.transition.all_events.min_percent_comparable_to_all_events_for_previous_url = 0.0

    app.settings.suggestion.criteria.transition.last_events.min_count = 0
    app.settings.suggestion.criteria.transition.last_events.min_percent_comparable_to_last_events_for_previous_url = 0.0
    app.settings.suggestion.criteria.transition.last_events.past_hours = 1
  end

  def diselect_last_events
    app.settings.suggestion.criteria.transition.last_events.min_count = 1000
    app.settings.suggestion.criteria.transition.last_events.min_percent_comparable_to_last_events_for_previous_url = 0.0
    app.settings.suggestion.criteria.transition.last_events.past_hours = 1
  end

  class ApplicationFactory
    DEFAULT_APPLICATION_ID = BSON::ObjectId("513dfad9e779892946000048")

    def initialize(collection)
      @collection = collection
    end

    def create(fields = {})
      application = build(fields)
      @collection.insert(application)
      application
    end

    def build(fields = {})
      { :_id => DEFAULT_APPLICATION_ID, :name => "Sample website" }.merge(fields)     
    end
  end

  class EventFactory
    def initialize(collection)
      @collection = collection
    end

    def create(fields = {})
      event = build(fields)
      @collection.insert(event)
      event
    end

    def build(fields = {})
      defaults = {
        :application_id => ApplicationFactory::DEFAULT_APPLICATION_ID, 
        :user_id => "1234",
        :supported => true, 
        :prerendered => true, 
        :load_speed => 100,
        :previous_url => "foo", 
        :url => "bar",
        :timestamp => Time.now
      }

      defaults.merge(fields)
    end
  end  
end
