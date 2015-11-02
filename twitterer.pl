#!/usr/bin/perl

use strict;
use warnings;

use 5.010;

use Config::Simple;
use Getopt::Std;
use Net::Twitter;

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
my $search = $cfg->param( -block => 'SEARCH' );

my $tw = Net::Twitter->new(
  traits => [ qw( API::RESTv1_1 ) ],
  ssl => 1,
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

say "Search query: [" . $search->{query} . "]";

my $r = $tw->search( {
  q => $search->{query},
  count => $search->{count},
  result_type => 'recent',
  since_id => $latest_id,
} );

my @statuses = reverse @{ $r->{statuses} };

if ( scalar @statuses ) {
  foreach my $s ( @statuses ) {
    say "Retweeting id $s->{id}";
    # Bit of a hack here, but if a tweet has already been retweeted it throws a fatal error
    eval {
      $tw->retweet( { id => $s->{id} } );
    };
  }
}
else {
  say "Nothing to retweet.";
}
