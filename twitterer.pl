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
my $search = $cfg->param( -block => 'SEARCH' );
my $blacklist = $cfg->param( 'BLACKLIST.patterns' );

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


my @statuses;
my $r;

if ( ref( $search->{query} ) eq 'ARRAY' ) {
  foreach my $s ( @{ $search->{query} } ) {
    say "Search query: [" . $s . "]";  
    $r = $tw->search( {
      q => "\"$s\"",
      count => $search->{count},
      result_type => 'recent',
      since_id => $latest_id,
    } );
    #print Dumper( $r->{statuses} );
    push @statuses, grep { $_->{text} =~ m/$s/i } @{ $r->{statuses} };
  }
}
else {
  say "Search query: [" . $search->{query} . "]";  
  $r = $tw->search( {
    q => "\"$search->{query}\"",
    count => $search->{count},
    result_type => 'recent',
    since_id => $latest_id,
  } );
  #print Dumper( $r->{statuses} );
  push @statuses, grep { $_->{text} =~ m/$search->{query}/i } @{ $r->{statuses} };
}

@statuses = sort { $a->{id} cmp $b->{id} } @statuses;

say "Search returned " . scalar @statuses . " status(es).";

if ( scalar @statuses ) {
  STATUS: foreach my $s ( @statuses ) {
    say "Found status $s->{id}: [$s->{text}]";

    # Attempt to avoid some of the common spammy bot tweets
    if ( defined $blacklist ) {
      if ( ref( $blacklist ) eq 'ARRAY' ) {
        foreach my $bl ( @$blacklist ) {
          say "Checking blacklist pattern [$bl]";
          next STATUS if ( $s->{text} =~ m/$bl/i );
        }
      }
      else {
        say "Checking blacklist pattern [$blacklist]";
        next STATUS if ( $s->{text} =~ m/$blacklist/i );
      }
    }
    
    say "Retweeting id $s->{id}: [$s->{text}]";
    # Bit of a hack here, but if a tweet has already been retweeted it throws a fatal error
    eval {
      $tw->retweet( { id => $s->{id} } );
    };
    
    if ( $@ ) {
      say "RT error: $@";
    }
  }
}
else {
  say "Nothing to retweet.";
}
