require 'rubygems'
require 'sinatra'
require "sinatra/cookies"
require "sinatra/config_file"
require 'mongo'
require 'json/ext'
require 'rack/logger'

require_relative 'helpers/utils'
require_relative 'helpers/events'
require_relative 'helpers/transitions'

include Mongo

config_file './config.yml.erb'

configure do

  # replace hash with structure
  settings.suggestion = DeepStruct.new(settings.suggestion)
  set :database, build_database_connection(settings.mongodb_uri)
  set :logging, Logger::DEBUG  
end

configure :development do

  # disable access logs for WEBrick
  set :server_settings, { :AccessLog => [] }
end   

configure :production do
  require 'newrelic_rpm'
end

helpers do  
  def unregistered_application?(application_id)
    return true unless BSON::ObjectId.legal?(application_id)
    settings.database['applications'].find_one(:_id => BSON::ObjectId(application_id)).nil?
  end 

  def generate_user_id_if_needed
    # `cookies[:user_id] = SecureRandom.uuid` sets domain as "localhost" but should be empty
    response.set_cookie("user_id", :value => SecureRandom.uuid) if cookies[:user_id].nil?
  end

  def last_suggestion_active?
    (Time.now - 60) < Time.at(cookies[:suggestion_timestamp].to_i)
  end

  def generate_suggestion_timestamp
    response.set_cookie(:suggestion_timestamp, :value => Time.now.to_i)
  end

  def remove_suggestion_timestamp
    if params[:prerendered]
      response.delete_cookie(:suggestion_timestamp)
    end
  end

  def valid_parameters    
    %w(app_id previous_url url supported prerendered load_speed).each do |param| 
      halt 400 if params[param].nil?
    end

    # previous_url can be empty
    %w(app_id url supported prerendered load_speed).each do |param| 
      halt 400 if params[param].empty?
    end    
  end

  def increase_suggestion_count(application_id)
    settings.database['applications'].update( { :_id => application_id }, '$inc' => { :suggestion_count => 1 } )
  end
end

helpers Transitions, Events

get '/health' do
  "Service is operational"
end

get '/t' do
  halt 401 if unregistered_application?(params[:app_id])

  valid_parameters
  generate_user_id_if_needed

  event = build_event
  save_event(event)

  # optimization: don't suggest if browser isn't supported
  unless event[:supported]
    logger.debug("No suggestion because browser isn't supported")

    # content type should be `image/gif` if browser is NOT supported
    content_type 'image/gif'    
    status 204

    return nil
  end

  # content type should be `application/javascript` if browser is supported
  content_type 'application/javascript', :charset => 'utf-8'

  remove_suggestion_timestamp if event[:prerendered]

  # optimization: don't suggest if old suggestion is still active (otherwise browser will ignore it)
  if last_suggestion_active?
    logger.debug("No suggestion because last suggestion is still active")

    status 204 
    return nil
  end    

  suggestion = suggest_next_url(event[:url], event[:application_id])
  
  if suggestion.nil?
    logger.debug("No suggestion")
    
    status 204 
    return nil
  end

  generate_suggestion_timestamp
  increase_suggestion_count(event[:application_id])

  "famba.suggest('#{suggestion}');"
end
