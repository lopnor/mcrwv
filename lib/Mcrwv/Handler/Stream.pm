package Mcrwv::Handler::Stream;
use strict;
use warnings;
use parent 'Mcrwv::Handler';
use Tatsumaki::MessageQueue;
use Data::Dumper;

__PACKAGE__->asynchronous(1);

sub get {
    my $self = shift;
    my $url = $self->request->param('url') or return;
    my $mq = Tatsumaki::MessageQueue->instance($url);
    $mq->poll_once($self->session->session_id, sub {
            my @event = @_;
            $self->write(\@event);
            $self->finish;
        }
    );
}

1;
