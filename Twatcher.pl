#!/usr/bin/perl

use strict;
use warnings;

use 5.010001;

use Getopt::Std;
use File::Slurp;
use Net::Twitter;
use List::Util qw( shuffle );
use Time::Piece;

use open ":std", ":encoding(UTF-8)";

use Data::Dumper;
$Data::Dumper::Sortkeys = 1;

use lib qw(
  /home/ardavey/perl5/lib/perl5
);

say "Script starting at ".gmtime();

our $opt_c;
our $opt_s;

getopts( 'c:s' );

my $c = read_config( $opt_c ) or die "Failed to load config: $!";

my $tw = Net::Twitter->new(
  traits => [ qw( API::RESTv1_1 ) ],
  ssl => 1,
  consumer_key => $c->{authentication}{consumer_key},
  consumer_secret => $c->{authentication}{consumer_secret},
  access_token => $c->{authentication}{access_token},
  access_token_secret => $c->{authentication}{access_token_secret},
);


if ( $opt_s ) {
  foreach my $s ( @{ $c->{spotlight} } ) {
    my $t = localtime;
    my $st = $tw->show_status( $s );
    $tw->update( "Check this out... #ad\nhttps://twitter.com/i/status/" . $st->{id} . "#" . $t->epoch );
  }
}
else {
  my $latest_s = $tw->home_timeline( {
    count => 1,
    exclude_replies => 1,
  } );
  
  my $latest_id = $latest_s->[0]{id} // 0;
  say "Searching for IDs newer than $latest_id";
  
  my @statuses;
  my $r;
  
  $r = $tw->search( {
    count => $c->{search_count},
    result_type => 'recent',
    since_id => $latest_id,
    geocode => $c->{geocode},
  } );
  
  #@statuses = sort { $a->{id} cmp $b->{id} } @{ $r->{statuses} };
  @statuses = @{ $r->{statuses} };
  
  say "Search returned " . scalar @statuses . " status(es).";
  
  my $rt_count = 0;
  
  if ( scalar @statuses ) {
    STATUS: foreach my $s ( shuffle( @statuses ) ) {
      print "[$s->{id}]: ";
      # Skip potentially sensitive content
      if ( $s->{possibly_sensitive} ) {
        say "Skipping potentially sensitive content";
        next STATUS;
      }
      
      # Skip if it's not flagged as English
      if ( $s->{lang} ne 'en' ) {
        say "Skipping non-English tweet";
        next STATUS;
      }
      
      # Skip if the tweet looks like a RT
      if ( $s->{is_quote_status} || $s->{text} =~ m/^RT[: ]/ ) {
        say "Skipping RT";
        next STATUS;
      }
      
      # Skip if the tweet looks like a reply
      if ( $s->{in_reply_to_user_id} || $s->{in_reply_to_status_id} || $s->{text} =~ m/^@/ ) {
        say "Skipping reply";
        next STATUS;
      }
      
      # Skip if the user is on the naughty list
      if ( grep { /^$s->{user}{screen_name}$/i } @{ $c->{user_blacklist} } ) {
        say "Skipping blacklisted user $s->{user}{screen_name}";
        next STATUS;
      }
      
      # Skip if the user has opted out
      if ( grep { /^$s->{user}{screen_name}$/i } @{ $c->{user_opt_out} } ) {
        say "Skipping opted out user $s->{user}{screen_name}";
        next STATUS;
      }
      
      ## The following are the most expensive checks
      # Check user bio for certain phrases which imply adult content
      foreach my $phrase ( @{ $c->{bio_blacklist} } ) {
        my $bio = $s->{user}{description};
        if ( $bio =~ m/$phrase/si ) {
          say "Skipping suspect bio phrase '$phrase' ($bio)";
          next STATUS;
        }
      }
      
      # Skip tweets with sources on the banned list
      foreach my $source ( @{ $c->{source_blacklist} } ) {
        if ( $s->{source} =~ m/$source/si ) {
          say "Skipping banned source '$source'";
          next STATUS;
        }
      }
      
      # Skip tweets with phrases on the banned list
      foreach my $phrase ( @{ $c->{phrase_blacklist} } ) {
        if ( $s->{text} =~ m/$phrase/si ) {
          say "Skipping banned phrase '$phrase'";
          next STATUS;
        }
      }
  
      say "RT-ing: $s->{text}";
      
      # Bit of a hack here, but if a status has already been retweeted it throws a fatal error
      eval {
        $tw->retweet( { id => $s->{id} } );
      };
      
      if ( $@ ) {
        say "Error: $@";
      }
      else {
        $rt_count++;
      }
      
      last STATUS if ( $rt_count == $c->{rts_per_run} );
    }
  }
  else {
    say "Nothing to retweet.";
  }
}

say "Script finished at ".gmtime()."\n";

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
