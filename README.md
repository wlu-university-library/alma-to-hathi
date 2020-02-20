# Alma to HathiTrust Processing
**Washington and Lee University Library**
_(forked from [Boston College](https://developers.exlibrisgroup.com/blog/publishing-records-from-alma-to-hathi-trust-1/))_

## Purpose
These files take exported records from XML publishing profiles in Alma, extract them, and convert them to tab-separated files of records for ingestion by HathiTrust.

## Workflow
1. Build and schedule publishing profiles in Alma where the files are sent via FTP to a server capable of running Perl.
1. Run the untar script to unzip and extract the XML files from their archived format.
1. Run the twig-alma-to-hathi script to read the XML files and extract the relevant information into TSV output files.
1. _(TBD - what happens to the TSVs now???)_

## Installation & Setup

### Requirements
- Linux-based server
- Perl 5
- Perl modules (installed using Linux package manager or with CPAN)
	- Archive::TAR
	- Getopt::Std
	- YAML::XS
	- POSIX
	- XML::Twig

### Setup prior to first run
1. Copy or rename the `config-sample.yaml` file to `config.yaml`
1. Edit the variables' values in `config.yaml` to fit your setup

### Running
1. `cd` to the directory holding the Perl scripts to run them

## Notes
- If you have multiple barcode schemes, you will need to edit the `twig-alma-to-hathi.pl` file to account for it
- These files assume that your FTP server and where these scripts are run are the same.  You can use the included `get-files.pl` script to secure copy files from the FTP endpoint to your script server.  Create a `secrets.yaml` file in your scripts directory using the following format:
```
---
username: USERNAME
password: PASSWORD
server: SERVER-URL-OR-IP
path: /LOCATION/OF/FILES/ON/SERVER
```

You will also need to install the Linux package `sshpass` for this file to function.
- You will need to manually clear out old files from the FTP server and XML.  This was not included to keep potential destruction to a minimum.