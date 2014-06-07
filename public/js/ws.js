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
//  ws = new WebSocket('ws://chat.dokechin.com/echo');
    ws = new WebSocket('ws://' + location.host + location.pathname + '/echo');
//    alert('ws://' + location.host + location.pathname + '/echo');

    ws.onmessage = function (msg) {
      var res = JSON.parse(msg.data);
      if (res.names){
        member(res.names);
      }
      else{
        log('[' + res.hms + '] (' + res.name + ') ' + res.message);
      }
    };  
    
    ws.onclose = function(){
      log('Connection closed');
    };
  };

  $('#msg').keydown(function (e) {
    if (e.keyCode == 13 && $('#msg').val()) {
        ws.send("message\t" + $('#msg').val());
        $('#msg').val('');
    }
  });


  $('#enter').click(function () {
    if ($(this).text() == 'enter'){
      if (ws == null || ws.readyState == 3){
        initialize();
      }
      $('#enter').prop('disabled', true); 
      $('#name').prop('disabled', true); 
      ws.onopen = function () {
        log("onopen");
        ws.send("name\t" + $('#name').val());
        $('#enter').text('leave');
        $('#enter').prop('disabled', false); 
      };
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