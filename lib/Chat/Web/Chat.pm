package Chat::Web::Chat;
use Mojo::Base 'Mojolicious::Controller';
use DateTime;
use Encode qw/from_to decode_utf8 encode_utf8/;
use Mojo::Redis;

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

    my $redis = Mojo::Redis->new;
    
    $clients->{$id} = { channel => $channel, redis => $redis};

    # messages from redis
    $redis->on(message => "$channel:message" , sub {
      my ($redis, $err, $message, $channel) = @_;

      my $json = Mojo::JSON->new;

      my $id = sprintf "%s", $self->tx;
      my $dt   = DateTime->now( time_zone => 'Asia/Tokyo');
      my ($name, $msg) = split /\n/ , $message;

      $self->tx->send(
       decode_utf8($json->encode({
         hms  => $dt->hms,
         name => $name,
         message  => $msg,
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

    # message from websocket
    $self->on(message => sub {
      my ($self, $arg) = @_;
      my ($key,$value) = split(/\t/,$arg);
      my $name;

      my $id = sprintf "%s", $self->tx;

      if ($key eq "name"){
        $name = $value || '名無し';

        $redis->hset($channel => { $id => $name});

        $self->app->log->debug(sprintf 'id: %s , name: %s', $id,$name);

        
        $clients->{$id}->{name} = $name;
        $channel = $clients->{$id}->{channel};

        $redis->hvals(
           $channel => sub {
             my ($redis, $vals) = @_;
             
             my $json = Mojo::JSON->new;
             
             my $pub_channel = sprintf "%s:names" , $channel;

             $redis->publish( $pub_channel => "@$vals");

           }
        );
      }
      else{

        my $msg = $value;

        $self->app->log->debug(sprintf 'id: %s , message: %s', $id,$msg);

        my $channel = $clients->{$id}->{channel};

        my $pub_channel = sprintf "%s:message" , $channel;

        $redis->publish($pub_channel => sprintf "%s\n%s" , $clients->{$id}->{name} , $msg);

      }
    });

    # need to clean up after websocket close
    $self->on(finish => sub {

      my $id = sprintf "%s", $self->tx;

      my $channel = $clients->{$id}->{channel};

      my $redis = $clients->{$id}->{redis};

      $redis->hdel(
        $channel => $id => sub {
        my ($redis, $ret) = @_;
        delete $clients->{$id};

        $redis->hvals(
           $channel => sub {
             my ($redis, $vals) = @_;

             my $json = Mojo::JSON->new;

             my $pub_channel = sprintf "%s:names" , $channel;

             $redis->publish($pub_channel => "@$vals");

           }
        );

      }
    );

  });

}

1;
