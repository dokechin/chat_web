$(function () {
  $('#msg').focus();

  var log = function (text) {
    $('#log').val( $('#log').val() + text + "\n");
  };
  
  var ws = new WebSocket('ws://localhost:3000/echo');
  ws.onopen = function () {
    log('Connection opened');
  };
  
  ws.onmessage = function (msg) {
    var res = JSON.parse(msg.data);
    log('[' + res.hms + '] (' + res.name + ') ' + res.text);
  };

  $('#msg').keydown(function (e) {
    if (e.keyCode == 13 && $('#msg').val()) {
        ws.send($('#name').val() + "\t" + $('#msg').val());
        $('#msg').val('');
    }
  });
});