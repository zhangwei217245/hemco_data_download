#!/usr/bin/perl -w

#------------------------------------------------------------------------------
#                  Harvard-NASA Emissions Component (HEMCO)                   !
#------------------------------------------------------------------------------
#BOP
#
# !MODULE: hemcoDataDownload.pl
#
# !DESCRIPTION: This perl script downloads data directories for the HEMCO
#  emissions component.  You may specify which directories to download
#  in the configuration file.
#\\
#\\
# !USES:
#
 require 5.003;                 # Need this version of Perl or newer
 use English;                   # Use English language
 use Carp;                      # Get detailed error messages
 use strict;
#
# !PUBLIC DATA MEMBERS:
#
 our $HEMCO_REMOTE_ROOT = "";   # Remote HEMCO data dir (with FTP prefix)
 our $HEMCO_LOCAL_ROOT  = "";   # Local HEMCO data root path
 our $VERBOSE           = "";   # Turn on extra debug printing
 our $DRYRUN            = "";   # Only print commands but do not download
#               
# !PUBLIC MEMBER FUNCTIONS:
#  &readConfigFile()
#  &downloadHemcoData()
#  &main()
#
# !CALLING SEQUENCE:
#  hemcoDataDownload.pl [ CONFIGURATION-FILE-NAME ]
#
# !REVISION HISTORY: 
#  06 Feb 2015 - R. Yantosca - Initial version
#EOP
#------------------------------------------------------------------------------
#                  GEOS-Chem Global Chemical Transport Model                  !
#------------------------------------------------------------------------------
#BOP
#
# !IROUTINE: readConfigFile
#
# !DESCRIPTION: Reads the configuration file and returns a hash with the
#  name and data path of each HEMCO directory to be downloaded.
#\\
#\\
# !INTERFACE:
#
sub readConfigFile($) {
#
# !INPUT PARAMETERS:
#
  # Path of the configuration file
  my ( $configFile ) = @_;
#
# !CALLING SEQUENCE:
#  %inventory = &readConfigFile( $donfigFile );
#  %inventory = &readConfigFile( "hemcoDataDownload.rc" );
#
# !REVISION HISTORY:
#  06 Feb 2015 - R. Yantosca - Initial version
#EOP
#------------------------------------------------------------------------------
#BOC
#
# !LOCAL VARIABLES:
#
  # Strings
  my $line       = "";
  my $line_no_ws = "";
  my $invName    = "";
  my $invPath    = "";

  # Scalars
  my $doDownload = 0;

  # Arrays
  my @result     = "";

  # Hashes
  my %inventory  = ();

  #--------------------------------------------------------------------------  
  # Read file w/ emission inventories to download
  #--------------------------------------------------------------------------

  # Open the configuration file
  open( I, "$configFile" ) or croak( "Cannot open $configFile!\n" );

  # Loop thru each line
  foreach $line ( <I> ) {
    
    # Remove newline character
    chomp( $line );

    # Strip all white space from the line
    # NOTE: $line contains white spaces, $line_no_ws does not
    $line_no_ws = $line;
    $line_no_ws =~ s/\s//g;

    #------------------------------------------------------
    # Get the remote and local data root paths
    # as well as the verbose and dryrun option flags
    #------------------------------------------------------

    # Skip comment lines
    if ( !( $line_no_ws =~ m/#/ ) ) {

      # Look for the remote data root path
      if ( $line_no_ws =~ m/RemoteHEMCOdatapath/ ) { 
	@result = split( '\|', $line_no_ws );
	$HEMCO_REMOTE_ROOT = $result[1];
      }

      # Look for the local data root path
      if ( $line_no_ws =~ m/YourHEMCOdatapath/ ) { 
	@result = split( '\|', $line_no_ws );
	$HEMCO_LOCAL_ROOT = $result[1];
      }

      # Look for the verbose debug flag
      if ( $line_no_ws =~ m/Verboseoutput/ ) { 
	@result = split( '\|', $line_no_ws );
	$VERBOSE = $result[1];
      }

      # Look for the verbose debug flag
      if ( $line_no_ws =~ m/Dryrunonly/ ) { 
	@result = split( '\|', $line_no_ws );
	$DRYRUN = $result[1];
      }
    }

    #------------------------------------------------------
    # Determine if we are in the section of the file
    # that specifies inventories to be downloaded
    #------------------------------------------------------

    # Set a flag if we are in the download section of the file
    if ( $line_no_ws =~ m/WILLBEDOWNLOADED/ ) {
      $doDownload = 1;
    }

    # Unset flag if we are out of the download section of the file
    if ( $line_no_ws =~ m/WILLNOTBEDOWNLOADED/ ) {
      $doDownload = 0;
    }

    #------------------------------------------------------
    # Define a hash of inventories to be downloaded
    #------------------------------------------------------
    if ( $doDownload > 0 ) {

      # Skip comment lines and blank lines
      if ( ( length( $line_no_ws ) > 0 ) && !( $line_no_ws =~ m/#/ ) ) {

        # Split the line
        @result  =  split( '\|', $line );

	# Name of the inventory (strip white space at beginning & end)
        $invName =  $result[0];
	$invName =~ s/^\s+|\s+$//g;

	# Directory path of the inventory (strip all white space)
        $invPath =  $result[1];
	$invPath =~ s/\s//g;
	  
	# Save the name & path into a hash
	$inventory{ $invName } = $invPath;
      }
    } 
  }

  # Close the configuration file
  close( I );

  # Exit
  return( %inventory );
}
#EOC
#------------------------------------------------------------------------------
#                  Harvard-NASA Emissions Component (HEMCO)                   !
#------------------------------------------------------------------------------
#BOP
#
# !IROUTINE: downloadHemcoData
#
# !DESCRIPTION: Downloads emissions data for use with HEMCO.  Only those
#  inventories specified in the configuration file will be downloaded.
#\\
#\\
# !INTERFACE:
#
sub downloadHemcoData(%) {
#
# !INPUT PARAMETERS:
#
  # Hash containing the HEMCO emimssion inventories to be downloaded
  my ( %inventory ) = @_;
#
# !CALLING SEQUENCE:
#  &downloadHemcoData( %inventory );
#
# !REMARKS:
#  Requires the GNU "wget" function.
#
# !REVISION HISTORY:
#  06 Feb 2015 - R. Yantosca - Initial version
#EOP
#------------------------------------------------------------------------------
#BOC
#
# !LOCAL VARIABLES: 
#
  # Strings
  my $cmd     = "";
  my $invName = "";
  my $invPath = "";
  my $result  = "";
  my @substrs = ();
  my $cutDirs = 0;
  my $refDir  = qx/pwd/;

  # Make sure the local HEMCO root directory exists
  if ( !( -d $HEMCO_LOCAL_ROOT ) ) { 
    $result = qx/mkdirhier $HEMCO_LOCAL_ROOT/;
    print "$result\n";
  }

  # Find the # of directories to cut 
  @substrs = split( "/", $HEMCO_REMOTE_ROOT );
  $cutDirs = scalar( @substrs ) - 3;

  print "VERBOSE\n";

  # Text-replace the proper color for each unit test
  while ( ( $invName, $invPath ) = each( %inventory ) ) { 

    # Replace the $ROOT tokens
    $invPath =~ s/\$ROOT/$HEMCO_REMOTE_ROOT/g;

    # Create the command for the data download via wget
    $cmd = qq/cd $HEMCO_LOCAL_ROOT; wget -r -nH -q --cut-dirs=$cutDirs "$invPath"; cd $refDir/;

    # Download the data!
    if ( $DRYRUN =~ m/[Nn][Oo]/ ) {

      print "Now downloading '$invName'...\n";
      if ( $VERBOSE =~ m/[Yy][Ee][Ss]/ ) { print "$cmd\n"; }

      $result = qx/$cmd/;
      if ( $VERBOSE =~ m/[Yy][Ee][Ss]/ ) { print "$result\n"; }
    }
  }

  # Return status to calling routine
  return( $? );
}
#EOC
#------------------------------------------------------------------------------
#                  Harvard-NASA Emissions Component (HEMCO)                   !
#------------------------------------------------------------------------------
#BOP
#
# !IROUTINE: main
#
# !DESCRIPTION: Driver program for the hemcoDataDownload script.  You may
#  specify a configuration file, or use the default configuration file.
#\\
#\\
# !INTERFACE:
#
sub main(@) {
#
# !CALLING SEQUENCE:
#  hemcoDataDownload.pl [ CONFIGURATON-FILE-NAME ]
#
# !REVISION HISTORY:
#  06 Feb 2015 - R. Yantosca - Initial version
#EOP
#------------------------------------------------------------------------------
#BOC
#
# !LOCAL VARIABLES: 
#
  my $configFile = "";

  # If the user passes a configuration filename from the command line,
  # then use it.  Otherwise, default to "HEMCO_Data_Download.rc"
  if   ( scalar( @ARGV ) == 1 ) { $configFile = $ARGV[0];               }
  else                          { $configFile = "hemcoDataDownload.rc"; }

  # Get a list of all HEMCO emission inventories to be downloaded
  my %inventory = &readConfigFile( $configFile );

  # Download all HEMCO emission inventories with the "wget" function
  &downloadHemcoData( %inventory );

  # Exit and pass status code back
  return( $? );
}
#EOC
#------------------------------------------------------------------------------

# Run main program
main();

# Exit and pass error code back to the shell
exit( $? );
