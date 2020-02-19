#!/usr/bin/perl

use YAML::XS 'LoadFile';
my $secrets = LoadFile('secrets.yaml');

my $u = $secrets->{username};
my $p = $secrets->{password};
my $s = $secrets->{server};
my $h = $secrets->{path};

system ("rm -rf /opt/hathi/alma/*");
system ("sshpass -p $p scp -r $u\@$s\:$h /opt/hathi/alma");
