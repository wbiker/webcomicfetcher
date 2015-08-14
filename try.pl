#!/usr/bin/env perl 
#===============================================================================
#
#         FILE: try.pl
#
#        USAGE: ./try.pl  
#
#  DESCRIPTION: 
#
#      OPTIONS: ---
# REQUIREMENTS: ---
#         BUGS: ---
#        NOTES: ---
#       AUTHOR: YOUR NAME (), 
# ORGANIZATION: 
#      VERSION: 1.0
#      CREATED: 14/08/15 17:42:35
#     REVISION: ---
#===============================================================================

use v5.14;
use strict;
use warnings;
use utf8;

use Smbc;

my $cs = Smbc->new;

my ($image, $image_url) = $cs->fetch;

say $image;
say $image_url;
