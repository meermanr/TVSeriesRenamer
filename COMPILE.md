# Compiling `tvrenamer.exe` on Windows 10 (x86_64)

1. Install [Strawberry Perl](http://strawberryperl.com/) (v5.30)
2. Launch "CPAN Client" via the Start menu (**not** from a cmd.exe prompt!)
3. Within the `cpan>` shell we'll install [PAR Packager](https://metacpan.org/pod/pp), but skip running tests because they fail to unlink temporary files fast enough on my VirtualBox VM:
    a. `get pp`
    b. `notest install pp`
4. (Optional: Uncomment `use Win32::Console::ANSI;` near top of script to enable coloured text)
5. Run `pp -o tvrenamer.exe tvrenamer.pl`

Steps 4 and 5 are scripted in `compile_win32.py`, but that requires Python v2.