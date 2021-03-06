use strict;
use warnings;
use FindBin;
use lib ("$FindBin::Bin/lib");
use Tatsumaki;
use Tatsumaki::Error;
use Nagare::Application;
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
    my $client_id = $self->request->param('client_id')
      or Tatsumaki::Error::HTTP->throw( 500, "'client_id' needed" );

    $self->multipart_xhr_push(1);

    my $mq = Tatsumaki::MessageQueue->instance($channel);
    $mq->poll(
        $client_id,
        sub {
            my @events = @_;
            for my $event (@events) {
                $self->stream_write($event);
            }
        }
    );
}

package ListPollHandler;
use base qw(Tatsumaki::Handler);
__PACKAGE__->asynchronous(1);

sub get {
    my $self = shift;
    my $mq = Tatsumaki::MessageQueue->instance('list');
    my $client_id = $self->request->param('client_id')
        or Tatsumaki::Error::HTTP->throw(500, "'client_id' needed");
    $mq->poll_once($client_id, sub { $self->on_new_event(@_) });
}

package ChannelHandler;
use base qw(Tatsumaki::Handler);
sub get {
    my ($self, $channel) = @_;
    $self->application->irc_service->update_channel_status( $channel,0 );
    $self->render('channel.html');
}

package MainHandler;
use base qw(Tatsumaki::Handler);
sub get {
    my $self = shift;
    my $channels = $self->application->get_channels();
    $self->render( 'index.html', { channels => $channels } );
}

package main;
use File::Basename;

my $irc_re = '[\w\-\.@]+';
my $app = Nagare::Application->new([
    "/channel/($irc_re)/poll" => 'PollHandler',
    "/channel/($irc_re)/mxhrpoll" => 'MultipartPollHandler',
    "/channel/($irc_re)" => 'ChannelHandler',
    "/(list)/mxhrpoll" => 'MultipartPollHandler',
    "/" => 'MainHandler',
]);

$app->template_path(dirname(__FILE__) . "/templates");
$app->static_path( dirname(__FILE__) . "/static" );
my $irc = Nagare::Service::IRC->new(
    server  => '192.168.1.3', # my private tiarra address ^^;
    nick    => 'yusukebe', # my nick name ^^;
);
$irc->setup();
$app->add_irc_service( $irc );
return $app;
