package Chat::Web;
use Mojo::Base 'Mojolicious';

# This method will run once at server start
sub startup {
  my $self = shift;

  # Router
  my $r = $self->routes;
  
  my $config = $self->plugin( 'Config', { file => 'chat.conf' } );

  $self->hook( before_dispatch=> sub {
    my $c = shift;
    $c->app->log->info($c->req->headers->to_string);
  });

  # Normal route to controller
  $r->websocket ('/:channel/echo')->to('chat#echo');
  $r->get ('/:channel')->to('chat#index');

}

1;
