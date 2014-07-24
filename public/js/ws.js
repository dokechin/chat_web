$(function () {

  $('#name').focus();

  var ws = null;
  var lastmsg = Date.now();

  var video = null;
  var canvas = $("#canvas");
  var ctx = canvas.get()[0].getContext('2d');
  navigator.getUserMedia = navigator.getUserMedia || navigator.webkitGetUserMedia || navigator.mozGetUserMedia || navigator.msGetUserMedia;
  window.URL = window.URL || window.webkitURL;

  if (!navigator.getUserMedia) {
        alert("カメラ未対応のブラウザです。");
  }
  else{
    navigator.getUserMedia(
        { video : true },
        function(stream) {
            video = $("#live").get()[0];
            video.src = window.URL.createObjectURL(stream);
        },
        function(err) {
            console.log("Unable to get video stream!");
        }
    );
  }


  function mytimeout(){
    console.log("mytimeout");
    if ((lastmsg + 600000) < Date.now() && ws != null && ws.readyState == 1){
      console.log("client timeout");
      ws.close(4502,"client timeout");
      $('#members').val('');
      $('#enter').text('enter');
      $('#name').prop('disabled', false); 
    }
  }

  timer = setInterval(
    function () {
      if (video){
        ctx.drawImage(video, 0, 0, 120, 90);
      }
      mytimeout();
    }, 500
  );

  var member = function (members) {
    $('#members').val('');
    for ( var i = 0; i < members.length; ++i ) {
      $('#members').val( $('#members').val() + members[i] + "\n");
    }
  };

  var log = function (text) {
    $('#log').val( $('#log').val() + text);
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
        log('[' + res.hms + '] (' + res.name + ') ' + res.message + '\n');
        var target = document.getElementById("target");
        target.src = res.image;
      }
    };  
    
    ws.onclose = function(){
      log('切断しました\n');
    };
  };

  function inout(){
    if ($('#enter').text() == 'enter'){
      if (ws == null || ws.readyState == 3){
        initialize();
      }
      $('#enter').prop('disabled', true); 
      $('#name').prop('disabled', true); 
      ws.onopen = function () {
        log("接続しました\n");
        ws.send("name\t" + $('#name').val());
        $('#enter').text('leave');
        $('#enter').prop('disabled', false); 
      };
      lastmsg = Date.now();
    }
    else{
      ws.close(4500,"leave room");
      $('#members').val('');
      $('#enter').text('enter');
      $('#name').prop('disabled', false); 
    }
  }

  $('#msg').keydown(function (e) {
    if (e.keyCode == 13 && $('#msg').val()) {
        if (video){
            var data = canvas.get()[0].toDataURL('image/jpeg');
            ws.send("message\t" + $('#msg').val() + "\n" + "image\t" + data);
        }
        else{
            ws.send("message\t" + $('#msg').val() + "\n" + "image\t");
        }
        $('#msg').val('');
        lastmsg = Date.now();
    }
  });

//  $('#name').keydown(function (e) {
//    if (e.keyCode == 13 && $('#name').val()) {
//      inout();
//    }
//  });

   $('#enter').click(function (){
    if ($('#name').val()) {
      inout();
    }
   });

  window.onunload = function(event){
    // 切断
    ws.close(4501,"close window");
  }

});