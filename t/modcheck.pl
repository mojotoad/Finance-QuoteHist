#!/usr/bin/perl

use warnings;
use strict;

use Data::Dumper;

use FindBin;
use lib ("$FindBin::RealBin/../lib", "$FindBin::RealBin");
use testload;

my $Dat_Dir = "$FindBin::RealBin/dat";

my %Modules = all_modules();

my @sources = @ARGV ? @ARGV : sort keys %Modules;

for my $s (@sources) {
  my $m = $Modules{$s} || die "source '$s' not found";
  eval "use $m";
  die $@ if $@;
}

my $q_sym   = 'IBM';
my $q_start = '2010/07/01';
my $q_end   = '2011/07/01';

my $s_sym   = 'GIS';
my $s_start = '2009/01/01';
my $s_end   = '2011/08/01';

my $d_sym   = 'INTC';
my $d_start = '2009/01/01';
my $d_end   = '2011/08/01';

sub new_qh {
  my($m, $sym, $s, $e, $g) = @_;
  $m->new(
    symbols     => $sym,
    start_date  => $s,
    end_date    => $e,
    granularity => $g,
    verbose     => 1,
    #debug => 5,
  );
}

for my $s (@sources) {
  my $m = $Modules{$s};
  my @granularities = $m->granularities;
  my($q, @res, $worthy);
  for my $g ($m->granularities) {
    $q = new_qh($m, $q_sym, $q_start, $q_end, $g);
    $worthy = $q->target_worthy(target_mode => 'quote') || 0;
    #print "WORTHY: $m $g : $worthy\n";
  }
  #print "\n";
  $q = new_qh($m, $s_sym, $s_start, $s_end);
  $worthy = $q->target_worthy(target_mode => 'split') || 0;
  #print "WORTHY: $m : $worthy\n";
  #print "\n";
  $q = new_qh($m, $d_sym, $d_start, $d_end);
  $worthy = $q->target_worthy(target_mode => 'dividend') || 0;
  #print "WORTHY: $m : $worthy\n";
}
