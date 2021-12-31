TV Series Renamer v2.x
======================

This is an ugly Perl script for tidying up the file-names in large collections 
of video files that belong to television and anime series. Key features:

    * Automatically finds episode titles on the web
    * Understands a massive variety of untidy filenames
    * Very customisable
    * Completely automatic!

The default behaviour [1]_ renames all files in the current directory based on 
the name of that directory. For instance::

    Battlestar Galactica
    `-- Season 4
        |-- Battlestar.Galactica.S04E02.720p.HDTV.x264-2HD.mkv
        `-- Battlestar.Galactica.S04E03.720p.hdtv.x264-ctu.mkv

Running ``tvrenamer.pl`` in this directory will do the following::

    TV Series Renamer v2.51
    Released 07 June 2010
    Detected series name 'Battlestar Galactica' (Season 4)
    Reading input in AutoFetch mode from EpGuides.com
    Fetching document ... [Done]
    Generating changes...[Done]


    Proposed changes:
    ____________________________________

    4x02 - Six of One (2).mkv
    4x03 - The Ties That Bind.mkv
    ____________________________________

    Would you like to proceed with renaming? [y/N/?]: ?


    Proposed changes:
    ____________________________________

    /--  Battlestar.Galactica.S04E02.720p.HDTV.x264-2HD.mkv
    \->  4x02 - Six of One (2).mkv

    /--  Battlestar.Galactica.S04E03.720p.hdtv.x264-ctu.mkv
    \->  4x03 - The Ties That Bind.mkv

    ____________________________________

    Would you like to proceed with renaming? [y/N/?]: n

If you prefer ``S04E02`` over ``4x02``, add the ``--scheme=SXXEYY`` option to 
your command line to get results as follows::

    S04E02 - Six of One (2).mkv
    S04E03 - The Ties That Bind.mkv

And if you hate spaces in filenames because you're a Unix/Solaris veteran, you 
can use ``--unixy`` and ``--separator=_`` to get the following::

    S04E02_Six_of_One_(2).mkv
    S04E03_The_Ties_That_Bind.mkv

There are a great many other options. To give you a taste, here is the full 
list at the time this README was written::

    TV Series Renamer v2.51
    Released 07 June 2010
    Usage: ../../../trunk/tvrenamer.pl [OPTIONS] [FILE|URL|-]

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
     --TV2              Assume input is in http://www.TV.com "All Seasons" format
     --EpGuides         Assume input is in http://www.EpGuides.com format

     Note: If you don't specify an input source, text files with names derived from
     the above will be tried in turn (AniDB.txt, TVtorrents.txt, ...). Failing this
     any .url or .desktop files will be scanned and the first URL found will be
     used. Hence you can put an internet shortcut in the current directory as a
     convenience.

     --search=TV      | Which group of sites to search? TV is the default unless
     --search=anime   | the word "anime" appears somewhere in the current path
     -                  Use STDIN (don't look for URL shortcuts or input files)
      
    Formatting options:
     --scheme=X         Episode number format. One of: SXXEYY, sXXeYY, XxYY, XYY,
                        YY

     Note: Numbers are "padded" with zeros to fit all numbers, so if 9 or
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
     --separator=X      Text to go between episode number and title (EG " - ")
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
     like "SeriesName/Season 1" or "SeriesName/Series 1"

     --autoseries       Use series title from input (useful when automatic
                         searching is disabled)
     --noautoseries     Do not use series title from input, even when available
     --rangemin=X       Discard input titles before X
     --rangemax=X       Discard input titles after X
     --autoranging      Discard input after a large gap (~50) in episode numbers
     --noautoranging    Never discard input due to gaps in numbering
     --dubious          Treat epNums like "234", "1234" as "2x34", "12x34"
     --nodubious        Do normal matching (In case you set --dubious by default)
     --preproc=X        Evaluate some PERL, X, before altering internal filename
     --postproc=X       Evaluate some PERL, X, before altering external filename
                         * The current filename is stored in $_.
                         * EG: --preproc='s/Samurai7/Samurai 7/;' to conform names
                         * EG: --postproc='s/Chapter \d+//;' to strip "Chapter XX"

    Choosing how to interact:
     --detailed         Show 'before -> after' (not just 'after') in proposal
     --show-missing     List episodes not present in your collection
     --interactive      Manually select each change to be applied
     --unattended       Assume NO for all user prompts except "Make changes?"
     --nofilter         Don't filter file extensions by
                         \.(avi|mkv|ogm|mpg|mpeg|rm|wmv|mp4|mpeg4|mov|srt|sub|ssa|smi|sami|txt)$
     --reversible       Create undo script ("unrename.pl" or "unrename.bat")
     --debug            Display debugging info (data extracted from input etc)
     --ANSI             Enable ANSI escape sequences (used for colouring text)
     --noANSI           Disable colour (use if you see gibberish)

    Maniuplating technical behaviour:
     --cache            Use/create .cache files to save 15min chunks of bandwidth
     --nocache          Do no make or use .cache files, always fetch the URL

    Windows-specific functionality:
     --associate-with-video-folders
     --unassociate-with-video-folders

     This will add or remove "Use TV Renamer Script" to the right-click menu of
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

     Report bugs to robert.meerman@gmail.com, I love the attention

Using the docker image
======================

Add the directory containing `tvrenamer` (a shell script without an extension)
to your system's $PATH environment variable, so you can call it from anywhere.

```bash
export "PATH=$PATH:$PWD"
cd 'test_suite/EpGuides_commas/First Love, Second Chance'
tvrenamer
```

Building docker image
=====================

```
./build_docker_image.sh
```

Installation
============

```
cpanm Carton                # Install dependency manager
carton install              # Use dependency manager to install libraries into ./local/
carton exec tvrenamer.pl    # Use dependency manager to load libraries from ./local/

# alternative to carton exec
perl -I./local/lib/perl5 tvrenamer.pl
```

Building Windows executables
============================

Install https://strawberryperl.com/ and run

```powershell
cpanm Carton
carton install
carton install --cpanfile cpanfile.Win32
carton install pp
python compile_win32.py
```

.. [1] I know the internet speaks US English, but this is *my* README :-)
