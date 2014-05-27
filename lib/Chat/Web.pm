package Chat::Web;
use Mojo::Base 'Mojolicious';

# This method will run once at server start
sub startup {
  my $self = shift;

  # Router
  my $r = $self->routes;

  # Normal route to controller
  $r->websocket ('/echo')->to('chat#echo');
  $r->get ('/')->to('chat#index');

}

1;
