#!/usr/bin/perl

use strict;
use warnings;

use 5.010;

use Getopt::Std;
use File::Slurp;
use Net::Twitter;

use Data::Dumper;

use lib qw(
  /home/ardavey/perl5/lib/perl5
);

my $t = gmtime;
say "$0 running at $t";

our $opt_c;
getopts( 'c:' );

my $c = read_config( $opt_c ) or die "Failed to load config: $!";

my $tw = Net::Twitter->new(
  traits => [ qw( API::RESTv1_1 ) ],
  ssl => 1,
  consumer_key => $c->{authentication}{consumer_key},
  consumer_secret => $c->{authentication}{consumer_secret},
  access_token => $c->{authentication}{access_token},
  access_token_secret => $c->{authentication}{access_token_secret},
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
  count => 5,
  result_type => 'recent',
  since_id => $latest_id,
  geocode => '55.9485613,-3.2004082,10km',
} );

@statuses = sort { $a->{id} cmp $b->{id} } @{ $r->{statuses} };

say "Search returned " . scalar @statuses . " status(es).";

if ( scalar @statuses ) {
  STATUS: foreach my $s ( @statuses ) {
        
    #say Dumper($s);
    foreach my $un ( @{ $c->{blacklist} } ) {
      if ( lc( $s->{user}{screen_name} ) eq lc( $un ) ) {
        say "Skipping blacklisted user $un";
        next STATUS;
      }
    }
    
    if ( $s->{in_reply_to_user_id} || $s->{in_reply_to_status_id} || $s->{text} =~ m/^@/s ) {
      say "Skipping reply $s->{id}";
      next STATUS;
    }
    
    foreach my $phrase ( @{ $c->{banned_phrases} } ) {
      if ( $s->{text} =~ m/$phrase/si ) {
        say "Skipping banned phrase: $phrase";
        next STATUS;
      }
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


sub read_config {
  my ( $file ) = @_;
  
  unless ( $file && -f $file ) {
    die 'Config file not found';
  }
  
  my $cfg_text = read_file( $file );
  my $cfg = {};
  eval $cfg_text;
  
  return $cfg;
}
