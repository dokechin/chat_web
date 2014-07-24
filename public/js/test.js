//getUserMediaのAPIをすべてnavigator.getUserMediaに統一
navigator.getUserMedia = navigator.getUserMedia || navigator.webkitGetUserMedia || navigator.mozGetUserMedia || navigator.msGetUserMedia;
//window.URLのAPIをすべてwindow.URLに統一
window.URL = window.URL || window.webkitURL;
var ws_lobby = new WebSocket('ws://' + location.host + '/notify');
var ws_room  = null;
var video = null;
var canvas = document.querySelector("#canvas");
var ctx;
var entrance = new Vue({
    el: '#chat',
    data: {
        title: 'かめチャット',
        rooms: [
        ],
        entries: [
        ],
        names:[],
        room: '',
        your_name: '名無し',
        message: '',
        isLobby: true,
        isEntrance: false,
        isRoom: false,
        lastmsg: Date.now(),
        isVideo: false,
        entries_length : 0
    },
    methods: {
        say: function(){
            if (video){
//                var data = canvas.get()[0].toDataURL('image/jpeg');
                var data = canvas.toDataURL('image/jpeg');
                ws_room.send("message\t" + this.$get("message") + "\n" + "image\t" + data);
            }
            else{
                ws_room.send("message\t" + this.$get("message"));
            }
            this.$set("message","");
            this.$set("lastmsg", Date.now());
        },
        open_room: function (e) {
            this.$set("isLobby", false);
            this.$set("isEntrance", true);
            this.$set("names",[]);
        },
        go_entrance: function (room) {
            if ( typeof room.name != 'undefined' ) {
                this.$set("room",room.name);
            }
            this.$set("isLobby", false);
            this.$set("isEntrance", true);
            this.$set("names",[]);
        },
        allow: function(name){
           name.display = !name.display;

           if (name.display){
               console.log("display" + name.name);
               ws_room.send("display\t" + name.name);
           }
           else{
               console.log("undisplay" + name.name);
               ws_room.send("undisplay\t" + name.name);
           }

        },
        enter: function(room){
            console.log("enter")
            this.$set("lastmsg", Date.now());
            if (this.$get("isRoom") == true){
              ws_room.close();
            }
            else{
                ctx = canvas.getContext('2d');
                var context = this;
                if (!navigator.getUserMedia) {
                      alert("カメラ未対応のブラウザです。");
                }
                else{
                  videoObj = {
                       video: true,
                       audio: false
                  };
                  navigator.getUserMedia(
                      videoObj,
                      function(stream) {
                          context.$set("isVideo", true);
                          video = document.querySelector("#live");
                          video.src = window.URL.createObjectURL(stream);
                      },
                      function(err) {
                          console.log("Unable to get video stream!" + err);
                      }
                  );
                }
                console.log("enter:" + this.$get("room"));
                this.$set("isRoom", true);
                this.$set("isEntrance", false);
                this.$set("isLobby",false);
                ws_room = new WebSocket('ws://' + location.host + '/' + this.$get("room") + '/echo');
                var entries =  this.$get("entries");
                var your_name = this.$get("your_name");
                ws_room.onopen = function(){
                     ws_room.send("name\t" + your_name);
                }
                ws_room.onerror = function (msg){
                  console.log("ws_room on error");
                }
                ws_room.onmessage = function (msg){
                    console.log("onmessage");
                    var res = JSON.parse(msg.data);
                    if (res.names){
                        console.log(res.names);
                        var names = [];
                        var olds = context.$get("names");
                        for ( var i = 0; i < res.names.length; ++i ) {
                            var obj = {name: res.names[i]};
                            for ( var j = 0; j < olds.length; ++j ) {
                                if (res.names[i] == olds[j].name){
                                    obj.display = olds[j].display;
                                    obj.money = olds[j].money;
                                }
                            }
                            names.push(obj);
                        }

                        context.$set("names", names);
                    }
                    else if (res.message){
                        entries.push ({content : 
                          '[' + res.hms + '] (' + res.name + ') ' + res.message + '\n',
                          img_src : res.image});

                          var names = context.$get("names");
                          for ( var i = 0; i < names.length; ++i ) {
                              if (res.name == names[i].name){
                                names[i].money = res.money;
                              }
                          }
//                        var target = document.querySelector("#target");
//                        target.src = res.image;
                    }
                    else{
                        alert("already same name");
                        context.$set("isRoom", false);
                        context.$set("isEntrance", true);
                        context.$set("isLobby",false);
                    }
                }
                ws_room.onclose = function (){
                    console.log("ws_room.onclose");
                    context.$set("isRoom",false);
                    context.$set("isLobby",true);
                    context.$set("isEntrance", false);
                    context.$set("entries",[]);
                    context.$set("names",[]);
                    ws_room = null;
                }
                timer = setInterval(
                  function () {
                    var len = context.$get("entries").length;
                    console.log("len" + len);
                    if (context.$get("entries_length") < len){
                      var s = document.getElementById('entries');
                      s.scrollTop = document.getElementById('entries').scrollHeight;
                      context.$set("entries_length",len);
                    }

                    if (video){
                      ctx.drawImage(video, 0, 0, 160, 120);
                    }
                    if ((context.$get("lastmsg") + 600000) < Date.now() && 
                        ws_room != null && ws_room.readyState == 1){
                        console.log("client timeout");
                        ws_room.close(4502,"client timeout");
                    }
                  }, 500
                );
            }
        }
    } 
});


ws_lobby.onopen = function () {
    console.log("on open");
    ws_lobby.send("rooms");
};
ws_lobby.oclose = function () {
    console.log("ws_lobby on close");
};

ws_lobby.onmessage = function (msg) {
    var res = JSON.parse(msg.data);
    console.log(res.rooms);
    console.log(entrance);
    if (res.rooms){
        entrance.$set("rooms", res.rooms);
    }
};
window.onunload = function(event){
    // 切断
    ws_lobby.close(4501,"close window");
    if (ws_room){
        ws_room.close(4501,"close window");
    }
}
  