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
package ExplainXkcd;

use strict;
use warnings;
use feature qw(say);
use Mojo::UserAgent;
use Data::Printer;

use YAML::Any qw(DumpFile LoadFile);

sub new {
	my $class = shift;

	return bless {
		url => 'http://www.explainxkcd.com/wiki/index.php/Main_Page',
		selector_image => '.image > img:nth-child(1)',
		selector_explain => '#mw-content-text > div:nth-child(3) > p:not(:first-child)',
		}, $class;
}

sub fetch {
	my $self = shift;

	my $last_comic_urls = LoadFile('comics.yaml');
	my $last_url = $last_comic_urls->{hashexplainxkcd} // "";

	my $ua = Mojo::UserAgent->new;
	my $response;
	my $image_url;
	$response = $ua->get($self->{url});
	if(!$response->success) {
		say "Get failed";
	} # if not response success
	else {
		my $dom = $response->res->dom;
		
		my $image_url;
		my $image_title;
		my $explain_paragraphs = "";
		my $img = $dom->find($self->{selector_image});
		$img->each(sub {
			my ($e, $num) = @_;
			$image_url = 'http://www.explainxkcd.com' . $e->attr('src');
			$image_title = $e->attr('alt');
		});
		my $ps = $dom->find($self->{selector_explain});
		$ps->each(sub {
			my ($e, $num) = @_;
			$explain_paragraphs .= $e->content;
		});

		if($last_url ne $image_url) {
			say "last '$last_url'";
			say "now  '$image_url'";
			say "image url $image_url";
			my $command = "wget -O explainxkcd.png ".$image_url;
			system($command);
			return ("explainxkcd.png", $image_title, $explain_paragraphs, $image_url);
		}
	}
	return;
}

1;
