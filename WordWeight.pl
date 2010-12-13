#!/usr/bin/env perl
use strict;
use utf8;
use YAWC;


my $yawc = &YAWC::new;
$yawc->set_background_color("black");
my $words = &YAWC::read_words(16, 36);


while (my ($k, $word) = each %$words) {
	print "k=$k\n";
	$yawc->do_layout($word);
	print "size=", $word->{"size"}, "\tcolor=", $word->{"color"}, "\tx=", $word->{"x"}, "\ty=", $word->{"y"}, "\tangle=", $word->{"angle"}, "\n";
	$yawc->center_text($word);
}

$yawc->save_to_png("output.png");
