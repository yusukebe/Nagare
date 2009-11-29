use strict;
use warnings;
use FindBin;
use lib ("$FindBin::Bin/lib");
use Tatsumaki;
use Tatsumaki::Error;
use Tatsumaki::Application;
use Tatsumaki::MessageQueue;
use Nagare::Service::IRC; #xxx 

package MutipartPollHandler;
use base ('Tatsumaki::Handler');

__PACKAGE__->asynchronous(1);

sub get {
    my ( $self, $channel ) = @_;
    my $session = $self->request->param('session')
      or Tatsumaki::Error::HTTP->throw( 500, "'session' needed" );
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

package MainHandler;
use base ('Tatsumaki::Handler');
sub get {
    my $self = shift;
    $self->render('index.html');
}

package main;
use File::Basename;

my $irc_re = '\w+';
my $app = Tatsumaki::Application->new([
    "/irc/($irc_re)/poll" => 'PollHandler',
    "/irc/($irc_re)/mxhrpoll" => 'MultipartPollHandler',
    "/irc/($irc_re)" => 'ChannelHandler',
    "/" => 'MainHandler',
]);

$app->template_path(dirname(__FILE__) . "/tmpl");
$app->static_path(dirname(__FILE__) . "/static");
my $svc = Nagare::Service::IRC->new();
$app->add_service( $svc );
return $app;
