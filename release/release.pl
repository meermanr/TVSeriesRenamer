#!/usr/bin/perl
# Upload renamer.pl and tvrenamer.exe

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
