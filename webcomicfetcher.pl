#!/usr/bin/perl -l 

#use Modern::Perl;
use strict;
use warnings;

use LWP::Simple; # for doenloading the images
use File::Slurp; # for reading the hash-files
use utf8;

use Email::Stuffer; # for sending email
use Email::Sender::Transport::SMTPS; # for sending email
use Authen::SASL; # for sending email
use MIME::Base64; # for sending email
use IO::Socket::SSL; # for sending email
use WWW::xkcd; # for download image and meta data from the xkcd web side
use IO::All; # for storing image in a file.
use YAML::Any qw(DumpFile LoadFile);
 
use Mojo::UserAgent;

my $credentials = LoadFile('credentials.yaml');
my $email = $credentials->{email};
my $password = $credentials->{pass};

my $transport = Email::Sender::Transport::SMTPS->new(
    host => 'smtp.gmx.net',
    ssl  => 'starttls',
    sasl_username => $email,
    sasl_password => $password,
    SSL_verify_mode => SSL_VERIFY_NONE,
                 );

# in this hash I store the name of the hash file and the content of each of them.
# I go through the hash and if the file exists I store the content in the hash.
# later then if I have got the url of the current comic I compare this with the content of the particular file
# If it matches I do nothing, if differs I send this comic.
my %urlFiles = (
	hashAbstruseGoose => "unknown",
	hashxkcd => "unknown",
	hashape => "unknown",
	hashsmbc => "unknown",
);

# read in the image urls of the last run and store them.
eval {
	my $ufs = LoadFile('comics.yaml');
	$urlFiles{$_} = $ufs->{$_} for keys %{$ufs};
};

my @fetchComics = (
	[
		"http://www.abstrusegoose.com",	# the root url of the comic
		'img[src*="http://abstrusegoose.com/strips"]', # the regex pattern to search the comic url
		"hashAbstruseGoose",	# the file name of the url file. In this file is the url written and with the extension .png it descripts the comic file name.
	],
	[
		"http://www.apenotmonkey.com/",
		'img[src*="http://www.apenotmonkey.com/comics"]',
		"hashape",
	],
	[
		"http://www.smbc-comics.com/",
		'img#comic',
		"hashsmbc",
	],
);
my $anyisnew = 0;
my $body = "Comics:\n";

#initialize email object
my $mail = Email::Stuffer->new;
$mail->to('wolfgang.banaston@gmail.com,thomas.reisinger@jku.at,armin.praher@sophos.com');
$mail->from('wbiker@gmx.at');
$mail->subject('Webcomics');

# for xkcd I have got the great WWW::xkcd module.
my $xkcd = WWW::xkcd->new;
my ($pic, $meta) = $xkcd->fetch;

my $hashFileName = $meta->{img};
if($urlFiles{hashxkcd} ne $hashFileName) {
    print "New xkcd comic\n";
	$anyisnew = 1;
	$body .= "xkcd\n".$meta->{title}."\n".$meta->{alt}."\n\n";
	$pic > io('hashxkcd.png');
	$mail->attach_file('hashxkcd.png') or die "Error adding xkcd comic: $!\n";
			
	# store image url for future runs.
	$urlFiles{'hashxkcd'} = $meta->{img};
}

#print Dumper @fetchComics;
# 0 = url 
# 1 = regex pattern
# 2 = the name of the url file.
my $failed = undef;
my $ua = Mojo::UserAgent->new;
foreach my $wc (@fetchComics) {
	my $response;
    $hashFileName = $wc->[2];
	$response = $ua->get($wc->[0]) or $failed = 1;
	if(!$response->success) {
		parse_html($response->res->body);
	} # if not response success
	else {
		my $dom = $response->res->dom;
		
		my $img = $dom->find($wc->[1])->first;
        if($img) {
			my $desiredPic = $img->attr('src');
			if($wc->[0] =~ /smbc/i) {
				$desiredPic = $wc->[0] . $desiredPic;
			}
    		if($urlFiles{$hashFileName} ne $desiredPic) {
   	            # new pic 
				$anyisnew = 1;
				my $command = "wget -O $hashFileName.png ".$desiredPic;
				print $command;
				
   	    	    system($command); # use wget to fetch comic

        		# store the new image url in the hash. Hash is stored in a file at the end of the script.
            	$urlFiles{$hashFileName} = $desiredPic;
				# attach to email
				my $title = $img->attr('title');
				if($title) {
					$body = $body." @{$wc}[0]\n$title\n\n";
				}
				else {
					$body = $body." @{$wc}[0]\nNo title\n\n";
				}
				$mail->attach_file(
				#	Type => 'image/png',
				#	Path => "$hashFileName.png",
					"$hashFileName.png",
				#	Disposition => 'attachment'
				) or die "Error adding @{$wc}[0] comic: $!\n";
        	}
		}
	}
}

if($anyisnew)
{
	$mail->text_body($body);
 	$mail->transport($transport);
	print "send mail.\n";
	$mail->send_or_die();
}

DumpFile('comics.yaml', \%urlFiles);

#print Dumper @fetchComics;
sub parse_html {
	my $wc = shift;
	$failed = undef;
	print $wc->[0], " failed to download. Try it with wget again!\n";
	my $ret = system("wget -O localWebPage ".$wc->[0]);
	my $lines;
	if(0 == $ret) {
		$lines = io("localWebPage")->slurp;
		unlink("localWebPage");
	}
	else {
		warn "Something went wrong with wget :-( Wget error code is: $ret";
	}
	
	if($lines) {
		my $pattern = @{$wc}[1];
		if($lines =~ /$pattern/) {
			print "found $pattern";
			my $desiredPic = $1;
			my $title = $2 // "";
		
			$title =~ s/&quot;/" /g;
			$title =~ s/&#39;/' /g;

			my $hashFileName = @{$wc}[2];
			if($urlFiles{$hashFileName} ne $desiredPic) {
				$anyisnew = 1;
				my $command = "wget -O $hashFileName.png ".$desiredPic;
				print $command;
				
       	        	system($command); # use wget to fetch comic

       		        # store the new image url in the hash. Hash is stored in a file at the end of the script.
                	$urlFiles{$hashFileName} = $desiredPic;
				
				# attach to email
				if($title) {
					$body = $body." @{$wc}[0]\n$title\n\n";
				}
				$mail->attach_file(
				#	Type => 'image/png',
				#	Path => "$hashFileName.png",
					"$hashFileName.png",
				#	Disposition => 'attachment'
				) or die "Error adding @{$wc}[0] comic: $!\n";
			}
		}
	}
}
