use inc::Module::Install;
all_from 'lib/Mcrwv.pm';
requires 'Tatsumaki';
requires 'HTTP::Session';
requires 'Archive::Zip';
requires 'FFmpeg::Command';
requires 'Digest::MD5';
requires 'File::Spec';
requires 'parent';
build_requires 'Test::More';
auto_set_repository;
WriteAll;
