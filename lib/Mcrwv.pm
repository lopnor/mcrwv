package Mcrwv;
use strict;
use warnings;
our $VERSION = '0.01';

use Tatsumaki::Application;
use Mcrwv::FFmpeg;

sub h($) {
    my $class = shift;
    $class = 'Mcrwv::Handler'.$class;
    eval "require $class" or die $@;
    $class;
}

sub webapp {
    my ($class, $dir) = @_;
    my $app = Tatsumaki::Application->new( [
        '/stream' => h '::Stream',
        '/zap' => h '::Zap',
        qr'^/$' => h '::Root',
    ] );
    $app->add_service(ffmpeg => Mcrwv::FFmpeg->new(out => $dir.'/static/mp4'));
    $app->template_path($dir.'/templates');
    $app->static_path($dir.'/static');
    $app->psgi_app;
}

1;
