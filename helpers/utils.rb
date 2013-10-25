require 'ostruct'

# from: http://andreapavoni.com/blog/2013/4/create-recursive-openstruct-from-a-ruby-hash
class DeepStruct < OpenStruct
  def initialize(hash=nil)
    @table = {}
    @hash_table = {}

    if hash
      hash.each do |k,v|
        @table[k.to_sym] = (v.is_a?(Hash) ? self.class.new(v) : v)
        @hash_table[k.to_sym] = v

        new_ostruct_member(k)
      end
    end
  end

  def to_h
    @hash_table
  end
end

class String
  def to_b
    "true" == self.downcase
  end
end

def build_database_connection(mongodb_uri)
  uri = URI.parse(mongodb_uri)
  database_name = uri.path.gsub(/^\//, '')
  connection = Mongo::Connection.new(uri.host, uri.port).db(database_name)
  connection.authenticate(uri.user, uri.password) unless (uri.user.nil? || uri.user.nil?) 
  connection
end