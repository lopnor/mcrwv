package Mcrwv::Handler::Zap;
use strict;
use warnings;
use parent 'Mcrwv::Handler';
use Tatsumaki::HTTPClient;
use Tatsumaki::MessageQueue;
use Web::Scraper;
use File::Basename;
use AnyEvent::Util;

__PACKAGE__->asynchronous(1);

sub get { 
    my $self = shift;
    my $url = $self->request->param('url');
    unless ($url) {
        $self->response->redirect('/');
        return;
    }

    my $agent = $self->request->headers->user_agent;
    my $client = Tatsumaki::HTTPClient->new( agent => $agent );
    $client->get($url, $self->async_cb( sub { $self->on_response($url, $agent, @_) }));
   
}

sub on_response {
    my ($self, $url, $agent, $res) = @_;

    my $scraper = scraper {
        process '//a[@href=~/.zip$/]', 'files[]', '@href';
        process '//form[@action=~/.zip$/]', 'files[]', '@action';
        result 'files';
    };
    my $files;
    for my $file (@{$scraper->scrape($res->decoded_content,$url) || []}) {
        push @{$files->{basename($file->path)}}, $file;
    }
    if (
        grep({$_ =~ m{r\.zip$}} keys %$files)
        && grep({$_ =~ m{[^r]\.zip$}} keys %$files)
    ) {
        delete $files->{$_} for grep({$_ =~ m{r\.zip$}} keys %$files);
    }

    my $cb = sub {
        my $mq = Tatsumaki::MessageQueue->instance($url);
        $mq->publish({type => 'file', file => $_[0]});
    };
    my $ffmpeg = $self->application->service('ffmpeg');
    $ffmpeg->zap({files => $files, agent => $agent, url => $url}, $self->async_cb($cb));
    $self->render('zap.html', {f => $files});
}

1;
