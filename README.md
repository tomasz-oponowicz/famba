famba
=====

[![Build Status](https://travis-ci.org/tomasz-oponowicz/famba.png?branch=master)](https://travis-ci.org/tomasz-oponowicz/famba)

Prefetching mechanism, for your website, controlled by users' activity. For a brief overview visit a [promotion page](http://tomasz-oponowicz.github.io/famba).

## Try locally

Please install [Git](http://git-scm.com/), [Mongo](http://www.mongodb.org/), [Ruby](https://www.ruby-lang.org/en/), [Rake](http://rake.rubyforge.org/) and [Bundler](http://bundler.io/) before you start.

1. Run a database process:

		mongod

1. Clone the famba repository:

		git clone git@github.com:tomasz-oponowicz/famba.git && cd ./famba

1. Add a reference to a sample website in a database:

		rake add_sample_website

1. Install dependencies:

		bundle install

1. Run the famba:

		ruby famba.rb

1. Go to (using Google Chrome):

		http://localhost:4567/test1.html
		
   Navigate between `test1`, `test2` and `test3` links. Record pattern. Look for a `&prerender=true` in log messages. It indicates that page was successfully prerender.

   _TIP:_ Google Chrome won't prerender page if developer tools are open.

## Install inside your website

Please install [Git](http://git-scm.com/) and [Heroku command line](https://toolbelt.herokuapp.com/) before you start.

1. Clone the famba repository:

		git clone git@github.com:tomasz-oponowicz/famba.git && cd ./famba
		
1. Adjust parameters for a suggestion algorithm to your needs, by modifying `config.yml.erb` file:


		suggestion:
			criteria:
				transition:
					all_events:
						min_count: 1
						min_percent_comparable_to_all_events_for_previous_url: 0.1
					last_events:
						min_count: 1
						min_percent_comparable_to_last_events_for_previous_url: 0.1
						past_hours: 1

1. Commit your changes;

1. Create a free instance of the famba with the Heroku:

		heroku apps:create <your Heroku application ID>
		heroku addons:add mongohq:sandbox
		heroku run rake add_sample_website


1. Add a tracking snippet to every sub page of your website:

		<script type="text/javascript">
			var fambaBaseURL = "http://<your Heroku application ID>.herokuapp.com"
			
			var fambaConfig = fambaConfig || {};
			fambaConfig['app_id'] = '513dfad9e779892946000048';
			fambaConfig['tracking_url'] = fambaBaseURL + '/t'
		
			(function() {
				var a=document.createElement("script");
				a.type="text/javascript";
				a.async=!0;
				a.src=fambaBaseURL+"/js/famba.min.js";
				
				var b=document.getElementsByTagName("script")[0];
				b.parentNode.insertBefore(a,b);
			})();
		</script>
