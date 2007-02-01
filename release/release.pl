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
print "Done.\n";

# Tag if upload was successful
# $?'s high byte is the return code (low byte is the signal it died with, if
# any)
$retcode = $? >> 8;
if($retcode = 0)
{
    print "Tagging this release...\n";
    system("c:\\cygwin\\bin\\bash.exe -login -i -c '~/svn/tvrenamer/release/tag.sh'");
    print "Done\n";
}
system("pause");
