#!/usr/bin/perl

use YAML::XS 'LoadFile';
my $secrets = LoadFile('secrets.yaml');
my $config = LoadFile('config.yaml');

my $u = $secrets->{username};
my $p = $secrets->{password};
my $s = $secrets->{server};
my $h = $secrets->{path};

system ("rm -rf " . $config->{path_lib} . "/*");
system ("sshpass -p $p scp -r $u\@$s\:$h " . $config->{path_lib});
