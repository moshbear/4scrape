#!/usr/bin/perl -w
#4chan scraper
#Dependencies: WWW::Curl, HTML::Parser
#
#Changelog:
#
#0.5 Changed: disabled headers in output - JPEG doesn't like non-zero starts
#0.4 Changed: better curl error message
#0.3 Changed: per-file download from wget to curl for finer control
#0.2 Added: scan current dir for existing files to save bandwidth
#0.1 initial version
#
use strict;
use WWW::Curl::Easy;
use HTML::Parser;
my %args = ('board' => '', 'thread' => '');
if (scalar(@ARGV)) {
	$args{'board'} = $ARGV[0];
	$args{'thread'} = $ARGV[1];
} else {
	print "Board: ";
	my $b = <>;
	chop($b);
	print "Thread: ";
	my $t = <>;
	chop($t);
	$args{'board'} = $b;
	$args{'thread'} = $t;
}
	
my $curl = new WWW::Curl::Easy;
$curl->setopt(CURLOPT_HEADER,0);
$curl->setopt(CURLOPT_URL, 'http://boards.4chan.org/'.$args{'board'}.'/res/'.$args{'thread'});
$curl->setopt(CURLOPT_FAILONERROR,1);
my $response_body;
$::errbuf="";
open (my $fileb, ">", \$response_body);
$curl->setopt(CURLOPT_WRITEDATA,$fileb);
$curl->setopt(CURLOPT_ERRORBUFFER, "::errbuf");
my $retcode;
sub curlerror {	return "curl: ($retcode) $::errbuf\n"; }
if (($retcode = $curl->perform) == 0) {
	my @src_in;
	my $p = HTML::Parser->new(api_version => 3);
	$p->report_tags(qw(a));
	$p->handler(start =>
		sub {
			 my ($_0, $_1, $attr, $_2, $_3) = @_;
			 ($attr->{'href'} =~ /i\.4cdn\.org\/$args{'board'}/) and do
			 	push(@src_in,$attr->{'href'});
		},
		"self, tagname, attr, attrseq, text");
	$p->parse($response_body);
	my %t = map { $_ => 1} @src_in;
	my @srcs = sort keys %t;
	for my $z (@srcs) {
		$z =~ s/^\/\//http:\/\//;
	}
	print scalar(@srcs)." image replies in $args{'board'}/$args{'thread'}...\n";
	for my $y (@srcs) {
		my $fn = $y;
		$fn =~ s/^[a-z0-9:.\/]+\///;
		if (-e $fn) {
			print "$fn exists, skipping.\n";
			next;
		}
		print "Downloading $args{'board'}/$fn...";
		$curl->setopt(CURLOPT_URL, $y);
		open (my $f, ">", $fn) or die "Fatal: cannot open file: $!\n";
		$curl->setopt(CURLOPT_WRITEDATA,$f);
		if (($retcode = $curl->perform) == 0) {
			print "OK\n";
			close($f);
		} else { die "Fatal: ".curlerror(); }
	}
} else { die "Fatal: ".curlerror(); }
