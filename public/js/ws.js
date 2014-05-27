$(function () {
  $('#name').focus();
  var ws = null;
  var member = function (members) {
    $('#members').val('');
    for ( var i = 0; i < members.length; ++i ) {
      $('#members').val( $('#members').val() + members[i] + "\n");
    }
  };

  var log = function (text) {
    $('#log').val( $('#log').val() + text + "\n");
  };

  var initialize = function() {
    ws = new WebSocket('ws://localhost:3000/echo');
    ws.onopen = function () {
      log('Connection opened');
    };
    
    ws.onmessage = function (msg) {
      var res = JSON.parse(msg.data);
      if (res.names){
        member(res.names);
      }
      else{
        log('[' + res.hms + '] (' + res.name + ') ' + res.text);
      }
    };
    
    ws.onclose = function(){
      log('Connection closed');
    };
  };

  initialize();

  $('#msg').keydown(function (e) {
    if (e.keyCode == 13 && $('#msg').val()) {
        ws.send("message\t" + $('#msg').val());
        $('#msg').val('');
    }
  });


  $('#enter').click(function () {
    if ($(this).text() == 'enter'){
      if (ws.readyState == 3){
        initialize();
      }
      $(this).text('leave');
      $('#name').prop('disabled', true); 
      ws.send("name\t" + $('#name').val());
    }
    else{
      ws.close(4500,"leave room");
      $('#members').val('');
      $(this).text('enter');
      $('#name').prop('disabled', false); 
    }
  });

  window.onunload = function(event){
    // Ø’f
    ws.close(4501,"close window");
  }

});