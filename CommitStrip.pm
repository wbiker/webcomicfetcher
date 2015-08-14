#!/usr/bin/env perl 
#===============================================================================
#
#         FILE: test.pl
#
#        USAGE: ./test.pl  
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
#      CREATED: 23/03/15 19:48:20
#     REVISION: ---
#===============================================================================
package CommitStrip;

use strict;
use warnings;
use feature qw(say);
use Mojo::UserAgent;
use Data::Printer;

use YAML::Any qw(DumpFile LoadFile);

sub new {
	my $class = shift;

	return bless {
		url => 'http://www.commitstrip.com/en/',
		selector_image => 'a[href*="http://www.commitstrip.com/wp-content/uploads"]',
		selector_explain => '',
		}, $class;
}

sub fetch {
	my $self = shift;

	my $last_comic_urls = LoadFile('comics.yaml');
	my $last_url = $last_comic_urls->{hashcommitstrip} // "";

	my $ua = Mojo::UserAgent->new;
	my $response;
	my $image_url;
	$response = $ua->get($self->{url});
	if(!$response->success) {
		say "Get failed";
		say $response->error->message;
	} # if not response success
	else {
		my $dom = $response->res->dom;
		
		my $image_url;
		my $image_title;
		my $explain_paragraphs = "";
		my $img = $dom->find($self->{selector_image});
		$img->each(sub {
			my ($e, $num) = @_;
			$image_url = $e->attr('href');
		});

		if($last_url ne $image_url) {
			say "last '$last_url'";
			say "now  '$image_url'";
			say "image url $image_url";
			my $command = "wget -O commitstrip.png ".$image_url;
			system($command);
			return ("commitstrip.png", $image_url);
		}
	}
	return;
}

1;
