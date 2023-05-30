var newGameButton = document.getElementById('newGameButton');
var newGamePopup = document.getElementById('newGamePopup');
var confirmNewGameButton = document.getElementById('confirmNewGameButton');
var cancelNewGameButton = document.getElementById('cancelNewGameButton');
var closeButton = document.getElementById('closeButton');
var overlay = document.getElementById('overlay');

newGameButton.addEventListener('click', function() {
  newGamePopup.classList.add('show');
  overlay.classList.add('show');
});

confirmNewGameButton.addEventListener('click', function() {
  window.location.href = "{{ url_for('category') }}";
});

cancelNewGameButton.addEventListener('click', function() {
  newGamePopup.classList.remove('show');
  overlay.classList.remove('show');
});

closeButton.addEventListener('click', function() {
  newGamePopup.classList.remove('show');
  overlay.classList.remove('show');
});

overlay.addEventListener('click', function() {
  newGamePopup.classList.remove('show');
  overlay.classList.remove('show');
});

var statsButton = document.getElementById('statsButton');
var statsPopup = document.getElementById('statsPopup');
var closeButtonStats = document.getElementById('closeButtonStats');
var overlayStats = document.getElementById('overlayStats');

statsButton.addEventListener('click', function() {
  statsPopup.classList.add('show');
  overlay.classList.add('show');
});

closeButtonStats.addEventListener('click', function() {
  statsPopup.classList.remove('show');
  overlay.classList.remove('show');
});

overlayStats.addEventListener('click', function() {
  statsPopup.classList.remove('show');
  overlay.classList.remove('show');
});