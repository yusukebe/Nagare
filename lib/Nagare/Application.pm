package Nagare::Application;
use Any::Moose;

extends 'Tatsumaki::Application';

has 'irc_service' => ( is => 'rw', isa => 'Nagare::Service::IRC' );

sub add_irc_service {
    my ( $self, $irc ) = @_;
    $self->irc_service($irc);
    $self->add_service( $self->irc_service );
}

sub get_channels {
    my $self = shift;
    return $self->irc_service->channels;
}

1;
