package Chat::Web::Chat;
use Mojo::Base 'Mojolicious::Controller';
use Time::Piece;
use Encode qw/from_to decode_utf8 encode_utf8/;
use Mojo::Redis;
use Redis::Fast;
use Data::Dumper;
use Mojo::IOLoop::Delay;
use MIME::Base64;
use Cwd 'getcwd';

my $clients = {};

sub index {
  my $self = shift;

  my $channel = $self->param("channel");

  $self->render('chat/index', {channel => $channel});
}

# This action will render a template
sub echo {
    my $self = shift;
    
    my $channel = $self->param("channel");

    Mojo::IOLoop->stream($self->tx->connection)->timeout(600);

    $self->app->log->debug(sprintf 'Client connected: %s', $self->tx);
    my $id = sprintf "%s", $self->tx;

    my $redis = Mojo::Redis->new(server => $self->redisserver());

    $clients->{$id} = { channel => $channel, redis => $redis , display =>{}, money => 0};

    # messages from redis
    $redis->on(message => "$channel:message" , sub {
      my ($redis, $err, $message, $channel) = @_;

      my $json = Mojo::JSON->new;

      my $id = sprintf "%s", $self->tx;
      my $lt   = localtime;
      my ($name, $msg, $image, $money) = split /\n/ , $message;
      
      $self->app->log->debug("$id: $name $msg $image $money");

      my $display = 0;
      if ($name eq $clients->{$id}->{name}  || $image =~ /png/ ){
          $display = 1;
      }
      else{
          for my $target ( keys %{$clients->{$id}->{display}}){
              if ($target eq $name && $clients->{$id}->{display}->{$target} == 1){
                  $display = 1;
              }
          }
      }

      $self->tx->send(
       decode_utf8($json->encode({
         hms  => $lt->hms,
         name => $name,
         message  => $msg,
         image => ($display) ? $image : '',
         money => $money,
      }))
      );
    });

    $redis->on(message => "$channel:names" , sub {
      my ($redis, $err, $message, $channel) = @_;

      my $json = Mojo::JSON->new;

      my @names = split / /, $message;
      $self->tx->send(
        decode_utf8($json->encode({
          names  => \@names,
        }))
      );

    });

    $redis->on(message => "$channel:display" , sub {
      my ($redis, $err, $message, $channel) = @_;

      my $json = Mojo::JSON->new;

      my ($target, $src) = split / /, $message;

      my $id = sprintf "%s", $self->tx;

      if ($target eq $clients->{$id}->{name}){
          $clients->{$id}->{display}->{$src} = 1;
      }

    });

    $redis->on(message => "$channel:undisplay" , sub {
      my ($redis, $err, $message, $channel) = @_;

      my $json = Mojo::JSON->new;

      my ($target, $src) = split / /, $message;

      my $id = sprintf "%s", $self->tx;

      if ($target eq $clients->{$id}->{name}){
          $clients->{$id}->{display}->{$src} = 0;
      }

    });

    $redis->on(close => sub {
      my($redis) = @_;
    });

    $redis->on(error => sub {
      my ($redis, $err) = @_;

      warn("redis error : %s", $err);

    });


    # message from websocket
    $self->on(message => sub {
      my ($self, $arg) = @_;
      
      my @lines = split(/\n/,$arg);

      my $params = {image=>''};
      for my $line(@lines){
        my ($key,$value) = split /\t/ ,$line;
        $params->{$key} = $value;
      }
      
      $self->app->log->info(Dumper($params));

      my $name;

      my $id = sprintf "%s", $self->tx;

      if ($params->{name}){
        $name = $params->{name} || '名無し';

        $redis->hvals(
           $channel => sub {
          my ($redis, $vals) = @_;
             
          my $json = Mojo::JSON->new;

          my @names = map { my ( $name, $last_say, $money) = split /\n/, $_; $name} @$vals;

          for my $exist_name(@names){
            if ($exist_name eq $name){
              $self->tx->send(
                decode_utf8($json->encode({
                  deny  => $name
                }))
              );
              return;
            }
          }

          my $now = localtime;

          $redis->hset($channel => { $id => $name . "\n" . $now->datetime });

          $redis->smembers(rooms => sub{
              my ($redis, $vals) = @_;
              my $json = Mojo::JSON->new;

              if (scalar (grep (/^$channel$/, @$vals)) == 0){
                  $redis->sadd("rooms", $channel);
                  $redis->publish( "rooms" => "@$vals $channel");
                  # menu create
                  my $menu = getMenu();
                  for my $key(keys %$menu){
                      $redis->hset ("$channel:menu" => {$key => $menu->{$key}->{price}});
                  }
                  my @response = map{ {name => $_, price => $menu->{$_}->{price}} } keys(%$menu);

                  warn(\@response);

                  $self->tx->send(
                    decode_utf8($json->encode({
                      menu  => \@response
                    }))
                  );
              }
              else{

                  $redis->hgetall(
                     "$channel:menu" => sub {
                     my ($redis, $vals) = @_;
                     my $json = Mojo::JSON->new;
                     my @response = map{ {name => $_, price => $vals->{$_}} } keys(%$vals);

                     warn(\@response);

                     $self->tx->send(
                       decode_utf8($json->encode({
                         menu  => \@response
                       }))
                     );
                  });
              }
          });
          my $channel = $clients->{$id}->{channel};
          my $pub_channel = sprintf "%s:message" , $channel;
          $redis->publish($pub_channel => sprintf "%s\n%s\n\n0" , $name, "へい、いらっしゃい！");

          $clients->{$id}->{name} = $name;
          $channel = $clients->{$id}->{channel};

          $redis->hvals(
               $channel => sub {
            my ($redis, $vals) = @_;
                 
            my $json = Mojo::JSON->new;
                 
            my $pub_channel = sprintf "%s:names" , $channel;

            my @names = map { my ( $name, $last_say, $money) = split /\n/, $_; $name} @$vals;

            $redis->publish( $pub_channel => "@names");

          });
        });
      }
      elsif($params->{message}){

        my $msg = $params->{message};
        my $image = $params->{image};

        $self->app->log->info(sprintf 'id: %s , message: %s', $id,$msg);

        my $channel = $clients->{$id}->{channel};

        my $pub_channel = sprintf "%s:message" , $channel;

        my $money = $clients->{$id}->{money} + 100;
        $clients->{$id}->{money} = $money;

        $redis->publish($pub_channel => sprintf "%s\n%s\n%s\n%d" , $clients->{$id}->{name} , $msg, $image, $money);

        my $now = localtime;

        $redis->hset($channel => { $id => $clients->{$id}->{name} . "\n" . $now->datetime });

      }
      elsif($params->{order}){

        my $channel = $clients->{$id}->{channel};
        my $name = $clients->{$id}->{name};
        my ($neta, $price) = split /:/ , $params->{order};
        $clients->{$id}->{money} = $clients->{$id}->{money} - $price;
        my $money = $clients->{$id}->{money};

        my $pub_channel = sprintf "%s:message" , $channel;

        $redis->publish($pub_channel => sprintf "%s\n%s%s\n\n%s" , $name , $neta , "いっちょー", $money);

        Mojo::IOLoop->timer(10 => sub {
             my $cwd =getcwd();
             warn("$cwd");
             my $menu = getMenu();
             my $image = $menu->{$neta}->{image};
             my $file = "./img/$image.png";
             my $binary;
             my $filesize = -s $file;
             {
                 open my $IN, '<', $file;
                 binmode $IN;
                 read $IN, $binary, $filesize;
                 close $IN;
            }

            $redis->publish($pub_channel => sprintf "%s\n%s%s\ndata:image/png;base64,%s\n" , $name , $neta, "お待ちどうさま", encode_base64( $binary, '' ));
        });

      }
      else{
        my $kind = ($params->{display})? "display": "undisplay";
        my $target = ($params->{display})? $params->{display} : $params->{undisplay};

        my $pub_channel = sprintf "%s:%s" , $channel, $kind;
        my $msg = sprintf "%s %s", $target,$clients->{$id}->{name};
#        warn("$pub_channel $msg");

        $redis->publish($pub_channel => $msg);

      }

    });

    # need to clean up after websocket close
    $self->on(finish => sub {

      my $id = sprintf "%s", $self->tx;
      warn("finish $id");
      my $tx = $self->tx;
      my $name = $clients->{$id}->{name};
      my $channel = $clients->{$id}->{channel};

      my $redis = $clients->{$id}->{redis};
      
      $redis->unsubscribe(message => $channel . ":names" );
      $redis->unsubscribe(message => $channel . ":message" );
      $redis->unsubscribe(message => $channel . ":display" );
      $redis->unsubscribe(message => $channel . ":undisplay" );

      delete $clients->{$id}->{redis};
      undef $clients->{$id};
      delete $clients->{$id};
      undef $tx;

      # 入室前の人の場合処理しない
      if (defined $name){
        my $redis_f = Redis::Fast->new(server => $self->redisserver());
        $redis_f->hdel($channel => $id);
        my @ids = $redis_f->hkeys ($channel);
        my @vals = $redis_f->hvals($channel);
        my @names = map { my ( $name, $last_say, $money) = split /\n/, $_; $name} @vals;
        my $pub_channel = sprintf "%s:names", $channel;
        $redis_f->publish($pub_channel => "@names");

        if (@ids == 0 ){
          $redis_f->srem(rooms => $channel);
          my @vals = $redis_f->smembers("rooms");
          $redis_f->publish( "rooms" => "@vals");
        }
        else{
          $pub_channel = sprintf "%s:message" , $channel;
          $redis_f->publish($pub_channel => sprintf "%s\n%s\n%s\n0" , $name , "まいどありー", "");
        }
      }

    });
}

END{
  my $redis = Redis::Fast->new(server => $Chat::Web::redisserver);
  for my $id (keys %$clients){
    my $channel = $clients->{$id}->{channel};
    $redis->hdel($channel => $id);
    warn("hdel $channel,$id");
  }
  my @rooms = $redis->smembers("rooms");
  for my $room ( @rooms){
    my @ids = $redis->hkeys ($room);
    my @vals = $redis->hvals($room);
    my @names = map { my ( $name, $last_say, $money) = split /\n/, $_; $name} @vals;
    my $pub_channel = sprintf "%s:names", $room;
    $redis->publish($pub_channel => "@names");
    if (@ids == 0 ){
      $redis->srem(rooms => $room);
      warn("srem $room");
      my @vals = $redis->smembers("rooms");
      $redis->publish( "rooms" => "@vals");
    }
  }
}

sub getMenu{
    return  {
      "あじ"    =>{price =>200,image=>"azi"},
      "中トロ"  =>{price =>400,image=>"cyu_toro"},
      "たまご"  =>{price =>100,image=>"tamago"},
      "マグロ"  =>{price =>300,image=>"maguro"},
      "エビ"    =>{price =>300,image=>"ebi"},
      "いくら"  =>{price =>400,image=>"ikura"},
      "しめ鯖"  =>{price =>200,image=>"shimesaba"},
      "かんぱち"=>{price =>300,image=>"kanpachi"},
      "ぶり"    =>{price =>300,image=>"buri"}
    };
}
1;
