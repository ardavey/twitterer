#!/usr/bin/perl

use strict;
use warnings;

use 5.010;

use Config::Simple;
use Getopt::Std;
use Net::Twitter;

use Data::Dumper;
$Data::Dumper::Sortkeys = 1;

use lib qw(
  /home/ardavey/perl5/lib/perl5
);

use vars qw( $opt_c $opt_s );

getopts( 'c:s:' );

unless ( $opt_c && -f $opt_c ) {
  die 'Config file not found';
}

unless ( $opt_s && $opt_s =~ /^\d+$/ ) {
  die 'Non-numeric status provided';
}

my $cfg = new Config::Simple( $opt_c ) or die 'Failed to load config';

my $creds = $cfg->param( -block => 'AUTHENTICATION' );

my $tw = Net::Twitter->new(
  traits => [ qw( API::RESTv1_1 ) ],
  ssl => 1,
  consumer_key => $creds->{consumer_key},
  consumer_secret => $creds->{consumer_secret},
  access_token => $creds->{access_token},
  access_token_secret => $creds->{access_token_secret},
);

my $r = $tw->show_status( $opt_s );

say "Dumping status $opt_s:\n\n" . Dumper( $r );
