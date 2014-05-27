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

# This action will render a template
sub echo {
    my $self = shift;

    Mojo::IOLoop->stream($self->tx->connection)->timeout(600);

    $self->app->log->debug(sprintf 'Client connected: %s', $self->tx);
    my $id = sprintf "%s", $self->tx;
    $clients->{$id} = $self->tx;

    $self->on(message =>
        sub {
            my ($self, $arg) = @_;
            my ($key,$value) = split(/\t/,$arg);
            my $name = '名無し';
            if ($key eq "name"){
              $name = $value;
            }

            my $json = Mojo::JSON->new;
            my $dt   = DateTime->now( time_zone => 'Asia/Tokyo');

            for (keys %$clients) {
                $clients->{$_}->send(
                    decode_utf8($json->encode({
                        hms  => $dt->hms,
                        text => $msg,
                        name => $name,
                    }))
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
