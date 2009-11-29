package Nagare::Service::IRC;
use Any::Moose;
use AnyEvent::IRC::Client;

extends 'Tatsumaki::Service';
has irc => ( is => 'rw', isa => 'AnyEvent::IRC::Client', lazy_build => 1 );

sub _build_irc {
    my ($self) = @_;
    my $irc = AnyEvent::IRC::Client->new;
    $irc->reg_cb( disconnect => sub { warn @_; undef $irc } );
    $irc->reg_cb(
        publicmsg => sub {
            my ( $con, $channel, $packet ) = @_;
            $channel =~ s/\@.*$//;    # bouncer (tiarra)
            $channel =~ s/^#//;
            if (   $packet->{command} eq 'NOTICE'
                || $packet->{command} eq 'PRIVMSG' )
            {                         # NOTICE for bouncer backlog
                my $msg = $packet->{params}[1];
                ( my $who = $packet->{prefix} ) =~ s/\!.*//;
                warn "$who $msg";
                my $mq = Tatsumaki::MessageQueue->instance($channel);
                $mq->publish(
                    {
		        channel => $channel,
                        time    => scalar localtime,
                        name    => $who,
                        text => Encode::decode_utf8($msg),
                    }
                );
            }
        }
    );
    return $irc;
}

sub start {
    my $self = shift;
    my $nick = 'irc_stream'; #xxx
    $self->irc->connect( "irc.freenode.net", 6667,
			 { nick => $nick, user => $nick, real => $nick } );
}

__PACKAGE__->meta->make_immutable();
1;

