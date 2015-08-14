#!/usr/bin/perl -l 

#use Modern::Perl;
use strict;
use warnings;

use LWP::Simple; # for doenloading the images
use File::Slurp; # for reading the hash-files
use utf8;
use Data::Printer;

use Email::Stuffer; # for sending email
use Email::Sender::Transport::SMTPS; # for sending email
use Authen::SASL; # for sending email
use MIME::Base64; # for sending email
use IO::Socket::SSL; # for sending email
use WWW::xkcd; # for download image and meta data from the xkcd web side
use IO::All; # for storing image in a file.
use YAML::Any qw(DumpFile LoadFile);
 
use Mojo::UserAgent;

use ExplainXkcd;
use CommitStrip;
use ApeNotMonkey;
use Smbc;
use AbstruseGoose;

if(! -e 'credentials.yaml') {
	my $conf = {
	email => 'dummy@gmx.at',
	pass => '1234',
	};

	DumpFile('credentials.yaml', $conf);
	print "No credentials file found. Create it. Enter email data.\n";
	exit;
}
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
	$body .= "xkcd<br>".$meta->{title}."<br>".$meta->{alt}."<br><br>";
	$pic > io('hashxkcd.png');
	$mail->attach_file('hashxkcd.png') or die "Error adding xkcd comic: $!\n";
			
	# store image url for future runs.
	$urlFiles{'hashxkcd'} = $meta->{img};
}

{
	my $explain_xkcd = ExplainXkcd->new;
	my ($image, $title, $paragraphs, $image_url) = $explain_xkcd->fetch;
	if($image) {
		$anyisnew = 1;
		$body = $body." http://www.explainxkcd.com<br>$title<br>$paragraphs<br>";

		#$mail->attach_file($image) or $body .= " Could not add file '$image': $!";
		$urlFiles{hashexplainxkcd} = $image_url;
	}
}
{
	my $commit_strip = CommitStrip->new;
	my ($image, $image_url) = $commit_strip->fetch;
	if($image) {
		$anyisnew = 1;
		$body = $body." http://www.commitstrip.com<br><br>";
		$urlFiles{hashcommitstrip} = $image_url;
		$mail->attach_file($image) or $body .= " Could not add file '$image': $!";
	}
}

{
	my $ape_not_monkey = ApeNotMonkey->new;
	my ($image, $image_url) = $ape_not_monkey->fetch;
	if($image) {
		$anyisnew = 1;
		$body = $body." http://www.apenotmonkey.com<br><br>";
		$urlFiles{hashape} = $image_url;
		$mail->attach_file($image) or $body .= " Could not add file '$image': $!";
	}
}

{
	my $smbc = Smbc->new;
	my ($image, $image_title, $image_url) = $smbc->fetch;
	if($image) {
		$anyisnew = 1;
		$body = $body." http://www.smbc-comics.com<br>$image_title<br><br>";
		$urlFiles{hashsmbc} = $image_url;
		$mail->attach_file($image) or $body .= " Could not add file '$image': $!";
	}
}
{
	my $abstruse_goose = AbstruseGoose->new;
	my ($image, $image_title, $image_url) = $abstruse_goose->fetch;
	if($image) {
		$anyisnew = 1;
		$body = $body." http://www.abstrusegoose.com<br>$image_title<br><br>";
		$urlFiles{hashAbstruseGoose} = $image_url;
		$mail->attach_file($image) or $body .= " Could not add file '$image': $!";
	}
}

if($anyisnew)
{
	$mail->html_body($body);
 	$mail->transport($transport);
	print "send mail.\n";
	$mail->send_or_die();
}

DumpFile('comics.yaml', \%urlFiles);
