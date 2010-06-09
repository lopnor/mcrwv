package Mcrwv::Handler::Root;
use parent 'Mcrwv::Handler';

sub get {
    my $self = shift;
    $self->render('root.html');
}

1;
