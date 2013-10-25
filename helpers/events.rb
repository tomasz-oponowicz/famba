module Events
  def build_event
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

  def save_event(event)
    settings.database['events'].insert(event)
  end       
end
