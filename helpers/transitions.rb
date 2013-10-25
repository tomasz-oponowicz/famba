module Transitions 

  MAP = %Q{
    function () {
      emit(
        { // id
          application_id: this.application_id,
          source_url: this.previous_url,
          target_url: this.url
        },       
        { // value
          all_events: {
            count: 1
          },
          last_events: {
            count: (this.timestamp > from ? 1 : 0) // does an event occur within past hours?
          }          
        }        
      );
    };        
  }

  REDUCE = %Q{
    function (id, values) {
      var result = {
        all_events: {
          count: values.length
        },
        last_events: {
          count: 0
        }
      };

      values.forEach(function(value) { result.last_events.count += value.last_events.count; });

      return result;
    };      
  }

  FINALIZE = %Q{
    function (id, value) {
      value.all_events.percent_comparable_to_all_events_for_previous_url = 
        (allEventsForPreviousUrlCount != 0) ? (value.all_events.count / allEventsForPreviousUrlCount) : 0;

      value.last_events.percent_comparable_to_last_events_for_previous_url = 
        (lastEventsForPreviousUrlCount != 0) ? (value.last_events.count / lastEventsForPreviousUrlCount) : 0;

      return value;
    };      
  }

  def update_transitions_for_url(url, application_id)
    from = Time.now - (settings.suggestion.criteria.transition.last_events.past_hours * 60 * 60)

    settings.database['events'].map_reduce(
      MAP, 
      REDUCE, 
      { # options
        :query => { 
          :application_id => application_id,
          :previous_url => url
        },
        :scope => {
          :allEventsForPreviousUrlCount => count_all_events_for_previous_url(url, application_id),
          :lastEventsForPreviousUrlCount => count_last_events_for_previous_url(from, url, application_id),
          :from => from
        },
        :finalize => FINALIZE,
        :out => { 
          :merge => "transitions" 
        }
      }
    )    
  end

  def count_all_events_for_previous_url(url, application_id)
    settings.database['events'].count({ 
      :query => {
        :application_id => application_id,
        :previous_url => url
      }
    })
  end  

  def count_last_events_for_previous_url(from, url, application_id)
    settings.database['events'].count({ 
      :query => {
        :application_id => application_id,
        :previous_url => url,
        :timestamp => {
          :'$gt' => from
        } 
      }
    })
  end

  def find_the_most_possible_transition(url, application_id)
    transition = settings.database['transitions'].find_one(
      { # selector
        '_id.application_id' => application_id,
        '_id.source_url' => url,
        'value.all_events.count' => {
          '$gte' => settings.suggestion.criteria.transition.all_events.min_count
        },
        'value.all_events.percent_comparable_to_all_events_for_previous_url' => {
          '$gte' => settings.suggestion.criteria.transition.all_events.min_percent_comparable_to_all_events_for_previous_url
        } 
      },
      { # options
        :sort => [
          ['value.last_events.percent_comparable_to_last_events_for_previous_url', -1],
          ['value.all_events.percent_comparable_to_all_events_for_previousUrl', -1]
        ]
      }
    )

    return transition unless transition.nil?

    settings.database['transitions'].find_one(
      { # selector
        '_id.application_id' => application_id,
        '_id.source_url' => url,
        'value.last_events.count' => {
          '$gte' => settings.suggestion.criteria.transition.last_events.min_count
        },
        'value.last_events.percent_comparable_to_last_events_for_previous_url' => {
          '$gte' => settings.suggestion.criteria.transition.last_events.min_percent_comparable_to_last_events_for_previous_url
        }
      },
      { # options
        :sort => [
          ['value.all_events.percent_comparable_to_all_events_for_previousUrl', -1],
          ['value.last_events.percent_comparable_to_last_events_for_previous_url', -1]
        ]
      }
    )    

  end

  def suggest_next_url(url, application_id)
    update_transitions_for_url(url, application_id)

    transition = find_the_most_possible_transition(url, application_id)

    return nil if transition.nil?

    transition = DeepStruct.new(transition)

    logger.debug(
      "Suggested a next page, " \
        "url='#{transition._id.target_url}', " \
        "source_url='#{transition._id.source_url}', " \
        "all_percent='#{transition.value.all_events.percent_comparable_to_all_events_for_previous_url}', " \
        "last_percent='#{transition.value.last_events.percent_comparable_to_last_events_for_previous_url}'"
    )

    transition._id.target_url
  end  
end