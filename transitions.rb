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
          allEvents: {
            count: 1
          },
          lastEvents: {
            count: (this.timestamp > from ? 1 : 0) // does an event occur within past hours?
          }          
        }        
      );
    };        
  }

  REDUCE = %Q{
    function (id, values) {
      var result = {
        allEvents: {
          count: values.length
        },
        lastEvents: {
          count: 0
        }
      };

      values.forEach(function(value) { result.lastEvents.count += value.lastEvents.count; });

      return result;
    };      
  }

  FINALIZE = %Q{
    function (id, value) {
      value.allEvents.percentComparableToAllEventsForPreviousUrl = 
        (allEventsForPreviousUrlCount != 0) ? (value.allEvents.count / allEventsForPreviousUrlCount) : 0;

      value.lastEvents.percentComparableToLastEventsForPreviousUrl = 
        (lastEventsForPreviousUrlCount != 0) ? (value.lastEvents.count / lastEventsForPreviousUrlCount) : 0;

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
    settings.database['transitions'].find_one(
      { # selector
        '_id.application_id' => application_id,
        '_id.source_url' => url,
        '$or' => [
          '$and' => [
            'value.allEvents.count' => {
              '$gt' => settings.suggestion.criteria.transition.all_events.min_count
            },
            'value.allEvents.percentComparableToAllEventsForPreviousUrl' => {
              '$gt' => settings.suggestion.criteria.transition.all_events.min_percent_comparable_to_all_events_for_previous_url
            }              
          ],
          '$and' => [
            'value.lastEvents.count' => {
              '$gt' => settings.suggestion.criteria.transition.last_events.min_count
            },
            'value.lastEvents.percentComparableToLastEventsForPreviousUrl' => {
              '$gt' => settings.suggestion.criteria.transition.last_events.min_percent_comparable_to_last_events_for_previous_url
            }              
          ]          
        ],          
      },
      { # options
        :sort => [
          ['value.lastEvents.percentComparableToLastEventsForPreviousUrl', -1],
          ['value.allEvents.percentComparableToAllEventsForPreviousUrl', -1]
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
        "all_percent='#{transition.value.allEvents.percentComparableToAllEventsForPreviousUrl}', " \
        "last_percent='#{transition.value.lastEvents.percentComparableToLastEventsForPreviousUrl}'"
    )

    transition._id.target_url
  end  
end