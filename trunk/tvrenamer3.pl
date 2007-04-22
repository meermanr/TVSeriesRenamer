#!/usr/bin/perl
# TV Renamer Script {{{1

#------------------------------------------------------------------------------
# Written by: Robert Meerman (robert.meerman@gmail.com)
# Website: http://robmeerman.co.uk/coding/file_renamer
#
# Please send comments, feature requests, bugs, etc to the address above.
# If you find this useful, I'd love to hear from you - I love the attention :)
#------------------------------------------------------------------------------
# Recent changes (see bottom of file for complete version history):
#------------------------------------------------------------------------------
#	v3.0	{{{2
#	  * Pretty-much complete rewrite, mostly done for ease of maintenance and
#		the desire to play with more advanced features of perl.
#------------------------------------------------------------------------------
# To Do:	{{{1
#	  * Lots, it's a complete rewrite.
#------------------------------------------------------------------------------

use strict;		# {{{1
use warnings;
use diagnostics;


use English qw( -no_match_vars );	# Long name for built-in vars, such as $OSNAME vs $^O
use Data::Dumper;					# Pretty prints data structures, used for debugging

use Switch;			# Switch statements make things more readable
use Term::ReadKey;	# Allows unbuffered input (so no waiting to press enter etc)

use constant true	=> (1==1);
use constant false	=> (!true);

# Globals {{{1
my %Capabilities;	# e.g. Active internet connection? ANSI colour?
my %Options;		# e.g. Debugging? File-by-file prompt? Input URL?

# ANSI colour codes
my ($ANSInormal, $ANSIbold, $ANSIblack, $ANSIred, $ANSIgreen, $ANSIyellow, $ANSIblue,
	$ANSImagenta, $ANSIcyan, $ANSIwhite, $ANSIsave, $ANSIrestore, $ANSIup, $ANSIdown);

	$ANSInormal  = $ANSIbold    = $ANSIblack   = $ANSIred     = $ANSIgreen   =
	$ANSIyellow  = $ANSIblue    = $ANSImagenta = $ANSIcyan    = $ANSIwhite   =
	$ANSIsave    = $ANSIrestore = $ANSIup      = $ANSIdown    = "";

# Short cuts for dense areas of code
my $C = \%Capabilities;
my $O = \%Options;

# Default Options (can be overridden using a preferences file or the command
# line)
$Options{"verbositylvl"}	= 0;
$Options{"debug"}			= defined $ENV{'DEBUG'};
$Options{"ANSI"}			= true;

# Detect system capabilities (internet connection, colour terminal etc) {{{1
## Internet connection {{{2
## | As I don't know how to detect this atm, I'll assume everyone has
## | internet access for now. They can always override it with a switch.
$Capabilities{"internet"} = true;

## Colour (ANSI escape sequence) support {{{2
## | All non-Microsoft operating systems can be assumed to support ANSI, for
## | Microsoft OSes you can install and use the Win32::Console::ANSI perl module.
## | Install it from http://www.bribes.org/perl/wANSIConsole.html#d and comment in
## | the "use" line below.

#use Win32::Console::ANSI;  # Automatically commented-in during Win32 binary builds

if($OSNAME eq "MSWin32")	# Microsoft Windows
{
	# Is the work-around module loaded?
	$Capabilities{"ANSI"} = defined $INC{"Win32/Console/ANSI.pm"};
}
else
{
	$Capabilities{"ANSI"} = true;
}

# Detect current context (working directory et al) {{{1
# Read in preferences and command-line options {{{1
# | The preferences file, .tvrenamerrc, if found contains command-line arguments,
# | one-per-line which will be place _before_ any actual command-line args.
my $tvrenamerrc = '';
if(defined $ENV{'HOME'} && -e "$ENV{'HOME'}/.tvrenamerrc")
{
	$tvrenamerrc = "$ENV{'HOME'}/.tvrenamerrc";
}
if(defined $ENV{'USERPROFILE'} && -e "$ENV{'USERPROFILE'}/.tvrenamerrc")
{
	$tvrenamerrc = "$ENV{'USERPROFILE'}/.tvrenamerrc";
}
unless($tvrenamerrc eq '')
{
	debugprint("Reading preferences from $tvrenamerrc\n");
	open(RCFILE, "< $tvrenamerrc");
	while(<RCFILE>)
	{
		chomp;
		@ARGV = ($_, @ARGV);
	}
	close(RCFILE);
}
debugprint("Effective command-line is: ", join(" ", @ARGV), "\n");
if($#ARGV ne -1)
{
	foreach(@ARGV){
		switch ($_) {
			case /^--online$/i		{$Options{"internet"}=true;}
			case /^--offline$/i		{$Options{"internet"}=false;}
#			case /^--autofetch$/i    {$implicit_format = 0; $format = Format_AutoFetch;}
#			case /^--autodetect$/i   {$implicit_format = 0; $format = Format_AutoDetect;}
#			case /^--anidb$/i        {$implicit_format = 0; $format = Format_AniDB;}
#			case /^--tvtorrents$/i   {$implicit_format = 0; $format = Format_TVtorrents;}
#			case /^--tvtome$/i       {$implicit_format = 0; $format = Format_TVtome;}
#			case /^--tv$/i           {$implicit_format = 0; $format = Format_TV;}
#			case /^--tv2$/i          {$implicit_format = 0; $format = Format_TV2;}
#			case /^--epguides$/i     {$implicit_format = 0; $format = Format_EpGuides;}

#			case /^--search=.*$/i	 { /^--search=(.*)$/i;
#										if(/anime/i){ $search_anime=1; }
#										else{ $search_anime=undef; }
#									 }

#			case /^--scheme=.*$/i    {/^--scheme=(.*)$/i; $scheme = $1;}
#			case /^--series=.*$/i    {/^--series=(.*)$/i; $series = $1;}
#			# Note that $exclude_series is 1 by factory default
#			case /^--include_series$/i {$exclude_series = 0;}
#			case /^--exclude_series$/i {$exclude_series = 2;}
#			case /^--season=.*$/i    {/^--season=(.*)$/i; $season = $1;}
#			case /^--autoseries$/i   {$autoseries = 1;}
#			case /^--noautoseries$/i {$autoseries = 0;}
#			case /^--nogroup$/i      {$nogroup = 1;}
#			case /^--nogap$/i        {$gap = undef;}
#			case /^--gap$/i          {$gap = ' ';}
#			case /^--gap=.*$/i       {/^--gap=(.*)$/i; $gap = $1;}
#			case /^--separator=.*$/i {/^--separator=(.*)$/i; $separator = $1;}
#			case /^--detailed$/i     {$detailedView = 1;}
#			case /^--interactive$/i  {$interactive = 1;}
#			case /^--unattended$/i   {$unattended = 1;}
#			case /^--cache$/i        {$nocache = 0;}
#			case /^--nocache$/i      {$nocache = 1;}

#			case /^--dubious$/i      {$dubious = 1;}
#			case /^--nodubious$/i    {$dubious = undef;}
#			case /^--rangemin=.*$/i  {/^--rangemin=(.*)$/i; $rangemin= $1;}
#			case /^--rangemax=.*$/i  {/^--rangemax=(.*)$/i; $rangemax= $1;}
#			case /^--autoranging$/i  {$autoranging = 1;}
#			case /^--noautoranging$/i{$autoranging = 0;}
#			case /^--series$/i       {$series = undef;}
#			case /^--pad=.*$/i       {/^--pad=(.*)$/i; $pad= $1;}
#			case /^--nofilter$/i     {$filterFiles = undef;}
#			case /^--unixy$/i        {$unixy = 1;}
#			case /^--cleanup$/i      {$cleanup = 1;}
			case /^--colour|--color$/i		{$Options{"ANSI"} = true;}
			case /^--nocolour|--nocolor$/i	{$Options{"ANSI"} = false;}
#			case /^--reversible$/i   {$reversible = 1;}

#			case /^--preproc=.*$/i   {/^--preproc=(.*)$/i; $preproc = $1;}
#			case /^--postproc=.*$/i  {/^--postproc=(.*)$/i; $postproc = $1;}

			case /^--associate[-_]video[-_]folders$/	{$Options{"associate_action"} = "install";}
			case /^--unassociate[-_]video[-_]folders$/	{$Options{"associate_action"} = "uninstall";}

#			case /^--help$/i        {print $helpMessage; exit;}
#			case /^--version$/i     {print $version; exit;}
#			
			case qr/^-.+/           {print STDERR "Invalid option $_!\n";
										$Options{"invalid_switch"} = true;}
#			else                    {$implicit_format = 1; $inputFile = $_; $format= Format_AutoDetect;}
		}
	}
}

if($Options{"debug"})
{
	print Dumper(\%Capabilities, \%Options);
}

if( $Options{"invalid_switch"} )
{
	$Options{"print_help"} = true;
	debugprint("Quitting due to invalid option.\n");
	# FIXME: Pause here?
}
if( $Options{"print_help"} )
{
	print
"Usage: $PROGRAM_NAME [OPTIONS] [FILE|URL|-]

 Renames files in the current directory either using data provided, or
 attempting to find the relevant data on the internet.

 [More options to come later, a big re-write is underway]

System capabilities:
 --online		Assume an internet connection is available to the script
 --offline		Do not attempt to access the internet
 --colour		Display text in colour
 --nocolour		Don't display text in colour (can cause weird output)

Misc:
 You enable debugging by setting an environment variable called DEBUG.

 Website: http://robmeerman.co.uk/coding/file_renamer

 Report bugs to robert.meerman\@gmail.com, I love the attention.
";
exit 1;
}

# Init any options as required {{{1
## Define ANSI variables {{{2
## | These were defined earlier, and are currently NULL
if($Capabilities{"ANSI"} && $Options{"ANSI"}){
	$ANSInormal  = "\e[0m";
	$ANSIbold    = "\e[1m";
	$ANSIblack   = "\e[30m";
	$ANSIred     = "\e[31m";
	$ANSIgreen   = "\e[32m";
	$ANSIyellow  = "\e[33m";
	$ANSIblue    = "\e[34m";
	$ANSImagenta = "\e[35m";
	$ANSIcyan    = "\e[36m";
	$ANSIwhite   = "\e[37m";
	$ANSIsave    = "\e[s";
	$ANSIrestore = "\e[u";
	$ANSIup      = "\e[1A";
	$ANSIdown    = "\e[1B";
	debugprint("Enabing ANSI colour.\n");
}

## (Un)Associate with video folders in Win32
if(defined $Options{"associate_action"})
{
	switch($Options{"associate_action"})
	{
		# Exit with error code returned by subroutine
		case "install"		{exit &associate_video_folders();}
		case "uninstall"	{exit &unassociate_video_folders();}
	}
}

# Parse filelist from current directory (create list of episode numbers that {{{1
# need titles)
# Acquire episode titles (data -> eptitle array) {{{1
# XXX: Keep results from all analysis. Iterate it later to pick "best match"
## / Copy'n'Paste via STDIN
## \ Copy'n'Paste via cached text file
## / Use URL provided
## \ Search web, then use URL
# Construct new filenames for current directory {{{1
# Selection process ((interactive) accept/reject) {{{1
# TODO: Ability to switch between title result sets {{{1
# TODO: Allow config settings (preference + command line options) to be
# overridden and script reran from here
# Rename files (+ create undo info as requested) {{{1
## TODO: Add option to create symlinks instead of rename (allows continued
## uploading for BitTorrent etc)

sub alert
{
	print $ANSIbold,@_,$ANSInormal;
}
sub verboseprint
{
	if( shift le $Options{"verbositylvl"} )
	{
		print $ANSIcyan,@_,$ANSInormal;
	}
}

sub debugprint
{
	if( $Options{"debug"} )
	{
		print $ANSImagenta,@_,$ANSInormal;
	}
}

# Utility functions
#------------------------------------------------------------------------------
sub unassociate_video_folders
{
	alert("Unassociate action invoked, no renaming will take place.\n");
	open(FH, '> tvrenamer_unassociate_win32.reg');
	print FH "REGEDIT4\n\n";
	print FH "[-HKEY_CLASSES_ROOT\\SystemFileAssociations\\Directory.Video\\shell\\tvrenamer]\n";
	close(FH);

	qx/regedit -s tvrenamer_unassociate_win32.reg/;
	unlink("tvrenamer_unassociate_win32.reg");
	alert("Associateion has been removed.\n\n");
	print "You will no longer see \"Use TV Renamer script\" when you right\n";
	print "click a video folder\n";
}

sub associate_video_folders
{
	my $invokation = $EXECUTABLE_NAME;	# aka $EXECUTABLE_NAME, a built-in global
	my $script_location = $0;
	my $cd;
	my $script_name;
	alert("Associate action invoked, no renaming will take place.\n");

	if($OSNAME eq "cygwin")
	{
		# Simple, just use the "cygpath --dos --absolute" command to convert to a Win32 path
		$invokation = `cygpath --dos --absolute $invokation`;
		chomp $invokation;
		$script_location = `cygpath --dos --absolute $script_location`;
		chomp $invokation;
	}
	elsif($OSNAME eq "MSWin32")
	{
		# Deal with relative directories
		$script_location =~ tr/\//\\/;
		if( substr($script_location, 1, 1) ne ':' ) # Consider "c:\Progr..."
		{
			# Path is not absolute, need to mangle
			if( $script_location =~ /\\/ )	# Has at least one backslash
			{
				($cd, $script_location) = split(/\\(?=[^\\]*?$)/, $script_location);	# Split on last '\'
				chdir $cd;
				$cd = getcwd();
				$script_location = "$cd\\$script_location";
			}
			else
			{
				# Missing path entirely, must be in current dir then
				$cd = getcwd();
				$script_location = "$cd\\$script_location";
			}
		}

		# Get short-name for path (8.3 filenames)
		## NB: '@' before a command in a DOS script executes it without local echo,
		## i.e. it doesn't type the command text to the screen or its accompanying prompt
		$invokation = qx/for %I in ("$invokation") do \@echo %~sI/;
		$script_location = qx/for %I in ("$script_location") do \@echo %~sI/;
		chomp $invokation;
		chomp $script_location;

	}
	else
	{
		print "It is this script's opinion that you are not using a Windows-based OS,\n";
		print "if you think you know better, you can try anyways.\n";
		print "Take a stand? [y/${ANSIbold}N${ANSInormal}]: ";

		ReadMode "cbreak";
		$_ = ReadKey();
		ReadMode "normal";
		
		if($_ =~ /y| |\x0a|\.|>/i){    # 'Y', space, enter or the '>|.' key
			print $ANSIgreen."y\n".$ANSInormal;
			print "\nOK then, hotshot, here are my guesses as to how you run this script:\n";
			print "Perl:   $EXECUTABLE_NAME\n";
			print "Script: $0\n";
			print "Anything about that strike you as odd? [y/${ANSIbold}N${ANSInormal}]: ";

			ReadMode "cbreak";
			$_ = ReadKey();
			ReadMode "normal";

			if($_ =~ /y| |\x0a|\.|>/i){    # 'Y', space, enter or the '>|.' key
				print $ANSIgreen."y\n".$ANSInormal;
				print "\nTough! The author hasn't implemented this option yet! :P\n";
				print "Email the bastard at robert.meerman\@gmail.com and tell him to sort\n";
				print "his act out, and what freaky version of Windows you think you're\n";
				print "using.";
				exit 1;
			}else{
				print $ANSIred."n\n".$ANSInormal;
				print "\nPeachy, then let's get going!\n";
			}
		}else{
			print $ANSIred."n\n".$ANSInormal;
			print "\nProbably wise. Another time perhaps?";
			exit 1;
		}
	}
	$invokation =~ s/\\/\\\\/g;
	$script_location =~ s/\\/\\\\/g;
	$script_location =~ s/^(.*)\n/$1/;	# Inexplicibly multiline string. Keep only first line
	open(FH, '> tvrenamer_associate_win32.reg');
	print FH "REGEDIT4\n\n";
	print FH '[HKEY_CLASSES_ROOT\SystemFileAssociations\Directory.Video\shell\tvrenamer]',"\n";
	print FH '@="Use T&V Renamer script"',"\n";
	print FH "\n";
	print FH '[HKEY_CLASSES_ROOT\SystemFileAssociations\Directory.Video\shell\tvrenamer\command]',"\n";
	if( $script_location =~ m/.EXE$/i )
		{ print FH '@="cmd /C \"cd %1 & ',$script_location,' & pause\""',"\n"; }
	else
		{ print FH '@="cmd /C \"cd %1 & ',$invokation,' ',$script_location,' & pause\""',"\n"; }
	close(FH);

	qx/regedit -s tvrenamer_associate_win32.reg/;
	unlink("tvrenamer_associate_win32.reg");
	print "${ANSIcyan}Association created.${ANSInormal}\n\n";
	print "When you right click a video folder, you will see a new option \"Use\n";
	print "TV Renamer script\", enjoy!\n";
}

#------------------------------------------------------------------------------
# Version History {{{1
#------------------------------------------------------------------------------
#  v1.0 First, useful, version (Late 2001) {{{2
#  v1.1 Fixed problem where series name had a number in it (was mistaken for EpNumber) {{{2
#   Improved extention handling ( made it more generic )
#       Improved invalid character swapping ( " for ', and correct mistake in ? deletion)
#   Added   "Pre-fix series name",
#       "Replace series name",
#       "remove specific text" and
#       "Force extension to lowercase"
#  v1.2 Fixed [] and () removal problem ( didn't match minimally ) {{{2
#  v1.3 Updated pattern matching to reflect changes in AniDB.net table layout {{{2
#  v1.4 Completed (Win32) invalid char replacement list {{{2
#   Corrected misc typos in comments
#  v1.5 Many user prompt changes, fixed bugs where epTitles were repeated in renaming {{{2
#        due to an oversight in the 'extract fileExt' code
#   Improved handling for two-digit 'special ep' numbers
#  v1.6 Introduced a "No changes nessesary" message {{{2
#   Revised "New names" to "Names to change" at user scruteny stage
#   Vast improvement to data structure, input no longer needs to be sorted, or complete
#   User is also warned when a file does not appear to have an episode number,
#   and when no related data can be found on a particular file.
#  v1.7 Added ability to read AniDB table from input files {{{2
#  v1.8 Updated to fit new AniDB table layout, as well as my switch to Firefox from IE {{{2
#   also added misc clean-up for unnecessary whitespace / orphaned hypens before an extension
#  v1.9 [Never existed, jumped to v2.0] {{{2
#  v2.0 Complete rewrite of most areas. For one, it's no longer "Anime Renamer" but "TV Series Renamer" {{{2
#   - Support for TVtorrents.com format
#   - Series renaming approached in new manner - find episode number, and discard everything else
#   - Allow series name to be specified from command-line
#   - New support for s1e08, 1x08 and (with '-dubious' option) 108 epNumber formats
#   - File filters via reg expression (can be disabled with '-nofilter' option)
#   - Script always skips over itself when renaming, and it's input file (if used)
#   - Searches for AniDB.txt and TVtorrents.txt by default, setting appropriate format if found
#   - Series name is assumed to be the currect directory's name unless otherwise specified/overridden
#   - Option to display detailed proposal ('before -> after', instead of just 'after')
#   - Added "-preproc" option to allow easy one-time script alterations
#   - Checks target files names, so files won't be inadvertantly wiped out anymore
#   - Checks input for multiple definitions of the same episode, displays warnings as appropriate.
#   - Ep number is padded with leading zeros to match length of largest epNumber in input
#   - Group tags (such as '[AniCo]') are now preserved. Can be stripped by using '-nogroup' option
#   - Added '-unixy' option to replace spaces with underscores (usually it's the other way around)
#
#  v2.1 Re-coded to avoid use of 'enum' package as most don't seem to have it {{{2
#   - "Group" tags are checked against episode titles, and dropped as appropriate
#   - Added -postproc option to allow easy one-time script alterations.
#   - Improved file-already-exists detection (no more 'Duplicate target...' errors when the problem is
#     the target already exists)
#   - Considerable rewrite of many areas (added subroutines & clean-up), should be easier to extend now
#
#  v2.2 Added "-cleanup" option to allow renaming without input: still moves group tags to the end and {{{2
#     works with some other switches (-unixy, -detailed and -nofilter)
#   - BugFix: Episode number is mistakenly extracted from a group tag
#   - Automatically applies "-nogap" if series name ends with a x preceeded by a digit
#
#  v2.3 Fixed glitch in logic which meant that "[group] series ep#.ext" type filenames would still  {{{2
#     incorrectly extract the episode number from the series name if it contains one (such as Ichigo 100%,
#     or Samurai 7). This was due to the presence of the [group], so I fiddled the order these are handled.
#   - Fixed bug which always printed "1 dubious names extraction" regardless of the true count, and tweaked
#     it so dubious name extractions don't count as warnings anymore
#
#  v2.4 Added TVtome.com support to recognised formats {{{2
#   - Added option to display a detailed view at the confirmation prompt (enter '?' to do so)
#
#  v2.5 Omit "(Complete)" from end of series name, if present {{{2
#   - Added "AutoDetect format" feature (now the default)
#   - BUGFIX: No longer loses last char of TVtome input in STDIN mode (changed assumption of "\n" to "\r")
#   - BUGFIX: epNumber padding was misaligned (would only pad to two digits if ep 11 existed, instead of just 10)
#
#  v2.6 Added "TV.com" format support (TVtome.com has been replaced!) {{{2
#   - BUGFIX: Sometimes would expect multi-line repsonse to "Proceed with changes? [y/n/?]"
#
#  v2.7 Added 'TV.com "All Seasons"' format support - this uses the "All Seasons" episode listing for {{{2
#     a season, and overcomes issues with episode numbers in seaons 2 onwards being offset (i.e. 2x01 would be
#     listed at episode 16).
#   - Added some colouring to ouput (red errors etc), and fiddled default verbosity
#   - Now beeps only if parsing produced warnings
#   - Added .mp4 to list of default extensions
#
#  v2.8 Internal limitation fix (episodes numbered '0' are now allowed) {{{2
#   - Added "interactive" mode which allows manually selection of changes
#   - Added (unpolished) support for double-episodes (i.e. 11-12, 01-02, 1-2, 11&12, etc)
#   - Changed the way userprompts work (automatically grabs first keystroke)
#   - BUGFIX: Renumbering 0|Pilot to 1|Pilot did not actually check the epTitle
#
#  v2.9 Added file number schemes, now supports sXXeYY, XxYY and YY. Default behaviour is unchanged. {{{2
#   - Changed all command-line options to have two minus signs - EG "-AutoDetect" became "--AutoDetect". This is
#     move conventional.
#   - BUGFIX: Leading/trailing whitespace was sometimes included around episode title in the proposed filename.
#
#  v2.10 BUGFIX: Episode "Specials" were not been given titles {{{2
#   - Episode "Specials" now support double-episode, not that I think that'll ever be used.
#
#  v2.11 Added ability to fetch and parse input from the web {{{2
#   - Added new parser for AniDB html pages ("AniDB (fetched)" format)
#   - Improved autodetect code, now it's a bit easier to understand when adding / updating parsers
#
#  v2.12 Added parser for "TV.com All Seasons (fetched)" format. {{{2
#   - Scans for any *.URL or *.desktop file and grabs the link from it (.URL being a standard Windows internet 
#     shortcut, while .desktop is the standard KDE / Gnome one), although any text file named something.URL with
#     an URL in it works.
#   - Changed default behavious with regards to dubious file number extraction
#  v2.13 Introduced "--rangemin", "--rangemax", "--autoranging" and "--noautoranging" to help control and overcome {{{2
#     difficult input sources, such as TV.com All Seasons Mode (fetched) for Lost, which has some "special" episodes
#     for season two marked as episode 200 and 201 (i.e. S02E200, S02E201). Auto-Ranging looks for a large gap in
#     the input, and discards everything after this gap. You can also manally specify these values.
#
#  v2.14 BUGFIX Duplicate entries in input started an infinite loop issuing warnings, thanks to Rolf Wojtech for fixing this! {{{2
#
#  v2.15 Added "--autoseries" switch, which grabs the series name from scraped data if possible {{{2
#   - Updated filename parser to recognise "S1- E08" and "S1-E08"
#   - Added "--ANSI" and "--noANSI" to enable / disable colour. This will be useful for those using DOS without
#     "Win32::Console::ANSI" (which you can comment in at the top of the script).
#
#  v2.16 Rewrote TVTorrents (pasted) parser {{{2
#   - Converted "TV.com "All Seasons" (fetched)" mode -> "TV.com (monotonic)" mode and worked around TV.com's nasty decisions to 
#     discard season/episode information in their all seasons listings. >.<
#   - Fixed oversight: Specifying an input format / source has priority over auto-detected choice now.
#   - Added "--autofetch" mode, which searches TV.com for the episode listing, and saves a link to avoid repeating the search
#   - Deprecated "TV.com All Seasons mode" - script now attempts to convert URLs from All Season to normal on the fly
#   - BUGFIX: Double episode support fixed (i.e. "Bleach 68-69.avi" & "Bleach S01E68-69.mpg" & "Bleach 68&69.mkv" etc)
#
#  v2.17 Proposed changes are now sorted by destination, making it easier to check {{{2
#   - "--separator=X" switch added. This allows you to specify the text that
#     appears between the episode number and the title (the default is " - ")
#   - Added EpGuides format (both pasted and fetched mode). "--EpGuides" or the
#     presence of "EpGuides.txt" will force the script to use EpGuides format.
#   - Added new preference "preferredSite", which dictates which site AutoFetch
#     mode searchs for data. Can be one of:
#      "TV.com" and "EpGuides.com". Default is now EpGuides.com.
#   - Added fallback to pilot episode name for EpGuides format. Much more
#     elegant that previous solutions
#   - Added "--pad=X" arugment which allows you to specify the number of digits
#     to pad the episode number to (E.G ep8 -> ep008 for "--pad=3")
#   - Season number in files names is now used to filter which episodes are
#     considered for renaming. So now having series 1 and 2 in the same folder
#     should be possible without problems, so long as the file names specify the season.
#   - Misc usability improvements, such as colour in error messages and
#     prompting user for clarifications (EG when season and URL season don't agree)
#   - ANSI colour disabled when script run in DOS
#   - BUGFIX: Command-line argument for input source is always respected (was just searching TV.com... >.< )
#
#  v2.18 Added unattended mode on request (--unattended) {{{2
#
#  v2.19 Reformatted --help message to fit within 80-char wide terminals. Heh. {{{2
#   - Season-name detection expanded to use parent directory name if current
#     directory is called "Series 1" or "Season 2" etc
#   - Changes are now reversible via use of the "--reversible" switch which
#     creates (or updates) an undo script. Win32 stand-alone
#     users will be treated to a BATCH script, everyone else will get a PERL one. (unrename.bat / unrename.pl)
#
#  v2.20 Added --gap=X, to allow custom gap characters (such as "." which was requested) {{{2
#   - Fixed support for AniDB (they were gzipping their webpages)
#   - Added anime detection (looks for "anime" within absolute path to current directory)
#   - Added "--search=X" argument. Can be either "anime" or "tv", and defines which
#     set of sites to search.
#   - Extended AutoFetch to search AniDB.info
#	- Added Unicode support, *even for windows*, which was a non-trivial task as google will
#	  assert. So now HTML Entities are represented as Unicode (EG: "&#9829;" -> "♥"). Tested
#	  with ASCII containing HTML Entities and UTF-8 containing Kanji.
#
#  v2.21 Fixed bug AutoFetch mode which caused many searches to fail with AniDB {{{2 
#  (spaces were not being converted to %20 when sending data to the website).
#
#  v2.22 BUGFIX: --reversible didn't log non-Unicode name changes in Windows / Cygwin {{{2
#
#  v2.23 Tidied --help up a lot and revisited many comments in the script proper {{{2
#        Added --exclude_series, which excludes the series name from the new filename
#         and counter-part --include_series to override this (incase you set it to be
#         default)
#        Changed default behaviour, series name is dropped when current dir is called
#         "series 1" or similar
#        Added support for a preferences file. Place command-line arguments, one per
#         line, in a file called ".tvrenamerrc" in your home directory to use this.
#         Windows users: Your home directory is what you get when you go Start > Run
#         "explorer ." > OK  -  Note the "." in that command!
#
#  v2.24 Updated to match changed to AniDB's page layout. {{{2
#        BUGFIX: Fixes support for "s01 e01" in file names (space wasn't
#                allowed before)
#
#  v2.25 AniDB search facility fixed, this also broke because of the new AniDB layout {{{2
#
#  v2.26 Added --associate-with-video-folders and --unassociate-with-video-folders, {{{2
#         a pair of windows-specific switches to (un)install a registry change that
#         adds "Use TV Renamer Script" to the right-click menu of video folders
#
#  v2.27 BUGFIX: Season numbers are treated as numbers now (were treated as strings), {{{2
#         so season "06" becomes "6", which fixed automatic fetching from the web.

# vim: set ft=perl ff=unix ts=4 sw=4 sts=4 fdm=marker fdc=4:
