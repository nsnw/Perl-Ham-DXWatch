#!/usr/bin/perl

package Ham::DXWatch::Spot;

use strict;
use warnings;

our $VERSION = '0.001';

use base qw(Class::Accessor);
use Carp qw(cluck croak confess);
use Data::Dumper;
use Data::GUID;
use Digest::MD5 qw(md5_hex);
use Time::Local;
use namespace::clean;

__PACKAGE__->follow_best_practice;
__PACKAGE__->mk_accessors( qw(spot_id callsign spotter frequency timestamp comment) );
__PACKAGE__->mk_ro_accessors( qw(id hash c_timestamp) );

sub commit
{
	my ($self) = @_;

	# Generate GUID
	my $guid = Data::GUID->new;
	$self->{id} = $guid->as_string();

	# Calculate hash
	$self->_calculate_timestamp;
	$self->{hash} = $self->calculate_hash($self->get_spot_id, $self->get_callsign, $self->get_spotter, $self->get_frequency, $self->get_timestamp, $self->get_comment);

	if($@)
	{
		return 0;
	}
	else
	{
		return 1;
	}
}

sub _calculate_timestamp
{
	my ($self) = @_;

	my $m = {'Jan' => 1, 'Feb' => 2, 'Mar' => 3, 'Apr' => 4, 'May' => 5, 'Jun' => 6, 'Jul' => 7, 'Aug' => 8, 'Sep' => 9, 'Oct' => 10, 'Nov' => 11, 'Dec' => 12};
	my $spot_time = $self->get_timestamp;
	my ($hour, $minute, $day, $month) = $spot_time =~ /(\d{2})(\d{2})z (\d{2}) (\w{3})/;
	my $year = (localtime)[5];
	my $mon = $m->{$month};
	$mon--;

	$self->{c_timestamp} = timegm(0, $minute, $hour, $day, $mon, $year);
}

sub calculate_hash
{
	my ($self, $spot_id, $callsign, $spotter, $frequency, $timestamp, $comment) = @_;

	my $hash_source = "$spot_id~$callsign~$spotter~$frequency~$timestamp~$comment";

	my $hash = md5_hex($hash_source);

	return $hash;
}
	
1;
