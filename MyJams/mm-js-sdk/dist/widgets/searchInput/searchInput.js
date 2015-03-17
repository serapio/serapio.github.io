/* exported MindMeldSearchInput */

;(function searchInput () {
  'use strict';

  var MindMeldSearchInput = window.MindMeldSearchInput = window.MindMeldSearchInput || {};

  var containerElement;
  var textElement;
  var inputElement;
  var messageElement;
  var warningElement;

  var errorMessages = {
    'not-allowed': 'Microphone access was denied. Please grant access and try again.',
    'service-not-allowed': 'Microphone access was denied. Please grant access and try again.',
    'no-speech': 'We did not hear you. Please try again.',
    'speech-not-supported': 'This browser does not support speech recognition'
  };


  /**
   * Initialize the search element.  Pass in the DOM (not jQuery) element
   * that contains the search input.  In the provided html snippet, it would be
   * `document.querySelector('.mindmeld-search')`.
   */
  MindMeldSearchInput.initialize = function initialize (element) {
    containerElement = element;
    textElement = containerElement.querySelector('.mindmeld-search-text');
    inputElement = containerElement.querySelector('.mindmeld-search-input');
    messageElement = containerElement.querySelector('.mindmeld-message');
    warningElement = containerElement.querySelector('.mindmeld-warning');

    textElement.addEventListener('focus', function() {
      MindMeldSearchInput.setFinal(false);
    });

    textElement.addEventListener('keypress', function (e) {
      // We are looking for CR (keyCode 13)
      var keyCode = e.keyCode;
      if (keyCode !== 13) {
        return;
      }

      // User pressed return
      textElement.blur();
      var text = MindMeldSearchInput.getText();
      MindMeldSearchInput.setText(text, true);
      MindMeldSearchInput.emit('submitText', text);

      e.preventDefault();
    });

    textElement.addEventListener('click', function (e) {
      //We want to focus on the span inside.
      textElement.querySelector('span').focus();
    });

    textElement.addEventListener('focusin', function (e) {
      textElement.classList.add('editing');
    });

    textElement.addEventListener('focusout', function (e) {
      textElement.classList.remove('editing');
    });

    messageElement && messageElement.addEventListener('click', function (e) {
      if (inputElement.classList.contains('prompt')) {
        return;
      }
      MindMeldSearchInput.clearAllMessage();
      textElement.querySelector('span').focus();
    });

    containerElement.querySelector('.mindmeld-search-glass').addEventListener('click',
      function (e) {
        console.log('Clicking glass');
        MindMeldSearchInput.setFinal(true);
        var text = MindMeldSearchInput.getText();
        MindMeldSearchInput.emit('submitText', text);

        return false;
      }
    );

    var warningMessage = document.createElement('p');
    warningMessage.setAttribute('id', 'warning-message');
    warningElement && warningElement.appendChild(warningMessage);
    var warningButtonContainer = document.createElement('div');
    warningButtonContainer.setAttribute('id', 'close-warning');
    var warningButton = document.createElement('a');
    warningButton.setAttribute('id', 'close-warning-button');
    warningButtonContainer.appendChild(warningButton);
    warningElement && warningElement.appendChild(warningButtonContainer);
    warningMessage.innerHTML = 'Your browser does not support speech input. Try using a&nbsp;<a id="supported-browser-link" href="http://caniuse.com/web-speech" target="_blank">supported browser.</a>';

    MindMeldSearchInput.emit('init');
  };

  /**
   * Set whether the search text is considered finalized or not.
   * Non-final text is de-emphasized.
   */
  MindMeldSearchInput.setFinal = function setFinal (isFinal) {
    if (isFinal) {
      textElement.classList.remove('interim');
    } else {
      textElement.classList.add('interim');
    }
  };

  /**
   * Get the text of the search input.
   */
  MindMeldSearchInput.getText = function getText () {
    var text = textElement.querySelector('span').textContent;
    // contentEditable divs encode spaces as '&nbsp;'
    text = text.replace(/&nbsp;/g, ' ');
    if (text.trim) text = text.trim();
    return text;
  };

  /**
   * Sets the text of the search input. Use isFinal boolean to
   * indicate whether the text is finalized or not
   */
  MindMeldSearchInput.setText = function setText (text, isFinal) {
    MindMeldSearchInput.setFinal(isFinal);
    textElement.querySelector('span').innerHTML = text;
  };

  /**
   * Get the error message when given an error name.
   */
  MindMeldSearchInput.getErrorMessage = function getErrorMessage (error) {
    return errorMessages[error];
  };

  MindMeldSearchInput.showPromptMessage = function showPromptMessage() {
    MindMeldSearchInput.setText('', true);
    inputElement.classList.remove('error');
    inputElement.classList.add('prompt');
    if (messageElement) {
      messageElement.innerHTML = 'Start speaking now...';
    }
  };

  MindMeldSearchInput.showErrorMessage = function showErrorMessage(text) {
    MindMeldSearchInput.setText('', true);
    inputElement.classList.remove('prompt');
    inputElement.classList.add('error');
    if (messageElement) {
      messageElement.innerHTML = text;
    }
  };

  MindMeldSearchInput.clearPromptMessage = function clearPromptMessage() {
    inputElement.classList.remove('prompt');
  };

  MindMeldSearchInput.clearAllMessage = function clearAllMessage() {
    inputElement.classList.remove('prompt');
    inputElement.classList.remove('error');
  };

  MindMeldSearchInput.showWarningMessage = function showWarningMessage() {
    // Show a warning message
    containerElement.classList.add('no-speech');
    containerElement.classList.add('warning');
    textElement.click();

    warningElement && warningElement.querySelector('a#close-warning-button').addEventListener('click', function (e) {
      containerElement.classList.remove('warning');
      textElement.click();
    });
  };

  // Event Dispatcher
  var subscriptions = {};

  /**
  * Subscribe to search input events
  */
  MindMeldSearchInput.on = function on (eventName, callback, context) {
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
  MindMeldSearchInput.emit = function emit (eventName /*, args...*/) {
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
}());
