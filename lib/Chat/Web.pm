package Chat::Web;
use Mojo::Base 'Mojolicious';
use Redis::Fast;
use Time::Piece;

our $redisserver;
our $redishost;
our $redisname;
our $redispassword;

# This method will run once at server start
sub startup {
  my $self = shift;

  # Router
  my $r = $self->routes;
  
  my $config = $self->plugin( 'Config', { file => 'chat.conf' } );

  # bindするとインスタンスの起動に失敗するため
  if (defined $ENV{VCAP_APPLICATION}){
    $ENV{VCAP_SERVICES} = qq/
    {"redis-2.6": {"name": "redis-ml","label": "redis-2.6","plan": "100","credentials": {"hostname": "192.155.194.214","host": "192.155.194.214","port": 6332,"password": "8bfd2943-08a7-45fc-9c09-fb90a471b364","name": "4637d649-37b4-4552-a280-27e76d4d80b8"}}}
    /;
  }

  if ($ENV{VCAP_SERVICES}) {
    my $json = Mojo::JSON->new;
    my $env = $json->decode($ENV{VCAP_SERVICES});
    my $cre = $env->{"redis-2.6"}->{"credentials"};
    $redisserver = sprintf "redis://%s:%s@%s:%s",$cre->{name},$cre->{password},$cre->{host}, $cre->{port};
    $redishost = sprintf "%s:%s",$cre->{host}, $cre->{port};
    $redisname = $cre->{name};
    $redispassword = $cre->{password};
  }
  else 
  {
    $redisserver = "127.0.0.1:6379";
    $redishost = $redisserver;
    $redisname = "";
    $redispassword = "";
  }
  warn($redisserver);

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
  $r->get ('/')->to('chat#index');
  $r->get ('/clear')->to('chat#clear');

}

1;
