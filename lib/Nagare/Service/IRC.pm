package Nagare::Service::IRC;
use Any::Moose;
use AnyEvent::IRC::Client;
use DateTime;
use Encode;
use HTML::Entities;

extends 'Tatsumaki::Service';
has irc => ( is => 'rw', isa => 'AnyEvent::IRC::Client', lazy_build => 1 );
has server => ( is => 'rw', isa => 'Str', default => 'irc.freenode.net' );
has port => ( is => 'rw', isa => 'Int', default => 6667 );
has nick => ( is => 'rw', isa => 'Str', required => 1  );
has debug => ( is => 'rw', isa => 'Int', default => 0 );

sub _build_irc {
    my ($self) = @_;
    my $irc = AnyEvent::IRC::Client->new;
    $irc->reg_cb(
        connect => sub {
            my ( $irc, $err ) = @_;
            if ( defined $err ) {
                warn "Couldn't connect to server: $err\n";
            }
        }
    );
    $irc->reg_cb( disconnect => sub { warn @_; undef $irc } );
    $irc->reg_cb(
        registered => sub {
            my ($self) = @_;
            warn "IRC : Registered!\n";
            $irc->enable_ping(60);
        }
    );
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
                warn "$channel : $who : $msg" if $self->debug;
                my $mq = Tatsumaki::MessageQueue->instance($channel);
                $mq->publish(
                    {
                        channel => $channel,
                        time    => DateTime->now( time_zone => 'Asia/Tokyo' )->hms(':'),
                        name    => $who,
                        text    => Encode::decode_utf8($self->format_message($msg)),
                    }
                );
            }
        }
    );
    return $irc;
}

sub format_message {
    my ( $self, $text ) = @_;
    $text =~ s{ (https?://\S+) | ([&<>"']+) } { $1 ? do { my $url = HTML::Entities::encode($1); qq(<a target="_blank" href="$url">$url</a>) } :  $2 ? HTML::Entities::encode($2) : '' }egx;
    $text;
}

sub start {
  my $self = shift;
}

sub setup {
    my $self = shift;
    my $nick = $self->nick;    #xxx
    $self->irc->connect( $self->server, $self->port,
        { nick => $nick, user => $nick, real => $nick } );
}

__PACKAGE__->meta->make_immutable();
1;

