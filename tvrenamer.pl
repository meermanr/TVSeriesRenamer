#!/usr/bin/perl
# This script is designed to rename anime/TV series which are arranged {{{1
# in folders (so all files in current directory can be assumed to belong to one
# series).
#------------------------------------------------------------------------------
# Written by: Robert Meerman (robert.meerman@gmail.com, ICQ# 37099562)
# Website: http://www.robmeerman.co.uk/coding/file_renamer
#
# Please send comments, feature requests, bugs, etc to the address above.
# If you find this useful, I'd love to hear from you - I love the attention :)
#------------------------------------------------------------------------------
# Recent changes (see bottom of file for complete version history):
#------------------------------------------------------------------------------
#
#  v2.51 MAINTENANCE: AniDB scraper updated in sympathy with site changes
#        ENHANCEMENT: Season number detection now supports following directory 
#        name / layouts:
#
#          SeriesName/2
#          SeriesName/Series 2
#          SeriesName/Season 2
#          SeriesName 2x
#          SeriesName (2)
#
#  v2.52 FEATURE: List episodes missing from the user's collection with
#        --show-missing. (Thanks Baldur Karlsson!)
#        MAINTENANCE: --include_series and --exclude_series became 
#        --include-series and --exclude-series (underscore became hyphen). Old 
#        option names are still accepted (for compatibility with .tvrenamerrc 
#        files)
#
#  v2.53 MAINTENANCE:
#            EpGuides support updated to cope with annoying links to trailers / 
#            recaps etc which now appear as <spans> within the episode titles.  
#            Thanks to Frederic and Jasper for bringing this to my attention.
#        MAINTENANCE:
#            Added m4v to the filename filter (thanks Frederic!)
#
# TODO: {{{1
#  (Note most of this list is being ignored due to work on the v3 rewrite of this script in Python)
#	* Hellsing 2006 doesn't parse properly: http://anidb.net/perl-bin/animedb.pl?show=anime&aid=3296
#   * Update Default Settings section to explain the use of a preferences file,
#     the preferred way of setting defaults (pardon the pun)
#   * Test Unicode support properly, and see if a workaround for Win32 source
#     filenames can be found
#   * Migrate @before & @after arrays to a single hash (partly done)
#   * Add dubious autodetect based on exisiting files (i.e. prepare two sets of
#     changes, and then pick the one which causes the least active change
#     (no-changes due to lack of input don't count))
# }}}
#use warnings;				# I'm not that leet {{{
use strict;					# Let's be scientific about this
use Term::ReadKey;			# Allows single keypresses to be detected (so no need to press <ENTER> all the time)
use Cwd;					# Current Working Directory library
use LWP::Simple;			# Adds get($url) function
use URI::Escape;			# Convenient translation of " " <-> %20 etc in URIs
use Compress::Zlib;			# AniDB sends us gzip'd data, and I can't persuade it not to!
use File::Glob ':glob';		# Avoids using "perlglob(.exe)" which makes for neater Win32 stand-alone versions
use Encode;					# Allow importing of UTF-8 data and generation of UTF-16LE names for Win32API::File

if($^O eq "MSWin32" || $^O eq "cygwin"){
	require Win32API::File;	# Low-level calls to circumvent windows Unicode hell
	require Encode;			# Win32API::File expects unicode arguments in UTF16-LE
}

binmode(STDOUT, ":utf8");	# Suppress warnings about Unicode characters in output

#}}}
# Colour in DOS {{{
# Install the Win32::Console::ANSI module from http://www.bribes.org/perl/wANSIConsole.html#d (or CPAN)
# and comment in the line below to enable it's use. That's it ;-)
#
# Alternatively, set "ANSIcolour = 0" in the default settings bit to supress the warning
#use Win32::Console::ANSI;  # Hack to fix up Win32 console to support ANSI  (http://www.bribes.org/perl/wANSIConsole.html#dl)

my @FormatList = ("AutoFetch", "AutoDetect", "AniDB (fetched)", "TV.com (monotonic)", "EpGuides", "AniDB", "TVtorrents", "TVtome", "TV.com \"All Seasons\"", "TV.com");
use constant Format_AutoFetch   => 0;
use constant Format_AutoDetect  => 1;
use constant Format_URL_AniDB   => 2;
use constant Format_URL_TV2     => 3;   # i.e. "All Seasons" episode list
use constant Format_EpGuides    => 4;
use constant Format_AniDB       => 5;
use constant Format_TVtorrents  => 6;
use constant Format_TVtome      => 7;
use constant Format_TV2         => 8;   # Preferred over older Format_TV
use constant Format_TV          => 9;
use constant NumFormats         => 10;

my @SiteList = ("EpGuides.com", "TV.com");
use constant Site_EpGuides	=> 0;
use constant Site_TV		=> 1;
use constant NumSites		=> 2;
#------------------------------------------------------------------------------}}}
# Default settings {{{
#------------------------------------------------------------------------------
# Change this to match your primary use of the script
# Set 'disabled' entries to 1 to enable them, and set 'not set' variables to a string
# to enable them
# EG: my $unixy = 1; is equivalent to always specifying '--unixy' on the command line
# EG: my $inputFile = "../$series.txt"; will look for text file in parent dir, named after this dir/series

my $format       = Format_AutoFetch;
my $site         = Site_EpGuides;	# Preferred site search for title data. NB: These are tried in the order they are listed above
my $search_anime = undef; 			# Search TV sites

my $filterFiles  = '\.(avi|mkv|ogm|mpg|mpeg|rm|wmv|m4v|mp4|mpeg4|mov|srt|sub|ssa|smi|sami|txt)$';
my ($series)     = (getcwd() =~ /\/([^\/]+)$/);     # Grab current dir name, discard rest of path
my $exclude_series     = 1;	# 0=Always include series name, 1=Exclude if cwd is "Series X", 2=Always exclude
my $autoseries   = 0;	# Do not automatically use scraped series name
my $gap          = ' ';	# Comes between series name/prefix & episode number
my $separator    = ' - '; # Comes between episode number and episode title
my $scheme       = undef; # Not set
my $season       = undef; # Not set (use detected)
my $inputFile    = undef; # Not set (scan for appropriate file)
my $preproc      = undef; # Not set
my $postproc     = undef; # Not set
my $rangemin     = undef; # Not set
my $rangemax     = undef; # Not set
my $autoranging  = 1;     # Perform AutoRanging
my $pad			 = undef; # Automatically choose padding (i.e. "8" -> "08" if there are 10 or more episodes in the input)

my $nocache      = 1;     # Do not use/make .cache files
my $dubious      = 0;     # Take file numbers above 99 literally
my $nogroup      = undef; # Use auto-detection (Anime: Keep group, other: Discard)
my $dontgroup    = 0;     # Whether group-extraction is enabled or not (0 = "Do extract", 1 = "No special treatment")

my $detailedView = undef; # Disabled
my $interactive  = undef; # Disabled
my $unattended   = undef; # Disabled
my $unixy        = undef; # Disabled
my $reversible   = undef; # Disabled
my $debug        = undef; # Disabled
my $ANSIcolour   = 1;     # Use colour
my $cleanup      = undef; # Disabled
my $show_missing = 0;     # 0: Don't show, 1: List missing episodes

if($ANSIcolour && $ENV{'TERM'} eq '' && $INC{'Win32/Console/ANSI.pm'} eq ''){print "You appear to be using MS-DOS without the Win32::Console::ANSI module, colour disabled!\n (See script header for a workaround)\n\n"; $ANSIcolour = 0;}

# Internal Flags
my $implicit_season = 0;    # 0=Autodetect season, 1=Script has guessed, 2=User has provided season
my $implicit_format = 1;  # 1="Soft" format, use internal algorithm to detect input source, 2="Hard" format - no guessing allowed
my $do_win32_associate = 0;	# 0=Do nothing, 1=associate, -1=unassociate

#------------------------------------------------------------------------------}}}
my $version = "TV Series Renamer v2.53\nReleased 30 June 2010\n"; # {{{
print $version;
my $helpMessage = 
"Usage: $0 [OPTIONS] [FILE|URL|-]

Renames files in the current directory using data provided, or attempts a
search on the web and uses resulting data.

Non-URL input is expected to have been copy'n'pasted from Firefox, from any of
the sites listed below:

Input options:
 --AutoFetch        Search sites automatically (no need to provide input)
 --AutoDetect       Systematically try each format below (input required)
 --AniDB            Assume input is in http://AniDB.net format
 --TVtorrents       Assume input is in http://www.TVtorrents.com format
 --TVtome           Assume input is in http://www.TVtome.com format
 --TV               Assume input is in http://www.TV.com format
 --TV2              Assume input is in http://www.TV.com \"All Seasons\" format
 --EpGuides         Assume input is in http://www.EpGuides.com format

 Note: If you don't specify an input source, text files with names derived from
 the above will be tried in turn (AniDB.txt, TVtorrents.txt, ...). Failing this
 any .url or .desktop files will be scanned and the first URL found will be
 used. Hence you can put an internet shortcut in the current directory as a
 convenience.

 --search=TV      | Which group of sites to search? TV is the default unless
 --search=anime   | the word \"anime\" appears somewhere in the current path
 -                  Use STDIN (don't look for URL shortcuts or input files)
  
Formatting options:
 --scheme=X         Episode number format. One of: SXXEYY, sXXeYY, XxYY, XYY,
                    YY

 Note: Numbers are \"padded\" with zeros to fit all numbers, so if 9 or
 less episodes are listed on your source website, you will have 1-digit
 numbers, 10-99 -> 2-digit numbers, 100-999 -> 3-digit, ...

 --pad=X            Pad episode number to X digits. (EG --pad=3 : ep8 -> ep008)

 Note: If you do not specify --nogroup / --group the default behaviour is
 dependant on the type of series being renamed. Anime defaults to --group and
 everything else to --nogroup. You can force Anime/Other with the --search
 option.

 --nogroup          Do not (attempt to) preserve group tags (EG: '[AnCo]')
 --group            Attempt to preserve group tags (EG: '[AnCo]')
 --dontgroup        Don't treat groups specially. Useful when the
                    episode-number is surrounded by square brackets (EG:
                    '[3x11]')
 --dogroup          Opposite of --dontgroup

 --nogap            Do not place a gap between series name and episode number
 --gap              Force gap, useful when --nogap is automatically applied
 --gap=X            Use custom gap, perhaps to enable use of other scripts
 --separator=X      Text to go between episode number and title (EG \" - \")
 --unixy            Replace spaces with underscores (usually other way around)
 --cleanup          Don't require input, just clean-up names

Specifying data to use:
 --season=X         Override season detection
 --series=X         Uses X as a prefix (enclose in quotes for best results)
 --exclude-series   Don't include the series name in the new filename, ever
 --include-series   Overrides the above setting, incase you set it default
 --chdir=X          Specify a directory to rename. If specified multiple times
                    all but last are ignored.

 Note: If neither of the above two settings are used, the default behaviour
 is to drop the series name when the directories are structured in a manner
 like \"SeriesName/Season 1\" or \"SeriesName/Series 1\"

 --autoseries       Use series title from input (useful when automatic
                     searching is disabled)
 --noautoseries     Do not use series title from input, even when available
 --rangemin=X       Discard input titles before X
 --rangemax=X       Discard input titles after X
 --autoranging      Discard input after a large gap (~50) in episode numbers
 --noautoranging    Never discard input due to gaps in numbering
 --dubious          Treat epNums like \"234\", \"1234\" as \"2x34\", \"12x34\"
 --nodubious        Do normal matching (In case you set --dubious by default)
 --preproc=X        Evaluate some PERL, X, before altering internal filename
 --postproc=X       Evaluate some PERL, X, before altering external filename
                     * The current filename is stored in \$_.
                     * EG: --preproc='s/Samurai7/Samurai 7/;' to conform names
                     * EG: --postproc='s/Chapter \\d+//;' to strip \"Chapter XX\"

Choosing how to interact:
 --detailed         Show 'before -> after' (not just 'after') in proposal
 --show-missing     List episodes not present in your collection
 --interactive      Manually select each change to be applied
 --unattended       Assume NO for all user prompts except \"Make changes?\"
 --nofilter         Don't filter file extensions by
                     $filterFiles
 --reversible       Create undo script (\"unrename.pl\" or \"unrename.bat\")
 --debug            Display debugging info (data extracted from input etc)
 --ANSI             Enable ANSI escape sequences (used for colouring text)
 --noANSI           Disable colour (use if you see gibberish)

Maniuplating technical behaviour:
 --cache            Use/create .cache files to save 15min chunks of bandwidth
 --nocache          Do no make or use .cache files, always fetch the URL

Windows-specific functionality:
 --associate-with-video-folders
 --unassociate-with-video-folders

 This will add or remove \"Use TV Renamer Script\" to the right-click menu of
 video folders in windows. It does this by adding/removing a key in the
 registry.

Standard GNU stuff:
 --version          Display version & release date
 --help             Display this help message

 (all options are case-insensitive)

 Note: You can specify these switches, one per line, in a .tvrenamerrc file in
 your home directory for convenience

 Please consult source code comments for more detailed help
 Docs & Updates: www.robmeerman.co.uk/coding/file_renamer

 Report bugs to robert.meerman\@gmail.com, I love the attention
";

# }}}
# Check for command-line arguments {{{
my $tvrenamerrc = '';
if(-e $ENV{"HOME"}."/.tvrenamerrc"){$tvrenamerrc = $ENV{"HOME"}."/.tvrenamerrc";}
if(-e $ENV{"USERPROFILE"}."/.tvrenamerrc"){$tvrenamerrc = $ENV{"USERPROFILE"}."/.tvrenamerrc";}
if(-e $ENV{"USERPROFILE"}."/_tvrenamerrc"){$tvrenamerrc = $ENV{"USERPROFILE"}."/_tvrenamerrc";}
unless($tvrenamerrc eq '')
{
	print "Reading preferences from $tvrenamerrc\n";
	open(RCFILE, "< $tvrenamerrc");
	while(<RCFILE>)
	{
		@ARGV = ($_, @ARGV);
	}
	close(RCFILE);
}
if($#ARGV ne -1)
{
	foreach my $arg (@ARGV){
		if( $arg =~ /^$/ )                {}	# Skip empty strings, often from .tvrenamerrc files
		if( $arg =~ /^--autofetch$/i )    {$implicit_format = 0; $format = Format_AutoFetch;}
		if( $arg =~ /^--autodetect$/i )   {$implicit_format = 0; $format = Format_AutoDetect;}
		if( $arg =~ /^--anidb$/i )        {$implicit_format = 0; $format = Format_AniDB;}
		if( $arg =~ /^--tvtorrents$/i )   {$implicit_format = 0; $format = Format_TVtorrents;}
		if( $arg =~ /^--tvtome$/i )       {$implicit_format = 0; $format = Format_TVtome;}
		if( $arg =~ /^--tv$/i )           {$implicit_format = 0; $format = Format_TV;}
		if( $arg =~ /^--tv2$/i )          {$implicit_format = 0; $format = Format_TV2;}
		if( $arg =~ /^--epguides$/i )     {$implicit_format = 0; $format = Format_EpGuides;}

		if( $arg =~ /^--search=(.*)$/i )	 {
										if($1 =~ m/anime/i){ $search_anime=1; }
										else{ $search_anime=undef; }
									 }

		elsif( $arg =~ /^--scheme=(.*$)/i )    {$scheme = $1;}
		elsif( $arg =~ /^--series=(.*$)/i )    {$series = $1;}
			# Note that $exclude_series is 1 by factory default
		elsif( $arg =~ /^--chdir=(.*)$/i )    {
										print "Switching to directory $1\n"; chdir($1);
										($series) = (getcwd() =~ /\/([^\/]+)$/);
									}
		elsif( $arg =~ /^--include[-_]series$/i ) {$exclude_series = 0;}
		elsif( $arg =~ /^--exclude[-_]series$/i ) {$exclude_series = 2;}
		elsif( $arg =~ /^--season=(.*)$/i )    {$season = $1; $implicit_season = 2;}
		elsif( $arg =~ /^--autoseries$/i )   {$autoseries = 1;}
		elsif( $arg =~ /^--noautoseries$/i ) {$autoseries = 0;}
		elsif( $arg =~ /^--nogroup$/i )      {$nogroup = 1;}
		elsif( $arg =~ /^--group$/i )        {$nogroup = 0;}
		elsif( $arg =~ /^--dontgroup$/i )    {$dontgroup = 1;}
		elsif( $arg =~ /^--dogroup$/i )      {$dontgroup = 0;}
		elsif( $arg =~ /^--nogap$/i )        {$gap = undef;}
		elsif( $arg =~ /^--gap$/i )          {$gap = ' ';}
		elsif( $arg =~ /^--gap=(.*)$/i )       {$gap = $1;}
		elsif( $arg =~ /^--separator=(.*)$/i ) {$separator = $1;}
		elsif( $arg =~ /^--detailed$/i )     {$detailedView = 1;}
		elsif( $arg =~ /^--show-missing$/i ) {$show_missing = 1;}
		elsif( $arg =~ /^--interactive$/i )  {$interactive = 1;}
		elsif( $arg =~ /^--unattended$/i )   {$unattended = 1;}
		elsif( $arg =~ /^--cache$/i )        {$nocache = 0;}
		elsif( $arg =~ /^--nocache$/i )      {$nocache = 1;}

		elsif( $arg =~ /^--dubious$/i )      {$dubious = 1;}
		elsif( $arg =~ /^--nodubious$/i )    {$dubious = undef;}
		elsif( $arg =~ /^--rangemin=(.*)$/i )  {$rangemin= $1;}
		elsif( $arg =~ /^--rangemax=(.*)$/i )  {$rangemax= $1;}
		elsif( $arg =~ /^--autoranging$/i )  {$autoranging = 1;}
		elsif( $arg =~ /^--noautoranging$/i ){$autoranging = 0;}
		elsif( $arg =~ /^--series$/i )       {$series = undef;}
		elsif( $arg =~ /^--pad=(.*)$/i )     {$pad= $1;}
		elsif( $arg =~ /^--nofilter$/i )     {$filterFiles = undef;}
		elsif( $arg =~ /^--unixy$/i )        {$unixy = 1;}
		elsif( $arg =~ /^--cleanup$/i )      {$cleanup = 1;}
		elsif( $arg =~ /^--ansi$/i )         {$ANSIcolour = 1;}
		elsif( $arg =~ /^--noansi$/i )       {$ANSIcolour = 0;}
		elsif( $arg =~ /^--reversible$/i )   {$reversible = 1;}
		elsif( $arg =~ /^--debug$/i )        {$debug = 1;}

		elsif( $arg =~ /^--preproc=(.*)$/i )   {$preproc = $1;}
		elsif( $arg =~ /^--postproc=(.*)$/i )  {$postproc = $1;}

		elsif( $arg =~ /^--associate-with-video-folders$/ ) {$do_win32_associate = 1;}
		elsif( $arg =~ /^--unassociate-with-video-folders$/ ) {$do_win32_associate = -1;}
			
		elsif( $arg =~ /^--help$/i )        {print $helpMessage; exit;}
		elsif( $arg =~ /^--version$/i )     {exit;}
			
		elsif( $arg =~ qr/^-.+/ )           {print "Invalid option $arg!\nUse --help for list of available options\n"; exit 1;}
		else                                {$implicit_format = 1; $inputFile = $arg; $format= Format_AutoDetect;}
		}
}

if( $implicit_season != 2 ){
    # Try to deduce the season from the current folder name.
    #
    # Examples:
    #
    #   "2" -> season 2, get series name from parent directory
    #   "Season 2" -> season 2, get series name from parent directory
    #   "Series 2" -> season 2, get series name from parent directory
    #
    #   "Survivor (20)" -> season 20 of "Survivor"
    #   "Survivor 20x" -> season 20 of "Survivor"
    #
    if( $series =~ m{^(?P<prefix>.*)(?:season|series)\s*(?P<season>\d+)\s*$}i 
            or $series =~ m{^\s*(?P<season>\d+)\s*$}i ){

        $season = $+{season};

        if( $+{prefix} =~ m/^\s*$/ ){
            # No prefix, get series names from parent directory
            ($series) = (getcwd() =~ m{/([^/]+)/[^/]+/?$});
        }else{
            $series = $+{prefix};
        }

        if( $exclude_series == 1 ){
            # 1=Exclude if cwd is "Season X", 2=Exclude always
            $exclude_series=2;
        }
    }
    elsif( $series =~ m{^(?P<series>.*)\((?P<season>\d+)\)\s*$}i ){
        $series = $+{series};
        $season = $+{season};
    }
    elsif( $series =~ m{^(?P<series>.+?)(?P<season>\d+)x\s*$}i ){
        $series = $+{series};
        $season = $+{season};
    }else{
        print "Autodetecting season number failed\n";
    }
}

# Sanitize series name, incase it happens to be a valid regular expression (for
# instance if brackets are present)
# This is used whenever pattern matching on the series is done
my $escaped_series;
$escaped_series = $series;
$escaped_series =~ s/([({\[^\$\*+?\]})])/\\$1/g;

#------------------------------------------------------------------------------}}}
# Setup ANSI sequences {{{
my ($ANSInormal, $ANSIbold, $ANSIblack, $ANSIred, $ANSIgreen, $ANSIyellow, $ANSIblue,
	$ANSImagenta, $ANSIcyan, $ANSIwhite, $ANSIsave, $ANSIrestore, $ANSIup, $ANSIdown);

if($ANSIcolour){
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
}
#------------------------------------------------------------------------------}}}
# (Un)Associate with video folder in Win32 {{{
#------------------------------------------------------------------------------
if($do_win32_associate == -1)
{
	print $ANSIcyan."Unassociate action invoked, no renaming will take place.\n".$ANSInormal;
	open(FH, '> tvrenamer_unassociate_win32.reg');
	print FH "REGEDIT4\n\n";
	print FH "[-HKEY_CLASSES_ROOT\\SystemFileAssociations\\Directory.Video\\shell\\tvrenamer]\n";
	close(FH);

	qx/regedit -s tvrenamer_unassociate_win32.reg/;
	unlink("tvrenamer_unassociate_win32.reg");
	print "${ANSIcyan}Association removed.${ANSInormal}\n\n";
	print "You will no longer see \"Use TV Renamer script\" when you right\n";
	print "click a video folder\n";
	exit 0;
}

if($do_win32_associate == 1)
{
	my $invokation = $^X;	# aka $EXECUTABLE_NAME, a built-in global
	my $script_location = $0;
	my $cd;
	my $script_name;
	print $ANSIcyan."Associate action invoked, no renaming will take place.\n".$ANSInormal;

	if($^O eq "cygwin")
	{
		# Simple, just use the "cygpath --dos --absolute" command to convert to a Win32 path
		$invokation = `cygpath --dos --absolute $invokation`;
		chomp $invokation;
		$script_location = `cygpath --dos --absolute $script_location`;
		chomp $invokation;
	}
	elsif($^O eq "MSWin32")
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
		
		if($_ =~ /y| |\xa|\.|>/i){    # 'Y', space, enter or the '>|.' key
			print $ANSIgreen."y\n".$ANSInormal;
			print "\nOK then, hotshot, here are my guesses as to how you run this script:\n";
			print "Perl:   ${^X}\n";
			print "Script: $0\n";
			print "Anything about that strike you as odd? [y/${ANSIbold}N${ANSInormal}]: ";

			ReadMode "cbreak";
			$_ = ReadKey();
			ReadMode "normal";

			if($_ =~ /y| |\xa|\.|>/i){    # 'Y', space, enter or the '>|.' key
				print $ANSIgreen."y\n".$ANSInormal;
				print "\nTough! The author hasn't implemented this option yet! :P\n";
				print "Email the bastard at robert.meerman\@gmail.com and tell him to sort\n";
				print "his act out, and what freaky version of Windows you think you're\n";
				print "using.\n";
				exit 1;
			}else{
				print $ANSIred."n\n".$ANSInormal;
				print "\nPeachy, then let's get going!\n";
			}
		}else{
			print $ANSIred."n\n".$ANSInormal;
			print "\nProbably wise. Another time perhaps?\n";
			exit 1;
		}
	}
	$invokation =~ s/\\/\\\\/g;
	$script_location =~ s/\\/\\\\/g;
	$script_location =~ s/^(.*)\n/$1/;	# Inexplicibly multiline string. Keep only first line
	open(FH, '> tvrenamer_associate_win32.reg');
	print FH "REGEDIT4\n\n";
	print FH '[HKEY_CLASSES_ROOT\SystemFileAssociations\Directory.Video\shell]',"\n";
	print FH '@="open"',"\n";
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
	exit 0;
}
#------------------------------------------------------------------------------}}}
# Look for input {{{
#------------------------------------------------------------------------------

my $expect_epName = 0;  # FIXME: Hack used by AniDB multi-line parser (should
						# be removed once backward compatability with the old
						# parser is removed)
my @input;
my $raw_input;	# Sometimes searching a website results in a series' page
				# instead of a results page, using this variable we can simply
				# avoid refetching for eptitle parsing
my (@sname, @name, @pname); # Specials, Normals, Pilots
my $warnings = 0;
my $AutoDetect; # undef = 'Don't AutoDetect', 0 = 'Finished AutoDetecting'

if($cleanup)
{
	print "Doing simple filename clean-up (series name '$series' discarded)\n";
	$series = undef;	# Skip episode data / (proper) filename parsing
}
else
{
	if ( $implicit_format ){
		if ( !defined $inputFile )
		{
			if ( -e 'AniDB.txt')								{$site = NumSites-1; $format = Format_AniDB;		$inputFile = 'AniDB.txt';		}
			if ( -e 'TVtorrents.txt')							{$site = NumSites-1; $format = Format_TVtorrents;	$inputFile = 'TVtorrents.txt';	}
			if ( -e 'TVtome.txt')								{$site = NumSites-1; $format = Format_TVtome;		$inputFile = 'TVtome.txt';		}
			if ( -e 'TV.txt')									{$site = NumSites-1; $format = Format_TV;			$inputFile = 'TV.txt';			}
			if ( -e 'TV2.txt')									{$site = NumSites-1; $format = Format_TV2;			$inputFile = 'TV2.txt';			}
			if ( -e 'EpGuides.txt')								{$site = NumSites-1; $format = Format_EpGuides;		$inputFile = 'EpGuides.txt';	}
			if ( ($_ = bsd_glob('*.url', GLOB_NOCASE )))		{$site = NumSites-1; $format = Format_AutoDetect;	$inputFile = readURLfile($_);	}
			if ( ($_ = bsd_glob('*.desktop', GLOB_NOCASE )))	{$site = NumSites-1; $format = Format_AutoDetect;	$inputFile = readURLfile($_);	}
		}
		if ($inputFile eq '-'){$site = NumSites-1; $format=Format_AutoDetect; $inputFile = undef;}
	}

	# Display settings
	if($series && !$autoseries)
	{
		print "Detected series name $ANSIbold'$series'$ANSInormal";
	}
	unless($season){$season = 1; $implicit_season = 1;}
	$season = $season + 0;	# Cast to numeric (removing leading zeros)
	print " (Season $season".($implicit_season==1?" $ANSIred(assumed)$ANSInormal":"").")\n";

	print "Reading input in $FormatList[$format] mode from ";
	if($format == Format_AutoFetch){print $SiteList[$site]."\n";}
	else{print $inputFile ? $inputFile."...\n" : "STDIN (Press ^D to end):\n";}
	
	# AutoFetch mode {{{
	###
	# Label this point to allow re-entry if parsing fails.
	#
	AUTOFETCH:
	if($format == Format_AutoFetch)	# {{{
	{
		my $search_term;

		# First check if we have a fresh .cache file we can use instead
		if( -e ".cache" && -M ".cache" < (15/60/24)){
			open(CACHE, "< .cache");
			$_ = <CACHE>;
			close(CACHE);
			($inputFile) = ($_ =~ /(^.*$)/m);	# First line contains URL
			$format = Format_AutoDetect;
			goto AUTOFETCH;
		}

		if( $series =~ /, The$/i )
		{
			$search_term = "The ".substr($series, 0, -5);
		}
		else
		{
			$search_term = $series;
		}

		# Detect Anime and use AniDB{{{
		if($search_anime || getcwd() =~ /anime/i)
		{
			print $ANSIcyan."Current directory detected as anime.\n".$ANSInormal;

			# Choose group behaviour if user has not
			if( ! defined $nogroup ){ $nogroup = 0; }

			print "Searching AniDB.net for \"$search_term\"... ";
			my $searchURL = ('http://anidb.net/perl-bin/animedb.pl?show=animelist&adb.search='.uri_escape($search_term).'&do.search=search');
			if($debug){print "Fetching $searchURL\n";}
			$_ = get($searchURL);
			# 0x1f 0x8b = GZIP compression. C.f. http://www.gzip.org/zlib/rfc-gzip.html
			if ( substr($_, 0, 2) eq chr(0x1f).chr(0x8b) ){
				if($debug){print $ANSIcyan."Compressed data detected\n".$ANSInormal;}
				$_ = Compress::Zlib::memGunzip($_);	
			}
			#$_ = Encode::decode 'UTF-8', $_;
			# Save snapshot for debugging
			if($debug){
				print $ANSIcyan."Saving html to .search_results.full...$ANSInormal\n";
				open(RESULTS, '> .search_results.full');
				binmode(RESULTS, ":raw");
				print RESULTS $_;
				close RESULTS;
			}

			# Strip attributes from non-<a> tags
            s/(?<=<)(?!label|a)([^ >]*)[^>]*/\1/g;
	
			# Save snapshot for debugging
			if($debug){
				print $ANSIcyan."Saving (simplified) html to .search_results...$ANSInormal\n";
				binmode(RESULTS, ":raw");
				open(RESULTS, '> .search_results');
				print RESULTS $_;
				close RESULTS;
			}

			# Now to parse the results page
			my ($rcache, $rlink, $rseries, $rresults);
			$rcache = $_;
			$rresults = 0;	# Count number of results returned by AniDB
			while(($rlink, $rseries) = /<a href="(animedb\.pl\?show=anime&amp;aid=\d+)">([^<]+)<\/a>/m){
				if($debug){print "$ANSIcyan"."Considering result: '$rseries' and link '$rlink'$ANSInormal\n";}
				$rresults++;
				if( $rseries =~ /^$series$/i ){
					print "Found match!\n"; 
					$rlink =~ s/&amp;/&/;
					$inputFile = "http://anidb.net/perl-bin/$rlink";
					$format = Format_URL_AniDB;
					last;
				}
				else{
					# Try remaining input
					$_ = substr($_, $+[0]);
				}
			}

			# No results? Could be that AniDB transparently redirected to the
			# series page, if the series name is a unique hit in the database.
			if($rresults == 0){
				# Give up the search after AniDB is exhausted for possibilities
				$inputFile = undef;
				$site = NumSites-1;

				# Search result pages are titled "Anime List", while series
				# page's are titled "Anime - SERIESNAME"
				if($rcache =~ /::AniDB.net:: Anime - /i ){
					print "Unique hit!\n";	
					$raw_input = $rcache;	# Configure script to use $raw_input

					# Strip attributes from non-a and non-labal tags, making format detection
					# slightly more resistant to change
			        $raw_input =~ s/(?<=<)(?!label|a)([^ >]*)[^>]*/\1/g;
				}
				else{
					print "No results.\n";
					print $ANSIred."I didn't percieve a single result from AniDB, please check www.AniDB.net\n".
						"lists your series and try again providing a link to the series' page on\n".
					   	"the command line.\n".
						"\nIt is likely that AniDB's page layout has changed, if that is the case\n".
						"please notify my author (see end of \"$0 --help\")\n".$ANSInormal;
					print $ANSIcyan."Search URL was: $searchURL\n".$ANSInormal;
					exit 1;
				}
			}
			else{
				# FIXME: Detect non-empty results set which didn't contain an
				# exact match, and prompt user to select a result. (This will
				# require constructing a result list)
				$site = NumSites-1;	# Don't bother to search other sites
			}

			# Free up memory
			undef $rcache;
			undef $rlink;
			undef $rseries;
			undef $rresults;
		}
		# End detect anime }}}
		else
		{
			# Choose group behaviour is user has not
			if(! defined $nogroup){ $nogroup = 1; }

			# Guess an URL for epGuides.com an use it (no need to save an URL shortcut) {{{
			#
			if($site eq Site_EpGuides)
			{
				$format = Format_EpGuides;
				my  ($shortSeries) = ($search_term =~ /^(?:The\s+)?(.*?)\s*(?:, The)?$/i);
				$shortSeries =~ tr/'//d;
				$shortSeries =~ s/\s+//g;
				$inputFile = "http://epguides.com/$shortSeries/";
			}    
			# }}}
			# Search TV.com and pass the final URL to the usual TV.com parser {{{
			#
			elsif($site eq Site_TV)
			{
				my $page;
				my $url = "http://www.tv.com/search.php?type=11&stype=program&qs=".uri_escape($search_term);
				my $link;
				my $len = 0;
				my $retries = 3;
				$format = Format_URL_TV2;
				
				if($debug){print $ANSImagenta."Search URL: $url\n".$ANSInormal;}

				# Peform search on TV.com for programme ("program" to those in the U.S.A.)
				while($len==0 && $retries > 0){
					print "Performing search...\n";
					$page = get($url);
					#$page = Encode::decode 'UTF-8', $page;
					$len = length($page);
					$retries--;
					# Note we sleep for 3 seconds between retries, but present the message AFTER the wait,
					# this way the user doesn't get annoyed after the last retry when they're made to wait 3 seconds
					# before the script quits.
					if($len==0){sleep(3); print $ANSIyellow."Problem with server (received 0 bytes)...\n".$ANSInormal;}
				}
				die ($ANSIred."Unable to perform search on TV.com! (Fetched $len bytes of data) Please try the following in a browser:\n  $url\n".$ANSInormal) unless length($page) > 0;

				#EG: <span class="f-18">Show: <a class="f-bold f-C30" href="http://www.tv.com/human-weapon/show/74629/summary.html?q=Human Weapon&tag=search_results;title;1">Human Weapon</a></span>
				($link) = ($page =~ m@<a class="[^"]+" href="(http://www.tv.com/[^/]+/show/\d+/summary.html[^"]+)">$escaped_series</a>@i);
				die("I did the search but I couldn't find \"$series\" in the response!") unless defined $link;

				# Peform adaptation. Eg:
				# /-  http://www.tv.com/24/show/3866/summary.html&q=24
				# \-> http://www.tv.com/24/show/3866/episode_listings.html&season=0
				print $ANSIgreen."Found match!\n".$ANSInormal;
				if($debug){print $ANSIcyan."Hit link is: $link\n".$ANSInormal;}
				($inputFile) = ($link =~ /^(.*?)summary.html/);
				$inputFile .= "episode_listings.html&season=$season";

				print $ANSIyellow."Creating link file in current directory to avoid repeating search...\n".$ANSInormal;
				open(URI, "> $series (Season $season) [$SiteList[$site]].URL");
				print URI "[InternetShortcut]\nURL=".$inputFile."\n";
				close(URI);
			}
			# End Site_TV }}}
			undef $search_term;
		}
	}	# End Format_AutoFetch }}}

	# Got some input {{{
	if($inputFile)	# {{{
	{
		local(*FH, $/);     # Temporarily disable the record seperator (aka "enter slurp mode")

		if($inputFile =~ /\.url|\.desktop$/i)	# {{{
		{
			if($debug){print "Opening $inputFile as URL shortcut\n";}
			$inputFile = readURLfile($inputFile);
			if($debug){print "New input source is $inputFile\n";}
		}	# }}}

		if($inputFile =~ /^http:\/\//)	# {{{
		{
			my $doFetch = 1;

			if($inputFile =~ /^http:\/\/(www.)?tv.com\/.*?&season=0$/){
			
				# Check for use of deprecated "TV.com All Seasons mode", and convert to normal mode
				print $ANSIyellow."TV.com \"All Seasons\" mode is deprecated\n$ANSInormal  (They removed some data this script relied on)\n".$ANSInormal;
				($inputFile) = ($inputFile =~ /^(.*)0/);

				# Season was guessed by script, prompt user to resolve to concrete number
				if($implicit_season){
					print $ANSIred."Season number was assumed to be $season by script.\n".$ANSInormal;
					print "\aDo you wish to redefine the season number? [".$ANSIbold."Y".$ANSInormal."/n]: ";
					if($unattended){
						$_ = 'N';
					}
					else{
						ReadMode "cbreak";
						$_ = ReadKey();
						ReadMode "normal";
					}
					
					if($_ =~ /y| |\xa|\.|>/i){    # 'Y', space, enter or the '>|.' key
						print $ANSIgreen."y\n".$ANSInormal;
						print "Please enter new season number, and press Enter: ";
						$/ = "\n";
						$_ = <STDIN>;
						($season) = ($_ =~ /^(\d+)/);
					}else{
						print $ANSIred."n\n".$ANSInormal;
					}
					
				}

				$inputFile .= $season;
				print $ANSIgreen."Using season $season page instead.\n".$ANSInormal;

				if($debug){print "New URL: $inputFile";}
			}

			if($debug){print "Input is URL: $inputFile\n";}
			if(-e ".cache" && !$nocache){     
				print "Checking freshness of .cache... ";
				if($debug){print "\nCache is " . (-M ".cache") . " days old. (15min = " . 15/60/24 . ")\n";}
				if(-M ".cache" < (15/60/24)){       # Check if cache is 15min old or fresher (measured in days)
					open(CACHE, "< .cache");
					$_ = <CACHE>;
					close(CACHE);
					
					my $fline;
					($fline) = ($_ =~ /(^.*$)/m);
					
					if($debug){print "First line of .cache is \"" . $fline ."\"\n";}
					if($fline eq $inputFile){
						print "smells good!\n";
						$doFetch = 0;
					}else{
						print "this isn't what I ordered!\n";
					}
				}else{
					print "could be fresher\n";
				}
				
			}
			
			if($debug && $nocache){print "Will not look for cache file\n";}
			if($doFetch){
				# Note about ANSI: {{{ We're going to use a trick so that if an error message is produced during the
				# fetch it will NOT be displayed after the "..." but instead on it's own line underneath.
				#   
				#   To do this we first ensure there's a blank line below us (this is not always the case if the screen
				#   is scrolling on each new line we create) and then pop back up onto our line, write out "Fetching
				#   document..." and save the cursor position on the screen. Send a newline, safe in the knowledge that
				#   this new line will not scroll the text (which would make a mess of our saved screen coordinate). If
				#   an error occurs it's displayed on its own line and we won't print "[Done], so we don't have to clean
				#   up the cursor position. If there's no error we simply restore the cursor position and write out
				#   "[Done]".
				#   
				#   Nifty eh? }}}
				my $message = "\n".$ANSIup."Fetching document ".($debug?$inputFile:'')."... $ANSIsave$ANSIred\n";
				print $message ;
				if($_ = get($inputFile)){
					my $t;
					print $ANSIrestore.$ANSInormal."[Done]\n";

					# Attempt decompression
					#
					# (Experience shows that the memGunzip() function can
					# handle more than just "pure" gzip data. Specifically
					# magic number 0x1fc18b08 can be decompressed, where I'd
					# expect that just 0x1f8b08 to be compatible becuase that's
					# what RFC1952 says)
					#
					# 0x1f 0x8b = GZIP compression. C.f. http://www.gzip.org/zlib/rfc-gzip.html
					if ( substr($_, 0, 2) eq chr(0x1f).chr(0x8b) ){
						if($debug){print $ANSIcyan."Compressed data detected\n".$ANSInormal;}
						$_ = Compress::Zlib::memGunzip($_);	
					}

					# XXX
					# Removed in v2.41, was causing problems with epguides.com, but didn't seem to preclude correct use
					# of AniDB...
					# Probably obsolete since "binmode(STDOUT, ':utf8')" was added to the top of the script...
					#$_ = Encode::decode 'UTF-8', $_;
				}
				else{
					print $ANSIred."Can't fetch \"$inputFile\", please check this URL in a browser\n$ANSIyellow Consider specifying an URL on the command-line. Error was: $!".$ANSInormal."\n";
				}

				unless($nocache){
					open(CACHE, "> .cache");
					print CACHE $inputFile."\n";
					print CACHE $_;
					close(CACHE);
				}
			}

			## Strip attributes from tags, making format detection slightly more resistant to change
			s/<([^ >]*)[^>]*\/?>/<\1>/g;
			
			#print; # Print stripped page to aid parser development

		} # Close if($inputFile) }}}
		elsif($inputFile =~ /\.txt$/)	#{{{
		{
			open(FH, $inputFile) || die "Can't open intput file: $!";
			$_ = <FH>;
			close(FH);
		}	# }}}
		else	# {{{
		{
			print $ANSIred."Unsupported input source: \"$inputFile\"".$ANSInormal;
			exit 1;
		}	# }}}
	}	# }}}
	elsif($format == Format_AutoFetch)	#{{{
	{
		# Do nothing (i.e. use current $_) unless $raw_input is defined
		if(defined $raw_input){$_ = $raw_input;}	# Detect and use raw input (use data generated by script)
	}	#}}}
	else	#{{{
	{
		my $stdin;
		binmode(STDIN, "utf8");
		while(<STDIN>){$stdin .= $_}
		$_ = $stdin;
	}	#}}}
	tr /\015/\n/; # Convert ^M to newlines in input. Fixes some weirdness from epGuides.com
	#}}}
	
	# Quick hack for backwards compatability (FIXME - remove this)
	@input = split($/);
	
	#}}}
	##[ EPISODE DATA PARSER ]#######################################################{{{
	
	my $continueParsing = 1;
	my $autoseries_successful = 0;
	while ($continueParsing) #{{{
	{
		$warnings = 0;
		# If autodetecting, flag this and proceed with systematic parsing attempts
		if($format eq Format_AutoDetect || $format eq Format_AutoFetch)
		{
			$AutoDetect = 1;
			$format = Format_AutoDetect + 1;  # AutoDetect/Fetch preceeds concrete formats in FormatList
		}
		for my $arg ($format)
		{
			if( $arg == Format_AniDB ) { # {{{
				# When you copy the AniDB table from Firefox (v1.0.1) the clipboard
				# contents are in the following format. Note that the epname and number
				# are on seperate lines.
				#
				#  [epNumber] [tab] [epName] [tab]
				#  Noting that epName may be made up of [English ( Kanji / Romanji )]

				my ($num, $snum);

				# Parse input data
				foreach(@input){
					my $epTitle;
					my $strippedEpTitle;

					($num, $epTitle) = ($_ =~ /^\s*(S?\d+)\s+(.*?)\s+\d+m/);
					if ( ($strippedEpTitle) = ($epTitle =~ /^(.*)\([^\/]+\/[^)]+\)/) ) {
						$epTitle = $strippedEpTitle;
					}

					if(($snum) = ($num =~ /S(\d+)/)){              # Detect Special
						check_and_push($epTitle, \@sname, $snum);
					}else{
						check_and_push($epTitle, \@name, $num);
					}
				}
			} # End case Format_AniDB }}}
			elsif( $arg == Format_URL_AniDB ) { #{{{
				# Remember that most attributes are stripped from the HTML before being passed to us. Sample data:
                #
		        # <tr class="g_odd newtype" id="eid_42520">
		        # 	<td class="id eid">
		        # 		<a href="animedb.pl?show=ep&amp;eid=42520">1</a>
		        # 	</td>
		        # 	<td class="title">
		        # 		<label title="緑の座 / Midori no za">The Green Seat
		        # 		</label>
		        # 	</td>
		        # 	<td class="duration">24m
		        # 	</td>
		        # 	<td class="date airdate">23.10.2005
		        # 	</td>
		        # </tr>

				my $offset = 0;
				my ($num, $snum, $epTitle, $japEpTitle);
				
				if($autoseries){
					if(($series) = $_ =~ /^\s*<title>::AniDB.net:: Anime - \s*(.*?)\s*::<\/title>\s*$/ms){
						$autoseries_successful = 1;
					}
				}

                while( $_ =~ m{
                    # <tr>
                    #     <th>EP</th>
                    #     <th>Title</th>
                    #     <th>Duration</th>
                    #     <th>Air Date</th>
                    # </tr>
                    <tr>\s*
                        <td>\s*
                            <a\shref="animedb.pl\?show=ep&amp;eid=\d+">\s*(?P<num>[sS]?\d+)\s*</a>\s*
                        </td>\s*
                        <td>\s*
                            <label\s*title="(?P<altTitle>[^"]*)">(?P<epTitle>[^<]*)
                            </label>\s*
                        </td>\s*
                        <td>[^<]*
                        </td>\s*
                        <td>[^<]*
                        </td>\s*
                    </tr>
                }xg ){
                    if(($snum) = ($+{num} =~ /S(\d+)/i)){              # Detect Special
                        check_and_push($+{epTitle}, \@sname, $snum);
                    }else{
                        check_and_push($+{epTitle}, \@name, $+{num});
                    }
				}
			} # End case Format_URL_AniDB }}}
			elsif( $arg == Format_TVtorrents ) { #{{{
				# TVtorrent.com uses the following format when copied to the clipboard with
				# Firefox (v1.0.2)
				#
				# 5x18  My New Suit
				# download  161 8   174.8 Mb    2006-04-12 05:31
				# 5x17  My Chopped Liver
				# download  52  6   175.3 Mb    2006-04-05 21:50

				my ($num, $epTitle);

				# Parse input data
				foreach(@input){
					if( ($num, $epTitle) = ($_ =~ /^\d+x(\d+)\t([^\t]+)/) ){
						$epTitle =~ s/\s*\([^\)]*\)$//;         # Remove '(hdtv-lol)' etc
						if($num == "Pilot"){$num = 0;}
						check_and_push($epTitle, \@name, $num);
					}
				}
			} # End case Format_TVtorrents }}}
			elsif( $arg == Format_TVtome ) { #{{{
				# TVtome.com uses the following format when copied to the clipboard with
				# Firefox (v1.0.4)
				#
				# "51.   4-1    4ACX01  01-May-2005     North by North Quahog"
				# [absoluteEp#] \t [seriesNum]x[epNum] \t [productionCode] \t [AirDate] \t [(unsure)] \t [epTitle]

				my ($num, $epTitle);
				my $OLD_INPUT_RECORD_SEPARATOR;

				# Parse input data
				foreach(@input){
					if( ($num, $epTitle) = ($_ =~ /\t\s*\d-(\d+)[^\t]*\t[^\t]*\t[^\t]*\t[^\t]*\t(.+)$/) ){
						$OLD_INPUT_RECORD_SEPARATOR = $/;
						$/ = "\r";
						chomp $epTitle;                      # Trim end-of-lines
						check_and_push($epTitle, \@name, $num);
					}
					$/ = $OLD_INPUT_RECORD_SEPARATOR;
				}
			} # End case Format_TVtome }}}
			elsif( $arg == Format_TV2 ) { #{{{
				# A varient of TV.com's format, as used by their "All Seasons" Episode listings
				# NB: This format is tried before the older Format_TV
				#
				# Pilot: Pilot       6/1/2003    100    1 - 0
				# 2: Dead Girl Walking      7/4/2003    101     1 - 2
				# 3: Curious George     7/11/2003   102     1 - 3
				#
				# ["Pilot"|epNum]:[epTitle] {TAB} [AirDate] {TAB} [Prod#] {TAB} [season] - [epnum]
				
				my ($epNum, $epTitle);
				
				# Parse input data
				foreach(@input){
					if( ($epTitle, $epNum) = ($_ =~ /[^:]+:\s+([^\t]+)\t[^\t]*\t[^\t]*\t\s*$season\s*-\s*(\d+)/) ){
						$epTitle =~ s/\s+$//;
						if($debug){print "TV2 parser: ".$epNum."|".$epTitle."\n";}
						if($epNum == 0 and $epTitle eq "Pilot"){$epNum = 1;}
						check_and_push($epTitle, \@name, $epNum);
					}
				}
			} # End case Format_TV2 }}}
			elsif( $arg == Format_URL_TV2 ) { #{{{
				# Remember that all attributes are stripped before the HTML is passed to us. Sample data:
				#
				# <table><thead><tr><th><div>no.</div></th><th><div>episode</div></th><th><div>air date</div></th><th><div>prod #</div></th><th><div>reviews</div></th><th><div>downloads</div></th><th><div>score</div></th></tr></thead><tbody><tr><td><div>1</div></td><td><div><a>Pilot</a></div></td><td><div>1/13/2008</div></td><td><div>276022</div></td><td><div><a> Reviews</a></div></td><td><div>&nbsp;</div></td><td><div>9.09</div></td></tr>

				my $offset = 0;
				my ($epSeason, $epNum, $epTitle, $epOffset);

				if($autoseries){
					# Parse "<title>Scrubs Episode List  - TV.com  </title>" into a series name
					if(($series) = $_ =~ /^\s*<title>\s*(.*)\s+Episode List\s*-\s*TV.com.*<\/title>\s*$/ms){
						$autoseries_successful = 1;
					}
				}

				while($offset < length($_)){
					if(($epNum, $epTitle) = (substr($_, $offset) =~ /<tr>\s*<td>\s*<div>\s*(\d+|Pilot)\s*<\/div>\s*<\/td>\s*<td>\s*<div>\s*<a>(.*?)<\/a>\s*<\/div>\s*<\/td>/ms)){
					if($debug){print "epNum = $epNum & epTitle = $epTitle\n";}
					if($epNum == "Pilot"){$epNum = 1;}
					if(!defined $epOffset){$epOffset = ($epNum-1);} # "-1" to ensure that epNum-epOffset = 1 for the first epTitle (Note epNum="Pilot" can make epNum= -1)
					$epNum = $epNum - $epOffset;
					check_and_push($epTitle, \@name, $epNum);
					}
					$offset += $+[0];   ## Append (local to substr) ending pos of last entire (mis)match
				}

			} # End case Format_URL_TV }}}
			elsif( $arg == Format_TV ) { #{{{
				# TVtome.com has become TV.com, a new shiney version which wastes a lot of bandwidth on things
				# I don't care about. Also, the format has changed :(
				#
				# 1: Rose        3/26/2005               1 review        8.4
				# 2: The End of the World   4/2/2005            8.4
				
				my ($num, $epTitle);
				
				# Parse input data
				foreach(@input){
					if( ($num, $epTitle) = ($_ =~ /\s*(\d+|Pilot):\s+([^\t]+)\t/) ){
						if($num == "Pilot"){$num = 0;}
						$epTitle =~ s/\s+$//;
						check_and_push($epTitle, \@name, $num);
					}
				}
			} # End case Format_TV }}}
			elsif( $arg == Format_EpGuides ) { #{{{
			# EpGuides.com format
            #                             Original
            #   Episode #     Prod #      Air Date   Titles
            # _____ ______ ___________  ___________ ___________________________________________
            # 
            # 
            # Pilot
            # 
            #        P- 0       1992                 The Spirit of Christmas (Jesus vs. Frosty)
            #        P- 0        101                 Pilot
            #        P- 0       1995                 The Spirit of Christmas (Jesus vs. Santa)
            # 
            # Special
            # 
            #        S- 0        301      4 Jul 99   Oh Holy Night
            # 
            # Season 1
            # 
            #   1.   1- 1        101     13 Aug 97   Cartman Gets an Anal Probe
            #   2.   1- 2        103     20 Aug 97   Volcano
            #   3.   1- 3        102     27 Aug 97   Weight Gain 4000
			##
			# OR (after simplification that takes place prior to this stage)
			##
            #  1.   1- 1        101     13 Aug 97   <a>Cartman Gets an Anal Probe</a>
            #  2.   1- 2        103     20 Aug 97   <a>Volcano</a>
            #  3.   1- 3        102     27 Aug 97   <a>Weight Gain 4000</a>
			#
			# NB: The air date is missing in some cases, and the production code in others
				my ($num, $epTitle, $lastPilotNum);
				$lastPilotNum = -1;	# i.e. none

				
				foreach(@input)
				{
					# First remove any <span> tags and anything they contain 
					# (links to Trailers etc)
					s!<span[^>]*>.*?</span>!!g;

					# Then remove the <a> tags themselves (but *not* their 
					# contents!)
					s!</?a[^>]*>!!g;

					# Episodes with airdates
					if( ($num, $epTitle) = ($_ =~ /\s+$season-(..).*\d+ [A-Z][a-z]+ \d+ \s*(.*)$/) )
					{
						# Cleanup whitespace (and tags if using online version)
						($epTitle) = ($epTitle =~ /^(?:<a[^>]*>)?(.*?)(?:<\/a>)?$/);
						check_and_push($epTitle, \@name, $num);
					}
					# Most episodes (new parser, v2.34)
					elsif( ($num, $epTitle) = ($_ =~ /\s+$season-(..)(.*)$/) )
					{
						# Cleanup whitespace (and tags if using online version)
						($epTitle) = ($epTitle =~ /^.{28}(?:<a[^>]*>)?(.*?)(?:<\/a>)?$/);
						$epTitle =~ s@<img></a> <a>@@;
						check_and_push($epTitle, \@name, $num);
					}
					# Most episodes (old parser, v2.33 and earlier)
					elsif( ($num, $epTitle) = ($_ =~ /\s*\d+\.\s+$season-(..).*? \w{3} \d{2}(.*$)/) )
					{
						# Cleanup whitespace (and tags if using online version)
						($epTitle) = ($epTitle =~ /^\s*(?:\<a\>)?(.*?)(?:\<\/a\>)?$/);
						check_and_push($epTitle, \@name, $num);
					}
					# Pilot episodes (c.f. "Lost" & "24" season 1)
					elsif( ($num, $epTitle) = ($_ =~ /\s+P-\s*(\d+).{26}(.*$)/) )
					{
						# Often a series has multiple P-0 entries, but people like to order then by release date.
						# So we assume pilots are listed chronologically
						if( $num == 0 && $lastPilotNum != -1 )
						{
							$lastPilotNum += 1;
							$num = $lastPilotNum;
						}
						else
						{
							$lastPilotNum = $num;
						}
						# Cleanup whitespace (and tags if using online version)
						($epTitle) = ($epTitle =~ /^\s*(?:\<a\>)?(.*?)(?:\<\/a\>)?$/);
						check_and_push($epTitle, \@pname, $num);
					}
					# Special episodes
					elsif( ($num, $epTitle) = ($_ =~ /\s+S-\s*(\d+).{26}(.*$)/) )
					{
						# Cleanup whitespace (and tags if using online version)
						($epTitle) = ($epTitle =~ /^\s*(?:\<a\>)?(.*?)(?:\<\/a\>)?$/);
						check_and_push($epTitle, \@sname, $num);
					}
				}
			
			} # End Format_EpGuides }}}
			elsif( $arg == NumFormats ) { #{{{
			##
			# Occurs when all formats have been tried
			#
				$continueParsing = 0;
				$AutoDetect = 0;    # NB Semantics: undef = 'Don't AutoDetect', 0 = 'Finished AutoDetecting'
			}# }}}
			else	# {{{
			{
				print $ANSIred."Format $format ($FormatList[$format]) parser missing!\n".$ANSInormal;
			} #}}}
		}

		@name = clean_up(@name);
		@sname = clean_up(@sname);

		# Check if any data was extracted {{{
		if ($#name eq -1 && $#sname eq -1)
		{
			if($AutoDetect)
			{
				if($debug){print "$FormatList[$format] format produced no matches\n";}
				$format++;
			}
			else
			{
				$site++;
				if($implicit_format && $site ne NumSites)
				{
					print $ANSIyellow."No useable results. Trying: $SiteList[$site]$ANSInormal\n";
					
					# Reset detection
					$format = Format_AutoFetch;
					@name = undef;
					@sname = undef;
					@pname = undef;
					
					# Try next site
					goto AUTOFETCH;
				}
				else
				{
					print $ANSIred."No data (related to season $season) was extracted from input! ".$ANSInormal;
					# NB Semantics: undef = 'Don't AutoDetect', 0 = 'Finished AutoDetecting'
					unless(defined $AutoDetect){print "(Did you select the correct format?)";}
					print "\n";
					exit 2;
				}
			}
		}	#}}}
		else	#{{{
		{
			if(defined $AutoDetect){print $ANSIgreen."Input detected as $ANSIbold$FormatList[$format]$ANSInormal$ANSIgreen format\n".$ANSInormal;}
			$continueParsing = 0;
		} #}}}
	} # }}}

	if($autoseries) #{{{
	{
		if($autoseries_successful){
			print "Series name grabbed from input as: $ANSIbold$series\n".$ANSInormal;
		}
		else{
			print $ANSIred."Unable to grab series name from input, falling back to current folder name\n".$ANSInormal;
			$warnings++;
		}
	} #}}}

	if($warnings){print $ANSIred."\a$warnings warning(s) during input\n".$ANSInormal; $warnings = 0}
	
	if($autoranging) #{{{
	{
		my $firstBlank = undef;
		my $lastBlank = undef;
		my $inBlank = undef;
		for(my $i=0; $i<$#name; $i++){
			if($name[$i] eq undef){
				if( ! $inBlank){
					$inBlank = 1;
					$firstBlank = $i;
				}
				$lastBlank = $i;
			}
			else{
				$inBlank = undef;
			}
		}
		if( ($lastBlank - $firstBlank) > 20 ){
			print $ANSIyellow."Large gap detected in input from entry #$firstBlank to #$lastBlank, discarding #$firstBlank onwards.\n$ANSInormal  (Use --noautoranging to disable this)\n";
			$rangemax = ($firstBlank - 1);
		}
	} #}}}
	
	if($rangemin or $rangemax){
		if( ! $rangemax){ $rangemax = $#name; }
		@name  =  @name[0..$rangemax];

		if( ! $rangemin){ $rangemin = 0; }
		for(my $i=0; $i<$rangemin; $i++){@name[$i]= undef;}
	}

	# Display all extracted episode names.
	if($debug){
		print "\nEpisode titles (Normals, \@name)\n";
		my $i = $[; foreach (@name) {print "$i|$_\n"; $i++}
		print "Episode titles (Specials, \@sname)\n";
		my $i = $[; foreach (@sname) {print "$i|$_\n"; $i++}
		print "Episode titles (Pilots, \@pname)\n";
		my $i = $[; foreach (@pname) {print "$i|$_\n"; $i++}
	}
	# End EPISODE DATA PARSER }}}
} # end else clause of if($cleanup)
# End Look for input }}}

##[ FILENAME PARSER ]###########################################################{{{

print "Generating changes...";

# Create our file list
my $file;
my @fileList;
opendir(DIR, '.') || die "Error opening directory: $!";
while ($file = readdir(DIR))
{
	if(! -d $file)         # Ensure not a directory
	{
		$file = Encode::decode 'UTF-8', $file;
		if(! defined $filterFiles || ($file =~ /$filterFiles/i) ){ push(@fileList, $file); }
	}
}
closedir(DIR);

my (@b, @a);                # Arrays to store $before and $after values
my $dubious_count = 0;
my ($before, $after, $fileExt, $filePrefix, $fileSeason, $fileNum, $sfileNum, $fileNum2, $group, $titles, $match);

print $ANSIred;             # Set text colour to red

# Assume we are missing all episodes until proven otherwise
# %missing{$epNum} -> $title
my %missing = ();
my $i = 0;
foreach (@name) { $missing{$i++} = $_; }

foreach(@fileList){
	$titles = \@name;       # Reference normal episode to begin with
	$fileSeason = undef;	# Reset grabbed season, not all file names have this
	$fileNum2 = undef;      # Reset double file number (i.e. '09' in episode 08-09)
	
	# Chomp newline characters off the end of our file list entries
	# Check for certain file names which we'll ignore.. 
	
	chomp($_);
	if($_ eq $0 or $_ eq $inputFile){next;}
	
	$before = $_;

	# Note To Self: tr/a-zA-Z0-9_-//dc Will delete all characters NOT matched

	if($preproc){eval $preproc;}

	($fileExt) = ($_ =~ /.*\.(.*?$)/);  # Put file extension into a variable
	($_) = ($_ =~ /(.*)\..*?$/);        # Strip file extension
	
	s/%5b/[/g;                          # %5b -> [  (avoids bad epNumber extraction)
	s/%5d/]/g;                          # %5b -> ]  (avoids bad epNumber extraction)
	tr/\_/ /;                           # Replace _ with " "
	tr/\./ /;                           # Replace . with " "
	s/\[[0-9a-f]{8}\]/ /gi;             # Remove matching '[]' if their content fits the bill of a CRC
	s/\s+/ /g;                          # Reduce multiple white space to a single " "

	if(!$dontgroup){
		($group) = ($_ =~ /\[([^\]]*)\]/);  # Yank contents of matching '[]' as the release group
		s/^(.*)\[$group\](.*)$/$1$2/;       # Strip group (ifdef)
	}
	s/^\s*$escaped_series(.*)$/$1/i;    # Strip series name (ifdef), overcomes numbers-in-series troubles

	if($cleanup){
		# Skip episode-matching stage
		s/\s+$//;                               # Remove trailing whitespace
		s/^\s+//;                               # Remove leading whitespace
		if($group){$group = " [$group]";}       # Apply make-up
		if($nogroup == 1){$group = undef;}      # Crush group if unwanted
		$_ .= "$group.$fileExt";                # Append group and re-add file extension
	}else{
		# Note that series 'specials' are denoted with an 'S' before the episode number,
		# hence we use $titles to reference our current name list (either @name or @sname)
		# and take care to detect which we need

		# This next block will extract the episode number from the filename (if possible)
		# and then determine if it is an series 'special' or warn the user if the episode
		# number cannot be extracted

		if( ($fileSeason, $fileNum, $fileNum2) = ($_ =~ /season\D?(\d+)\D?episode\D?(\d+)[-&](\d+)/i) ){$match='Match "Season $$ Episode @@-@@"';}
		elsif( ($fileSeason, $fileNum, $fileNum2) = ($_ =~ /s(\d+)\D?e(\d+)[-&]e(\d+)/i) ){$match='Match "S$$.E@@-E@@"';} 
		elsif( ($fileSeason, $fileNum, $fileNum2) = ($_ =~ /s(\d+)\D?e(\d+)[-&](\d+)/i) ){$match='Match "S$$.E@@-@@"';}
		elsif( ($fileSeason, $fileNum, $fileNum2) = ($_ =~ /s(\d+)\D?e(\d+)e(\d+)/i) ){$match='Match "S$$.E@@E@@"';}
		elsif( ($fileSeason, $fileNum, $fileNum2) = ($_ =~ /(\d+)x(\d+)[-&](\d+)/i) ){$match='Match "$x@@-@@"';}
		elsif( ($fileNum, $fileNum2) = ($_ =~ /S(\d+)[-&](\d+)/i)){$match='Match "S@@-@@" (Special)'; $titles=\@sname;}         
		elsif( ($fileNum) = ($_ =~ /season\D?\d+.?episode\D?P(\d+)/i) ){$match='Match "Season $$ Episode P@@" (Pilot)'; $titles=\@pname;}
		elsif( ($fileNum) = ($_ =~ /season\D?\d+.?episode\D?(\d+)/i) ){$match='Match "Season $$ Episode @@"';}
		elsif( ($fileSeason, $fileNum) = ($_ =~ /s(\d+)\D?ep(\d+)/i) ){$match='Match "S$$EP@@" (Pilot)'; $titles=\@pname;}
		elsif( ($fileSeason, $fileNum) = ($_ =~ /s(\d+)\D?pe(\d+)/i) ){$match='Match "S$$PE@@" (Pilot)'; $titles=\@pname;}
		elsif( ($fileSeason, $fileNum) = ($_ =~ /s(\d+)\D?e(\d+)/i) ){$match='Match "S$$E@@"';}
		elsif( ($fileSeason, $fileNum) = ($_ =~ /(\d+)xp(\d+)/i) ){$match='Match "$xP@@" (Pilot)'; $titles=\@pname;}
		elsif( ($fileSeason, $fileNum) = ($_ =~ /(\d+)x(\d+)/i) ){$match='Match "$x@@"';}
		elsif( ($fileNum) = ($_ =~ /.S(\d+)/i)){$match='Match "S@@" (Special)'; $titles=\@sname;}
		elsif( ($fileNum, $fileNum2) = ($_ =~ /(\d+)[-&](\d+)/i) ){$match='Match "@@-@@"';}
		elsif( ($fileNum) = ($_ =~ /pe(\d+)/i) ){$match='Match "PE@@"'; $titles=\@pname;}
		elsif( ($fileNum) = ($_ =~ /p(\d+)/i) ){$match='Match "P@@"'; $titles=\@pname;}
		elsif( ($fileNum) = ($_ =~ /s(\d+)/i) ){$match='Match "S@@"'; $titles=\@sname;}
		elsif( ($fileNum) = ($_ =~ /(\d+)/i) ){$match='Match "@@"';}
		else{                                                             # Finding episode number failed
			print "\nCan't extract episode number from snippet '$_'\tof filename: \"$before\", ignoring.";
			if(!$dontgroup){
				if( $before =~ /\[/ || $before =~ /\]/){
					print " (Consider using --dontgroup)";
				}
			}
		   	$warnings++;
		   	next;
		}

		# If flagged, treat numbers greater than 2 digits as shorthand for "1x08" / "01x08" / "001x08" etc
		if( $dubious  ) { ($fileNum) = ($fileNum =~ /\d*(\d{2})/); }
		
		if($fileSeason ne '' && $fileSeason != $season){
			if($debug){
				print $ANSIcyan."\nFiltering due to wrong season ($fileSeason): $before".
				$ANSIred;
			}
		   	next;
		}

		if(defined $series){$filePrefix = $series;}         # If we know what the series is called, override prefix
		my $dispNum;
		$dispNum = pad($fileNum, length $#{$titles});
		if(defined $pad){$dispNum = pad($dispNum, $pad);}
		if($fileNum2){
			if($debug){print "\nfileNum2 defined for $fileNum as $fileNum2";}
			$fileNum2 = pad($fileNum2, length $#{$titles});
		}
		if($nogroup == 1){$group = undef;}               # Crush group if unwanted

		#End FILENAME PARSER }}}
		##[ CONSTRUCT NEW FILENAME ]####################################################{{{
		# Print all source data before compiling new name
		if($debug && ($before ne $_)){
			print "\n".
				"\n$ANSIblue"."Working Set: $_".$ANSInormal.
				"\n\$match = ".$match.
				"\n\$fileSeason = ".$fileSeason.
				"\n\$fileNum = ".$fileNum.
				"\n\$fileNum2 = ".$fileNum2.
				"\n\$group = ".$group.
				"\n\$fileExt = ".$fileExt
				;
		}
		if(defined $$titles[$dispNum] || defined $sname[$dispNum] || defined $pname[$dispNum]) {
			check_group();
			if($exclude_series == 2){$filePrefix = '';}							# See default settings
			my $S = ($titles == \@sname) ? 'S' : '' ;                           # "Special episode" prefix
			my $P = ($titles == \@pname) ? 'P' : '' ;                           # "Pilot episode" prefix
			my $dispNum = $S.$P.$dispNum . ($fileNum2 ? "-".$S.$fileNum2 : ''); # Compound file number (special prefix & double episode)
			my $epTitle2 = $fileNum2 ? " - ".$$titles[$fileNum2] : '' ;         # Double episode's second title
			my $epNum;
			my $local_gap = $gap;
			for my $arg ($scheme){
				   if( $arg eq 'SXXEYY') {$epNum = "S".pad($season, 2)."E".$dispNum;}
				elsif( $arg eq 'sXXeYY') {$epNum = "s".pad($season, 2)."e".$dispNum;}
				elsif( $arg eq 'YY'    ) {$epNum = $dispNum;}
				elsif( $arg eq 'XxYY'  ) {$epNum = $season."x".$dispNum;}
				elsif( $arg eq 'XYY'   ) {$epNum = $season.$dispNum;}
				elsif( $arg == undef   ) {$epNum = (!$implicit_season ? $season.'x' : '').$dispNum;}
				else          {print "\nUnknown scheme '$scheme'! Try \"$0 --help\" for list of valid schemes.\n"; exit 1;}
			}
			if($filePrefix eq ''){$local_gap = undef;}
			
			# Print all source data before compiling new name
			if($debug && ($before ne $_)){
				print 
					"\n\$filePrefix = ".$filePrefix.
					"\n\$local_gap = ".$local_gap.
					"\n\$epNum = ".$epNum.
					"\n\$S = ".$S.
					"\n\$P = ".$P.
					"\n\$dispNum = ".$dispNum.
					"\n\$epTitle2 = ".$epTitle2
					;
			}
			
			# Compile new name
			$_ = "$filePrefix$local_gap$epNum$separator$$titles[$fileNum]$epTitle2$group.$fileExt";

		}else{
			print "$ANSIred\nNo input corresponds to $ANSIbold\"$before\"$ANSInormal $ANSIred(treated as ep ", $titles==\@sname ? "S" : "", "$fileNum), ignoring.$ANSInormal";
			$warnings++;
			next;
		}
	}
	s/&#(\d+);/eval("v$1")/ge;	# HTML Entities -> Unicode (EG: "&#9829;" -> v9829 -> "♥" = U+2665)
	if($unixy){ tr/\ /_/; }     # Replace " " with _
	s/(.*)(\..+)$/$1\L$2/;      # Force extension to lowercase

	if($postproc){eval $postproc;}

    # Remove current episode(s) from list of missing episodes
    delete $missing{$fileNum};
    delete $missing{$fileNum2};

	$after = $_;
	#End CONSTRUCT NEW FILENLAME }}}
	##[ Interactive ]####################################################{{{
	if($before ne $after)
	{
		if($interactive){
			print "\n".$ANSInormal;                # Set text colour to defaults

			my $key;

			print "/--  $before\n\\->  $after\n\n";
			print "Make this change? [".$ANSIbold."Y".$ANSInormal."|n]: ";
			
			if($unattended){
				$key = 'Y';
			}
			else{
				ReadMode "cbreak";
				$key = ReadKey();
				ReadMode "normal";
			}
			
			if($key =~ /y| |\xa|\.|>/i){    # 'Y', space, enter or the '>' key
				print $ANSIgreen."y\n".$ANSInormal;
				push(@b, $before);
				push(@a, $after);
			}else{
				print $ANSIred."n\n".$ANSInormal;
			}
		}else{
			push(@b, $before);
			push(@a, $after);
		}        
	} #}}}
} # End foreach(@fileList) (near top of FILENAME PARSER)
##[ CHECK NAME TRANSITIONS ]####################################################{{{

print $ANSIred;             # Set text colour to red
# Check if target file already exists or if duplicate target names exist, and take action
for( my $i = 0; $i < @a; $i++ )
{
	if(($b[$i] ne $a[$i]) && -e $a[$i])
	{
		print "\nFile \"$a[$i]\" already exists file\n     \"$b[$i]\" will not be renamed!\n";
		$warnings++;
		$b[$i] = undef;
		$a[$i] = undef;
	}
	for( my $j = $i; $j < @a; $j++ )
	{
		if($a[$i] eq $a[$j] && $b[$i] ne $b[$j])
		{
			# Warn user, and delete both entries
			print "\nDuplicate target \"$a[$i]\" for files \n     \"$b[$i]\" and \n     \"$b[$j]\", not renmaing either!\n";
			$warnings++;
			$b[$i] = undef;
			$a[$i] = undef;
			
			$b[$j] = undef;
			$a[$j] = undef;
		}
	}
}

print $ANSInormal;      # Reset text colour

if ($warnings eq 0){ print "[Done]\n"; } else{ print "\n$warnings warning(s)"; }
if ($dubious_count ne 0 ){ print "\n$dubious_count dubious name extraction(s)"; }
# End CHECK NAME TRANSITIONS }}}

if($show_missing){
    # Gotta catch 'em all!
    print $ANSIcyan;
    print "\n";
    foreach my $epNum ( sort {$a <=> $b} keys %missing ) {
        my $title = $missing{$epNum};
        if ($title){
            print "Info: Your collection is missing episode $epNum: $title\n";
        }
    }
    print $ANSInormal;
}


# Sort proposed changes by destination name for an improved user-experience
my %changes = @a;
for (my $i = 0; $i < @a; $i++){ $changes{$a[$i]} = $b[$i]; }
@a = undef;
@b = undef;
foreach my $key(sort keys(%changes))
{
	@a = (@a, $key);
	@b = (@b, $changes{$key});
}

##[ USERPROMPT ]################################################################ {{{

# Label this block, so we can jump back here as desired
USERPROMPT: {
	# Now lets print out our new set of names for the user's scrutiny.
	print "\n\n",
	"Proposed changes:\n",
	"____________________________________\n\n";

	# Run a little loop to check, print and count if they're defined
	my $count = 0;
	for( my $i = 0; $i < @a; $i++ ){
		if ($a[$i] && $b[$i]){
			$count++;
			if($detailedView){
				print "/--  $b[$i]\n\\->  $a[$i]\n\n";
			}else{
				print "$a[$i]\n";
			}
		}
	}

	if ($count eq 0) {print "No changes necessary.\n";} 
	else {
		print 
		"____________________________________\n\n",
		"Would you like to proceed with renaming? [y/".$ANSIbold."N".$ANSInormal."/?]: ";

		if($unattended){
			$_ = 'Y';
		}
		else{
			ReadMode "cbreak";
			$_ = ReadKey();
			ReadMode "normal";
		}
		
		if($_ eq '?'){print "?\n"; $detailedView = 1; goto USERPROMPT;}
		if(lc $_ eq 'y'){
			my ($before, $after);
			print $ANSIgreen."y".$ANSInormal."\nRenaming in progress... ";
			
			# If creating undo script, read in any existing undo script
			# First check if this is the Win32 stand-alone version (i.e. rename.EXE)
			my $undofile = 'unrename.pl';
			if($0 =~ /\.exe$/i || -e 'unrename.bat'){ $undofile = 'unrename.bat'; }

			open(UNDO, $undofile);
			my @undo = <UNDO>; # Slurp in entire file, breaking lines into elements
			close(UNDO);
			
			@undo = @undo[4 .. $#undo]; # Discard header
			foreach(@undo){chop;} # Clean up line endings
			
			my ($before_is_unicode, $after_is_unicode, $teststring, $success, $warned_w32);
			until ($#a==-1)
			{
				$before = pop(@b);
				$after = pop(@a);
				if($before ne $after){
						$success = 0;	# Flags if we want to save undo info

						unless($^O eq "MSWin32" || $^O eq "cygwin"){
							$success = rename($before, $after);
						}
						else{
							# Windows {{{
							# Possibly need to work around rename() not supporting unicode

							# Look for characters above the 7-bit ASCII range
							$after_is_unicode = undef;
							$teststring = $before;
							while($teststring){
								if(  ord substr($teststring, 0, 1, "") > 128 ){
									$before_is_unicode = 1;
									last;
								}
							}

							$teststring = $after;
							while($teststring){
								if(  ord substr($teststring, 0, 1, "") > 128 ){
									$after_is_unicode = 1;
									last;
								}
							}


							# Unicode source names not implemented
							if($before =~ /\?/ || $before_is_unicode){
								# FIXME Look into using http://perlingresprogramming.blogspot.com/2008/04/opening-files-with-unicode.html
								unless($warned_w32){
									print $ANSIcyan,
									"\n This script is unable to deal with files whose names already contain Unicode",
									"\n characters. It can, however, rename files with ordinary names into files with",
									"\n Unicode characters.",
									"\n ",
									"\n The problem is that the current code used by this script (which has been",
									"\n written to run on Linux, Mac OS X and Windows) to obtain the list of files",
									"\n to generate new names for returns garbage when it encounters Unicode",
									"\n characters.",
									"\n ",
									"\n As far as the author knows, this only affects Windows users. Certainly it does",
									"\n not occur under Linux.",
									"\n",
									$ANSInormal;
									$warned_w32 = 1;
								}
								print $ANSIred,"\nSkipped (UNICODE): ",$ANSIbold,$before,$ANSInormal;
							}
							elsif($after_is_unicode){
								# Unicode
								my ($w_before, $w_after);
								$w_before	= Encode::encode("UTF16-LE", $before);
								$w_after	= Encode::encode("UTF16-LE", $after);
								$success= Win32API::File::MoveFileW($w_before, $w_after) 
									or print $ANSIred,"\nError renaming $before: ",Win32API::File::fileLastError(),$ANSInormal;

									# Deprecated method ("hack") to achieve the above
									#
									# NB: elsif($after_is_unicode && -e "$ENV{WINDIR}\\SYSTEM32\\WSCRIPT.EXE")
									# We use an intermediate VB script to do the renaming	
									#print "\n$ANSIgreen","Dealing with unicode target name...",$ANSInormal;
									#
									#open(FH, ">tmp20060804.vbs");
									#binmode(FH, ":raw:encoding(UTF16-LE):crlf:utf8"); # Win32 encoding
									#print FH "\x{feff}";	# Byte-Order-Mark (BOM)
									#print FH "Dim fso\nSet fso = CreateObject(\"Scripting.FileSystemObject\")\n";
									#print FH "fso.MoveFile \"$before\", \"$after\"";
									#close(FH);
									#
									#$success = system("wscript tmp20060804.vbs");
									#unlink("tmp20060804.vbs");
							}
							else{
								# Plain text, no need for anything fancy
								$success = rename($before, $after);
							} #}}}
						}
 
					if($success && $reversible){ #{{{
						# Create undo information if requested and rename was successfull
						if($undofile eq 'unrename.bat'){
							unless($before_is_unicode || $after_is_unicode){
								unshift(@undo, 'ren "'.$after.'" "'.$before.'"');
							}
							else{
								print $ANSIyellow,
								"\nNote: Cannot save undo info due to unicode characters:",
								"/-  $before",
								"\\-> $after",
								"\n",
								$ANSInormal;
							}
						}
						else{
							unshift(@undo, 'rename ("'.$after.'", "'.$before.'");');
						}
					} #}}}
				}
			}
			if($reversible){ #{{{
				# Tag session block
				$_ = localtime();
				if($undofile eq 'unrename.bat'){
					unshift(@undo, "REM Renaming completed at $_");
				}
				else{
					unshift(@undo, "# Renaming completed at $_");
				}
				
				# Prepend header
				if($undofile eq 'unrename.bat'){
					unshift(@undo, "\@ECHO OFF\nREM TV Renamer undo script\nREM Generated by $0\nECHO Remember to remove this script before using the TV renamer again!\n\n");
				}
				else{
					unshift(@undo, "#!/usr/bin/perl\n# TV Renamer undo script\n# Generated by $0\nprint \"Remember to remove this script before using the TV renamer again!\\n\";\n\n");
				}
				
				# Write to file
				print "\n\n".$ANSIup."Writing undo infomation into $undofile... ".$ANSIsave;
				open(UNDO, '> '.$undofile) || die $ANSIred."Can't open undo script: $!".$ANSInormal;
				foreach(@undo){print UNDO $_."\n"; }
				close(UNDO);
				print $ANSIrestore."Done".$ANSInormal;
			} #}}}
			print "\nRenaming Complete\n";
		}
		else{print $ANSIred."n\n".$ANSInormal;}
	}
} # }}} End USERPROMPT

##[ SUBROUTINES ]############################################################### {{{

sub check_and_push #{{{
{
# Checks array destination is not defined before assigning value
	my ($data, $array_ref, $index) = @_;
	if($array_ref->[$index]){
		print $ANSIred."  Duplicate input: Ep ",$array_ref == \@sname ? 'S' : '' ,$index,
			  " already defined! Discarding redefinition.\n".$ANSInormal;
		  print $ANSIyellow."    Current:   ",$array_ref->[$index],"\n",
				"    Discarded: $data\n".$ANSInormal;
		$warnings++;
	}
	else{
		$data =~  s/^\s+//;             # Trim leading whitespace
		$data =~  s/\s+$//;             # Trim trailing whitespace
		$array_ref->[$index] = $data;   # Feed ep number to array
	}
} # }}} End sub

sub clean_up #{{{
{
# Prepare arguments for filesystem, and do some tidying
	foreach(@_){
		tr/\\/-/;                   # Replace invalid char \ with -
		tr/\//-/;                   # Replace invalid char / with -
		tr/\*/-/;                   # Replace invalid char * with -
		tr/\</-/;                   # Replace invalid char < with (
		tr/\>/-/;                   # Replace invalid char > with )
		tr/\:/-/;                   # Replace invalid char : with -
		tr/\x60/\x27/;              # Replace ` with ' (Using ANSI char vals in _hex_)
		tr/\x22/\x27/;              # Replace " with '
		tr/\x3F//d;                 # Delete invalid char '?'
	}
	return @_;
} #}}} End sub

sub check_group #{{{
{
# Check if our supposed 'group' is actually nothing more than part of the episode title
	if($group){
		$group = ($$titles[$fileNum] =~ /$group/) ? undef : ' ['.$group.']';        
	}
} #}}} End sub

sub pad #{{{
{
# Pad/trim first argument with zeros to the length defined in the second element
# EG. "8" is padded to "008" if the array last index >= 100 (NB the length of such an array >= 101)
	my ($string, $length) = @_;

	($string) = ($string =~ /^0*(\d+)$/);     # Trim leading zeros
	until(length $string  >= $length)         # NB the '>=' allowing renaming without padding zeros
		{$string = '0'.$string; }             # Pad for normals
	
	return ($string);
} #}}} End sub

sub readURLfile #{{{
{
# Extract link from shortcut file
	my ($file) = @_;
	my $url_season;
	my $answer;
	
	print "Parsing internet shortcut: $file\n";
	
	# Temporarily disable our record seperator. This is rest automatically at the end of the block
	local(*FH, $/);
	open(FH, $file) || die "Can't open URL shortcut: $!";
	$_ = <FH>;
	($_) = ($_ =~ /(http:\/\/.*)$/m);
	$/ = "\r";
	chomp;
	if( (($url_season) = ($_ =~ /&season=(\d+)/)) && !/&season=0/ && !/&season=$season/){
		print $ANSIred."Season specified in $ANSIbold\"$file\"$ANSInormal$ANSIred ($url_season) doesn't match the season we're renaming ($season)!\n".$ANSInormal;
		print "\aContinue? [y/".$ANSIbold."N".$ANSInormal."] ";
		if($unattended){
			$answer = 'N';
		}
		else{
			ReadMode "cbreak";
			$answer = ReadKey();
			ReadMode "normal";
		}

		if($answer =~ /y|\.|>/i){    # 'Y', space, enter or the '>'/'.' key
			print $ANSIgreen."y\n".$ANSInormal;
		}else{
			print $ANSIred."n\n".$ANSInormal;
			exit 0;
		}
	}
	return ($_);

} #}}} End sub

# }}} End SUBROUTINES

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
#        BUGFIX: Fixes support for "s01 e01" in file names (space wasn't allowed before)
#
#  v2.25 AniDB search facility fixed, this also broke because of the new AniDB layout {{{2
#
#  v2.26 Added --associate-with-video-folders and --unassociate-with-video-folders, {{{2
#         a pair of windows-specific switches to (un)install a registry change that
#         adds "Use TV Renamer Script" to the right-click menu of video folders
#
#  v2.27 BUGFIX: Season numbers are treated as numbers now (were treated as strings), {{{2
#         so season "06" becomes "6", which fixed automatic fetching from the web.
#
#  v2.28 BUGFIX: Windows-specific associate with Video Folders was causing some people {{{2
#         trouble. The script would set itself as the default action when double clicking
#         a folder - hence you couldn't open a folder anymore! This was because
#         some copies of Windows don't have the default @="open" specified in
#         their registry, the script now sets this when you associate.
#        ENHANCEMENT: Subtitle files are now renamed by default, no need for "--nofilter"
#
#  v2.29 COMPATABILITY: Updated epguide format parser to handle Battlestar {{{2
#         Galactica, which does not have a space between the episode number and
#         production code.
#
#  v2.30 COMPATABILITY: Heirarchical paths (EG "24/Season 6") are now a bit {{{2
#		 fuzzier, allowing "24/Season.6" and the like
#
#  v2.31 FLEXABILITY: --preproc evaluation moved earlier, to allow it to {{{2
#		 manipulate the filename _before_ file extensions are detected.
#		 BUGFIX: Now prints "Reading preferences" message when doing so
#		 MAINTENANCE: Updated AniDB parser in sympathy with AniDB.info's
#		 changes. AniDB search facility also updated.
#
#  v2.32 BUGFIX: Now prints newlines at end of messages {{{2
#		 BUGFIX: Re-worked AniDB parser so that alternative episode titles are
#		 optional- this was causing some pages to be percieved as blank by the
#		 script.
#		 BUGFIX: Updated AniDB parsers in sympathy with changes to AniDB.info
#		 layout changes
#		 FEATURE: Added new scheme: XYY. This creates output suitable for the
#		 --dubious option. E.g. S01E08 -> 108
#
#  v2.33 FEATURE: Added new --scheme variant: SXXEYY. I.e. an upper-case
#		 alternative to the existing sXXeYY
#
#  v2.34 BUGFIX: Series names which contained punctuation would confuse (or
#		  crash!) the script if they happened to resemble a regular expression.
#		  This also prevented it from being able to differentiate between
#		  numbers in the series title and a file's episode number.
#		  BUGFIX: Empty lines in config files no longer upset the script
#		  BUGFIX: TV.com search fixed - the site's HTML layout changed a bit too
#		  much
#		  BUGFIX: Shortcut finding is now case-insensitive, so fixed for
#		  MacOS/Linux/BSD
#		  FEATURE: Now understands double-episode filenames of the form
#		  s01.e08-e09 (note the second "e")
#		  BUGFIX: EpGuides.com parser improved - entries do not have to have
#		  been aired to be parsed correctly - thanks to Tony White for his patch!
#		  BUGFIX: "Specials" name extraction didn't check if the "s" in front of
#		  the episode number was "alone". If it was part of a word, strange
#		  things happened.
#		  BUGFIX: Filename extensions defined in the file filter (see --help) is
#		  no-longer case-sensitive
#
#  v2.35 BUGFIX: SXXEYY parsing had a couple of new bugs from v2.34 - either a
#        leading space was included with the SXXEYY snippet, or the "S" was
#        excluded.  Removed the complex (and now unnecessary) file-name
#        pre-filter that was cauing the problem.
#
#  v2.36 FEATURE: Added support for S00E00E00 file numbering formats, which
#        is more traditionally written as 00x00-00, e.g. "Season-name 1x12-13
#        Eptitle-for-12 - Eptitle-for-13.ext"
#
#  v2.37 BUGFIX: Dubious episode number extraction was broken in the previous
#        release
#
#  v2.38 BUGFIX: Non-anime series now default to "--nogroup", and Anime to (new
#        option) "--group"
#
#  v2.39 BUGFIX: Fixed Unicode support for UTF-8 systems (Linux and probably Mac OS X).
#
#  v2.40 BUGFIX: Fixed compression support for generic-path HTTP sources (used
#        to only work for AniDB.info unique hits, not those that require
#        parsing a search-results page)
#
#        ENHANCEMENT: Added --dontgroup and --dogroup options to disable/enable
#        special handling of filename text found between square brackets (e.g.:
#        '[AnCo]'). This is useful when the "group" is actually the episode
#        number (e.g.: '[3x15]')
#
#  v2.41 BUGFIX: Unicode support was broken for epguides.com. Code-change is
#        global, so although my tests show it works  for EpGuides and AniDB,
#        things may go wrong.
#
#  v2.42 BUGFIX: Updated TV.com parser in response to site changes
#
#        ENHANCEMENT: Adding --deaccent option, which strips accents from
#        proposed filenames. E.g.: è -> e
#        Thank you Brian Stolz for the patch!
#
#  v2.43 ENHANCEMENT: Filename pattern-matching reordered such that 7x01 is
#        preferred over 8-00, which was causing problems with episodes of "24"
#
#  v2.44 ENHANCEMENT: Pilot episode support for EpGuides vastly improved.
#        BUGFIX: --version doesn't print the version twice anymore
#        BUGFIX: Removed warning about $* being unsupported
#
#  v2.45 ENHANCEMENT: EpGuides support improved by removing apostrophes from
#        series names before looking them up
#        ENHANCEMENT: Added --chdir=X which lets you specify the directory to rename
#
#  v2.46 BUGFIX: Didn't properly test v2.45's --chdir support. Fixed
#        season-detection code when used with --chdir
#        MAINTENANCE: Updated EpGuides parser to remove "-img---a- -a-" from
#        certain episodes, caused by the embedding of image-links.
#
#  v2.47 BUGFIX: --season wasn't overriding the auto-detection. Thanks Jørn
#        Odberg for pointing this out!
#
#  v2.48 MAINTENANCE: Replace switch-statements with if..elsif..else
#        statements, to make it easier to compile the Win32 binary
#
#  v2.49 BUGFIX: Comparison of $scheme was using '==' instead of 'eq'
#        BUGFIX: Specifying input file / URL on command line wasn't working
#        MAINTENANCE: Removed some redundant pattern matches in command-line parser
#
#  v2.50 MAINTENANCE: AniDB.info changed back to AniDB.net
#        BUGFIX: AniDB.net data was always treated as compressed, even when not
#        the case (recent version of Perl decompress fetched data
#        automatically). Now uses proper detection.
#
# vim: set ft=perl ff=unix ts=4 sw=4 sts=4 fdm=marker fdc=4:
