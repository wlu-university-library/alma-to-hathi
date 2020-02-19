#!/usr/bin/perl

# alma_to_hathi.pl Written by Margaret Briand Wolfe December 17, 2014 for BC Libraries.
# Build files for Hathi Trust
# XML files are moved into the directory specified in path_xml by untar_hathi.pl
#
# Updated May 2016: For monograph and single-part monograph files print out a title line for each item. Parse the 901 tag for the barcode. For each barcode
# found increment the item count. If there is a description field then assume this item is part of a multi-part monograph. For the serials file print lines 
# at the bib level and not at the item level per Hathi Trust instructions.
#
# Updated 2020-02-19 (JTM):
# Edited for Washington and Lee University Library extract and processing.
# Fixed memory limit errors by using XML::Twig rather than XML::XPath
#

use LWP::UserAgent;
use POSIX;
use Data::Dumper;
use XML::Twig;

($my_day, $my_mon, $my_year) = (localtime) [3,4,5];
$pt_day = sprintf("%02d", $my_day);
$my_year += 1900;
$my_mon += 1;
$my_date = sprintf("%s%02d%02d", $my_year, $my_mon, $my_day);

# List of directories with files to process
@dir_list = ("HathiMonoL", "HathiMonoTelford", "HathiSerialsTelford1", "HathiSerialsTelford2", "SerialsLeyburn1", "SerialsLeyburn2");

# Log and output files
$out_dir = "/opt/hathi/out/";
$out_mono = $out_dir . "wlu_hathi_mono.tsv";
$out_multi = $out_dir . "wlu_hathi_multi.tsv";
$out_ser = $out_dir . "wlu_hathi_serials.tsv";
$out_rej = $out_dir . "wlu_hathi_rejected.tsv";
$out_log = $out_dir . "wlu_hathi_log.tsv";

# Open files. If serials directory open serial file and log
# If not open file for monographs and multi-volume monographs 
# Open files in append mode: >>
$ret = open(OUT_SER, ">>$out_ser");
if ($ret < 1) {
     die ("Cannot open file $out_ser");
}

$ret = open(OUT_MONO, ">>$out_mono");
if ($ret < 1) {
     die ("Cannot open file $out_mono");
}

$ret = open(OUT_MULTI, ">>$out_multi");
if ($ret < 1) {
     die ("Cannot open file $out_multi");
}


# Open log file to keep count of rejected records (either no OCLC # or no MMS ID)
$ret = open(OUT_LOG, ">>$out_log");
if ($ret < 1) {
     die ("Cannot open file $out_log");
}

$ret = open(OUT_REJ, ">>$out_rej");
if ($ret < 1) {
     die ("Cannot open file $out_rej");
}

$rec_out = $rec_rej = 0;

for ($d = 0; $d <= $#dir_list; $d++) {
     $path_xml = sprintf("%s%s%s", "/opt/hathi/alma/", $dir_list[$d], "/xml");
     if ($dir_list[$d] =~ /Serials/) {
          $serial_flg = 1;
     } else {
          $serial_flg = 0;
     }

     undef @file_list;
     
     # Open the directory where the xml files are and put them into a sorted array
     opendir(DIR_HATHI, $path_xml);
     while ($filenm = readdir(DIR_HATHI)) {
	  push (@file_list, $filenm);
     }

     @file_list = sort {lc($a) cmp lc ($b)} @file_list;
     foreach $filenm (@file_list) {
          @is_xml = split(/\./, $filenm); 
          $no_parts = @is_xml;
          if ($is_xml[$no_parts - 1] eq 'xml') {
               $xfile = sprintf("%s%s%s", $path_xml, "/", $filenm);
               $line_out = sprintf("%s%s", "Processing file: ", $xfile);
               print OUT_LOG ("$line_out\n");

               # Open XML::Twig to data
               my $xp = XML::Twig->new ( twig_handlers => { record => \&procRecord } );
	          $xp->parsefile($xfile);
          }
     }
     closedir (DIR_HATHI);
}

$line_out = sprintf("%s%s%s%s", "Records output: ", $rec_out, " | Records rejected: ", $rec_rej);
print OUT_LOG ("$line_out\n");

close (OUT_MONO);
close (OUT_MULTI);
close (OUT_SER);
close (OUT_LOG);
close (OUT_REJ);
exit;

#---------------------------------------------------------

sub procRecord {
     my ($t, $record) = @_;

     $mms_id = "";
     $i = $no_items = $lost = $missing = 0;
     undef @addl_tags;
     undef @addl_data;
     undef @addl_codes;
     undef @itm_cond;
     undef @itm_desc;

     # Grab all controlfields
     my @cntlfields = $record->children('controlfield');
     foreach my $ctlfld (@cntlfields) {
          $ctl_data = $ctlfld->text;
          $ctl_tag = $ctlfld->{'att'}->{'tag'};

          # If tag is 001 grab MMS ID
          if ($ctl_tag eq '001') {
               $mms_id = $ctl_data;
          }
     }
     $i = $oclc_len = $issn_len = $desc_len = $gov_doc = 0;
     $oclc_no = $issn = $desc = "";

     # Grab all of the additional tags and corresponding data for this control field
     my @datafields = $record->children('datafield');
     foreach my $datafld (@datafields) {
          my $tag = $datafld->{'att'}->{'tag'};

          my %subs;
          my @subfields = $datafld->children('subfield');
          foreach my $subfld (@subfields) {
               $subs{$subfld->{'att'}->{'code'}} = $subfld->text;
          }

          if ($tag eq '901') {                                   # Grab necessary item info
               $itm_cond[$no_items] = 'CH';                      # Assume item is not lost or missing

               if (exists $subs{'y'}) {                          # item description
                    # Try to split the item description from the rest of the subfield data. Not really sure how to do this since there is no way of knowing what the
                    # item description contains but try to break on the barcode prefix (14 digits starting with 3510101)
                    $found_barcode = 0;
                    $ret = $subs{'y'} =~ /3510101[0-9]{7}/;  # Look for a 14 digit barcode beginning with the number 3
                    if ($ret) {
                         $ret = $subs{'y'} =~ /3510101/;     # Look for the 3510101 prefix. This is the most standard WLU prefix
                         if ($ret) {
                              @subdata = split(/3510101/, $subs{'y'});
                              $itm_desc[$no_items] = $subdata[0];
                              $found_barcode++;
                         }

                         if (!$found_barcode) {
                              # If here then have a 14 digit barcode beginning with 3510101 but it's otherwise unreadable
                              $itm_desc[$no_items] = $subs{'y'}; # Grab the whole string for description since can't parse out the barcode
                              $found_barcode++;
                         }
                    }

                    # If here then haven't parsed out the barcode. Just send the whole string as the item description
                    if (!$found_barcode) {
                         $itm_desc[$no_items] = $subs{'y'};
                    }
               }

               if (exists $subs{'z'}) {                     # process status
                    $lost = $subs{'z'} =~ /LOST/;
                    $missing = $subs{'z'} =~ /MISSING/;

                    if ($lost || $missing) {
                         $itm_cond[$no_items] = 'LM';            # Set condition to Lost or Missing
                    }
               }

               # Don't really need to do anything if addl_code is a x - this is a barcode. It just contributes to the item count as do item desc & process status
               $no_items++;
          } elsif ($tag eq '035') {
               # Get OCLC number
               $ret = $subs{'a'} =~ /OCoLC/;
               if ($ret) {
                    $oclc_no = $subs{'a'};
                    $oclc_len = length($oclc_no);
               }
          } elsif ($tag eq '022') {
               # Is this a journal/issue/serials?
               $issn = $subs{'a'};
               $issn_len = length($issn);
               if ($issn_len >= 9) {
                    $no_issns = $issn_len / 9;

                    if ($no_issns >= 2) {                        # More than 1 issn in the list?
                         for ($k = 0, $l = 0; $k < $no_issns; $k++) {
                              $issns[$k] = substr($issn, $l, 9);
                              $l += 9;
                         }

                         $no_issns = @issns;

                         for ($k = 0; $k < $no_issns; $k++) {
                              if ($k == 0) {
                                   $issn = $issns[$k];
                              } else {                           # Put a comma between each issn in the list
                                   $issn_len = length($issns[$k]);
                                   # Make sure issn has a length of 9 before using it
                                   if ($issn_len == 9) {
                                        $issn = sprintf("%s%s%s", $issn, "\,", $issns[$k]);
                                   }
                              }
                         }

                         $issn_len = length($issn);
                    }
               }
          } elsif ($tag eq '074') {
               # Check for government document by presence of 074 tag
               $gov_doc = 1;
          }
     }

     if ($oclc_len && $mms_id) {                                 
          # Both are required fields. If either one is missing skip this entry.
          # If here have an MMS ID and OCLC # and no items then just have a bib and holding record in Alma. Still want to send it.
          # This is always the case for serials since we only count them at the title level.
               if (!$no_items) {
                    $itm_cond[0] = 'CH';
                    $itm_desc[0] = "";
                    $no_items++;
               }

               # Print a record for each item
               for ($k = 0; $k < $no_items; $k++) {
                    # Fields Hathi Trust is looking for (tab separated): 
                    # OCLC No, MMS ID, Holding Status (current holding, withdrawn, lost or missing), Condition, Enumeration (in our desc field), ISSN, Gov Doc #
                    # The only fields of the above that are required are OCLC # and MMS #/System #. 
                    # We also provide enumeration since that's the only way I know if this is a multi-volume set and gov doc indicator.
                    # The rest is too complicated to send. Since it's not required we are not sending it. Maybe when Alma gets easier to pull the information out.
                    if ($serial_flg) {                           # Journal/Issue/Serial
                         $line_out = sprintf("%s%s%s%s%s%s%s%s%s%s%s", $oclc_no, "\t", $mms_id, "\t", $itm_cond[$k], "\t", "\t", "\t", $issn, "\t", $gov_doc);
                         print OUT_SER ("$line_out\n");
                         $rec_out++;
                    } elsif ($itm_desc[$k]) {                    # Multi-part monograph
                         $line_out = sprintf("%s%s%s%s%s%s%s%s%s%s%s", $oclc_no, "\t", $mms_id, "\t", $itm_cond[$k], "\t", "\t", $itm_desc[$k], "\t", "\t", $gov_doc);
                         print OUT_MULTI ("$line_out\n");
                         $rec_out++;
                    } else {                                     # Single monograph
                         $line_out = sprintf("%s%s%s%s%s%s%s%s%s%s", $oclc_no, "\t", $mms_id, "\t", $itm_cond[$k], "\t", "\t", "\t", "\t", $gov_doc);
                         print OUT_MONO ("$line_out\n");
                         $rec_out++;
                    }
               }
     } else {                                               # Record rejected
          $line_out = sprintf("%s%s%s%s%s%s%s%s%s", $oclc_no, "\t", $mms_id, "\t", "\t", "\t", "\t", "\t", $gov_doc);
          print OUT_REJ ("$line_out\n");
          $rec_rej++;
     }
}
