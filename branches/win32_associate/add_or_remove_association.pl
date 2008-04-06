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

	qx/regedit tvrenamer_unassociate_win32.reg/;
	unlink("tvrenamer_unassociate_win32.reg");
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
	# FIXME, ok we got the short-names for the perl executable and this script,
	# now create a pair of registry fragments to merge into the registry!
	$invokation =~ s/\\/\\\\/g;
	$script_location =~ s/\\/\\\\/g;
	$script_location =~ s/^(.*)\n/$1/;	# Inexplicibly multiline string. Keep only first line
	open(FH, '> tvrenamer_associate_win32.reg');
	print FH "REGEDIT4\n\n";
	print FH '[HKEY_CLASSES_ROOT\SystemFileAssociations\Directory.Video\shell\tvrenamer]',"\n";
	print FH '@="Use T&V Renamer script"',"\n";
	print FH "\n";
	print FH '[HKEY_CLASSES_ROOT\SystemFileAssociations\Directory.Video\shell\tvrenamer\command]',"\n";
	print FH '@="cmd /C \"cd %1 & ',$invokation,' ',$script_location,' & pause\""',"\n";
	close(FH);

	qx/regedit tvrenamer_associate_win32.reg/;
	unlink("tvrenamer_associate_win32.reg");
	exit 0;
}

