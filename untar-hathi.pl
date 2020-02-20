#!/usr/bin/perl

# untar_hathi.pl
# Untar all of the zip files containing the .xml files exported from Alma
# These files will get extracted to the directory this perl script is running from.
# Move them to xml directory off of the library's directory.
# Margaret Briand Wolfe, December 17, 2014
#
# Updated 2020-02 (JTM)
# Edited for Washington and Lee University Library extract and process.
#

use Archive::Tar;
use Getopt::Std;
use YAML::XS 'LoadFile';

my $config = LoadFile('config.yaml');

# List of directories with files to process
my @dir_list = $config->{dir_list};

foreach my [$dir] (@dir_list) {
     my $path_lib = $config->{path_lib} . "/" . $dir;
     my $path_xml = $config->{path_xml} . "/" . $dir;
     my $path_perl = $config->{path_perl};

     my $tar_inst = Archive::Tar->new();

     # Untar the files containing the .XML files exported from Alma
     opendir(DIR_HATHI, $path_lib);
     for my $filenm (readdir DIR_HATHI) {
          my @is_tar = split(/\./, $filenm); 
          my $no_parts = @is_tar;
          if ($no_parts > 1 && $is_tar[$no_parts - 1] eq 'gz') {
               my $tar_fn = sprintf("%s%s%s", $path_lib, "/", $filenm);
               # This will throw a bunch of errors but the file will untar
               $tar_inst->read($tar_fn);
               # Extract .xml file to directory from which perl script is run
               $tar_inst->extract();
          }
     }

     closedir (DIR_HATHI);

     my $xmldir = $path_xml . "/" . $dir
     system("mkdir -p $xmldir");

     # Move all of the files that were just extracted to an xml directory off the library directory
     opendir(DIR_HATHI, $path_perl);
     for my $filenm (readdir DIR_HATHI) {
          my @is_xml = split(/\./, $filenm); 
          my $no_parts = @is_xml;
          if ($is_xml[$no_parts - 1] eq 'xml') {
               # chmod on the file to make it readable and move it to xml file off of the lib dir      
               system ("chmod 444 $filenm");
               # Move file from perl directory to library's xml directory
               my $filemv = sprintf("%s%s%s", $path_perl, "/", $filenm);
               system ("mv $filemv $xmldir");
          }
     }

     closedir (DIR_HATHI);
}

exit;

