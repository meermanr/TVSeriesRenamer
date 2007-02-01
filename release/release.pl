#!/usr/bin/perl
# Upload tvrenamer.pl and tvrenamer.exe

# A win32 binary created under cygwin only works under cygwin,
# which is not what we want.
if($^O eq "cygwin")
{
    print STDERR "You really ought to run this from MS-DOS!\n";
    exit 1;
}

system('win32_release.pl');
if(@ARGV[0] eq "beta")
{
    print "Renaming to betas...\n";
    rename("tvrenamer.pl", "tvrenamer.beta.pl");
    rename("tvrenamer.exe", "tvrenamer.beta.exe");
    $script = "tvrenamer.beta.pl";
    $binary = "tvrenamer.beta.exe";
}
else
{
    $script = "tvrenamer.pl";
    $binary = "tvrenamer.exe";
}
print "Uploading...";
system("c:\\cygwin\\bin\\scp.exe $script $binary robmeerman.co.uk:public_html/downloads");

print "Done.\n\nDON'T FORGET TO TAG THIS RELEASE IN SVN!\n";
