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
  
  ws.onclose = function(){
    log('Connection closed');
  };

  $('#msg').keydown(function (e) {
    if (e.keyCode == 13 && $('#msg').val()) {
        ws.send("message\t" + $('#msg').val());
        $('#msg').val('');
    }
  });


  $('#enter').keydown(function () {
    ws.send($("name\t" + '#name').val();
  });

  window.onunload = function(event){
    // êÿíf
    ws.close(4500,"êÿífóùóR");
  }

});