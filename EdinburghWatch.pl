#!/usr/bin/perl

use strict;
use warnings;

use 5.010001;

use Getopt::Std;
use File::Slurp;
use Net::Twitter;
use List::Util qw( shuffle );

use Data::Dumper;
$Data::Dumper::Sortkeys = 1;

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
  count => $c->{search_count},
  result_type => 'recent',
  since_id => $latest_id,
  geocode => '55.9485613,-3.2004082,10km',
} );

#@statuses = sort { $a->{id} cmp $b->{id} } @{ $r->{statuses} };
@statuses = @{ $r->{statuses} };

say "Search returned " . scalar @statuses . " status(es).";

my $rt_count = 0;

if ( scalar @statuses ) {
  STATUS: foreach my $s ( shuffle( @statuses ) ) {
    
    # Skip potentially sensitive content
    if ( $s->{possibly_sensitive} ) {
      say "Skipping potentially sensitive content in $s->{id}";
      next STATUS;
    }
    
    # Skip if it's not flagged as English
    if ( $s->{lang} ne 'en' ) {
      say "Skipping non-English tweet: $s->{id}";
      next STATUS;
    }
    
    # Skip if the tweet looks like a RT
    if ( $s->{retweeted} || $s->{text} =~ m/^RT[: ]/ ) {
      say "Skipping RT $s->{id}";
      next STATUS;
    }
    
    # Skip if the tweet looks like a reply
    if ( $s->{in_reply_to_user_id} || $s->{in_reply_to_status_id} || $s->{text} =~ m/^@/ ) {
      say "Skipping reply $s->{id}";
      next STATUS;
    }
    
    # Skip if the user is on the naughty list
    if ( grep { /$s->{user}{screen_name}/i } @{ $c->{user_blacklist} } ) {
      say "Skipping blacklisted user $s->{user}{screen_name}";
      next STATUS;
    }
    
    # Skip tweets with phrases on the banned list
    foreach my $phrase ( @{ $c->{banned_phrases} } ) {
      if ( $s->{text} =~ m/$phrase/si ) {
        say "Skipping banned phrase: $phrase";
        next STATUS;
      }
    }

    print "ID $s->{id}: ";
    
    # Bit of a hack here, but if a tweet has already been retweeted it throws a fatal error
    eval {
      $tw->retweet( { id => $s->{id} } );
    };
    
    if ( $@ ) {
      say "Error: $@";
    }
    else {
      say "Retweeted";
      $rt_count++;
    }
    
    last STATUS if ( $rt_count == $c->{rts_per_run} );
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
