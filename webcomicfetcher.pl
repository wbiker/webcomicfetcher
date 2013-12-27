#!/usr/bin/perl -l 

#use Modern::Perl;
use strict;
use warnings;

use LWP::Simple;
use File::Slurp;
use utf8;

use MIME::Lite;
use MIME::Base64;
use Authen::SASL;

#use Data::Dumper;

# in this hash I store the name of the has file and the content of each of them.
# I go through the hash and if the file exists I store the content in the hash.
# later then if I have got the url of the current comic I compare this with the content of the particular file
# If it matches I do nothing, if differs I send this comic.
my %urlFiles = (
	hashAbstruseGoose => "unknown",
	hashxkcd => "unknown",
	hashape => "unknown",
	hashsmbc => "unknown",
);

# Look for each file and read content (aka comix url from the last fetched comic)
foreach my $hashFile (keys %urlFiles) {
	if( -e $hashFile ) {
		open my $FH, "<", $hashFile;
		$urlFiles{$hashFile} = <$FH>;
		close($FH);
		chomp($urlFiles{$hashFile});
	}
}

#print Dumper %urlFiles;

my @fetchComics = (
	[
		"http://www.abstrusegoose.com",	# the root url of the comic
		qw((http://abstrusegoose.com/strips/.*png).*title="(.*)"), # the regex pattern to search the comic url
		"hashAbstruseGoose",	# the file name of the url file. In this file is the url written and with the extension .png it descripts the comic file name.
	],
	[
		"http://www.xkcd.com",
		q(<img src="(http://imgs.xkcd.com/comics/.*png)".*title="(.*)" alt),
		"hashxkcd"
	],
	[
		"http://www.apenotmonkey.com/",
		qq(<img src="(http://www.apenotmonkey.com/comics/.*jpg)".*title="(.*)"),
		"hashape",
	],
	[
		"http://www.smbc-comics.com/",
		qq(<img src='(http://www.smbc-comics.com/comics/.*png)'),
		"hashsmbc",
	],
);
my $anyisnew = 0;
my $body;

#initialize email object
my $mail = MIME::Lite->new(
		From => 'wbiker@gmx.at',
		To => 'wolfgang.banaston@gmail.com,thomas.reisinger@jku.at',
		Subject => 'Webcomics',
		Type => 'multipart/mixed'
	) or die "Error creating multipart container: $!\n";

#print Dumper @fetchComics;
# 0 = url 
# 1 = regex pattern
# 2 = the name of the url file.
my $failed = undef;
foreach my $wc (@fetchComics) {
	my $lines = get($wc->[0]) or $failed = 1;
	if($failed) {
		$failed = undef;
		print $wc->[0], " failed to download. Try it with wget again!\n";
		my $ret = system("wget -O localWebPage ".$wc->[0]);
		if(0 == $ret) {
			$lines = read_file("localWebPage");
			unlink("localWebPage");
		}
		else {
			warn "Something went wrong with wget :-( Wget error code is: $ret";
		}
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
				system($command);
				open my $ofh, ">", $hashFileName;
				print $ofh $desiredPic;
				close($ofh);
				
				# attach to email
				if($title) {
					$body = $body." @{$wc}[0]\n$title\n\n";
				}
				$mail->attach(
					Type => 'image/png',
					Path => "$hashFileName.png",
					Filename => "$hashFileName.png",
					Disposition => 'attachment'
				) or die "Error adding @{$wc}[0] comic: $!\n";
			}
		}
	}
}

if($anyisnew)
{
	$mail->attach(
		Type => 'TEXT',
		Data => $body
	) or die "Error adding body: $!\n";
	print "send mail.\n";
	$mail->send('smtp', 'mail.gmx.de', AuthUser=>'wbiker@gmx.at', AuthPass=>'IlBs1997');
#	$mail->send('smtp', 'mail.gmx.de', AuthUser=>'wbiker@gmx.at', AuthPass=>'IlBs1997', Debug => 1);
}

#print Dumper @fetchComics;
