
/** @define {boolean} */
var ENABLE_DEBUG = true; // overriden by compiler

(function(famba) {

  /** @const */
  var DEFAULT_TRACKING_URL = "http://localhost:4567/t";

  /** @const */
  var CONFIGURATION = window['FAMBA_CONFIG'];

  if (ENABLE_DEBUG && !window['console']) {
    window['console'] = {
      log: function() {}
    };
  }

  // fields

  var prerendered = false;
  var tracked = false;

  // methods

  // public api

  /** @expose */
  famba.suggest = function(url) {
    if (ENABLE_DEBUG) {
      window['console'].log("Suggested a next page, url='" + url + "'");
    }

    createAndAppendLinkElement(url);
  }  

  // helpers

  function isBrowserSupported() {
    return window['chrome'];
  }

  function isEmpty(value) {
    return !value || 0 === value.length;
  }

  function markIfPrerendered () {
    prerendered = (document['webkitVisibilityState'] == 'prerender');
    if (ENABLE_DEBUG) {
      if (prerendered) {
        window['console'].log("Page is prerendered");  
      } else {
        window['console'].log("Page isn't prerendered");  
      }      
    }
  }

  // configuration

  function getTrackingUrl() {
    return CONFIGURATION['tracking_url'] || DEFAULT_TRACKING_URL;
  }

  function getAppId() {
    var app_id = CONFIGURATION['app_id'];

    if (!app_id) {
      throw "'app_id' can't be undefined";
    }

    return app_id;
  }

  function getLoadSpeed() {
    var p = window.performance.timing;
    return (p.loadEventEnd - p.navigationStart).toString();
  }

  // track and suggest

  function track() {
    if (tracked) {
      if (ENABLE_DEBUG) {
        window['console'].log("Skipped tracking because it was already tracked");
      }
      return;
    }

    var imgElement = document.createElement('img');

    imgElement.setAttribute('src', buildUrl(false));
    imgElement.setAttribute('style', 'display:none;');
    imgElement.setAttribute('alt', '');

    document.getElementsByTagName('body')[0].appendChild(imgElement);

    tracked = true;
  }

  function trackAndSuggest() {
    if (tracked) {
      if (ENABLE_DEBUG) {
        window['console'].log("Skipped tracking because it was already tracked");
      }
      return;
    }

    var scriptElement = document.createElement('script')

    scriptElement.setAttribute('src', buildUrl(true));
    scriptElement.setAttribute('type', 'text/javascript');
    scriptElement.async = true;

    /* JSONP pattern: response will call `famba.suggest` if suggestion is available */
    document.getElementsByTagName('body')[0].appendChild(scriptElement);

    tracked = true;
  }

  function buildUrl(supported) {
    var url = getTrackingUrl();

    url += '?app_id=' + encodeURIComponent(getAppId());
    url += '&previous_url=' + encodeURIComponent(document.referrer);
    url += '&url=' + encodeURIComponent(location.href);

    if (supported) {
      url += '&supported=true';
      url += '&prerendered=' + encodeURIComponent(prerendered.toString());
      url += '&load_speed=' + encodeURIComponent(getLoadSpeed());
    } else {
      url += '&supported=false';
      url += '&prerendered=false';
      url += '&load_speed=0';      
    }

    if (ENABLE_DEBUG) {
      window['console'].log("Built tracking URL, url='" + url + "'");
    }

    return url;
  }

  function createAndAppendLinkElement(url) {
    var linkElement = document.createElement('link');

    linkElement.setAttribute('rel', 'prerender');
    linkElement.setAttribute('href', url);

    document.getElementsByTagName('head')[0].appendChild(linkElement);
  }

  // track and suggest if visible

  function trackAndSuggestWhenVisible() {
    if (!document['webkitHidden']) {
      trackAndSuggest();
    } else {
      document.addEventListener("webkitvisibilitychange", handleVisibilityChange, false);
    }
  }

  function handleVisibilityChange() {
    if (!document['webkitHidden']) {
      trackAndSuggest();
    }
  }

  // main

  function init() {
    if (isBrowserSupported()) {
      if (ENABLE_DEBUG) {
        window['console'].log("Browser is supported");
      }

      markIfPrerendered();

      window.addEventListener('load', function() {

        /*
          'load' event is fired just after 'loadEventStart' and before 'loadEventEnd'. Thus
          'window.performance.timing.loadEventEnd' is undefined. Workaround is to use 'setTimeout'.
        */
        setTimeout(function(){
          trackAndSuggestWhenVisible();
        }, 0);
      }, false);

    } else {
      if (ENABLE_DEBUG) {
        window['console'].log("Browser isn't supported");
      }

      track();
    }
  }

  try {
    init();
  } catch(ex) {
    if (ENABLE_DEBUG) {
      window['console'].error(ex);
    }
  }
})(window['famba'] = window['famba'] || {});