#!perl
use strict;
use warnings;
use Redis::Fast;
use Time::Piece;

  my $redis = Redis::Fast->new();

  my @rooms = $redis->smembers("rooms");

  for my $room ( @rooms){
    my @ids = $redis->hkeys ($room);
    for my $id (@ids){
      my ($name, $last) = split /\n/ , $redis->hget($room, $id);
      my $timeout = Time::Piece->strptime($last, '%Y-%m-%dT%H:%M:%S');
      my $localtime = localtime;
      printf "%s %s %s %s\n", $room, $id, $timeout, $localtime;
      if ($timeout - 9*60*60 + 600 < $localtime){
        printf "hdel\n";
        $redis->hdel($room, $id);
      }
    }
  }

  @rooms = $redis->smembers("rooms");
  for my $room ( @rooms){
    my @ids = $redis->hkeys ($room);
    my @names = $redis->hvals($room);
    my $pub_channel = sprintf "%s:names", $room;
    $redis->publish($pub_channel => "@names");
    if (@ids == 0 ){
      $redis->srem(rooms => $room);
      warn ( "srem $room");
      my @vals = $redis->smembers("rooms");
      $redis->publish( "rooms" => "@vals");
    }
  }
