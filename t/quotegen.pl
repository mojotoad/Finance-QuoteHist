#!/usr/bin/perl

use warnings;
use strict;

use FindBin;
use lib ("$FindBin::RealBin/../lib", $FindBin::RealBin);
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
my $q_start = '2012/07/01';
my $q_end   = '2013/07/01';

my $s_sym   = 'NKE';
my $s_start = '2009/01/01';
my $s_end   = '2013/10/01';

my $d_sym   = 'INTC';
my $d_start = '2011/01/01';
my $d_end   = '2013/10/01';

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
  my($q, @res);
  for my $g ($m->granularities) {
    $q = new_qh($m, $q_sym, $q_start, $q_end, $g);
    if (not $q->target_worthy(target_mode => 'quote')) {
      print STDERR "skip non capable: $m quote $g\n";
      next;
    }
    @res = $q->quotes;
    print STDERR "got ", scalar @res, " quotes from $s/$g\n";
    if (@res) {
      my $f = File::Spec->catdir($Dat_Dir, join('_', 'quote', $g, "$s.dat"));
      save_res($m, $q_sym, $q_start, $q_end, \@res, $f);
    }
    else {
      print STDERR "NO RESULTS: $m $g quotes\n";
    }
  }
  $q = new_qh($m, $s_sym, $s_start, $s_end);
  if ($q->target_worthy(target_mode => 'split')) {
    @res = $q->splits;
    print STDERR "got ", scalar @res, " splits from $s\n";
    if (@res) {
      my $f = File::Spec->catdir($Dat_Dir, join('_', 'split', "$s.dat"));
      save_res($m, $s_sym, $s_start, $s_end, \@res, $f);
    }
    else {
      die "NO RESULTS: $m splits\n";
    }
  }
  else {
    print STDERR "skip non capable: $m split\n";
  }
  $q = new_qh($m, $d_sym, $d_start, $d_end);
  if ($q->target_worthy(target_mode => 'dividend')) {
    @res = $q->dividends;
    print STDERR "got ", scalar @res, " dividends from $s\n";
    if (@res) {
      my $f = File::Spec->catdir($Dat_Dir, join('_', 'dividend', "$s.dat"));
      save_res($m, $d_sym, $d_start, $d_end, \@res, $f);
    }
    else {
      die "NO RESULTS: $m splits\n";
    }
  }
  else {
    print STDERR "skip non capable: $m dividend\n";
  }
}

sub save_res {
  my($m, $sym, $start, $stop, $res, $f) = @_;
  open(F, '>', $f) or die "problem writing to $f : $!";
  print F "$m\n";
  print F join(',', $sym, $start, $stop), "\n";
  print F join(':', @$_), "\n" foreach @$res;
  close(F);
}
