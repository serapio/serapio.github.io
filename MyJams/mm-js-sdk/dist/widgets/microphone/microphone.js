/* global MM */
/* exported MindMeldMicrophone */

/**
 * Adds the MindMeldMicrophone singleton object to the global namespace. The MindMeldMicrophone
 * exposes the following methods:
 * - initialize(): sets the listener config for MM.Listener, registers click handlers, and sets up volume monitor
 * - start(): starts recording
 * - stop(): stops recording
 * - listening(): returns a boolean indicating whether the mic is listening
 * - isContinuous(): returns a boolean indicating whether the mic is in continuous mode
 * - on(event, callback, context): register for a MindMeldMicrophone event. Events exposed:
 *  - 'init': fired after initialize() finishes
 *  - 'result': there is a speech-to-text result.  Passes a result object:
 *      `result = { transcript: (String), final: (Boolean) }`
 *  - 'start': the microphone starts recording
 *  - 'stop': the microphone stops recording
 *  - 'error': there was an error with the microphone.  Passes an event object:
 *      `event = { error: (String) }`
 */

(function microphone (MM) {
  'use strict';

  var MindMeldMicrophone = window.MindMeldMicrophone = window.MindMeldMicrophone || {};
  var listener;
  var volumeMonitor;
  var microphoneElement;
  var hasVoiceResult;
  // notAllowed == true if the browser doesn't support microphones.
  var notAllowed;

  /**
   * `initialize()` checks for speech recognition support, initializes
   * the volume monitor, and initializes mindmeld-microphone's
   * click handlers.  It will emit an `'init'` event when successfully
   * completed, or an `'error'` event in the case of an error.
   *
   * @param element a vanilla DOM element that contains the microphone.
   * Generally `document.getElementById('mindmeld-microphone')`
   */
  MindMeldMicrophone.initialize = function initialize (element) {
    microphoneElement = element;
    hasVoiceResult = false;
    notAllowed = false;

    if (! MM.support.speechRecognition) {
      microphoneElement.classList.add('disabled');
      MindMeldMicrophone.emit('error', {error: 'speech-not-supported'});
      notAllowed = true;
      return;
    }

    initMMListener();

    /* The volume monitor started causing "audio-capture" errors from webkitSpeechRecognition between
     * Chrome 40.0.2214.38 beta (64-bit) and 40.0.2214.45 beta (64-bit). We are disabling it for now.
     */
    //initVolumeMonitor();
    initClickHandlers();
    initUIHandlers();
    MindMeldMicrophone.emit('init');
  };

  // Sets the listener config for a new MM.Listener The mindmeld-microphone's
  // event handlers publish the Listener events like onResult and onEnd
  function initMMListener () {
    listener = MM.listener = new MM.Listener({
      interimResults: true
    });

    listener.on('result', function (result, resultIndex, results, event) {
      hasVoiceResult = true;
      MindMeldMicrophone.emit('result', result, resultIndex, results, event);
    });

    listener.on('start', function (event) {
      hasVoiceResult = false;
      notAllowed = false;
      MindMeldMicrophone.emit('start', event);
    });

    listener.on('end', function (event) {
      // Check if we received any listener results.
      if (!notAllowed && !hasVoiceResult) {
        MindMeldMicrophone.emit('error', {error: 'no-speech'});
      }
      MindMeldMicrophone.emit('end', event);
    });

    listener.on('error', function (event) {
      if (event.error == 'not-allowed' || event.error == 'service-not-allowed') {
        notAllowed = true;
        var holdMessage = microphoneElement.querySelector('.hold-message');
        if (holdMessage) {
          holdMessage.style.display = "none";
        }
      }
      MindMeldMicrophone.emit('error', event);
    });
  }

  // Initializes the volume monitor used to animate the microphone
  // as the volume changes
  function initVolumeMonitor () {
    var volumePulser = microphoneElement.querySelector('.volume-pulser');

    volumeMonitor = new window.VolumeMonitor({
      listener: listener,

      // Animate volume pulser by scaling a background circle based on volume
      onVolumeChange: function onVolumeChanged (volume) {
        var scale = ((volume / 100) * 0.5) + 1.0;
        volumePulser.style.transform = 'scale(' + scale + ')';
      },

      // Hide volume pulser on stop
      onStop: function onVolumeMonitorStopped () {
        volumePulser.style.transform = 'scale(0.9)';
      },

      // Public microphone error event when there is a volume monitor error
      onError: function onVolumeMonitorError (error) {
        MindMeldMicrophone.emit('error', error);
      }
    });
  }

  // Initializes mouse click handlers to start/stop the microphone
  function initClickHandlers () {
    var holdTimeout = null;
    var holdDuration = 1000;

    var micButton = microphoneElement.querySelector('.icon-container');
    micButton.addEventListener('mousedown', onMouseDown);
    micButton.addEventListener('touchstart',
      // some mobile devices fire both 'touchstart' and 'mousedown'
      // this prevents trying to start the listener twice at
      // the same time
      function onTouchStart (e) {
        e.stopPropagation();
        e.preventDefault();
        onMouseDown();
      }
    );

    function onMouseDown () {
      if (listener.listening) {
        MindMeldMicrophone.stop();
      } else {
        holdTimeout = setTimeout(
          function startContinuousOnHold () {
            MindMeldMicrophone.start(true); // start mic in continuous mode
            holdTimeout = null;
          },
          holdDuration
        );
      }
    }

    micButton.addEventListener('mouseup', onMouseUp);
    micButton.addEventListener('touchend',
      function onTouchEnd (e) {
        e.stopPropagation();
        e.preventDefault();
        onMouseUp();
      }
    );

    function onMouseUp () {
      if (holdTimeout !== null) {
        // We have not reached the hold timeout yet, start mic in normal mode
        clearTimeout(holdTimeout);
        holdTimeout = null;
        MindMeldMicrophone.start();
      }
    }

    micButton.addEventListener('mouseout', onMouseOut);
    micButton.addEventListener('touchleave',
      function onTouchLeave (e) {
        e.stopPropagation();
        e.preventDefault();
        onMouseOut();
      }
    );

    function onMouseOut () {
      clearTimeout(holdTimeout);
      holdTimeout = null;
    }
  }

  // Subscribes to microphone start/stop events to add CSS classes
  // indicating listening, lock, or waiting state
  function initUIHandlers () {
    MindMeldMicrophone.on('start', function onMicrophoneStart () {
      microphoneElement.classList.add('listening');
      if (listener.continuous) {
        microphoneElement.classList.add('lock');
      }
    });

    MindMeldMicrophone.on('end', function onMicrophoneEnd () {
      microphoneElement.classList.remove('listening');
      microphoneElement.classList.remove('lock');
    });

  }


  // Publicly Accessible Methods of mindmeld-microphone widget

  /**
   * Start recording
   */
  MindMeldMicrophone.start = function start (continuous) {
    if (notAllowed) {
      return;
    }

    listener.continuous = continuous;
    listener.start();

    /* The volume monitor started causing "audio-capture" errors from webkitSpeechRecognition between
     * Chrome 40.0.2214.38 beta (64-bit) and 40.0.2214.45 beta (64-bit). We are disabling it for now.
     */
    //volumeMonitor.start();
  };

  /**
   * Returns if the microphone is currently listening
   */
  MindMeldMicrophone.listening = function listening () {
    if (notAllowed) {
      return false;
    }

    return listener.listening;
  };

  /**
   * Stops recording
   */
  MindMeldMicrophone.stop = function stop () {
    if (notAllowed) {
      return;
    }

    listener.cancel();
  };

  // Event Dispatcher
  var subscriptions = {};

  /**
   * Subscribe to microphone events
   */
  MindMeldMicrophone.on = function on (eventName, callback, context) {
    if (! subscriptions[eventName]) {
      subscriptions[eventName] = [];
    }
    var subscription = {
      callback: callback,
      context: context
    };
    subscriptions[eventName].push(subscription);
  };

  /**
   * Publish microphone events to subscribers
   */
  MindMeldMicrophone.emit = function emit (eventName) {
    var subscribers = subscriptions[eventName];
    if (subscribers !== undefined) {
      var args = Array.prototype.slice.call(arguments, 1);
      subscribers.forEach(
        function invokeCallback (subscription) {
          var context = subscription.context || this;
          subscription.callback.apply(context , args);
        }
      );
    }
  };

  /**
   * Check if microphone is in continuous mode.
   */
  MindMeldMicrophone.isContinuous = function () {
    if (notAllowed) {
      return false;
    }

    return listener && listener.continuous;
  };

}(MM));
