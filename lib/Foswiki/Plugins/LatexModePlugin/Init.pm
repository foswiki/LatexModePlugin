# LatexModePlugin::Init.pm
# Copyright (C) 2008 W Scott Hoge, shoge at bwh dot harvard dot edu
#
# ported from TWiki to Foswiki, Nov 2008
#
# Copyright (C) 2005-2006 W Scott Hoge, shoge at bwh dot harvard dot edu
# Copyright (C) 2002 Graeme Lufkin, gwl@u.washington.edu
#
# TWiki WikiClone ($wikiversion has version info)
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

package Foswiki::Plugins::LatexModePlugin::Init;

use strict;

my $debug = $Foswiki::Plugins::LatexModePlugin::debug;

sub doInit{

    my %LMPcontext = ();

    # Get preferences values
    $LMPcontext{'default_density'} = 
        &Foswiki::Func::getPreferencesValue( "DENSITY" ) ||
        &Foswiki::Func::getPreferencesValue( "LATEXMODEPLUGIN_DENSITY" ) || 
        116;
    $LMPcontext{'default_gamma'} = 
        &Foswiki::Func::getPreferencesValue( "GAMMA" ) ||
        &Foswiki::Func::getPreferencesValue( "LATEXMODEPLUGIN_GAMMA" ) ||
        0.6;
    $LMPcontext{'default_scale'} = 
        &Foswiki::Func::getPreferencesValue( "SCALE" ) ||
        &Foswiki::Func::getPreferencesValue( "LATEXMODEPLUGIN_SCALE" ) ||
        1.0;

    $LMPcontext{'preamble'} = 
        &Foswiki::Func::getPreferencesValue( "PREAMBLE" ) ||
        &Foswiki::Func::getPreferencesValue( "LATEXMODEPLUGIN_PREAMBLE" ) ||
        '\usepackage{latexsym}'."\n";

    # initialize counters
    # Note, these can be over-written by topic declarations
    $LMPcontext{'eqn'} = &Foswiki::Func::getPreferencesValue( "EQN" ) || 0;
    $LMPcontext{'fig'} = &Foswiki::Func::getPreferencesValue( "FIG" ) || 0;
    $LMPcontext{'tbl'} = &Foswiki::Func::getPreferencesValue( "TBL" ) || 0;
    
    $LMPcontext{'maxdepth'} = 
        &Foswiki::Func::getPreferencesValue( "LATEXMODEPLUGIN_MAXSECDEPTH" ) ||
        0;

    # initialize section counters
    $LMPcontext{'curdepth'} = 0;
    for my $c (1 .. $LMPcontext{'maxdepth'}) {
        $LMPcontext{'sec'.$c.'cnt'} = 0;
        # &Foswiki::Func::getPreferencesValue( "SEC".$c ) || 0;
    }

    $LMPcontext{'eqnrefs'} = (); # equation back-references 
    $LMPcontext{'figrefs'} = (); # figure back-references 
    $LMPcontext{'tblrefs'} = (); # table back-references 
    $LMPcontext{'secrefs'} = (); # table back-references 

    my %e = ();
    $LMPcontext{'hashed_math_strings'} = \%e;
    # $LMPcontext{'markup_opts'} = \%e;
    $LMPcontext{'error_catch_all'} = '';

    # $LMPcontext{'topic'} = $topic;
    # $LMPcontext{'web'} = $web;

    $LMPcontext{'use_color'} = 0; # initialize color setting.

    # $latexout = 1 if ($script =~ m/genpdflatex/);

    my $query = &Foswiki::Func::getCgiQuery();
    $LMPcontext{'rerender'} = &Foswiki::Func::getPreferencesValue( "RERENDER" ) || 0;
    if (($query) and $query->param( 'latex' )) {
        $LMPcontext{'rerender'} = ($query->param( 'latex' ) eq 'rerender');
    }

    $LMPcontext{'alltexmode'} = &Foswiki::Func::getPreferencesValue( "LATEXMODEPLUGIN_ALLTEXMODE" ) || 0;
    if (($query) and $query->param( 'latex' )) {
        $LMPcontext{'alltexmode'} = ($query->param( 'latex' ) eq 'tml');
    }

    Foswiki::Func::getContext()->{'LMPcontext'} = \%LMPcontext;

    # Plugin correctly initialized
    &Foswiki::Func::writeDebug( "- Foswiki::Plugins::LatexModePlugin::doInit() is OK" ) if $debug; 

    return 1;
}

1;
