#!/usr/bin/perl

# ----------------------------------------------------------
#
# Written by Justin Elliott <jde6@psu.edu>
# TLT/Classroom and Lab Computing, Penn State University
#
# This script is included with PSU Blast Image Config:
#
#   http://clc.its.psu.edu/UnivServices/itadmins/mac/blastimageconfig
#
# Use of this script for other purposes is permitted as long as credit to Justin Elliott is mentioned.
# ----------------------------------------------------------

use strict; # Declare strict checking on variable names, etc.
use File::Basename; # Used to get this script's filename

my ( $programName ) = basename($0);

print "***\n$0 Script starting...\n";

# ----------------------------------------------------------
# Check that we're running as root (or via sudo)
# ----------------------------------------------------------

if ( $< != 0 ) # $< = effective user id (euid)
{
        print "Sorry, but this script must be executed via 'sudo' or as the root user. Exiting.\n***\n";
        exit -1;
}

# ----------------------------------------------------------
# Check that we're running on 10.7 or later:
# ----------------------------------------------------------

my $fullOSXversionStr = `/usr/bin/sw_vers -productVersion`;
$fullOSXversionStr =~ s/\s+//; # Remove all whitespace characters

# (my $MajorVersion, my $MinorVersion, my $BugFixVersion) = ("10","6","8"); # For Testing Purposes, to get the check to fail
(my $MajorVersion, my $MinorVersion, my $BugFixVersion) = split('\.', $fullOSXversionStr);

print "OS X System Version: Major = '$MajorVersion', Minor = '$MinorVersion', Bug Fix = '$BugFixVersion'\n";

my $ErrMsg = "ERROR: Sorry, but this script only supports Mac OS X 10.7 and higher.\n\n***$programName exiting.\n";

if ( ($MajorVersion < 10) || ( ( $MajorVersion == 10 ) && ( $MinorVersion < 7 ) ) )
{
	print "$programName: $ErrMsg";
	exit (-1);	
}

# ----------------------------------------------------------
# Check that we have the correct number of input parameters:
# ----------------------------------------------------------

my $argc;   # Declare variable $argc. This represents
            # the number of commandline parameters entered.

my ( $dirName ) = dirname($0);
my ( $fullPathToMe ) = $dirName . "\/" . $programName;
my ( $recoveryHDdiskDevID ) = "";
my ( $argvCountGoodFlag ) = 0; # FALSE
my ( $onlyReceivedDiskVolumePath ) = 0; # FALSE

$argc = @ARGV; # Get the number of command line parameters

if ( ( @ARGV == 1 ) || ( @ARGV == 4 ) )
{

	$argvCountGoodFlag = 1; # TRUE
	$onlyReceivedDiskVolumePath = 1;

} else
{

	$argvCountGoodFlag = 0; # FALSE
	$onlyReceivedDiskVolumePath = 0; # FALSE
}

if ( ! ( $argvCountGoodFlag ) )
{

  # if ONE argv received, it should be the path of the disk volume. Ie, /Volumes/NameOfDisk.
  # If FOUR argv's are received, assume it's being called from Blast Image Config.
  
  usage();  # Call subroutine usage()
  exit(-1);   # When usage() has completed execution, exit the program.

}

# ----------------------------------------------------------
# Build the input parameters list:
# ----------------------------------------------------------

my $RestoredDiskPath = $ARGV[0]; # /Volumes/SL Mac HD
my $ip_address = $ARGV[1]; # "DHCP", "123.123.123.123"
my $RestoredDiskDevPath = $ARGV[2]; # /dev/disk0s5
my $RestoredDiskTotalBytes = $ARGV[3]; # 19731566592

print "RestoredDiskDevPath = '$RestoredDiskDevPath'\n";

my @lt = localtime(time);

# ----------------------------------------------------------
# Specify the path to the OS X 'Recovery HD' System Image:
# ----------------------------------------------------------

# Look for the 'RecoveryHD.dmg' Recovery HD disk image in the main BIC 'RestoreImages' Directory, one directory back from this script.
# This path can be changed to anything that is valid in the terminal run with 'sudo' rights.
my $recoveryHDdiskImageFileName = "RecoveryHD.dmg";
my $recoveryHDdiskImagePath = dirname($0) . "/$recoveryHDdiskImageFileName";

# ----------------------------------------------------------
# Get the $RestoredDiskDevPath and its parent disk dev ID:
# ----------------------------------------------------------

my $diskToGetInfo = "";
my $parentDiskID = "";

if ( $onlyReceivedDiskVolumePath )
{

	print "Determining dev ID of received disk volume path next...\n";
	$diskToGetInfo = $RestoredDiskPath;
	
	# ----------------------------------------------------------
	# Dump the data on the restored volume
	# ----------------------------------------------------------

	my $restoredSystemDiskData = system("/usr/sbin/diskutil info -plist " . $diskToGetInfo) >> 8;

	if ($restoredSystemDiskData != 0)
	{
		print "ERROR: Unable to obtain data on restored system disk! Cannot continue, exiting.\n";
		exit(1);
	}
	else
	{
		# Now get the output of the same exact command so we can parse it for the parent disk dev ID:
		$restoredSystemDiskData = `/usr/sbin/diskutil info -plist $diskToGetInfo`;
	}

	$_=$restoredSystemDiskData;
	/(\/dev\/)(.*)(s\d)(.*)/;
	$parentDiskID=$2;
	
	# ----------------------------------------------------------
	# Get the total number of bytes for the supplied disk volume path
	# ----------------------------------------------------------

	my $totalBytesOfReceivedDiskVolumeTmpLog = &generateLogFileName("totalBytesOfReceivedDiskVolumeTmpLog");	
	my $totalBytesOfReceivedDiskVolume = system("/usr/sbin/diskutil info -plist " . $diskToGetInfo . " | /usr/bin/tee " . $totalBytesOfReceivedDiskVolumeTmpLog ) >> 8;

	if ($totalBytesOfReceivedDiskVolume != 0)
	{
		print "ERROR: Unable to obtain details on the received disk volume path at '$diskToGetInfo'. Exiting.\n";
		exit (-1);
	}
	else
	{
		print "Successfully obtained details on the received disk volume path at '$diskToGetInfo'.\n";
	}
	
	my $totalBytesOfReceivedDiskVolumeResult = `/usr/bin/grep -A 1 TotalSize $totalBytesOfReceivedDiskVolumeTmpLog`;
		
	$totalBytesOfReceivedDiskVolumeResult =~ s/\s+//g; # Remove all white space characters

	$_=$totalBytesOfReceivedDiskVolumeResult;
	/(\<key\>TotalSize\<\/key\>\<integer\>)(\d*)/;

	my $totalBytesOfReceivedDiskVolumeResult=$2;

	if ( ( $totalBytesOfReceivedDiskVolumeResult == '' ) || ($totalBytesOfReceivedDiskVolumeResult == 0 ) )
	{
		print "ERROR: Failed to obtain the total number of bytes for the disk volume, exiting.";
		exit(1);
	}
	else
	{	
		$RestoredDiskTotalBytes = $totalBytesOfReceivedDiskVolumeResult;
	}

	print "Total number of bytes for the disk volume at '$diskToGetInfo' = $RestoredDiskTotalBytes\n";
	
	# ----------------------------------------------------------
	# Get the $RestoredDiskDevPath for the received disk volume path:
	# ----------------------------------------------------------

	my $DeviceIDofReceivedDiskVolumeResult = `/usr/bin/grep -A 1 DeviceIdentifier $totalBytesOfReceivedDiskVolumeTmpLog`;
	$DeviceIDofReceivedDiskVolumeResult =~ s/\s+//g; # Remove all white space characters
	
	$_=$DeviceIDofReceivedDiskVolumeResult;
	/(\<key\>DeviceIdentifier\<\/key\>\<string\>)(.*)(\<\/string\>)/;

	$DeviceIDofReceivedDiskVolumeResult=$2;
	
	print "**** DeviceIDofReceivedDiskVolumeResult = '$DeviceIDofReceivedDiskVolumeResult'\n";	

	if ( $DeviceIDofReceivedDiskVolumeResult eq "" )
	{
		print "ERROR: Failed to obtain the device ID of the received disk volume path, exiting.\n";
		exit(1);
	}
	else
	{	
		$RestoredDiskDevPath = $DeviceIDofReceivedDiskVolumeResult;
	}
	
} else
{
	print "Received the disk dev ID, using it...\n";	

	$_=$RestoredDiskDevPath;
	/(\/dev\/)(.*)(s)(.*)/;
	$parentDiskID=$2;
	
}

if ( $parentDiskID eq "")
{
	print "ERROR: Unable to determine parent disk device ID. Exiting.\n";
	exit(-1);
}
else
{
	print "Parent Disk Device ID = '$parentDiskID'\n";
}

# ----------------------------------------------------------
# Check to see if there's already a hidden 'Apple_Boot' (Recovery HD) partition, and use that partition if it does exist.
# ----------------------------------------------------------

my $existingRecoveryHDVolDiskIDtmpLog = &generateLogFileName("existingRecoveryHDVolDiskIDtmpLog");
my $existingRecoveryHDVolDiskID = system("/usr/sbin/diskutil list -plist /dev/" . $parentDiskID . " | /usr/bin/tee " . $existingRecoveryHDVolDiskIDtmpLog ) >> 8;

if ($existingRecoveryHDVolDiskID != 0)
{
	print "ERROR: Unable to obtain partition data on the parent disk located at /dev/$parentDiskID. Exiting.\n";
	exit (-1);
}
else
{
	print "Successfully obtained partition data located at /dev/$parentDiskID.\n";
}

my $existingRecoveryHDVolDiskIDresult = `/usr/bin/grep -A 1000 \"Apple_Boot\" $existingRecoveryHDVolDiskIDtmpLog`;
$existingRecoveryHDVolDiskIDresult =~ s/\s+//g; # Remove all white space characters

# diskutil list -plist /dev/disk0 | grep -i -A 2 Apple_Boot
#					<string>Apple_Boot</string><key>DeviceIdentifier</key><string>disk0s3</string>

$_=$existingRecoveryHDVolDiskIDresult;
/(\<string\>Apple_Boot\<\/string\>\<key\>DeviceIdentifier\<\/key\>\<string\>)(.*)(\<\/string\>\<key\>)(.*)/;

my $existingRecoveryHDVolDiskIDresult=$2;

print "existingRecoveryHDVolDiskIDresult = '$existingRecoveryHDVolDiskIDresult'\n";

if ( ( $existingRecoveryHDVolDiskIDresult != "" ) && ( $existingRecoveryHDVolDiskIDresult ne $parentDiskID) )
{
	print "Found exiting 'Apple_Boot' Recovery HD partition, using it for the restore next ...\n";
	$recoveryHDdiskDevID = "/dev/" . $existingRecoveryHDVolDiskIDresult;
}
elsif ( &createNewAppleBootPartition() != 0 )
{
		print "ERROR: createNewAppleBootPartition() failed, exiting.\n";
		exit (-1);
}

# ----------------------------------------------------------
# Restore the imaged 'Recovery HD' disk image via ASR:
# asr restore --source 10.7.0-Recovery-HD.dmg --target /dev/disk0s4 -erase --noprompt
#	Validating target...done
#	Validating source...done
#	Retrieving scan information...done
#	Validating sizes...done
#	Restoring  ....10....20....30....40....50....60....70....80....90....100
#	Verifying  ....10....20....30....40....50....60....70....80....90....100
#	Remounting target volume...done
# ----------------------------------------------------------

print "recoveryHDdiskImagePath = '$recoveryHDdiskImagePath'\n";

my $asrRestoreRecoveryHDvolume = system("/usr/sbin/asr --source \"" . $recoveryHDdiskImagePath . "\" --target " . $recoveryHDdiskDevID . " -erase --noprompt" ) >> 8;

if ( $asrRestoreRecoveryHDvolume != 0 )
{
	print "ERROR! Failed to restore the Mac OS X hidden 'Recovery HD' volume. Exiting.\n";
	exit(-1);	
}

# ----------------------------------------------------------
# Must UNMOUNT the restored volume next BEFORE using asr to change the partition type
# Check if the Recovery HD disk device ID is already unmounted or not...
# ----------------------------------------------------------

my $recoveryHDdiskDevIDumountCheckTmpLog = &generateLogFileName("recoveryHDdiskDevIDumountCheckTmpLog");

# Run the command again to get the result, assuming that it worked the first time we should be ok:
my $recoveryHDdiskDevIDumountCheck = `/usr/sbin/diskutil info -plist $recoveryHDdiskDevID | tee $recoveryHDdiskDevIDumountCheckTmpLog`;

if ( $recoveryHDdiskDevIDumountCheck != 0 )
{
	print "ERROR: Failed to obtain data located at /dev/$recoveryHDdiskDevID. Exiting.\n";
	exit (-1);
}
else
{
	print "Successfully obtain data on the disk located at $recoveryHDdiskDevID.\n";
}

$recoveryHDdiskDevIDumountCheck = `/usr/libexec/PlistBuddy -c "print MountPoint" $recoveryHDdiskDevIDumountCheckTmpLog`;
chomp($recoveryHDdiskDevIDumountCheck); # remove any hard returns

if ($recoveryHDdiskDevIDumountCheck eq "")
{
	print "The disk located at /dev/$recoveryHDdiskDevID is not mounted. No need to force an unmount, continuing ...\n";
}
else
{

	print "Unmounting the disk located at /dev/$recoveryHDdiskDevID next...\n";

	my $unmountRecoveryHDVolume = system("/usr/sbin/diskutil unmount force " . $recoveryHDdiskDevID ) >> 8;
	
	if ( $unmountRecoveryHDVolume != 0 )
	{
		print "ERROR! Failed to unmount the 'Recovery HD' volume before changing the partition type. Exiting.\n";
		exit(-1);	
	}
	
}

# ----------------------------------------------------------
# Change the disk partition type from "Apple_HFS" to "Apple_Boot" via asr:
#
# % asr adjust --target /dev/disk1s2 -settype "Apple_Boot"
#
# ----------------------------------------------------------

my $asrChangePartitionType = system("/usr/sbin/asr adjust --target " . $recoveryHDdiskDevID . " -settype \"Apple_Boot\"" ) >> 8;

if ( $asrChangePartitionType != 0 )
{
	print "ERROR! Failed to restore the Mac OS X hidden 'Recovery HD' volume. Exiting.\n";
	exit(-1);	
}

# If we've made it this far, assume everything worked!

print "\n*** Successfully created and restored the Recovery HD volume! End of $0. ***\n";

exit(0);

# END OF MAIN SCRIPT CODE

# ----------------------------------------------------------
# PROCEDURES/FUNCTIONS BELOW
# ----------------------------------------------------------
	
sub usage
{
  print "ERROR: Minimum number of parameters not received.\n";
  print "Usage: $programName /Volumes/NameOfDiskToAddRecoveryPartitionTo\n";
  print "Usage: $programName /Volumes/RestoredDiskVolumeName \"IP_OR_DHCP_STRING\" /dev/RestoredDiskDevID RestoredDiskTotalBytes\n";
}

sub generateLogFileName {

	my ($tmpLogFileName) = @_;
	my $tmpLogFileNameNew = sprintf "%s-%04d%02d%02d%02d%02d%02d", $lt[+5]+1900, $lt[4]+1, @lt[3,2,1,0];

	$tmpLogFileNameNew = "/tmp/$tmpLogFileName." . $tmpLogFileNameNew . ".log";

	return $tmpLogFileNameNew;
}

sub createNewAppleBootPartition {

	print "createNewAppleBootPartition() : ---->\n";
	
	print "No partitions found with the 'Apple_Boot' partition type, creating new partition next...\n";

	## grep the file for 'Apple_Boot'. If found, use PlistBuddy to determine which partition it is
	### grep -A 2  "Apple_Boot" /tmp/disk0Info.log
	### Remove all white space characters.
	### Do a pattern match for the string: "<string>Apple_Boot</string><key>DeviceIdentifier</key><string>disk0s3</string>"
	
	# ----------------------------------------------------------
	# Calculate the new resize value to add the 'Recovery HD' Volume:
	# ----------------------------------------------------------
	
	my $recoverHDBytes = 650002432; # At least 650 MB. 650002432 = exactly 1269536 512-Byte-Blocks.
	print "recoverHDBytes = $recoverHDBytes (Even number of 512-Byte-Blocks, standard disk block size.)\n";
	
	if ($RestoredDiskTotalBytes < $recoverHDBytes)
	{
		print "ERROR: There is not enough space on the restored disk ($RestoredDiskTotalBytes bytes) to create a 650 MB ($recoverHDBytes bytes) Recovery HD partition. Exiting...\n";
		print "createNewAppleBootPartition() : <----\n";
		return (-1);
	}
	
	my $newMainPartitionSizeInBytes = $RestoredDiskTotalBytes - $recoverHDBytes;
	print "newMainPartitionSizeInBytes = $newMainPartitionSizeInBytes\n";
	
	# ----------------------------------------------------------
	# Resize the partition and create a new 650 MB partition for the 'Recovery HD' Volume next:
	#
	# % diskutil resizeVolume disk1s2 31016951808b JHFS+ RecoveryHD_NOT_IMAGED 0b
	#
	# ----------------------------------------------------------
	
	my $recoveryHDtempVolName = "BIC_RecoveryHD_NOT_IMAGED_YET";
	print "recoveryHDtempVolName = '$recoveryHDtempVolName'\n";
	
	my $createRecoveryHDPartition = system("/usr/sbin/diskutil resizeVolume " . $RestoredDiskDevPath . " " . $newMainPartitionSizeInBytes . "b JHFS+ " . $recoveryHDtempVolName . " 0b" ) >> 8;
	
	if ( $createRecoveryHDPartition != 0 )
	{
		print "ERROR! Failed to create new partition. Exiting.\n";
		print "createNewAppleBootPartition() : <----\n";
		return (-1);
	}
	
	$recoveryHDdiskDevID = system("/usr/sbin/diskutil info -plist /Volumes/" . $recoveryHDtempVolName . "| /usr/bin/grep -A 1 \"<key>DeviceNode<\/key>\"" ) >> 8;
	
	# need to get the return value in addition to the exit value here...
	
	if ( $recoveryHDdiskDevID != 0 )
	{
		print "ERROR! Failed to obtain RecoveryHD Disk Device ID. Exiting.\n";
		print "createNewAppleBootPartition() : <----\n";
		return (-1);
	}
	
	my $recoveryHDdiskDevIDtmpLogFile = &generateLogFileName("recoveryHDdiskDevIDtmpLogFile");

	# Run the command again to get the result, assuming that it worked the first time we should be ok:
	$recoveryHDdiskDevID = `/usr/sbin/diskutil info -plist /Volumes/$recoveryHDtempVolName | tee $recoveryHDdiskDevIDtmpLogFile`;
	
	print "Restore Disk Device ID, BEFORE Plistbuddy extract = '$recoveryHDdiskDevID'\n";
	
	# Macs-MacBook-Pro:~ macadmin$ /usr/libexec/PlistBuddy -c "print DeviceNode" /tmp/justin.txt 
	# /dev/disk0s3
	$recoveryHDdiskDevID = `/usr/libexec/PlistBuddy -c "print DeviceNode" $recoveryHDdiskDevIDtmpLogFile`;
	chomp($recoveryHDdiskDevID); # remove any hard returns
	
	if ($recoveryHDdiskDevID eq "")
	{
		print "ERROR: Unable to determine the recoveryHDdiskDevID from the '$recoveryHDtempVolName' volume. Exiting.\n";
		print "createNewAppleBootPartition() : <----\n";
		return (-1);
	}
	
	print "Restore Disk Device ID path is '$recoveryHDdiskDevID'\n";

	print "createNewAppleBootPartition() : <----\n";
	return (0);

}
