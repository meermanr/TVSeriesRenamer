#!c:\\Perl\\bin\\perl.exe
# Win32_Release.pl
# This is a utility script used to compile tvrenamer into a 
# win32 .EXE file

# A win32 binary created under cygwin only works under cygwin,
# which is not what we want.
if($^O eq "cygwin")
{
    print STDERR "You really ought to run this from MS-DOS!\n";
    exit 1;
}

# Required to compile without cygwin bindings
$ENV{"PATH"}="c:\\Perl\\bin;".$ENV{"PATH"};

# Read original into memory
print "Reading in original tvrenamer.pl...";
local(*FH, $/);     # Temporarily disable the record seperator (aka "enter slurp mode")
open(FH, '< C:\\cygwin\\home\\meermanr\\svn\\tvrenamer\\trunk\\tvrenamer.pl');
$_ = <FH>;
close(FH);
print " done\n";

# Update release VERSION
print "Updating version string to match most recent changelog entry...\n";
$version = qx!c:\\cygwin\\bin\\bash.exe -login -i -c "head -n300 ~/svn/tvrenamer/trunk/tvrenamer.pl | egrep '^# +v[0-9]' |sed -e 's/^#\\s\\+v//' | cut -d ' ' -f1 | tail -n1"!;
$version =~ s/\n//mg;	# Can't use chomp due to $/ override (above)
print "Version detected to be $version\n";
s/(^my \$version = "\D+)\d+\.\d+/$1$version/m;

# Update release DATE
print "Updating timestamp in version info...\n";
$datestamp = qx/c:\\cygwin\\bin\\date.exe +"%d %B %Y"/;
$datestamp =~ s/\n//mg;	# Can't use chomp due to $/ override (above)
s/(my \$version = ".*?Released )[^"]*/$1$datestamp\n/;

# Write updated script to file
print "Saving these changes to tvrenamer.pl...\n";
open(FH, '> tvrenamer.pl');	# Dump this out
print FH $_;
close(FH);

# Fix up this file to have unix line endings
qx/c:\\cygwin\\bin\\dos2unix.exe tvrenamer.pl/;

# Win32 changes
print "Enabling DOS colour...\n";
s/^#use Win32::Console::ANSI/use Win32::Console::ANSI/m;    # Comment in DOS ANSI

# Create new script file
print "Writing modified script to tvrenamer_win32.pl...";
local(*FH, $/);     # Temporarily disable the record seperator (aka "enter slurp mode")
open(FH, '> tvrenamer_win32.pl');
print FH $_;
close(FH);
print " done\n";

# Run the perl packager to make it a win32 binary
print "Packaging script into .exe...";
qx#cmd /C "c:\\Perl\\bin\\pp.bat tvrenamer_win32.pl -o tvrenamer.exe -v"#;
print " done\n";
print "Packaging script into 64-bit edition .exe...";
qx#cmd /C "c:\\Perl\\bin\\pp.bat tvrenamer.pl -o tvrenamer.noansi.exe -v"#;
print " done\n";
