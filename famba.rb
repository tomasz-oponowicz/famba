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
end

configure :development do

  # disable access logs for WEBrick
  set :server_settings, { :AccessLog => [] }
  set :logging, Logger::DEBUG  
end   

helpers do  
  def unregistered_application?(application_id)
    return true if application_id.nil?
    settings.database['applications'].find_one(:_id => BSON::ObjectId(application_id)).nil?
  end 

  def generate_user_id_if_needed
    # `cookies[:user_id] = SecureRandom.uuid` sets domain as "localhost" but should be empty
    response.set_cookie("user_id", :value => SecureRandom.uuid) if cookies[:user_id].nil?
  end

  def valid_parameters
    # previous_url can be empty
    %w(app_id supported prerendered load_speed url).each do |param| 
      halt 400 if params[param].nil? || params[param].empty?
    end    
  end
end

helpers Transitions, Events

get '/t' do
  halt 401 if unregistered_application?(params[:app_id])

  valid_parameters
  generate_user_id_if_needed

  event = build_event
  save_event(event)

  suggestion = suggest_next_url(event[:url], event[:application_id])
  status 204 if suggestion.nil?
  suggestion
end