package Chat::Web::Lobby;
use Mojo::Base 'Mojolicious::Controller';
use Encode qw/from_to decode_utf8 encode_utf8/;
use Mojo::Redis;
use Data::Dumper;

my $clients = {};


# This action will render a template
sub echo {
    my $self = shift;
    
    Mojo::IOLoop->stream($self->tx->connection)->timeout(600);

    $self->app->log->debug(sprintf 'Client connected: %s', $self->tx);
    my $id = sprintf "%s", $self->tx;

    my $redis = Mojo::Redis->new(server => $self->redisserver());
    
    $clients->{$id} = { redis => $redis};

    # messages from redis
    $redis->on(message => "rooms" , sub {
        my ($redis, $err, $message, $channel) = @_;

        my $json = Mojo::JSON->new;

        my @rooms = split / /, $message;

        my @ret = map { {name => $_} } @rooms;
        
        warn("rooms send");

        $self->tx->send(
          decode_utf8($json->encode({
            rooms  => \@ret
          }))
        );
    });


    # message from websocket
    $self->on(message => sub {
        my ($self, $arg) = @_;
        my $id = sprintf "%s", $self->tx;
        my @rooms = $redis->smembers("rooms" => sub {
          my ($redis, $vals) = @_;
          my @ret = map { {name => $_} } @$vals;
          $self->app->log->debug("@$vals");

          my $json = Mojo::JSON->new;
        
          $self->tx->send(
            decode_utf8($json->encode({
              rooms  => \@ret
            }))
          );
      
      });

    });

    # need to clean up after websocket close
    $self->on(finish => sub {


        my $id = sprintf "%s", $self->tx;

        my $redis = $clients->{$id}->{redis};
        

        $redis->unsubscribe(message => "rooms" );

        delete $clients->{$id}->{redis};
        undef  $clients->{$id};
        delete $clients->{$id};
        my  $tx = $self->tx;
        undef $tx;


    });

}

1;
