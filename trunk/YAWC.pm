#!/usr/bin/env perl
package YAWC;
use strict;
use utf8;
use Cairo;
use Pango;
use Graphics::ColorNames;
use Color::Mix;

use constant {
	PI         => 4 * atan2(1, 1),
	HALF_PI    => 2 * atan2(1, 1),
	NEG_HALF_PI    => -2 * atan2(1, 1),
	TRUE    => 1,
	FALSE    => 0,
};

use Data::Dumper;

# one pixel always use 4bytes 

sub new {
#	my ($height, $width) = (600,800);
	my ($height, $width) = (800,1280);
	my $surface = Cairo::ImageSurface->create ('argb32', $width, $height);
	my $cr = Cairo::Context->create ($surface);

	return bless {
		"width" => $width,
		"height" => $height,
		"surface" => $surface,
		"cr" => $cr,
		"color_engine" => new Graphics::ColorNames,
		"color_mix" => Color::Mix->new,
		"angle_type" => "MOSTLY_HORIZONTAL",
	};

}

sub random_point {
	my $self = shift;
	my ($width, $height) = ($self->{"width"}, $self->{"height"});
	my $x = rand( $width * 0.8 ) + $width * 0.1 ;
	my $y = rand( $height * 0.8 ) + $height * 0.1 ;
	return ($x, $y);
}


# sf1 is source
# sf2 is dest
sub is_intersect {
	my ($self, $yawc) = (@_);
	my $sf1 = $self->{"surface"};
	my $sf2 = $yawc->{"surface"};
	my @bytes1 = unpack "L*", $sf1->get_data;
	my @bytes2 = unpack "L*", $sf2->get_data;
	my $bg_color1 = $bytes1[0];
	my $bg_color2 = $bytes2[0];
	warn "not a same size surface" if ( scalar @bytes1 != scalar @bytes2 ) ;
	for(my $i=0; $i<scalar @bytes1; $i++){
		# we have some char on this pixel
		if ( $bytes1[$i] != $bg_color1 && $bytes2[$i] != $bg_color2 ) {
			print "b1=", $bytes1[$i], "\tb2=", $bytes2[$i], "\n";
			return TRUE;
		}
	}
	return FALSE;
}

sub pick_angle {
	my $self = shift;
	my ($type) = ($self->{"angle_type"});
	if ( $type eq "ANYWAY" ) {
		return rand(1.0) * PI - HALF_PI ;
	} elsif ( $type eq "MOSTLY_HORIZONTAL" ) {
		return rand(1.0) > 0.75 ? -1 * HALF_PI : 0;
	}
	return 0;
}

# we should find a empty point for that word
sub do_layout {
	my ($self, $word) = @_;
	my ($surface, $cr) = ($self->{"surface"}, $self->{"cr"});
	my $cnt = 0;
	my $intersect = FALSE;

	do {
		print "try ", $cnt++, "times\n";
		my $new_yawc = &YAWC::new;
		$new_yawc->set_background_color("white");
		($word->{"x"}, $word->{"y"}) = $new_yawc->random_point;
		$word->{"angle"} = $new_yawc->pick_angle;
		$new_yawc->center_text($word);
		$intersect = $new_yawc->is_intersect($self);
	} while ( $intersect == TRUE );

	return;
}

sub set_source_color {
	my ($self, $color) = @_;
	my ($surface, $cr) = ($self->{"surface"}, $self->{"cr"});
	my ($po) = ($self->{"color_engine"});
	my @rgb = $po->rgb($color);
	$cr->set_source_rgb ($rgb[0]/255.0, $rgb[1]/255.0, $rgb[2]/255.0);
	return;
}

sub set_background_color {
	my ($self, $color) = @_;
	my ($surface, $cr) = ($self->{"surface"}, $self->{"cr"});
	my ($width, $height) = ($self->{"width"}, $self->{"height"});
	my ($po) = ($self->{"color_engine"});
	$cr->save;
	$cr->rectangle (0, 0, $width, $height);
	$self->set_source_color($color);
	$cr->fill;
	$cr->restore;
}


sub save_to_png {
	my ($self, $filename) = @_;
	my ($surface, $cr) = ($self->{"surface"}, $self->{"cr"});
	$surface->write_to_png ($filename);
}

# the input str argument is just like:
# $word = {
#	"font" => "serif",
#	"size" => 30,
#	"x" => 100,
#	"y" => 100,
#	"angle" => 1.0,
#	"text" => "Hello, World",
# };

sub center_text {
	my ($self, $word) = @_;
	my ($surface, $cr) = ($self->{"surface"}, $self->{"cr"});
	my ($width, $height) = ($self->{"width"}, $self->{"height"});

	$cr->save;
	$cr->select_font_face($word->{"font"}, "normal", "normal");
	$self->set_source_color ($word->{"color"});
	$cr->set_font_size($word->{"size"});
	my $te = $cr->text_extents ($word->{"text"});
	my $fe = $cr->font_extents;
	if ( $word->{"x"} < $width && $word->{"y"} < $height ) {
		$cr->translate ($word->{"x"}, $word->{"y"});
		$cr->rotate($word->{"angle"});
		$cr->move_to (-$te->{"width"}/2-$te->{"x_bearing"},
			$fe->{"height"}/2-$fe->{"descent"});
		$cr->show_text($word->{"text"});
	}
	$cr->restore;
}

sub read_words {
	my ($font_min, $font_max) = @_;
	my $all_weight = 0.0;
	my $res = {};
	while (<>) {
		my @a=split /\t/;
		if ( scalar @a == 2 ) {
			$a[0] =~ s/\s*$//g;
			$a[1] =~ s/\s*$//g;
			$all_weight += $a[1];
			$res->{$a[0]}->{"weight"} = 0 if ( ! exists $res->{$a[0]}->{"weight"} );
			$res->{$a[0]}->{"weight"} += $a[1];
		} else {
			warn "error line: $_";
		}
	}
	my ($weight_min, $weight_max) = (1000000000, 0);
	while (my ($k, $v) = each %$res) {
		$weight_max = $v->{"weight"} if ( $v->{"weight"} >$weight_max );
		$weight_min = $v->{"weight"} if ( $v->{"weight"} <$weight_min );
	}
	print "weight_min = $weight_min weight_max = $weight_max\n";
	my @gray_color = Color::Mix->new->analogous('0000FF', 12, 12);
	while (my ($k, $v) = each %$res) {
		$v->{"size"} = (($v->{"weight"} - $weight_min) / ($weight_max - $weight_min)) *
					   ($font_max - $font_min) +
					   $font_min;
		$v->{"text"} = $k;
		$v->{"color"} = $gray_color[int(rand(12))];
	}
	return $res;
}


1;
