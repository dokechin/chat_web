package Chat::Web;
use Mojo::Base 'Mojolicious';
use Redis::Fast;
use Time::Piece;

our $redisserver;

# This method will run once at server start
sub startup {
  my $self = shift;

  # Router
  my $r = $self->routes;
  
  my $config = $self->plugin( 'Config', { file => 'chat.conf' } );

  if ($ENV{VCAP_SERVICES}) {
    my $json = Mojo::JSON->new;
    my $env = $json->decode($ENV{VCAP_SERVICES});
    my $cre = $env->{'redis-2.6'}->{credentials};
    $redisserver = sprintf ("redis://%s:%s@%s:%s",$cre->{username},$cre->{password},$cre->{host}, $cre->{port});
    }
  else {
    $redisserver = "127.0.0.1:6379";
  }

  $self->helper(redisserver => sub { 
    return $redisserver;
  });

  $self->hook( before_dispatch=> sub {
    my $c = shift;
    $c->app->log->info($c->req->headers->to_string);
  });

  # Normal route to controller
  $r->websocket ('/:channel/echo')->to('chat#echo');
  $r->websocket ('/notify')->to('lobby#echo');
  $r->get ('/:channel')->to('chat#index');

}

1;
