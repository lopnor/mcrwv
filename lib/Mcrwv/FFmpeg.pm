package Mcrwv::FFmpeg;
use Any::Moose;
extends 'Tatsumaki::Service';
use AnyEvent::Util;
use LWP::UserAgent;
use File::Temp;
use Archive::Zip;
use File::Basename;
use Digest::MD5;
use FFmpeg::Command;
use File::Spec::Functions;

has out => (is => 'ro', isa => 'Str');

sub start {}

sub zap {
    my ($self, $args, $cb) = @_;
    fork_call sub {
        my $ua = LWP::UserAgent->new($args->{agent} || '');
        my $url = $args->{url};
        my $target = Digest::MD5::md5_hex($url);
        my $mp4 = catfile($self->out,"$target.mp4");
        return $mp4 if (-r $mp4);
        my @mpg;
        for my $filename (sort {$a cmp $b} keys %{$args->{files}}) {
            my ($zip, $tmp);
            for my $file ( sort { $a->as_string cmp $b->as_string } @{$args->{files}->{$filename}} ) {
                $file =~ s/%0A//g;
                $tmp = File::Temp->new(SUFFIX => '.zip');
                binmode($tmp);
                my $length = 0;
                my $res = $ua->get($file,
                    Referer => $url,
                    ':content_cb' => sub {
                        print $tmp shift;
                    },
                );
                $tmp->close;
                $res->is_success or next;
                $zip = eval {Archive::Zip->new($tmp->filename)};
                $zip and last;
            }
            $zip or die 'could not get zip';
            my ($wmv) = grep {$_->{fileName} =~ /.(wmv|rm)$/} $zip->members;
            my $name = catfile($self->out, $wmv->{fileName});
            $zip->extractMember($wmv, $name);
            my $mpg = catfile($self->out, basename($name, '.wmv', '.rm').'.mpeg');
            my $ffmpeg = FFmpeg::Command->new;
            $ffmpeg->input_file($name);
            $ffmpeg->output_file($mpg);
            $ffmpeg->options(
                -r => 30,
                -s => '1024×768',
                '-sameq',
                '-y',
            );
            my $result = $ffmpeg->exec;
            unlink $name;
            push @mpg, $mpg;
        }
        my $mpeg = catfile($self->out,"$target.mpeg");
        system('cat '.join(' ',@mpg)." > $mpeg");
        unlink $_ for @mpg;
        {
            my $ffmpeg = FFmpeg::Command->new;
            $ffmpeg->input_file($mpeg);
            $ffmpeg->output_file($mp4);
            $ffmpeg->options(
#            -vcodec => 'mpeg4',
                -vcodec => 'libx264',
                -vpre => 'fastfirstpass',
                -b => '1200k'
                -pass => 1,
                -acodec => 'aac',
                '-y',
            );
            $ffmpeg->exec;
            $ffmpeg->errstr and die $ffmpeg->errstr;
        }
        {
            my $ffmpeg = FFmpeg::Command->new;
            $ffmpeg->input_file($mpeg);
            $ffmpeg->output_file($mp4);
            $ffmpeg->options(
#            -vcodec => 'mpeg4',
                -vcodec => 'libx264',
                -b => '1200k'
                -vpre => 'hq',
                -vpre => 'ipod320',
                -pass => 2,
                -acodec => 'aac',
                '-y',
            );
            $ffmpeg->exec;
            $ffmpeg->errstr and die $ffmpeg->errstr;
        }
        unlink $mpeg;
        return $mp4;;
    }, $cb;
}

1;
