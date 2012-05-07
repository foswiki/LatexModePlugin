# LatexModePlugin.pm
# Copyright (C) 2008 W Scott Hoge, shoge at bwh dot harvard dot edu
#
# ported from TWiki to Foswiki, Nov 2008
#
# Copyright (C) 2005-2006 W Scott Hoge, shoge at bwh dot harvard dot edu
# Copyright (C) 2002 Graeme Lufkin, gwl@u.washington.edu
#
# Copyright (C) 2000-2001 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001 Peter Thoeny, Peter@Thoeny.com
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at 
# http://www.gnu.org/copyleft/gpl.html
#
# =========================
#
# This is a Latex Mode Foswiki Plugin.  See Foswiki.LatexModePlugin for details.
#

# LatexModePlugin: This plugin allows you to include mathematics and
# other Latex markup commands in Foswiki pages.  To declare a portion of
# the text as latex, enclose it within any of the available markup tags:
#    %$ ... $%    for in-line equations
#    %\[ ... \]%  or
#    %MATHMODE{ ... }% for own-line equations
#
# For multi-line, or more complex markup, the syntax
# %BEGINLATEX{}% ... %ENDLATEX% is also available.
#
# An image is generated for each latex expression on a page by
# generating an intermediate PostScript file, and then using the
# 'convert' command from ImageMagick.  The rendering is done the first
# time an expression is used.  Subsequent views of the page will not
# require a re-render.  Images from old expressions no longer included
# in the page will be deleted.

### for custom styles, LaTeX needs to know where to find them.  The
### easiest way is to use a texmf tree below 'HOME'
$ENV{'HOME'} = $Foswiki::cfg{Plugins}{LatexModePlugin}{home} ||
    '/home/nobody';


# =========================
package Foswiki::Plugins::LatexModePlugin;

use strict;

# =========================
use vars qw( $VERSION $RELEASE $debug
             $sandbox $initialized
             );
#             @EXPORT_OK
#             $user $installWeb 
#             $default_density $default_gamma $default_scale $preamble
#             $eqn $fig $tbl $use_color @norender $tweakinline $rerender


# number the release version of this plugin
our $VERSION = '$Rev$';
our $RELEASE = '4.0';
# our $SHORTDESCRIPTION = 'Enables <nop>LaTeX markup (mathematics and more) in Foswiki topics';

# =========================
sub initPlugin
{
    my ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $Foswiki::Plugins::VERSION < 1.025 ) { 
        # this version is Foswiki compatible
        &Foswiki::Func::writeWarning( "Version mismatch between LatexModePlugin and Plugins.pm" );
        return 0;
    }

    #get the relative URL to the attachment directory for this page
    # $pubUrlPath = # &Foswiki::Func::getUrlHost() . 
    #     &Foswiki::Func::getPubUrlPath() . "/$web/$topic";
    
    # Get preferences values
    $debug = &Foswiki::Func::getPreferencesFlag( "LATEXMODEPLUGIN_DEBUG" );

    $initialized = 0;

    if( $Foswiki::Plugins::VERSION >= 1.1 ) {
        $sandbox = $Foswiki::sharedSandbox || 
            $Foswiki::sandbox;    # for Foswiki 1.0.0
    } else {
        $sandbox = undef;
    }

    Foswiki::Func::registerTagHandler( 'REFLATEX', \&handleReferences );

    return 1;
}


sub commonTagsHandler
{
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    ######################################################

    if ( !($initialized) ) {
        if ( ($_[0]=~m/%(REFLATEX|MATHMODE){.*?}%/) ||
             ($_[0]=~m/%BEGINALLTEX.*?%/)  ||
             ($_[0]=~m/%SECLABEL.*?%/)  ||
             ($_[0]=~m/%BEGINLATEX.*?%/)  ||
             ($_[0]=~m/%BEGIN(FIGURE|TABLE){.*?}%/) ||
             ( ($_[0] =~ m/%\$/) and ($_[0] =~ m/\$%/) ) || 
             ( ($_[0] =~ m/%\\\[/) and ($_[0] =~ m/\\\]%/) )
             ) 
        {   require Foswiki::Plugins::LatexModePlugin::Init;
            require Foswiki::Plugins::LatexModePlugin::Render;
            require Foswiki::Plugins::LatexModePlugin::CrossRef;
            eval(" require Foswiki::Plugins::LatexModePlugin::Parse;");
            $initialized = &Foswiki::Plugins::LatexModePlugin::Init::doInit(); 
        }
        else 
        { return; }
    }

    Foswiki::Func::getContext()->{'LMPcontext'}->{'topic'} = $_[1];
    Foswiki::Func::getContext()->{'LMPcontext'}->{'web'} = $_[2];

    Foswiki::Func::writeDebug( " Foswiki::Plugins::LatexModePlugin::commonTagsHandler( $_[2].$_[1] )" ) if $debug;

    # This is the place to define customized tags and variables
    # Called by sub handleCommonTags, after %INCLUDE:"..."%

    $_[0] =~ s!%BEGINALLTEX({.*?})?%(.*?)%ENDALLTEX%!&handleAlltex($2,$1)!gseo;
    return if ( Foswiki::Func::getContext()->{'LMPcontext'}->{'alltexmode'} );

    ### pass through text to assign labels to section numbers
    ###
    $_[0] =~ s!---(\++)(\!*)\s*(%SECLABEL{.*?}%)?\s(.*?)\n!&handleSections($1,$2,$3,$4) !gseo;

    # handle floats first, in case of latex markup in captions.
    $_[0] =~ s!%BEGINFIGURE{(.*?)}%(.*?)%ENDFIGURE%!&handleFloat($2,$1,'fig')!giseo;
    $_[0] =~ s!%BEGINTABLE{(.*?)}%(.*?)%ENDTABLE%!&handleFloat($2,$1,'tbl')!giseo;

    ### handle the standard syntax next
    $_[0] =~ s/%(\$.*?\$)%/&handleLatex($1,'inline="1"')/gseo;
    $_[0] =~ s/%(\\\[.*?\\\])%/&handleLatex($1,'inline="0"')/gseo;
    $_[0] =~ s/%MATHMODE{(.*?)}%/&handleLatex("\\[".$1."\\]",'inline="0"')/gseo;
    
    # pass everything between the latex BEGIN and END tags to the handler
    # 
    $_[0] =~ s!%BEGINLATEX{(.*?)}%(.*?)%ENDLATEX%!&handleLatex($2,$1)!giseo;
    $_[0] =~ s!%BEGINLATEX%(.*?)%ENDLATEX%!&handleLatex($1,'inline="0"')!giseo;
    $_[0] =~ s!%BEGINLATEXPREAMBLE%(.*?)%ENDLATEXPREAMBLE%!&handlePreamble($1)!giseo;

    # last, but not least, replace the references to equations with hyperlinks
    # $_[0] =~ s!%REFLATEX{(.*?)}%!&handleReferences($1)!giseo;
}

# =========================
sub handleAlltex
{
    return unless ($initialized);

    &Foswiki::Plugins::LatexModePlugin::Parse::handleAlltex(@_);
}

# =========================
sub handleFloat
{
    return unless ($initialized);

    &Foswiki::Plugins::LatexModePlugin::CrossRef::handleFloat(@_);
}

# =========================
sub handleSections
{
    return unless ($initialized);

    &Foswiki::Plugins::LatexModePlugin::CrossRef::handleSections(@_);
}

# =========================
sub handleReferences
{
    return unless ($initialized);

    &Foswiki::Plugins::LatexModePlugin::CrossRef::handleReferences(@_);
}

# =========================
sub handleLatex
{
    return unless ($initialized);

    &Foswiki::Plugins::LatexModePlugin::Render::handleLatex(@_);
}

# =========================
sub handlePreamble
{
    my $text = $_[0];	

    Foswiki::Func::getContext()->{'LMPcontext'}->{'preamble'} .= $text;

    return('');
}

# =========================
sub afterCommonTagsHandler # postRenderingHandler
{
# Here we check if we saw any math, try to delete old files, render new math, and clean up
### my ( $text ) = @_;   # do not uncomment, use $_[0] instead

    return unless ($initialized);

    &Foswiki::Plugins::LatexModePlugin::Render::renderEquations(@_);
}


# =========================

1;


__DATA__
