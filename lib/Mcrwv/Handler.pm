package Mcrwv::Handler;
use Any::Moose;
use HTTP::Session;
use HTTP::Session::State::Cookie;
use HTTP::Session::Store::OnMemory;
extends 'Tatsumaki::Handler';

has session => (is => 'rw', isa => 'HTTP::Session', lazy_build => 1);

sub _build_session {
    my $self = shift;
    HTTP::Session->new(
        state => HTTP::Session::State::Cookie->new,
        store => HTTP::Session::Store::OnMemory->new,
        request => $self->request,
    );
}

before finish => sub {
    my ($self, $chunk) = @_;
    $self->session->response_filter($self->response);
};

__PACKAGE__->meta->make_immutable;

1;
