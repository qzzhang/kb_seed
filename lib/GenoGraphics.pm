# This is a SAS component.

#
# Copyright (c) 2003-2012 University of Chicago and Fellowship
# for Interpretations of Genomes. All Rights Reserved.
#
# This file is part of the SEED Toolkit.
# 
# The SEED Toolkit is free software. You can redistribute
# it and/or modify it under the terms of the SEED Toolkit
# Public License. 
#
# You should have received a copy of the SEED Toolkit Public License
# along with this program; if not write to the University of Chicago
# at info@ci.uchicago.edu or the Fellowship for Interpretation of
# Genomes at veronika@thefig.info or download a copy from
# http://www.theseed.org/LICENSE.TXT.
#

package GenoGraphics;

use strict;

use GD;
use Data::Dumper;
use Carp;
use constant  MINPIX  =>  4;

use SeedHTML;
use SeedAware;
use vars qw($temp_dir $temp_url);
no warnings qw( redefine );

my $temp_dir     = "/tmp";
my $temp_url     = "file://localhost/tmp";
my $image_type   = "jpeg";
my $image_suffix = "jpg";

eval {
    require FIG;
    require FIG_Config;
    $temp_dir = $FIG_Config::temp;
    $temp_url = &FIG::temp_url;

    my $GD_format = $FIG_Config::GD_format || '';
    if ( $GD_format =~ m/^png$/i )
    {
        $image_type   = "png";
        $image_suffix = "png";
    }
    elsif ( $GD_format =~ m/^jpe?g$/i )
    {
        $image_type   = "jpeg";
        $image_suffix = "jpg";
    }
    elsif ( $GD_format =~ m/^gif$/i )
    {
        $image_type   = "gif";
        $image_suffix = "gif";
    }
};

BEGIN {
    eval {
        require Tracer;
        import Tracer;
    };
    if ($@)
    {
        sub T {}
    }
}

#
# A GenoGraphics request is a data structure of the form:
# 
#   1. $gg is a pointer to a list of "maps"
#   2. Each map is a 4-tuple of the form
#
#         [ $text, $beg, $end, $objects ]
#
#      or
#
#         [ [ $text, $link, $popup_text, $menu, $popup_title ], $beg, $end, $objects ]
#
#   3. $objects is a pointer to a list.  Each entry is of the form
#
#         [ $beg, $end, $shape, $color, ???, $url, $popup_text, $menu, $popup_title]
###
#      Whoever did the javascript stuff added fields, but I cannot figure out
#      what the one marked with ??? is.  I just set it to undef. (RAO 2009)
###
#
# When $gg is rendered, each map may be split into a set of
# "submaps", each containing a set of non-overlapping objects.
#
# Thus, $ggR is a data structure in which maps become
#
#         [$text, $beg, $end, $submaps]
#
# Where $submaps is a pointer to a list; each entry in the list
# is a pointer to a list of objects.


sub render {
    my( $gg, $width, $obj_half_heigth, $save, $img ) = @_;
    Trace("Rendering width = $width, OHH = $obj_half_heigth") if T(3);
    if (! $img) { $img = 1 }

    my $maxln = 0;
    my ( $text, $ln );
    foreach ( @$gg )
    {
        $text = ( ref( $_->[0] ) eq "ARRAY" ) ? $_->[0]->[0] : $_->[0];
        $ln = length( $text );
        $maxln = $ln if $ln > $maxln;
    }
    my $left_margin = ( ( $maxln + 1 ) * gdSmallFont->width ) + 5;
    my $image_width = $width + $left_margin;

    my $ggR = &generate_submaps($gg);            # introduces sublevels
    my $gd  = new GD::Image($image_width+5,&height($ggR,$obj_half_heigth));

    my $ismap = {};
    my $color_of = &choose_colors($gd,$ggR);
    &draw( $gd, $ismap, $ggR, $color_of, $width, $obj_half_heigth, $left_margin );
    my( $img_file, $img_url );
    if ($save) 
    { 
        &SeedUtils::verify_dir("$temp_dir/Save");
        #  SeedAware::new_file_name returns file name without path
        my $name = SeedAware::new_file_name( 'GenoGraphics', "$img.$image_suffix", "$temp_dir/Save" );
        $img_file = "$temp_dir/Save/$name";
        $img_url  = "$temp_url/Save/$name";
    }
    else
    {
        #  SeedAware::new_file_name returns file name without path
        my $name = SeedAware::new_file_name( 'GenoGraphics', "$img.$image_suffix", $temp_dir );
        $img_file = "$temp_dir/$name";
        $img_url  = "$temp_url/$name";
    }
    &write_image( $gd, $img_file );
    return &generate_html( $ismap, $img_url, $ggR, $img );
}


sub draw {
    my( $gd, $ismap, $ggR, $colors, $width, $obj_half_heigth, $left_margin ) = @_;
    my( $y, $map, $text, $beg, $end, $submaps, $submap, $object );

    my $map_incr    = 3 * $obj_half_heigth;
    my $submap_incr = (4 * $obj_half_heigth) + int(1.1 * gdSmallFont->height);
    my $text_color  = $colors->{"text"};
    my $char_height = gdSmallFont->height;
    my $char_width  = gdSmallFont->width;

    $y = (2 * $obj_half_heigth) + gdSmallFont->height;
    foreach $map (@$ggR)
    {
        ( $text, $beg, $end, $submaps ) = @$map;

        # draw the text label

        $text = $text->[0] if ref( $text ) eq "ARRAY";
        if ( $text =~ /\S/ )
        {
            $gd->string( gdSmallFont, 5, int($y - (0.5 * $char_height)), $text, $text_color );
            $ismap->{ $map } = [ [ 5,                             $y - $obj_half_heigth ],
                                 [ 5 + length($text)*$char_width, $y + $obj_half_heigth ]
                               ];
        }

        # draw map line + ticks at ends

        my $begP = &get_pos_of_pixel( $gd, $beg, $beg, $end, $width, $left_margin );
        my $endP = &get_pos_of_pixel( $gd, $end, $beg, $end, $width, $left_margin );
        $gd->line( $begP, $y,                  $endP, $y,                  $text_color );
        $gd->line( $begP, $y-$obj_half_heigth, $begP, $y+$obj_half_heigth, $text_color );
        $gd->line( $endP, $y-$obj_half_heigth, $endP, $y+$obj_half_heigth, $text_color );

        foreach $submap ( @$submaps )
        {
            foreach $object ( @$submap )
            {
                my( $begO, $endO, $shapeO, $colorO ) = @$object;
                my $begOP = &get_pos_of_pixel( $gd, $begO, $beg, $end, $width, $left_margin );
                my $endOP = &get_pos_of_pixel( $gd, $endO, $beg, $end, $width, $left_margin );

                #  Is feature too narrow?
                if ( ($endOP - $begOP - 1) < MINPIX )
                {
                    #  Move beginning to get desired width, conserving midpoint
                    $begOP -= int( (MINPIX - ($endOP - $begOP + 1) ) / 2 );
                    #  Adjust if out of bounds
                    $begOP  = $begP if $begOP <  $begP;
                    #  Move end to get desired width
                    $endOP  = $begOP + MINPIX - 1;
                    #  Move end (and beginning) if out of bounds
                    if ( $endOP >= $endP )
                    {
                        $endOP = $endP - 1;
                        $begOP = $endOP - MINPIX + 1;
                    }
                }
                Trace("Shape $shapeO from $begOP to $endOP in color $colorO.") if T(4);

                my $tmp = [];
                my $rtn = \&{$shapeO};
                &$rtn( $gd, $tmp, $y, $begOP, $endOP, $colors->{$colorO}, $obj_half_heigth );
                $ismap->{ $object } = pop @$tmp;
            }
            &text( $gd, $text_color, $submap, $y, $beg, $end, $begP, $endP, $width, $obj_half_heigth, $left_margin );
            $y += $submap_incr;
        }
        $y += $map_incr;
    }
}


sub text {
    my( $gd, $color, $submap, $y, $beg, $end, $begP, $endP, $width, $obj_half_heigth, $left_margin ) = @_;
    my($object);

    my $font_sz = gdSmallFont->width;
    my $text_y  = int($y - ((2 * $obj_half_heigth) + gdSmallFont->height));

    foreach $object (@$submap)
    {
        my($begO,$endO,undef,undef,$textO) = @$object;
        my $begOP = &get_pos_of_pixel( $gd, $begO, $beg, $end, $width, $left_margin );
        my $endOP = &get_pos_of_pixel( $gd, $endO, $beg, $end, $width, $left_margin );
        my $text_start = int((($begOP + $endOP) / 2) - ((length($textO) * $font_sz)/2));
        if ($text_start < $begP)
        {
            $text_start = $begP;
        }
        else
        {
            my $adj_left = $endP - (length($textO) * $font_sz);
            if ($text_start > $adj_left)
            {
                $text_start = $adj_left;
            }
        }
        if ($text_start >= $begOP)
        {
            $gd->string( gdSmallFont, $text_start, $text_y, $textO, $color );
        }
    }
}

sub generate_submaps {
    my($gg) = @_;
    my($ggR,$map,$text,$beg,$end,$objects);

    $ggR = [];
    foreach $map (@$gg)
    {
        ($text,$beg,$end,$objects) = @$map;
        push(@$ggR,[$text,$beg,$end,&split_overlaps($objects)]);
    }
    return $ggR;
}

sub split_overlaps {
    my($objects) = @_;
    my($submaps,$object,$i);

    $submaps = [];
    foreach $object (@$objects)
    {
        for ($i=0; ($i < @$submaps) && &will_not_fit($object,$submaps->[$i]); $i++) {}
        if ($i < @$submaps)
        {
            push(@{$submaps->[$i]},$object);
        }
        else
        {
            push(@$submaps,[$object]);
        }
    }
    return $submaps;
}

sub will_not_fit {
    my($object,$submap) = @_;
    my($i);

    for ($i=0; ($i < @$submap) && (! &overlaps($object,$submap->[$i])); $i++) {}
    return ($i < @$submap);
}

sub overlaps {
    my($obj1,$obj2) = @_;

    return &SeedUtils::between($obj1->[0],$obj2->[0],$obj1->[1]) ||
           &SeedUtils::between($obj2->[0],$obj1->[0],$obj2->[1]);
}

sub height {
    my($ggR,$obj_half_heigth) = @_;
    my($sz,$map,$sub);

    my $map_incr    = 3 * $obj_half_heigth;
    my $submap_incr = (4 * $obj_half_heigth) + int(1.1 * gdSmallFont->height);

    $sz             = (2 * $obj_half_heigth) + gdSmallFont->height;
    foreach $map (@$ggR)
    {
        $sub = $map->[3];
        $sz += ($map_incr + ($submap_incr * @$sub));
    }
    Trace("Height = $sz.") if T(4);
    return $sz;
}

sub choose_colors {
    my($gd,$ggR) = @_;

    my $color_of = {};
    my $colors =
        [
          '255-255-255',  # white
          '0-0-0',        # black
          '192-192-192',  # ltgray
          '128-128-128',  # gray
          '64-64-64',     # dkgray
          '255-0-0',      # red
          '0-255-0',      # green
          '0-0-255',      # blue
          '255-64-192',
          '255-128-64',
          '255-0-128',
          '255-192-64',
          '64-192-255',
          '64-255-192',
          '192-128-128',
          '192-255-0',
          '0-255-128',
          '0-192-64',
          '128-0-0',
          '255-0-192',
          '64-0-128',
          '128-64-64',
          '64-255-0',
          '128-0-64',
          '128-192-255',
          '128-192-0',
          '64-0-0',
          '128-128-0',
          '255-192-255',
          '128-64-255',
          '64-0-192',
          '0-64-64',
          '64-0-255',
          '192-64-255',
          '128-0-128',
          '192-255-64',
          '64-128-255',
          '255-128-192',
          '64-192-64',
          '0-128-128',
          '255-0-64',
          '128-64-0',
          '128-255-128',
          '255-64-128',
          '128-192-64',
          '128-128-64',
          '255-255-192',
          '192-192-128',
          '192-64-128',
          '64-128-192',
          '192-192-64',
          '192-0-128',
          '64-64-192',
          '0-128-192',
          '0-128-64',
          '255-192-128',
          '192-128-0',
          '64-255-255',
          '255-0-255',
          '128-255-255',
          '255-255-64',
          '0-128-0',
          '192-255-192',
          '0-192-0',
          '0-64-192',
          '0-64-128',
          '192-0-255',
          '192-192-255',
          '64-255-128',
          '0-0-128',
          '255-64-64',
          '192-192-0',
          '192-128-192',
          '128-64-192',
          '0-192-255',
          '128-192-192',
          '192-0-64',
          '192-255-255',
          '255-192-0',
          '255-255-128',
          '192-0-0',
          '64-64-0',
          '192-64-192',
          '192-128-255',
          '128-255-192',
          '64-64-255',
          '0-64-255',
          '128-64-128',
          '255-64-255',
          '192-128-64',
          '64-64-128',
          '0-128-255',
          '64-0-64',
          '128-0-192',
          '255-128-255',
          '64-128-0',
          '255-64-0',
          '64-192-192',
          '255-128-0',
          '0-0-64',
          '128-128-192',
          '128-128-255',
          '0-192-192',
          '0-255-192',
          '128-192-128',
          '192-0-192',
          '0-255-64',
          '64-192-0',
          '0-192-128',
          '128-255-64',
          '255-255-0',
          '64-255-64',
          '192-64-64',
          '192-64-0',
          '255-192-192',
          '192-255-128',
          '0-64-0',
          '0-0-192',
          '128-0-255',
          '64-128-64',
          '64-192-128',
          '0-255-255',
          '255-128-128',
          '64-128-128',
          '128-255-0'
        ];

    $color_of->{"background"} = $color_of->{"white"}      = &take_color($gd,$colors);
    $color_of->{"text"}       = $color_of->{"black"}      = &take_color($gd,$colors);
    $color_of->{"ltgray"}     = $color_of->{"ltgrey"}     = &take_color($gd,$colors);
    $color_of->{"gray"}       = $color_of->{"grey"}       = &take_color($gd,$colors);
    $color_of->{"dkgray"}     = $color_of->{"dkgrey"}     = &take_color($gd,$colors);
    $color_of->{'color0'}     = $color_of->{"red"}        = &take_color($gd,$colors);
    $color_of->{'color1'}     = $color_of->{"green"}      = &take_color($gd,$colors);
    $color_of->{'color2'}     = $color_of->{"blue"}       = &take_color($gd,$colors);
    $color_of->{'color3'}     = &take_color($gd,$colors);
    $color_of->{'color4'}     = &take_color($gd,$colors);
    $color_of->{'color5'}     = &take_color($gd,$colors);
    $color_of->{'color6'}     = &take_color($gd,$colors);
    $color_of->{'color7'}     = &take_color($gd,$colors);
    $color_of->{'color8'}     = &take_color($gd,$colors);
    $color_of->{'color9'}     = &take_color($gd,$colors);
    $color_of->{'color10'}    = &take_color($gd,$colors);
    $color_of->{'color11'}    = &take_color($gd,$colors);
    $color_of->{'color12'}    = &take_color($gd,$colors);
    $color_of->{'color13'}    = &take_color($gd,$colors);
    $color_of->{'color14'}    = &take_color($gd,$colors);
    $color_of->{'color15'}    = &take_color($gd,$colors);
    $color_of->{'color16'}    = &take_color($gd,$colors);
    $color_of->{'color17'}    = &take_color($gd,$colors);
    $color_of->{'color18'}    = &take_color($gd,$colors);
    $color_of->{'color19'}    = &take_color($gd,$colors);
    $color_of->{'color20'}    = &take_color($gd,$colors);
    
    my ($map,$submap,$object,$rgb,$color);
    my %how_many;
    foreach $map (@$ggR)
    {
        foreach $submap (@{$map->[3]})
        {
            foreach $object (@$submap)
            {
                $color = $object->[3];
                $how_many{$color}++;
            }
        }
    }

    foreach $color (sort { $how_many{$b} <=> $how_many{$a} } keys(%how_many))
    {
        if ((! $color_of->{$color}) &&
            ($rgb = &take_color($gd,$colors)))
        {
            $color_of->{$color} = $rgb;
        }
    }
    my $tooFew = 0;
    foreach $map (@$ggR)
    {
        foreach $submap (@{$map->[3]})
        {
            foreach $object (@$submap)
            {
                $color = $object->[3];
                if (! $color_of->{$color})
                {
                    $tooFew = 1;
                    $color_of->{$color} = $color_of->{"grey"};
                }
            }
        }
    }
    Trace("Could not allocate enough colors in choose_colors.") if $tooFew && T(1);
    return $color_of;
}

sub take_color {
    my($gd,$colors) = @_;
    my($color);

    if (@$colors > 0)
    {
        $color = shift @$colors;
#       print STDERR "allocating $color: ", scalar @$colors, " left\n";
        return $gd->colorAllocate(split(/-/,$color));
    }
    return undef;
}


#  Left margin was hard coded, making adaptation hard.

sub get_pos_of_pixel {
    my( $gd, $pos, $beg, $end, $width, $left_margin ) = @_;
    if (($end - $beg) == 0)
    {
        confess "Zero-length segment";
    }
    
    #  Margin should be an arg, if not provide previous behavior:

    $left_margin ||= ( 15 * gdSmallFont->width ) + 5;

    return int($left_margin + ($width * (($pos - $beg) / ($end - $beg))));
}


sub filledRectangle {
    my( $gd, $ismap, $y, $begOP, $endOP, $color, $obj_half_heigth ) = @_;
    Trace("filledRectangle begOP = $begOP, endOP = $endOP, color = $color, OHH = $obj_half_heigth.") if T(4);

    my $y1 = $y - $obj_half_heigth;
    my $y2 = $y + $obj_half_heigth;
    $gd->filledRectangle( $begOP, $y1, $endOP, $y2, $color );

    push( @$ismap, [ [ $begOP, $y1 ], [$endOP, $y2 ] ] );
}


sub Rectangle {
    my( $gd, $ismap, $y, $begOP, $endOP, $color, $obj_half_heigth ) = @_;
    Trace("Rectangle begOP = $begOP, endOP = $endOP, color = $color, OHH = $obj_half_heigth.") if T(4);

    my $y1 = $y - 2 * $obj_half_heigth;  # top
    my $y2 = $y + 2 * $obj_half_heigth;  # bottom
    $gd->filledRectangle( $begOP, $y1, $endOP, $y2, $color );

    push( @$ismap, [ [ $begOP, $y1 ], [ $endOP, $y2 ] ] );
}


sub rightArrow
{
    my( $gd, $ismap, $y, $begOP, $endOP, $color, $obj_half_heigth ) = @_;

    my $x0 = $begOP;
    my $x2 = $endOP; 
    my $x1 = $x2 - 2 * $obj_half_heigth;
    my $y0 = $y  + 2 * $obj_half_heigth;
    my $y1 = $y  +     $obj_half_heigth;
    my $y2 = $y;
    my $y3 = $y  -     $obj_half_heigth;
    my $y4 = $y  - 2 * $obj_half_heigth;

    my @poly = ();

    #   y4  *
    #       ***
    #   y2  *****
    #       *** |
    #   y0  *   |
    #    |  |   |
    #   x1 x0  x2
    if ( $x1 <= $x0 )
    {
        push( @poly, [ $x0, $y0 ] );
        push( @poly, [ $x0, $y4 ] );
        push( @poly, [ $x2, $y2 ] );
    }

    #   y4            *
    #   y3  **************
    #   y2  *****************
    #   y1  **************  |
    #   y0  |         *     |
    #       |         |     |
    #      x0        x1    x2
    else
    {
        push( @poly, [ $x0, $y1 ] );
        push( @poly, [ $x0, $y3 ] );
        push( @poly, [ $x1, $y3 ] );
        push( @poly, [ $x1, $y4 ] );
        push( @poly, [ $x2, $y2 ] );
        push( @poly, [ $x1, $y0 ] );
        push( @poly, [ $x1, $y1 ] );
    }
    &render_poly( $gd, $y, \@poly, $color );

    #                upper-left    lower-right
    push( @$ismap, [ [ $x0, $y4 ], [ $x2, $y0 ] ] );
}


sub leftArrow
{
    my( $gd, $ismap, $y, $begOP, $endOP, $color, $obj_half_heigth ) = @_;

    my $x0 = $begOP;
    my $x2 = $endOP; 
    my $x1 = $x0 + 2 * $obj_half_heigth;
    my $y0 = $y  + 2 * $obj_half_heigth;
    my $y1 = $y  +     $obj_half_heigth;
    my $y2 = $y;
    my $y3 = $y  -     $obj_half_heigth;
    my $y4 = $y  - 2 * $obj_half_heigth;

    my @poly = ();

    #   y4       *
    #          ***
    #   y2   *****
    #          ***
    #   y0       *
    #        |   |  |
    #       x0  x2 x1
    if ( $x1 >= $x2 )
    {
        push( @poly, [ $x2, $y0 ] );
        push( @poly, [ $x0, $y2 ] );
        push( @poly, [ $x2, $y4 ] );
    }

    #   y4        *
    #   y3     **************
    #   y2  *****************
    #   y1  |  **************
    #   y0  |     *         |
    #       |     |         |
    #      x0    x1        x2
    else
    {
        push( @poly, [ $x1, $y0 ] );
        push( @poly, [ $x0, $y2 ] );
        push( @poly, [ $x1, $y4 ] );
        push( @poly, [ $x1, $y3 ] );
        push( @poly, [ $x2, $y3 ] );
        push( @poly, [ $x2, $y1 ] );
        push( @poly, [ $x1, $y1 ] );
    }
    &render_poly( $gd, $y, \@poly, $color );

    #                upper-left    lower-right
    push( @$ismap, [ [ $x0, $y4 ], [ $x2, $y0 ] ] );
}


sub topArrow
{
    my( $gd, $ismap, $y, $begOP, $endOP, $color, $obj_half_heigth ) = @_;

    my $x0 = $begOP;
    my $x2 = $endOP; 
    my $x1 = $endOP - $obj_half_heigth;
    my $y0 = $y;
    my $y1 = $y -     $obj_half_heigth;
    my $y2 = $y - 2 * $obj_half_heigth;

    my @poly = ();

    #   y2  *
    #       ***
    #   y1  *****
    #       *** |
    #   y0  *  - - - -  - - - 
    #    |  |   |
    #   x1 x0  x2
    if ( $x1 <= $x0 )
    {
        push( @poly, [ $x0, $y0 ] );
        push( @poly, [ $x0, $y2 ] );
        push( @poly, [ $x2, $y1 ] );
    }

    #   y2  ***********
    #       **************
    #   y1  *****************
    #       **************  |
    #   y0  *********** - - - - - 
    #       |         |     |
    #      x0        x1    x2
    else
    {
        push( @poly, [ $x0, $y0 ] );
        push( @poly, [ $x0, $y2 ] );
        push( @poly, [ $x1, $y2 ] );
        push( @poly, [ $x2, $y1 ] );
        push( @poly, [ $x1, $y0 ] );
    }
    &render_poly( $gd, $y, \@poly, $color );

    #                upper-left    lower-right
    push( @$ismap, [ [ $x0, $y2 ], [ $x2, $y0 ] ] );
}


sub bottomArrow
{
    my( $gd, $ismap, $y, $begOP, $endOP, $color, $obj_half_heigth ) = @_;

    my $x0 = $begOP;
    my $x2 = $endOP; 
    my $x1 = $begOP + $obj_half_heigth;
    my $y0 = $y + 2 * $obj_half_heigth;
    my $y1 = $y +     $obj_half_heigth;
    my $y2 = $y;

    my @poly = ();

    #   y2 - - - *
    #          ***
    #   y1   *****
    #          ***
    #   y0       *
    #        |   |  |
    #       x0  x2 x1
    if ( $x1 >= $x2 )
    {
        push( @poly, [ $x2, $y0 ] );
        push( @poly, [ $x0, $y1 ] );
        push( @poly, [ $x2, $y2 ] );
    }

    #   y2  - - - ***********
    #          **************
    #   y1  *****************
    #       |  **************
    #   y0  |     ***********
    #       |     |         |
    #      x0    x1        x2
    else
    {
        push( @poly, [ $x1, $y0 ] );
        push( @poly, [ $x0, $y1 ] );
        push( @poly, [ $x1, $y2 ] );
        push( @poly, [ $x2, $y2 ] );
        push( @poly, [ $x2, $y0 ] );
    }
    &render_poly( $gd, $y, \@poly, $color );

    #                upper-left    lower-right
    push( @$ismap, [ [ $x0, $y2 ], [ $x2, $y0 ] ] );
}


sub move_and_render_poly {
    my( $gd, $y0, $poly, $color ) = @_;

    my $GDpoly = new GD::Polygon;
    foreach ( @$poly ) { $_->[1] += $y0; $GDpoly->addPt( @$_ ) }
    $gd->filledPolygon( $GDpoly, $color );
}


#  It is not clear why $y is passed.
sub render_poly {
    my( $gd, $y, $poly, $color ) = @_;

    my $GDpoly = new GD::Polygon;
    foreach my $pt ( @$poly )
    {
        my($x,$y) = @$pt;
        $GDpoly->addPt($x,$y);
    }

    $gd->filledPolygon( $GDpoly, $color );
}


sub write_image {
    my( $gd, $file ) = @_;
    open( TMPXXJPEG, ">$file" )
        || die "could not open $file";
    binmode( TMPXXJPEG );
    print TMPXXJPEG $gd->$image_type;
    close( TMPXXJPEG );
    chmod 0666, $file;
}


sub generate_html {
    my( $ismap, $gif, $ggR, $img ) = @_;
    my( $map, $i, $submap, $object, $link, $tip, $menu, $coords, $title, $java, $tag );

    my $html = [];
    my $map_name = "map_table_$$" . "_$img";

    push @$html, qq(<img src="$gif" usemap="#$map_name" border=0>\n),
                 qq(<map name="$map_name">\n);

    foreach $map ( @$ggR )
    {
        #  Allow links to the text titles -- GJO

        my $text = $map->[0]; 
        if ( ref( $text ) eq "ARRAY" && ( $coords = $ismap->{$map} ) )
        {
            ( $text, $link, $tip, $menu, $title ) = @$text;
            if ( ( $text =~ /\S/ ) && ( $link || $tip || $menu ) )
            {
                $coords  = join( ",", map {@$_} @{$coords} );
                $title ||= "Info";
                $java    = ( $tip || $menu ) ? &SeedHTML::mouseover( $title, $tip, $menu )
                                            : undef;

                $tag    =           qq(<area shape="rect" coords="$coords")
                        . ( $link ? qq( href="$link")                       : () )
                        . ( $java ? qq( $java)                              : () )
                        .           qq(>\n);
                push @$html, $tag;
            }
        }

        foreach $submap ( @{$map->[3]} )
        {
            foreach $object ( @$submap )
            {
                $link  = $object->[5];  # Usual html link
                $tip   = $object->[6];  # html text that is displayed on mouseover
                $menu  = $object->[7];  # Context menu.  Do not follow the href on
                                        #    click, put $object->[7] html in a box
                $title = $object->[8];  # Alternative to "Peg info" title text
                                        #    (not everything is a Peg!)

                if ( ( $link || $tip || $menu ) && ( $coords = $ismap->{$object} ) )
                {
                    $coords  = join( ",", map {@$_} @{$coords} );
                    $title ||= "Peg info";
                    $java    = ( $tip || $menu ) ? &SeedHTML::mouseover( $title, $tip, $menu )
                                                 : undef;

                    $tag    =           qq(<area shape="rect" coords="$coords")
                            . ( $link ? qq( href="$link")                       : () )
                            . ( $java ? qq( $java)                              : () )
                            .           qq(>\n);
                    push @$html, $tag;
                }
            }
        }
    }

    push @$html, "</map>\n";
    return $html;
}


sub disambiguate_maps {
    my($gg) = @_;
    my($map,$id,%seen);

    foreach $map (@$gg)
    {
        $id = ref( $map->[0] ) ? $map->[0]->[0] : $map->[0];
        while ($seen{$id}) 
        { 
            if ($id =~ /^(.*)\*(\d+)$/)
            {
                $id = $1 . "*" . ($2 + 1);
            }
            else
            {
                substr($id,-2) = "*0";
            }
        }
        $seen{$id} = 1;
        if ( ref( $map->[0] ) ) { $map->[0]->[0] = $id } else { $map->[0] = $id }
    }
}

1
