package Nagare::Service::Twitter;
use Any::Moose;
use AnyEvent::Twitter::Stream;

extends 'Tatsumaki::Service';
has twitter =>
  ( is => 'rw', isa => 'AnyEvent::Twitter::Stream', lazy_build => 1 );
has user     => ( is => 'rw', isa => 'Str' );
has password => ( is => 'rw', isa => 'Str' );

no Any::Moose;

sub _build_twitter {
    my $self    = shift;
    my $twitter = AnyEvent::Twitter::Stream->new(
        username => $self->user,
        password => $self->password,
        method   => "filter",
        track    => 'shibuya,shibuya.pm,shibuyapm,perl',      #xxx
        on_tweet => sub {
            my $tweet = shift;
            warn "$tweet->{user}{screen_name}: $tweet->{text}\n";
            my $mq = Tatsumaki::MessageQueue->instance('twitter');
            $mq->publish(
                {
		    channel => 'twitter',
                    time => scalar localtime,
                    name => $tweet->{user}{screen_name},
                    text => $tweet->{text},
                }
            );
        },
    );
    return $twitter;
}

sub setup {
  my $self = shift;
  $self->twitter();
}

sub start {
}

1;
