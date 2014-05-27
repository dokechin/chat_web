package Chat::Web::Chat;
use Mojo::Base 'Mojolicious::Controller';
use DateTime;

my $clients = {};

sub index {
  my $self = shift;

  # Render template "example/welcome.html.ep" with message
  $self->render();
}

# This action will render a template
sub echo {
    my $self = shift;

    $self->app->log->debug(sprintf 'Client connected: %s', $self->tx);
    my $id = sprintf "%s", $self->tx;
    $clients->{$id} = $self->tx;

    $self->on(message =>
        sub {
            my ($self, $msg) = @_;

            my $json = Mojo::JSON->new;
            my $dt   = DateTime->now( time_zone => 'Asia/Tokyo');

            for (keys %$clients) {
                $clients->{$_}->send_message(
                    $json->encode({
                        hms  => $dt->hms,
                        text => $msg,
                    })
                );
            }
        }
    );

    $self->on( finish => 
        sub {
            $self->app->log->debug('Client disconnected');
            delete $clients->{$id};
        }
    );
}

1;
