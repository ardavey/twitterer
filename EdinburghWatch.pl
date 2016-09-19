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

my $c = new Config::Simple( $opt_c ) or die 'Failed to load config';

my $creds = $c->param( -block => 'AUTHENTICATION' );
my $cfg = $c->param( -block => 'CONFIG' );

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

$r = $tw->search( {
  count => 50,
  result_type => 'recent',
  since_id => $latest_id,
  geocode => '55.9485613,-3.2004082,10km',
} );

@statuses = sort { $a->{id} cmp $b->{id} } @{ $r->{statuses} };

say "Search returned " . scalar @statuses . " status(es).";

if ( scalar @statuses ) {
  STATUS: foreach my $s ( @statuses ) {
        
    #say Dumper($s);
    my $un = $s->{user}{screen_name};
    my $unre = qr/^$un$/;
    if ( scalar grep { /$unre/i } @{ $cfg->{blacklist} } ) {
      say "Skipping blacklisted user $un";
      next STATUS;
    }
    
    if ( defined $s->{in_reply_to_user_id} || $s->{text} =~ m/^@/s ) {
      say "Skipping reply $s->{id}";
      next STATUS;
    }

    say "Retweeting id $s->{id}";
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
