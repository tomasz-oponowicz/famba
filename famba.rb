require 'rubygems'
require 'sinatra'
require "sinatra/cookies"
require "sinatra/config_file"
require 'mongo'
require 'json/ext'
require 'rack/logger'

require_relative 'utils'
require_relative 'events'
require_relative 'transitions'

include Mongo

config_file './config.yml.erb'

configure do

  # replace hash with structure
  settings.suggestion = DeepStruct.new(settings.suggestion)

  set :logging, Logger::DEBUG
  set :database, build_database_connection(settings.mongodb_uri)
end

helpers do  
  def unregistered_application?(application_id)
    settings.database['applications'].find_one(:_id => BSON::ObjectId(application_id)).nil?
  end 

  def generate_user_id_if_needed
    cookies[:user_id] = SecureRandom.uuid if cookies[:user_id].nil?
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