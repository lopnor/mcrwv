#!perl
use strict;
use warnings;

use LWP::UserAgent;
use Web::Scraper;
use URI;
use File::Temp;
use Archive::Zip;
use File::Basename;
use Digest::MD5;
use FFmpeg::Command;

my $uri = shift;
my $target = Digest::MD5::md5_hex($uri);

my $ua = LWP::UserAgent->new;
$ua->agent('Mozilla/5.0 (Macintosh; U; Intel Mac OS X 10_6_3; ja-jp) AppleWebKit/531.22.7 (KHTML, like Gecko) Version/4.0.5 Safari/531.22.7');
#$ua->cookie_jar({});

my $scraper = scraper {
    process '//a[@href=~/.zip$/]', 'files[]', '@href';
    process '//form[@action=~/.zip$/]', 'files[]', '@action';
    result 'files';
};
$scraper->user_agent($ua);

my $files;
for my $file (@{$scraper->scrape(URI->new($uri))}) {
    push @{$files->{basename($file->path)}}, $file;
}

if ( 
    grep({$_ =~ m{r\.zip$}} keys %$files) 
    && grep({$_ =~ m{[^r]\.zip$}} keys %$files) 
) {
    delete $files->{$_} for grep({$_ =~ m{r\.zip$}} keys %$files);
}

scalar keys %$files or die 'no zips';

my @mpg;
for my $filename (sort {$a cmp $b} keys %$files) {
    my ($zip, $tmp);
    for my $file ( sort { $a->as_string cmp $b->as_string } @{$files->{$filename}} ) {
        $file =~ s/%0A//g;
        print STDERR "downloading $file:";

        $tmp = File::Temp->new(SUFFIX => '.zip');
        binmode($tmp);
        my $length = 0;
        my $res = $ua->get($file,
            Referer => $uri,
            ':content_cb' => sub {
                my $chunk = shift;
                $length += length($chunk);
                print $tmp $chunk;
                print STDERR "\rdownloading $file: $length";
            },
        );
        use Data::Dumper;
        warn Dumper $res;
        $tmp->close;
        $res->is_success && $length or next;
        $zip = eval {Archive::Zip->new($tmp->filename)};
        $zip and last;
    }
    $zip or die 'could not get zip';
    my ($wmv) = grep {$_->{fileName} =~ /.(wmv|rm)$/} $zip->members;
    my $name = $wmv->{fileName};
    $zip->extractMember($wmv, $name);
#    push @mpg, $name;
    my $mpg = basename($name, '.wmv', '.rm').'.mpeg';
    my $ffmpeg = FFmpeg::Command->new;
    $ffmpeg->input_file($name);
    $ffmpeg->output_file($mpg);
    $ffmpeg->options(
        -r => 30,
        '-sameq',
        '-y',
    );
    my $result = $ffmpeg->exec;
    unlink $name;
    push @mpg, $mpg;
}
system('cat '.join(' ',@mpg)." > $target.mpeg");
unlink $_ for @mpg;
my $ffmpeg = FFmpeg::Command->new;
$ffmpeg->input_file("$target.mpeg");
#$ffmpeg->input_file(\@mpg);
$ffmpeg->output_file("$target.mp4");
$ffmpeg->options(
    -vcodec => 'mpeg4',
#    -vcodec => 'libx264',
#    -vpre => 'hq',
    -r => 30,
    -acodec => 'aac',
    '-y',
);
$ffmpeg->exec;
warn $ffmpeg->errstr;
unlink "$target.mpeg";
#unlink $_ for @mpg;
system('open', "$target.mp4");
