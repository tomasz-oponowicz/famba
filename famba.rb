require 'rubygems'
require 'sinatra'
require "sinatra/cookies"
require 'mongo'
require 'json/ext'

include Mongo

configure :development do
  set :database, MongoClient.new('localhost', 27017).db('famba')
end

configure :production do
  db = URI.parse(ENV['MONGOHQ_URL'])
  db_name = db.path.gsub(/^\//, '')
  database = Mongo::Connection.new(db.host, db.port).db(db_name)
  database.authenticate(db.user, db.password) unless (db.user.nil? || db.user.nil?)
  set :database, database
end

helpers do
  class String
    def to_b
      "true" == self.downcase
    end
  end

  def unregistered_application?(application_id)
    settings.database['applications'].find_one(:_id => BSON::ObjectId(application_id)).nil?
  end 

  def store_event(event)
    settings.database['events'].insert(event)
  end

  def generate_user_id_if_needed
    cookies[:user_id] = SecureRandom.uuid if cookies[:user_id].nil?
  end

  def valid_parameters
    %w(app_id supported prerendered load_speed previous_url url).each do |param| 
      halt 400 if params[param].nil?
    end    
  end

  def create_event
    {
      :application_id => BSON::ObjectId(params[:app_id]), 
      :user_id => cookies[:user_id],
      :supported => params[:supported].to_b, 
      :prerendered => params[:prerendered].to_b, 
      :load_speed => params[:load_speed].to_i,
      :previous_url => URI.decode(params[:previous_url]), 
      :url => URI.decode(params[:url]),
      :timestamp => Time.now
    }
  end
end

get '/t' do
  halt 401 if unregistered_application?(params[:app_id])

  valid_parameters
  generate_user_id_if_needed
  store_event(create_event)
  
  "ok"
end