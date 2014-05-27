package Chat::Web::Chat;
use Mojo::Base 'Mojolicious::Controller';
use DateTime;
use Encode qw/from_to decode_utf8 encode_utf8/;

my $clients = {};

sub index {
  my $self = shift;

  # Render template "example/welcome.html.ep" with message
  $self->render();
}

sub update_names(){
  my $json = Mojo::JSON->new;
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

    Mojo::IOLoop->stream($self->tx->connection)->timeout(600);

    $self->app->log->debug(sprintf 'Client connected: %s', $self->tx);
    my $id = sprintf "%s", $self->tx;
    $clients->{$id} = {tx => $self->tx, name =>''};

    $self->on(message =>
        sub {
            my ($self, $arg) = @_;
            my ($key,$value) = split(/\t/,$arg);

            if ($key eq "name"){
              $clients->{$id}->{name} = $value || '名無し';
              update_names();
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
            $self->app->log->debug('Client disconnected');
            delete $clients->{$id};
            update_names();
        }
    );
}

1;
