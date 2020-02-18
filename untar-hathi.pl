#!/usr/bin/perl

# untar_hathi.pl
# Untar all of the zip files containing the .xml files exported from Alma
# These files will get extracted to the directory this perl script is running from.
# Move them to xml directory off of the library's directory.
#
# Margaret Briand Wolfe, December 17, 2014
#

$path_lib = "/opt/hathi/alma";
$path_xml = "/opt/hathi/leyburn/xml/.";
$path_perl = "/opt/hathi";

use Archive::Tar;
use Getopt::Std;

# require "getopts.pl"; # this makes processing switches much easier

my $tar_inst = Archive::Tar->new();

#Untar the files containing the .XML files exported from Alma
opendir(DIR_HATHI, "$path_lib");
for $filenm (readdir DIR_HATHI)
{
     @is_tar = split(/\./, $filenm); 
     $no_parts = @is_tar;
     if ($no_parts > 1 && $is_tar[$no_parts - 1] eq 'gz')     
     {
         #print "$filenm\n";
         $tar_fn = sprintf("%s%s%s", $path_lib, "/", $filenm);
         #This will throw a bunch of errors but the file will untar
         $tar_inst->read($tar_fn);
         #This will extract .xml file to file running perl script from
         $tar_inst->extract();
     }
}

closedir (DIR_HATHI);

#Move all of the files that were just extracted to an xml directory off the library directory
opendir(DIR_HATHI, "$path_perl");
for $filenm (readdir DIR_HATHI)
{
     @is_xml = split(/\./, $filenm); 
     $no_parts = @is_xml;
     if ($is_xml[$no_parts - 1] eq 'xml')     
     {
          #chnod on the file to make it readable and move it to xml file off of the lib dir      
	  $ret = system ("chmod 555 $filenm");
          #Move file from perl directory to library's xml directory
          $filemv = sprintf("%s%s%s", $path_perl, "/", $filenm); 
	  $ret = system ("mv $filemv $path_xml");
     }
}

closedir (DIR_HATHI);

exit;

