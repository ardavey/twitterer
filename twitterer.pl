#!/usr/bin/perl

use strict;
use warnings;

use 5.010;

use Config::Simple;
use Getopt::Std;
use Net::Twitter;

my $t = localtime;
say "$0 running at $t\n";

our $opt_c;
getopts( 'c:' );

unless ( $opt_c && -f $opt_c ) {
  die 'Config file not found';
}

my $cfg = new Config::Simple( $opt_c ) or die 'Failed to load config';

my $creds = $cfg->param( -block => 'AUTHENTICATION' );
my $search = $cfg->param( -block => 'SEARCH' );

my $tw = Net::Twitter->new(
  traits => [ qw( API::RESTv1_1 ) ],
  consumer_key => $creds->{consumer_key},
  consumer_secret => $creds->{consumer_secret},
  access_token => $creds->{access_token},
  access_token_secret => $creds->{access_token_secret},
);

my $latest_s = $tw->home_timeline( {
  count => 1,
  exclude_replies => 1,
} );

my $latest_id = $latest_s->[0]{id} // 0;

say "Latest ID: $latest_id";

my $r = $tw->search( {
  q => $search->{query},
  count => $search->{count},
  result_type => 'recent',
  since_id => $latest_id,
} );

foreach my $s ( reverse @{ $r->{statuses} } ) {
  say "Retweeting id $s->{id}";
  eval {
    $tw->retweet( { id => $s->{id} } );
  };
}
