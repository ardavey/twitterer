#!/usr/bin/perl

use strict;
use warnings;

use 5.010;

use Config::Simple;
use Getopt::Std;
use Net::Twitter;

use Data::Dumper;

use lib qw(
  /home/ardavey/perl5/lib/perl5
);

my $t = gmtime;
say "$0 running at $t";

our $opt_c;
getopts( 'c:' );

unless ( $opt_c && -f $opt_c ) {
  die 'Config file not found';
}

my $cfg = new Config::Simple( $opt_c ) or die 'Failed to load config';

my $creds = $cfg->param( -block => 'AUTHENTICATION' );
my $statuses = $cfg->param( 'STATUS.statuses' );

my $tw = Net::Twitter->new(
  traits => [ qw( API::RESTv1_1 ) ],
  ssl => 1,
  consumer_key => $creds->{consumer_key},
  consumer_secret => $creds->{consumer_secret},
  access_token => $creds->{access_token},
  access_token_secret => $creds->{access_token_secret},
);

my $status = $statuses->[int(rand(scalar @$statuses))];

$tw->update( $status );
