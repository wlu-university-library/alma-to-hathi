#!/usr/bin/perl

# alma_to_hathi.pl Written by Margaret Briand Wolfe December 17, 2014 for BC Libraries.
# Build files for Hathi Trust
# XML files are moved into the directory specified in path_xml by untar_hathi.pl
#
# Updated May 2016: For monograph and single-part monograph files print out a title line for each item. Parse the 901 tag for the barcode. For each barcode
# found increment the item count. If there is a description field then assume this item is part of a multi-part monograph. For the serials file print lines 
# at the bib level and not at the item level per Hathi Trust instructions.
#
# Updated 2020-02 (JTM):
# Edited for Washington and Lee University Library extract and processing.
# Fixed memory limit errors by using XML::Twig rather than XML::XPath
#

use POSIX 'strftime';
use XML::Twig;
use YAML::XS 'LoadFile';

my $config = LoadFile('config.yaml');
my $today = strftime '%Y%m%d', localtime;                         # get today's date for output files

# List of directories with files to process
@dir_list = @{$config->{dir_list}};

# What string in the directory name list above indicates files with serials?
$serIndicator = $config->{ser_indicator};

# Barcode prefix
$barcodePrefix = $config->{barcode_prefix};
$barcodeLength = $config->{barcode_length};
$barcodeRegex = quotemeta($barcodePrefix . "[0-9]{" . $barcodeLength - length($barcodePrefix) . "}");

# Setup output files
$out_dir = $config->{out_dir};                                     # directory where output files will be saved
$out_prefix = $config->{out_prefix};                               # short initials for institution
$out_mono = $out_dir . "/" . $out_prefix . "_hathi_mono-$today.tsv";
$out_multi = $out_dir . "/" . $out_prefix . "_hathi_multi-$today.tsv";
$out_ser = $out_dir . "/" . $out_prefix . "_hathi_serials-$today.tsv";
$out_rej = $out_dir . "/" . $out_prefix . "_hathi_rejected-$today.tsv";
$out_log = $out_dir . "/" . $out_prefix . "_hathi_log-$today.tsv";

# Open all files in append mode: >>
open(OUT_SER, ">>$out_ser")        || die ("Cannot open file $out_ser");
open(OUT_MONO, ">>$out_mono")      || die ("Cannot open file $out_mono");
open(OUT_MULTI, ">>$out_multi")    || die ("Cannot open file $out_multi");
open(OUT_LOG, ">>$out_log")        || die ("Cannot open file $out_log");
open(OUT_REJ, ">>$out_rej")        || die ("Cannot open file $out_rej");

$rec_out = $rec_rej = 0;

foreach my $dir (@dir_list) {
     $path_xml = $config->{path_xml} . "/" . $dir;
     if ($dir =~ /\Q$serIndicator/) {
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

               # Read data record by record from XML files -> call sub procRecord for each
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
     my ($xp, $record) = @_;

     $mms_id = "";
     $no_items = $lost = $missing = 0;
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
     $oclc_len = $issn_len = $desc_len = $gov_doc = 0;
     $oclc_no = $issn = $desc = "";

     # Grab all of the additional tags and corresponding data for this control field
     my @datafields = $record->children('datafield');
     foreach my $datafld (@datafields) {
          my $tag = $datafld->{'att'}->{'tag'};

          # create hash to store subfield codes (keys) with tag content (values)
          my %subs;
          my @subfields = $datafld->children('subfield');
          foreach my $subfld (@subfields) {
               $subs{$subfld->{'att'}->{'code'}} = $subfld->text;
          }

          if ($tag eq '901') {                                   # Grab necessary item info
               $itm_cond[$no_items] = 'CH';                      # Assume item is not lost or missing

               if (exists $subs{'y'}) {                          # item description
                    # Try to split the item description from the rest of the subfield data. Not really sure how to do this since there is no way of knowing what the item description contains but try to break on the barcode prefix
                    $found_barcode = 0;
                    $ret = $subs{'y'} =~ /\Q$barcodeRegex/;           # Look for barcode beginning with the prefix of a the specified barcode length
                    if ($ret) {
                         $ret = $subs{'y'} =~ /\Q$barcodePrefix/;     # Look for just the barcode prefix
                         if ($ret) {
                              @subdata = split(/\Q$barcodePrefix/, $subs{'y'});
                              $itm_desc[$no_items] = $subdata[0];
                              $found_barcode++;
                         }

                         if (!$found_barcode) {
                              # If here, then have a proper length barcode but it's otherwise unreadable
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

     $record->purge;
}
