package Chat::Web::Chat;
use Mojo::Base 'Mojolicious::Controller';
use DateTime;
use Encode qw/from_to decode_utf8 encode_utf8/;
use Cache::FastMmap;

my $cache = Cache::FastMmap->new();

sub index {
  my $self = shift;

  my $channel = $self->param("channel");

  $self->render('chat/index', {channel => $channel});
}

sub update_names{
  my $json = Mojo::JSON->new;
  my $channel = shift;
  my $clients = $cache->get($channel);
  my @names = ();
  for my $key(keys %$clients) {
    push @names, $clients->{$key}->{name};
  }

  for (keys %$clients) {
    $clients->{$_}->{tx}->send(
    decode_utf8($json->encode({
      names  => \@names,
    }))
    );
  }
}


# This action will render a template
sub echo {
    my $self = shift;
    
    my $channel = $self->param("channel");

    Mojo::IOLoop->stream($self->tx->connection)->timeout(600);

    $self->app->log->debug(sprintf 'Client connected: %s', $self->tx);
    my $id = sprintf "%s", $self->tx;

    my $clients = $cache->get($channel);
    if (!defined $clients){
      $clients = {};
    }
    $clients->{$id} =  {tx => $self->tx, name =>'',channel => $channel};

    $cache->set($channel, $clients);

    $self->on(message =>
        sub {
            my ($self, $arg) = @_;
            my ($key,$value) = split(/\t/,$arg);

            $self->app->log->debug(sprintf 'Client connected: %s', $self->tx);

            if ($key eq "name"){
              $clients->{$id}->{name} = $value || '名無し';
              update_names($channel);
              return;
            }

            my $msg = $value;

            my $dt   = DateTime->now( time_zone => 'Asia/Tokyo');

            my $json = Mojo::JSON->new;

            for (keys %$clients) {
                $clients->{$_}->{tx}->send(
                    decode_utf8($json->encode({
                        hms  => $dt->hms,
                        text => $msg,
                        name => $clients->{$_}->{name},
                    }))
                );
            }
        }
    );

    $self->on( finish => 
        sub {
            my $channel = $clients->{$id}->{channel};
            my $name = $clients->{$id}->{name};
            $self->app->log->debug('Client disconnected' || $channel || $name);
            delete $clients->{$id};
            update_names($channel);
        }
    );
}

1;
