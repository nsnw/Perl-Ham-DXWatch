#!/usr/bin/perl

package Ham::DXWatch;

use strict;
use warnings;
use Ham::DXWatch::Spot;

our $VERSION = '0.001';

use base qw(Class::Accessor);
use Carp qw(cluck croak confess);
use Data::Dumper;
use LWP::Simple;
use XML::Simple;
use Class::Date qw(:errors date localdate gmdate now -DateParse -EnvC);
use JSON;
use DBI;
use namespace::clean;

__PACKAGE__->follow_best_practice;
__PACKAGE__->mk_accessors( qw(call start limit fid lang d l lwp request_uri dbh dbp debug) );
__PACKAGE__->mk_ro_accessors( qw(spots xml_spots) );

our $dxwatch_url_base = "http://www.dxwatch.com/dxsd1/s.php?";

sub init
{
	my ($self) = @_;

	$self->_init_lwp();
	$self->_init_db();

	# Set some default options
	$self->set_debug(0);
	$self->set_start('0');
	$self->set_limit('100');
	$self->set_fid('');
	$self->set_lang('en');
	$self->set_d('0');
	$self->set_l('0');

	if($@)
	{
		return 1;
	} else {
		return 0;
	}
}

sub _debug
{
	my ($self, $msg) = @_;

	if($self->get_debug eq 1)
	{
		print "[32;1mDEBUG[0m: (".__PACKAGE__.") ".$msg."\n";
	}
}
	
sub _error
{
	my ($self, $msg) = @_;

	print "[31;1mERROR[0m: ".$msg."\n";

}
	
sub _build_request_uri
{
	my ($self) = @_;

	my $uri = $dxwatch_url_base;
	$uri .= "s=".$self->get_start;
	$uri .= "&r=".$self->get_limit;
	$uri .= "&fid=".$self->get_fid;
	$uri .= "&lang=".$self->get_lang;
	$uri .= "&d=".$self->get_d;
	$uri .= "&l=".$self->get_l;

	$self->set_request_uri($uri);

	return 1;
}

sub _init_lwp
{
	my ($self) = @_;

	# Initiate a new LWP::UserAgent object and store it within the parent object
	my $ua = LWP::UserAgent->new();
	$ua->agent('Ham::DXWatch/'.$VERSION);
	$self->set_lwp($ua);

	# Return false if we have any problems, otherwise return true
	if($@)
	{
		return 0;
	} else {
		return 1;
	}
}

sub retrieve_spots
{
	my ($self) = @_;

	# Build the request URI
	$self->_build_request_uri;

	my $req = HTTP::Request->new(GET => $self->get_request_uri());
#	$req->header('Accept' => 'text/html');

	my $res = $self->get_lwp->request($req);

	if($res->is_success)
	{
		$self->_parse_content($res->{_content});
	}
	else
	{
		print "Error requesting ".$self->get_request_uri().": ".$res->status_line."\n";
		print Dumper($res);
	}
}

sub _parse_content
{
	my ($self, $content) = @_;

	my @lines = split("\n", $content);
	my %spots;

	my $s = decode_json $content;

	%spots = %{$s->{s}};

	my ($t, $a, $j, $e) = (0, 0, 0, 0);
	foreach my $spot (keys %spots)
	{
		my ($spotter, $frequency, $callsign, $comment, $timestamp) = @{$spots{$spot}};

		my $d = Ham::DXWatch::Spot->new({'spot_id' => $spot,
											'callsign' => $callsign,
											'spotter' => $spotter,
											'frequency' => $frequency,
											'comment' => $comment,
											'timestamp' => $timestamp});

		$d->commit;
		$t++;
		$self->{spots}->{'spot'}{$d->get_id} = $d;

		$self->{dbp}{'exists'}->execute($d->get_hash, $d->get_callsign);
		if($self->{dbp}{'exists'}->rows eq 0)
		{
			$self->_debug("Adding spot of $callsign by $spotter on $frequency");
			$self->{dbp}{'insert'}->execute($d->get_id, $d->get_hash, $spot, $callsign, $spotter, $frequency, $comment, $d->get_c_timestamp, "DXWatch");

			if($@)
			{
				$self->_error("Could not add spot to database!");
				$e++;
			}
			else
			{
				$a++;
			}
		}
		else
		{
			$self->_debug("Skipping spot of $callsign by $spotter on $frequency, as it is already in the database.");
			$j++
		}
	}

	print "TOTAL: $t ADDED: [32;1m$a[0m SKIPPED: [33;1m$j[0m ERRORED: [31;1m$e[0m\n";

	$self->{spots}->{'dxwatch-url'} = $self->get_request_uri();
	my $date = now;
	$self->{spots}->{'date'} = $date;
	my $xml = XML::Simple->new('RootName' => 'dxwatch-spots', 'XMLDecl' => 1, 'NoAttr' => 1);

	$self->{xml_spots} = $xml->XMLout($self->{spots});

}

sub _init_db
{
	my ($self) = @_;

	my $dbh = DBI->connect('DBI:mysql:dbname', 'dbuser', 'dbpass') || die "Could not connect to database: ".$DBI::errstr;

	$self->set_dbh($dbh);

	# Prepared statements
	$self->{dbp}{'exists'} = $dbh->prepare("SELECT hash FROM spot WHERE hash = ? AND callsign = ?");
	$self->{dbp}{'insert'} = $dbh->prepare("INSERT INTO spot (guid, hash, spot_id, callsign, spotter, frequency, comment, timestamp, source) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)");
}

1;
