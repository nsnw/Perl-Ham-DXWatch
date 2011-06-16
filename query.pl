#!/usr/bin/perl

# query.pl
#
# (c)2011 Andy Smith <andy@m0vkg.org.uk>
#
# Quick/dirty script to show how to use Ham::DXWatch

use DBI;

require Ham::DXWatch;
require Ham::Locator;
use Data::Dumper;
use Class::Date qw(:errors date localdate gmdate now -DateParse -EnvC);
use strict;
use warnings;
use CGI;
use Getopt::Std;

my $d = new Ham::DXWatch;
my $m = new Ham::Locator;
$d->init();
#$d->set_debug(1);
print "DXWatch Query Tool v1.0\n";
print "(c)2011 Andy Smith M0VKG - http://m0vkg.org.uk/\n\n";
print "Querying dxwatch.com...\n\n";
$d->retrieve_spots();

if($@)
{
	print "\n[31;1mERROR[0m: ".$@."\n";
}
else
{
	print "\n[32;1mOK[0m\n";
}
