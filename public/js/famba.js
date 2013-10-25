
/** @define {boolean} */
var ENABLE_DEBUG = true;

(function() {

  /** @const */
  var DEFAULT_TRACKING_URL = "http://localhost:4567/t";

  /** @const */
  var CONFIGURATION = window['fambaConfig'];

  if (ENABLE_DEBUG && !window['console']) {
    window['console'] = {
      log: function() {}
    };
  }

  // fields

  var prerendered = false;
  var tracked = false;

  // methods

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
    var imgElement = document.createElement('img');

    imgElement.setAttribute('src', buildUrl(false));
    imgElement.setAttribute('style', 'display:none;');
    imgElement.setAttribute('alt', '');

    document.getElementsByTagName('body')[0].appendChild(imgElement);
  }

  function trackAndSuggest() {
    if (tracked) {
      if (ENABLE_DEBUG) {
        window['console'].log("Skipped tracking because it was already tracked");
      }
      return;
    }

    var request = new XMLHttpRequest();

    request.open("GET", buildUrl(true), true);

    request.onreadystatechange = function() {

      // halt if a request isn't finished and a response isn't ready
      if (request.readyState != 4) {
        return;
      }

      // halt if a server error
      if (request.status != 200 && request.status != 204) {
        if (ENABLE_DEBUG) {
          window['console'].log("An error occurs while calling tracking method");
        }        
        return;
      }

      // halt if no suggestion
      if (request.status == 204) {
        if (ENABLE_DEBUG) {
          window['console'].log("No suggestion");
        }
        return;
      }

      if (ENABLE_DEBUG) {
        window['console'].log("Suggested a next page, url='" + request.responseText + "'");
      }

      createAndAppendLinkElement(request.responseText);
    };

    tracked = true;

    request.send();
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
})();