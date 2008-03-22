#!/usr/bin/perl
# Release ../trunk/tvrenamer.pl
# 1) Update $version string with latest version in script header and current date
# 2) Compile windows executable from a DOS shell
# 3) Upload

qx{/cygdrive/c/Perl/bin/perl.exe win32_release.pl};
if(@ARGV[0] eq "beta")
{
    print "Renaming to betas...\n";
    rename("tvrenamer.pl", "tvrenamer.beta.pl");
    rename("tvrenamer.exe", "tvrenamer.beta.exe");
    rename("tvrenamer.noansi.exe", "tvrenamer.noansi.beta.exe");
    $script = "tvrenamer.beta.pl";
    $binary = "tvrenamer.beta.exe";
    $64bit_binary = "tvrenamer.noansi.beta.exe";
}
else
{
    $script = "tvrenamer.pl";
    $binary = "tvrenamer.exe";
    $64bit_binary = "tvrenamer.noansi.exe";
}
print "Uploading...";
system("scp $script $binary $64bit_binary robmeerman.co.uk:public_html/downloads");
print "Done.\n";

# Tag if upload was successful (and the environment doesn't have a NOTAG
# variable)
# $?'s high byte is the return code (low byte is the signal it died with, if
# any)
$retcode = $? >> 8;
if(0 == $retcode and @ENV{NOTAG} eq "" and @ARGV[0] ne "beta")
{
    print "Tagging this release...\n";
    system('./tag.sh');
    print "Done\n";
}
system("cmd /C 'pause'");
