#!/usr/bin/perl
# IBM_PROLOG_BEGIN_TAG
# This is an automatically generated prolog.
#
# $Source: src/build/tools/addCopyright.pl $
#
# IBM CONFIDENTIAL
#
# COPYRIGHT International Business Machines Corp. 2011-2012
#
# p1
#
# Object Code Only (OCO) source materials
# Licensed Internal Code Source Materials
# IBM HostBoot Licensed Internal Code
#
# The source code for this program is not published or otherwise
# divested of its trade secrets, irrespective of what has been
# deposited with the U.S. Copyright Office.
#
# Origin: 30
#
# IBM_PROLOG_END_TAG

#################################### ABOUT ####################################
# Forked from:                                                                #
# Author: Mark Jerde (mjerde@us.ibm.com)                                      #
# Date: Fri Mar 19 17:40:32 2010 UTC                                          #
#                                                                             #
# addCopyright.pl will automatically insert appropriate copyright statements  #
# in source files following the IBM copyright guidelines (and templates)      #
# referenced below :                                                          #
#   FSP ClearCase Architecture                                                #
#   Version 1.9                                                               #
#   10/12/2010                                                                #
#   Editor: Alan Hlava                                                        #
#                                                                             #
#   Section 3.14.1 of the above doc has templates for different files         #
#                                                                             #
#   NOTE: FSP uses the phrase "OCO Source materials" in their copyright       #
#           block, which is classified as 'p1' .  We will use the same        #
#           classification here.                                              #
#   NOTE: to list all files in src EXCEPT the build dir, run:                 #
#   make clean      # remove autogenerated files                              #
#   find src -path 'src/build' -prune  -o ! -type d -print | tr '\n' ' '      #
#                                                                             #
#  addCopyright.pl does not support piping, but you can send these            #
#  to a file, add "addCopyright.pl update" to the beginning of the line,      #
#  and run the file to update all                                             #
###############################################################################


use strict;
use warnings;
use POSIX;
use Getopt::Long;
use File::Basename;
use lib dirname (__FILE__);


#------------------------------------------------------------------------------
# Project-specific settings.
#------------------------------------------------------------------------------
my $ReleaseYear = `date +%Y`;
chomp( $ReleaseYear );

my $copyrightSymbol = "";
# my $copyrightSymbol = "(C)";  # Uncomment if unable to use  character.

my  $projectName            =   "HostBoot";

my $copyright_IBM = 'COPYRIGHT International Business Machines Corp';

## note that these use single ticks so that the escape chars are NOT evaluated yet.
my  $OLD_DELIMITER_END      =   'IBM_PROLOG_END';
my  $DELIMITER_END          =   'IBM_PROLOG_END_TAG';
my  $DELIMITER_BEGIN        =   'IBM_PROLOG_BEGIN_TAG';

my  $SOURCE_BEGIN_TAG       =   "\$Source:";
my  $SOURCE_END_TAG         =   "\$";
my  $PVALUE                 =   "p1";       ## my best guess
my  $ORIGIN                 =   "30";

# End Project-specific settings

#------------------------------------------------------------------------------
#   Constants
#------------------------------------------------------------------------------
use constant    RC_INVALID_PARAMETERS   =>  1;
use constant    RC_OLD_COPYRIGHT_BLOCK  =>  2;
use constant    RC_NO_COPYRIGHT_BLOCK   =>  3;
use constant    RC_INVALID_SOURCE_LINE  =>  4;
use constant    RC_INVALID_YEAR         =>  5;
use constant    RC_OLD_DELIMITER_END    =>  6;
use constant    RC_NOT_HOSTBOOT_BLOCK   =>  7;
use constant    RC_NO_COPYRIGHT_STRING  =>  8;
use constant    RC_INVALID_FILETYPE     =>  9;

#------------------------------------------------------------------------------
#   Global Vars
#------------------------------------------------------------------------------
my  $opt_help               =   0;
my  $opt_debug              =   0;
my  $operation              =   "";
my  $opt_logfile            =   "";

my  $DelimiterBegin         =   "";
my  $CopyrightBlock         =   "";
my  $DelimiterEnd           =   "";
my  $CopyRightString        =   "";

my  $TempFile               =   "";
my  @Files                  =   ();

my  $rc                     =   0;

# NOTE: $OLD_DELIMITER_END is a subset of $DELIMITER_END so must match
#       $DELIMITER_END first in order to return the entire string.
my $g_end_del_re = "($DELIMITER_END|$OLD_DELIMITER_END)";
my $g_prolog_re  = "($DELIMITER_BEGIN)((.|\n)+?)$g_end_del_re";

#------------------------------------------------------------------------------
#   Forward Declaration
#------------------------------------------------------------------------------
sub validate( $ );
sub update( $$ );
sub extractCopyrightBlock( $ );
sub checkCopyrightblock( $$ );
sub createYearString( $ );
sub removeCopyrightBlock( $$ );
sub addEmptyCopyrightBlock( $$$ );
sub fillinCopyrightBlock( $$ );
#######################################################################
# Main
#######################################################################
if (scalar(@ARGV) < 2)
{
    ## needs at least one filename and an operation as a parameter
    usage();
}


my  @SaveArgV   =   @ARGV;
#------------------------------------------------------------------------------
# Parse optional input arguments
#------------------------------------------------------------------------------
GetOptions( "help|?"                    =>  \$opt_help,
            "validate"                  =>  sub { $operation="validate";    },
            "update"                    =>  sub { $operation="update";      },

            "log-failed-files=s"        =>  \$opt_logfile,
            "debug"                     =>  \$opt_debug,
          );

##  scan through remaining args and store all files in @Files
##  check for old-type parms, just in case
foreach ( @ARGV )
{
    ## print   $_;
    if  ( m/^debug$/      )   {   $opt_debug  =   1;  next;   }
    if  ( m/^update$/     )   {   $operation  =   $_; next;   }
    if  ( m/^validate$/   )   {   $operation  =   $_; next;   }

    push    @Files, $_ ;
}


if ( $opt_debug )
{
    print   STDERR  __LINE__, " : ---- DEBUG -----\n";
    print   STDERR  "help               =   $opt_help\n";
    print   STDERR  "debug              =   $opt_debug\n";
    print   STDERR  "operation          =   $operation\n";
    print   STDERR  "log-failed-files   =   $opt_logfile\n";

    ## dump files specified
    print   STDERR  "Files:\n";
    print   STDERR  join( ' ', @Files ), "\n";

    print   STDERR  "ReleaseYear        =   $ReleaseYear\n";

    print   "\n";
}

if ( $operation eq  "" )
{
    print   STDOUT  "No operation specified\n";
    usage();
    exit    RC_INVALID_PARAMETERS;
}

if (    ( $opt_logfile   ne  "" )
     ## && ( $operation eq "validate" )
   )
{
    my  $logdate    =   `date +%Y-%m-%d:%H%M`;
    chomp $logdate;
    open( LOGFH, "> $opt_logfile" ) or die "ERROR $?: Failed to open $opt_logfile: $!";
    print   LOGFH   "## logfile generated  $logdate from command line:\n";
    print   LOGFH   $0, " ", join( ' ', @SaveArgV );
    print   LOGFH   "\nFAILING files:\n";
}

########################################################################
##  MAIN
########################################################################
# Loop through all files and process.
foreach ( @Files )
{

    ##  clear global vars
    $DelimiterBegin         =   "";
    $CopyrightBlock         =   "";
    $DelimiterEnd           =   "";
    $CopyRightString        =   "";
    $rc                     =   0;


    ## get filetype
    my $filetype = filetype($_);
    print STDOUT    "File $_: Type $filetype\n";

    ##  set Temporary file name.
    $TempFile   =   "$_.gitCPYWRT";
    if ( $opt_debug )   {   print   STDERR __LINE__, ": Temporary file name = $TempFile\n";    }

    ##
    ##  Special case is this file, just return 0 and add copyright manually.
    ##
    if  ( m/addCopyright\.pl/ )
    {
        print STDOUT    "---------------------------------------------------------\n";
        print STDOUT    "Skipping special case file: $_\n";
        print STDOUT    "         Please add the copyright prolog manually.\n";
        print STDOUT    "---------------------------------------------------------\n";
        next;
    }

    ##
    ##  Gerrit submissions can include deleted files, just warn and continue
    if  ( ! -e $_ )
    {
        print STDOUT    "---------------------------------------------------------\n";
        print STDOUT    "Skipping deleted file: $_\n";
        print STDOUT    "---------------------------------------------------------\n";
        next;
    }

    ##
    ##  Unknown files are valid, but should generate a warning.
    if  ("Unknown" eq $filetype)
    {
        print STDOUT    "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n";
        print STDOUT     "WARNING:: File $_ :Unknown Filetype: $filetype\n";
        print STDOUT     "         Skipping this file and continuing.\n";
        print STDOUT     "         Please add the copyright prolog manually.\n";
        print STDOUT     "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n";

        next;
    }

    ##
    ##  text files are valid, but should generate a warning.
    if  ("txt" eq $filetype)
    {
        print STDOUT    "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n";
        print STDOUT     "WARNING:: File $_ :  Filetype: $filetype\n";
        print STDOUT     "         Skipping this file and continuing.\n";
        print STDOUT     "         If needed, Please add the copyright \n";
        print STDOUT     "         prolog manually.\n";
        print STDOUT     "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n";

        next;
    }

    ##  extract the existing copyright block
    ( $DelimiterBegin, $CopyrightBlock, $DelimiterEnd ) =   extractCopyrightBlock( $_ );

    ##
    ##  validate the file.
    ##  if $logfile exists, print failing filename to $logfile and
    ##      keep going.
    ##  Otherwise, exit with $rc
    ##
    if ( $operation =~  m/validate/i )
    {
        $rc = validate( $_ );
        if ( $rc == RC_OLD_DELIMITER_END )
        {
            ##  special case, let it go for now
            print STDOUT  "$_ has old prolog end '$OLD_DELIMITER_END', please fix\n";
        }
        elsif ( $rc )
        {
            print   STDOUT  "$_ FAILED copyright validation: $rc \n";
            if ( $opt_logfile   ne  "" )
            {
                print   LOGFH   "$_                 # FAILED $rc \n";
            }
            else
            {
                exit $rc;
            }
        }

        ##  continue to next file
        next;
    }   ## endif validate

    ##
    ##  update
    ##
    if ($operation =~ m/update/i)
    {
        $rc =   update( $_, $filetype );
        if ( $rc )
        {
            print   STDOUT  "$_ FAILED copyright update: $rc \n";
            exit $rc;
        }

        ## continue to next file
        next;
    }   ##  endif update

}   #   end foreach




if ( $opt_logfile ne "" )
{
    close( LOGFH );
}

#########################################################################
##  Subroutines
#########################################################################

#######################################
##  usage:  print usage and quit
#######################################
sub usage
{
    print STDOUT    "Usage: addCopyright.pl { update | validate } \n";
    print STDOUT    "                       [ --log-failed-files ]\n";
    print STDOUT    "                       [ --debug ] \n";
    print STDOUT    "                       file1 file2 ...\n";

}

#######################################
##  validate the file
##  param[in]   $filename to validate
##  returns     0 success, nonzero failure
##  See constants above for values of failure
#######################################
sub validate( $ )
{
    my  ( $filename )    =   @_;
    my  $rc =   0;

    if ( $CopyrightBlock  eq  ""  )
    {
        print STDOUT    "WARNING: No copyright block.\n";
        return  RC_NO_COPYRIGHT_BLOCK;
    }

    $rc =   checkCopyrightBlock( $CopyrightBlock, $filename );

    #   good file
    return  $rc;
}

##
##  @sub    update  the copyright block.
##
##  @param[in]  filename
##  @param[in]  filetype
##
##  @return success or failure  (currently only return success)
##
sub update( $$ )
{
    my  ( $filename, $filetype )    =   @_;
    my  $olddelimiter               =   0;
    my  $localrc                    =   0;

    $localrc        =   validate( $filename );

    if (    $localrc  != 0  )
    {
        print   STDOUT  "Copyright Block check returned $localrc , fixing...\n";

        if ( $localrc != RC_NO_COPYRIGHT_BLOCK )
        {
            if ( $opt_debug)    { print STDERR __LINE__, ": remove old copyright block...\n";  }
            removeCopyrightBlock( $filename, $filetype );
        }

        if ($opt_debug) { print STDERR __LINE__, ": Add empty copyright block...\n";   }
        addEmptyCopyrightBlock( $filename, $filetype, $localrc );

        if ( $opt_debug )   { print STDERR __LINE__, ": fill in new copyright block...\n"; }
        fillinEmptyCopyrightBlock( $filename, $filetype );

    }

    ##  return OK by default.
    return 0;
}


#####################################
##  Analyze file and return a text string of the file type
#####################################
sub filetype
{
    my $filename = shift;
    my $fileinfo = `file $filename | sed 's/^.*: //'`;
    chomp $fileinfo;

    # Sorted by anticipated frequency of occurrence.
    if ( $filename =~ m/\.xml$/i )
        # Added XML file to the top of the list because some comments in
        # an XML file cause older versions of 'file' to incorrectly return
        # "ASCII C++ program text" even though the file is obviously XML.
        # Specifically we are seeing "<!-- // ..." cause this trouble.
    {
        return "xml"
    }
    if ( $filename =~ m/\.txt$/i )
    {
        return "txt"
    }
    if ( ( $filename =~ m/\.[cht]$/i )
       ||( $filename =~ m/\.[cht]\+\+$/i )
       ||( $filename =~ m/\.[cht]pp$/i )
       ||( $filename =~ m/\.inl$/ ) # inline C functions
       ||( $filename =~ m/\.y$/ )   # yacc
       ||( $filename =~ m/\.lex$/ ) # flex
       ||( $fileinfo =~ m/c program text/i )
       ||( $fileinfo =~ m/c\+\+ program text/i )
       )
    {
        return "C";
    }
    if ( ( $filename =~ m/\.pl$/ )
       ||( $filename =~ m/\.perl$/ )
       ||( $filename =~ m/\.pm$/ )
       ||( $fileinfo =~ m/perl.*script.*text executable/i) )
    {
        return "Perl";
    }
    if ($filename =~ m/\.s$/i)
    {
        return "Assembly";
    }
    if (($filename =~ m/Makefile$/i) or
        ($filename =~ m/\.mk$/i))
    {
        return "Makefile";
    }
    if ( $filename =~ m/\.am$/i )
    {
        return "Automake";
    }
    if ( ($filename =~ m/configure\.ac$/i)
       ||($filename =~ m/Makefile\.in$/i) )
    {
        return "Autoconf";
    }
    if ( ( $filename =~ m/\.[kc]{0,1}sh$/i )
       ||( $filename =~ m/\.bash$/i )
       ||( $fileinfo =~ m/shell script/i )
       ||( $fileinfo =~ m/^a \/bin\/[af]sh( -x|) *script text( executable|)$/ )
       ||( $fileinfo eq "Bourne shell script text")
       ||( $fileinfo eq "Bourne shell script text executable")
       ||( $fileinfo eq "Bourne-Again shell script text")
       ||( $fileinfo eq "Bourne-Again shell script text executable") )
    {
        return "Shellscript";
    }
    if ( $filename =~ m/\.py$/ )
    {
        return "Python";
    }
    if ( $filename =~ m/\.tcl$/ )
    {
        return "Tcl";
    }
    if ( $filename =~ m/\.x$/ )
    {
        return "RPC";
    }
    if ( ($filename =~ m/^commitinfo$/)
       ||($filename =~ m/^checkoutlist$/)
       ||($filename =~ m/^loginfo$/) )
    {
        return "CVS";
    }
    if ( $filename =~ m/\.emx$/ )
    {
        # Used by Rational Software Architect.  modelling file.
        return "EmxFile";
    }
    if ( $filename =~ m/\.mof$/ )
    {
        return "MofFile";
    }
    if ( $filename =~ m/\.ld$/ )
    {
        return "LinkerScript";
    }
    if ( $filename =~ m/\.rule$/i )
    {
        return "PrdRuleFile"
    }
    if ( ( $filename =~ m/\.emx$/i )
       ||( $filename =~ m/\.odt$/i )
       ||( $filename =~ m/\.gitignore$/i )
       ||( $filename =~ m/\.conf$/i )
       ||( $filename =~ m/\.lidhdr$/i )
       ||( $filename =~ m/\.vpdinfo$/i )
       ||( $filename =~ m/\.pdf$/i )

       )
    {
        # Known, but we can't deal with it so call it unknown.
        return "Unknown";
    }
    if ( -f $filename )
    {
        my $type = `grep "\\\$Filetype:.*\\\$" $filename`;
        if ( $type =~ m/\$Filetype:([^\$]*)\$/ )
        {
            $type = $1;
        }
        $type =~ s/^\s*//;
        $type =~ s/\s*$//;
        my %knownTypes = qw/Assembly Assembly Automake Automake Autoconf Autoconf C C CVS CVS EmxFile EmxFile LinkerScript LinkerScript Makefile Makefile MofFile MofFile Perl Perl PrdRuleFile PrdRuleFile Python Python RPC RPC Shellscript Shellscript Tcl Tcl/;
        return $type if defined($knownTypes{$type});
    }
    { # Other random files containing non-printable characters.
        my $file = `cat $filename`;
        if ( $file =~ m/([^\x20-\x7E\s])/ )
        {
            return "Unknown";
        }
    }
    return "Unknown";
}

########################################################################
##  extractCopyrightBlock
##
##  param[in]   $infile -   filename
##
##  param[out]  returns block or ""
########################################################################
sub extractCopyrightBlock( $ )
{
    my  ( $infile )    =   shift;

    my  $data               =   "";

    open( FH, "< $infile")   or die "ERROR $? : can't open $infile : $!";
    read( FH, $data, -s FH ) or die "ERROR $? : reading $infile: $!";
    close FH;

    ## print   $data;

    # Extract the prolog into beginning delimiter, block data, and end delimiter
    my @prolog = ( '', '', '' );
    @prolog = ($1, $2, $4) if ( $data =~ m/$g_prolog_re/ );

    ##  As long as we're here extract the copyright string within the block
    ##  and save it to a global var
    $CopyRightString = $1 if ( $prolog[1] =~ /(^.*$copyright_IBM.*$)/m );

    if ( $opt_debug )
    {
        print STDERR __LINE__, ": DELIMITER_BEGIN: >${prolog[0]}<\n";
        print STDERR __LINE__, ": DELIMITER_END:   >${prolog[2]}<\n";
        print STDERR __LINE__, ": Extracted Block: \n>>>>>${prolog[1]}<<<<<\n";
        print STDERR __LINE__, ": CopyRightString: >$CopyRightString<\n";
    }

    return @prolog;
}


#######################################
##  Check Copyright Block
##
##  @param[in]   -   Copyright block
##  @parma[in]   -   filename
##
##  @return     0 if success, nonzero otherwise
#######################################
sub checkCopyrightBlock( $$ )
{
    my ( $block, $filename )    =   @_;
    my  $goodsourcelineflag     =   1;          ## init to TRUE
    my  $yearstring             =   createYearString( $filename );
    my  $goodyearflag           =   1;          ## init to TRUE

    ##  Check for old "$IBMCopyrightBlock" signature
    if ( $block =~ m/\$IBMCopyrightBlock:.*\$/s )
    {
        print   STDOUT  "WARNING:  Old copyright block\n";
        return  RC_OLD_COPYRIGHT_BLOCK;
    }

    if ( $DelimiterEnd eq $OLD_DELIMITER_END )
    {
        print   STDOUT  "WARNING:  Old Prolog Tag End\n";
        return  RC_OLD_DELIMITER_END;
    }

    ##  If no $CopyRightString was extracted above, fail with that
    if (    ( !defined( $CopyRightString ) )
         || ( $CopyRightString eq "" )
       )
    {
        print   STDOUT  "WARNING: can't find copyright string\n";
        return  RC_NO_COPYRIGHT_STRING;
    }

    ##  Check to see if this is a HostBoot Copyright notice
    if  ( !( $block =~ m/IBM $projectName Licensed Internal Code/ )  )
    {
        print   STDOUT  "WARNING:  Not a $projectName copyright block\n";
        return  RC_NOT_HOSTBOOT_BLOCK;
    }

    ##  split into lines and check for specific things
    ##      $Source: src/usr/initservice/istepdispatcher/istepdispatcher.H $
    for ( split /^/, $block )
    {
        chomp( $_ );

        ##  verify that the $Source: tag has the correct filename
        if  ( m/.*$SOURCE_BEGIN_TAG.*\$/ )
        {
            if ( $opt_debug )   { print STDERR __LINE__,  ": $SOURCE_BEGIN_TAG : >$_<\n";  }
            $goodsourcelineflag =   grep /$filename/, $_ ;
            if  ( !$goodsourcelineflag )
            {
                print   STDOUT  "WARNING: invalid filename in tag: $_\n";
                print   STDOUT  "         Expected: $filename\n";
                ##  FAIL, bad sourceline
            }
        }

        ##  check for the correct year string
        if  ( m/$copyright_IBM/ )
        {
            $goodyearflag = grep /$copyright_IBM.* $yearstring/, $_;
            if  ( !$goodyearflag )
            {
                print   STDOUT  "WARNING: outdated copyright year: $_\n";
                print   STDOUT  "         Expected: $yearstring\n";
                ##  FAIL, bad yearstring
            }
        }

    }   ## endfor

    if ( !$goodsourcelineflag )
    {
        return  RC_INVALID_SOURCE_LINE;
    }

    if  ( !$goodyearflag )
    {
        return  RC_INVALID_YEAR;
    }

    return  0;
}

sub createYearString( $ )
{
    my  ( $filename )   =   @_;
    my  $yearstr        =   "";
    my  @years          =   ();

    ##  Analyse the CopyRightString for begin and end years - this is for old
    ##  files that are checked in from FSP.  In this case the earliest
    ##  year will be before it was checked into git .  We have to construct
    ##  a yearstring based on the earliest year.
    if ( $CopyRightString =~  m/$copyright_IBM/ )
    {
        @years = ( $CopyRightString =~ /([0-9]{4})/g );
    }
    push @years, $ReleaseYear; # Add the current year.

    ##
    ##  Make a call to git to find the earliest commit date of the file
    ##  new files will not have a log, so the "git log" call above will
    #   return nothing.
    ##  Push any year we find onto the @years array
    my  $cmd = "git log -- $filename | grep Date: | tail --line=1";
    ## print "run $cmd\n";
    my @logstrings = split( " ", `$cmd` );
    if ( $? )   {   die "ERROR $? : Could not run $cmd $!\n";   }

    if ( scalar(@logstrings) >= 5 )
    {
        push @years, $logstrings[5] ;
    }

    ## sort and remove duplicates by loading it into a hash
    my %temphash;
    @temphash{@years} = ();
    my @outyears = sort keys %temphash;

    if ( $opt_debug )
    {   print STDERR __LINE__,  ": years: ", join( ',', @outyears ), "\n"; }

    ## lowest year, which may be the only one.
    $yearstr    =   $outyears[0] ;

    ## if there is more than one index then also output the highest one.
    if ( $#outyears > 0 )
    {
        # A '-' is preferred but CMVC uses ',' so using ','.
        $yearstr    .=  ",$outyears[$#outyears]";
    }


    return  $yearstr;
}

###################################
##  Helper function for removeCopyrightBlock()
###################################
sub removeProlog($$$)
{
    my ( $data, $begin_re, $end_re ) = @_;

    $data =~ s/(\n?)(.*?$begin_re.*$g_prolog_re(.|\n)*?$end_re.*?\n)/$1/;

    return $data;
}

###################################
##  remove old Copyright Block in preparation for making a new one.
##  makes up a debug file named "<filename>.remove"
###################################
sub removeCopyrightBlock( $$ )
{
    my  ( $filename, $filetype )    =   @_ ;
    my  $data                       =   "" ;

    ## Modify file in place with temp file  Perl Cookbook 7.8
    my  $savedbgfile    =   "$filename.remove";
    system( "cp -p $filename $TempFile" );  ## preserve file permissions
    open( INPUT, "< $filename"  )   or die " $? can't open $filename: $!" ;
    read( INPUT, $data, -s INPUT )  or die "ERROR $? :  reading $filename: $!";
    close( INPUT )      or die " $? can't close $filename: $!" ;

    open( OUTPUT, "> $TempFile"  )  or die " $? can't open $TempFile: $!" ;
    select( OUTPUT );               ## new default filehandle for print

    ## preprocess to get rid of OLD_DELIMITER_END
    $data   =~  s/$OLD_DELIMITER_END(\s+?)/$DELIMITER_END$1/;

    if  ( "C"  eq  $filetype )
    {
        ##  pre-process this for /* */ comments
        $data = removeProlog( $data, '\/\*', '\*\/' );

        ## Now apply filter for // comments
        $data = removeProlog( $data, '\/\/', '' );
    }
    elsif  ( ("RPC" eq $filetype) or
             ("LinkerScript" eq $filetype)
           )
    {
        $data = removeProlog( $data, '\/\*', '\*\/' );
    }
    elsif ( $filetype  eq "xml" )
    {
        $data = removeProlog( $data, '<!--', '-->' );
    }
    elsif  ( "Assembly" eq $filetype )
    {
        $data = removeProlog( $data, '\#', '' );
    }
    elsif ( ("Autoconf" eq $filetype) or
            ("Automake" eq $filetype) or
            ("CVS" eq $filetype) or
            ("Makefile" eq $filetype) or
            ("Perl" eq $filetype) or
            ("PrdRuleFile" eq $filetype) or
            ("Python" eq $filetype) or
            ("Shellscript" eq $filetype) or
            ("Tcl" eq $filetype)
          )
    {
        # Don't wipe the the '#!' line at the top.
        $data = removeProlog( $data, '\#', '' );
    }
    else
    {
        print  STDOUT  "ERROR: Don't know how to remove old block from $filetype file.\n";
        close  OUTPUT;
        return RC_INVALID_FILETYPE;
    }

    print   OUTPUT  $data;

    ##  finish up the files
    close( OUTPUT )     or die " $? can't close $TempFile: $!" ;
    rename( $filename, "$savedbgfile" ) or die " $? can't rename $filename: $!" ;
    rename( $TempFile, $filename )      or die " $? can't rename $TempFile: $!" ;
    if ( !$opt_debug )
    {
        ## leave the files around for debug
        unlink( $savedbgfile ) or die " $? can't delete $savedbgfile: $!";

    }
}

###################################
##  Add an empty copyright block to the file, for example (C/C++ files):
##
##  // IBM_PROLOG_BEGIN_TAG IBM_PROLOG_END_TAG
##
##  - The block will be filled-in in the next step.
##
##  @param[in]  -   filename to modify
##  @param[in]  -   filetype
##  @param[in]  -   returncode from validate
##
##  @return     none
##
##  - Makes up a debug file called "<filename>.empty"
##################################
sub addEmptyCopyrightBlock( $$$ )
{
    my ( $filename, $filetype, $validaterc )  =   @_;
    my $line;

    ## Modify file in place with temp file  Perl Cookbook 7.8
    my  $savedbgfile    =   "$filename.empty";
    system( "cp -p $filename $TempFile" ) ;     ## preserve permissions
    open( INPUT, "< $filename"  )   or die " $? can't open $filename: $!" ;
    open( OUTPUT, "> $TempFile"  )  or die " $? can't open $TempFile: $!" ;
    select( OUTPUT );               ## new default filehandle for print
    if ("Assembly" eq $filetype)
    {
        print OUTPUT "# $DELIMITER_BEGIN $DELIMITER_END\n";
    }
    elsif ( ("Makefile"    eq $filetype) or
            ("PrdRuleFile" eq $filetype) )
    {
        print OUTPUT "# $DELIMITER_BEGIN $DELIMITER_END\n";
    }
    elsif (("Autoconf" eq $filetype) or
           ("Automake" eq $filetype) or
           ("CVS" eq $filetype) or
           ("Perl" eq $filetype) or
           ("Python" eq $filetype) or
           ("Shellscript" eq $filetype) or
           ("Tcl" eq $filetype))
    {
        ## All files with a "shebang" at the beginning
        $line = <INPUT>;
        # Keep the '#!' line at the top.
        ##  The following says :  if the first line is a "shebang" line
        ##  (e.g. "#!/usr/bin/perl"), then print it _before_ the copyright
        ##  block, otherwise (the unless line), print it _after_ the copyright
        ## block.
        if ($line =~ m/^#!/)
        {
            print OUTPUT $line;
        }
        print OUTPUT "# $DELIMITER_BEGIN $DELIMITER_END\n";
        unless ($line =~ m/^#!/)
        {
            print OUTPUT $line;
        }
    }
    elsif ( "C" eq $filetype )
    {
        print OUTPUT "/* $DELIMITER_BEGIN $DELIMITER_END */\n";
    }
    elsif ( ("RPC" eq $filetype) or
            ("LinkerScript" eq $filetype)
          )
    {
        # ld stubbornly refuses to use modern comment lines.
        print OUTPUT "/* $DELIMITER_BEGIN $DELIMITER_END */\n";
    }
    elsif ("MofFile" eq $filetype)
    {
        print OUTPUT "// $DELIMITER_BEGIN $DELIMITER_END\n";
    }
    elsif ("xml" eq $filetype )
    {
        print   OUTPUT "<!-- $DELIMITER_BEGIN $DELIMITER_END -->\n";
    }
    else
    {
        print   STDOUT  "ERROR: Can\'t handle filetype:  $filetype\n";
        close( INPUT )      or die " $? can't close $filename: $!" ;
        close( OUTPUT )     or die " $? can't close $TempFile: $!" ;
        ## leave $Tempfile around for debug
        return RC_INVALID_FILETYPE;
    }

    # Copy rest of file
    while (defined($line = <INPUT>))
    {
        print OUTPUT $line;
    }

    ##  finish up the files
    close( INPUT )      or die " $? can't close $filename: $!" ;
    close( OUTPUT )     or die " $? can't close $TempFile: $!" ;
    rename( $filename, "$savedbgfile" ) or die " $? can't rename $filename: $!" ;
    rename( $TempFile, $filename )      or die " $? can't rename $TempFile: $!" ;
    if ( !$opt_debug )
    {
        ## leave the files around for debug
        unlink( $savedbgfile ) or die " $? can't delete $savedbgfile: $!";
    }
}

############################################
## Helper functions for fillinEmptyCopyrightBlock()
############################################
sub addPrologComments($$$)
{
    my ( $data, $begin, $end ) = @_;

    my @lines = split( /\n/, $data );

    $data = '';
    for my $line ( @lines )
    {
        # If there is an block comment end tag, fill the end of the line with
        # spaces.
        if ( $end )
        {
            my $max_line_len = 70;
            my $len = length($line);
            if ( $len < $max_line_len )
            {
                my $fill = ' ' x ($max_line_len - $len);
                $line .= $fill;
            }
        }

        # NOTE: CMVC prologs with inline comments will have a single trailing
        #       space at the end of the line. This is undesirable for most
        #       hostboot developers so it will not be added.

        if ( $line =~ m/$DELIMITER_BEGIN/ )
        {
            $line = "$line $end" if ( $end );
            $line = "$line\n";
        }
        elsif ( $line =~ m/$DELIMITER_END/ )
        {
            $line = "$begin $line";
        }
        else
        {
            if ( not $end and not $line )
            {
                # Compensate for blank lines with no end delimeter.
                $line = "$begin\n";
            }
            else
            {
                $line = "$begin $line";
                $line = "$line $end" if ( $end );
                $line = "$line\n";
            }
        }

        $data .= $line;
    }

    return $data;
}

############################################
##  fill in the empty copyright block
## Copyright guidelines from:
##   FSP ClearCase Architecture
##   Version 1.9
##   10/12/2010
##   Editor: Alan Hlava
##
##   Section 3.14.1 has templates for different files
##
############################################
sub fillinEmptyCopyrightBlock( $$ )
{
    my  ( $filename, $filetype )    =   @_;

    my  $copyrightYear  =   createYearString( $filename );
    ##  define the final copyright block template here.
    my $IBMCopyrightBlock = <<EOF;
$DELIMITER_BEGIN
This is an automatically generated prolog.

$SOURCE_BEGIN_TAG $filename $SOURCE_END_TAG

IBM CONFIDENTIAL

$copyright_IBM. $copyrightYear

$PVALUE

Object Code Only (OCO) source materials
Licensed Internal Code Source Materials
IBM $projectName Licensed Internal Code

The source code for this program is not published or otherwise
divested of its trade secrets, irrespective of what has been
deposited with the U.S. Copyright Office.

Origin: $ORIGIN

$DELIMITER_END
EOF

    ## Modify file in place with temp file  Perl Cookbook 7.8
    my  $savedbgfile    =   "$filename.fillin";
    system( "cp -p $filename $TempFile" );  ## preserve file permissions
    open( INPUT, "< $filename"  )   or die " $? can't open $filename: $!" ;
    open( OUTPUT, "> $TempFile"  )  or die " $? can't open $TempFile: $!" ;
    select( OUTPUT );               ## new default filehandle for print

    my $newline;
    my $lines = "";
    while ( defined($newline = <INPUT>) ) { $lines .= $newline; }

    if ("Assembly" eq $filetype)
    {
        $IBMCopyrightBlock = addPrologComments($IBMCopyrightBlock, '#', '');
    }
    elsif  ( ("Makefile"    eq $filetype) or
             ("PrdRuleFile" eq $filetype) )
    {
        $IBMCopyrightBlock = addPrologComments($IBMCopyrightBlock, '#', '');
    }
    elsif (("Autoconf" eq $filetype) or
           ("Automake" eq $filetype) or
           ("CVS" eq $filetype) or
           ("Perl" eq $filetype) or
           ("Python" eq $filetype) or
           ("Shellscript" eq $filetype) or
           ("Tcl" eq $filetype))
    {
        ##  all files with a "shebang"
        $IBMCopyrightBlock = addPrologComments($IBMCopyrightBlock, '#', '');
    }
    elsif ( "C" eq $filetype )
    {
        ## lex files are classified as C, but do not recognize '//' comments
        $IBMCopyrightBlock = addPrologComments($IBMCopyrightBlock, '/*', '*/');
    }
    elsif ( ("RPC" eq $filetype) or
            ("LinkerScript" eq $filetype)
          )
    {
        $IBMCopyrightBlock = addPrologComments($IBMCopyrightBlock, '/*', '*/');
    }
    elsif ("EmxFile" eq $filetype)
    {
        # Not yet formatted correctly for EmxFile needs, but should coexist.
        $IBMCopyrightBlock = "$DELIMITER_BEGIN IBM Confidential OCO Source Materials (C) Copyright IBM Corp. $copyrightYear The source code for this program is not published or otherwise divested of its trade secrets, irrespective of what has been deposited with the U.S. Copyright Office. $DELIMITER_END";
    }
    elsif ("MofFile" eq $filetype)
    {
        $IBMCopyrightBlock = addPrologComments($IBMCopyrightBlock, '//', '');
    }
    elsif ( "xml" eq $filetype)
    {
        $IBMCopyrightBlock = addPrologComments($IBMCopyrightBlock, '<!--', '-->');
    }
    else
    {
        print   STDOUT  "ERROR: Can\'t handle filetype:  $filetype\n";
        return RC_INVALID_FILETYPE;
    }


    # Replace existing block with the current content.
    $lines =~ s/$DELIMITER_BEGIN[^\$]*$DELIMITER_END/$IBMCopyrightBlock/s;

    print OUTPUT $lines;

    ##  finish up the files
    close( INPUT )      or die " $? can't close $filename: $!" ;
    close( OUTPUT )     or die " $? can't close $TempFile: $!" ;
    rename( $filename, "$savedbgfile" ) or die " $? can't rename $filename: $!" ;
    rename( $TempFile, $filename )      or die " $? can't rename $TempFile: $!" ;
    if ( !$opt_debug )
    {
        ## leave the files around for debug
        unlink( $savedbgfile ) or die " $? can't delete $savedbgfile: $!";
    }
}
