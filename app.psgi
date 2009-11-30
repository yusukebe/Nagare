use strict;
use warnings;
use FindBin;
use lib ("$FindBin::Bin/lib");
use Tatsumaki;
use Tatsumaki::Error;
use Tatsumaki::Application;
use Tatsumaki::MessageQueue;
use Nagare::Service::IRC; #xxx 
use Nagare::Service::Twitter; #xxx 

package PollHandler;
use base qw(Tatsumaki::Handler);
__PACKAGE__->asynchronous(1);

use Tatsumaki::MessageQueue;

sub get {
    my($self, $channel) = @_;
    my $mq = Tatsumaki::MessageQueue->instance($channel);
    warn "$channel\n";
    my $client_id = $self->request->param('client_id')
        or Tatsumaki::Error::HTTP->throw(500, "'client_id' needed");
    $client_id = rand(1) if $client_id eq 'dummy'; # for benchmarking stuff
    $mq->poll_once($client_id, sub { $self->on_new_event(@_) });
}

sub on_new_event {
    my($self, @events) = @_;
    $self->write(\@events);
    $self->finish;
}

package MultipartPollHandler;
use base qw(Tatsumaki::Handler);

__PACKAGE__->asynchronous(1);

sub get {
    my ( $self, $channel ) = @_;
    my $session = $self->request->param('session')
      or Tatsumaki::Error::HTTP->throw( 500, "'session' needed" );

    $self->multipart_xhr_push(1);

    my $mq = Tatsumaki::MessageQueue->instance($channel);
    $mq->poll(
        $session,
        sub {
            my @events = @_;
            for my $event (@events) {
                $self->stream_write($event);
            }
        }
    );
}

package ChannelHandler;
use base qw(Tatsumaki::Handler);
sub get {
    my ($self, $channel) = @_;
    $self->render('channel.html');
}

package MainHandler;
use base qw(Tatsumaki::Handler);
sub get {
    my $self = shift;
    $self->render('index.html');
}

package main;
use File::Basename;

my $irc_re = '[\w\-]+';
my $app = Tatsumaki::Application->new([
    "/channel/($irc_re)/poll" => 'PollHandler',
    "/channel/($irc_re)/mxhrpoll" => 'MultipartPollHandler',
    "/channel/($irc_re)" => 'ChannelHandler',
    "/twitter"=> 'TwitterHandler',
    "/" => 'MainHandler',
]);

$app->template_path(dirname(__FILE__) . "/templates");
$app->static_path(dirname(__FILE__) . "/static");
#my $irc = Nagare::Service::IRC->new( channel => '#nagare-test' );
my $twitter = Nagare::Service::Twitter->new( user => '', password => '' );
$twitter->setup();
$app->add_service( $twitter );
return $app;
