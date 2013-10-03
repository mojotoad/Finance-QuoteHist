package Finance::QuoteHist::BusinessWeek;

use strict;
use vars qw(@ISA $VERSION);
use Carp;

$VERSION = '1.02';

use constant DEBUG => 0;

use Finance::QuoteHist::Generic;
@ISA = qw(Finance::QuoteHist::Generic);

use MIME::Base64;
use Date::Manip;
Date::Manip::Date_Init("TZ=GMT");

# Example URL:
#
# /businessweek/research/common/charts/update_historical_chart.asp?duration=3653&frequency=1day&freq=undefined&scaling=linear&display=mountain&exportData=1&dMin=37431&dMax=39257&uppers=[]&lowers=[]&lastColorUsed=2&action=&action_value= H

my %Label_Map = (
  d => 'date',
  h => 'high',
  c => 'close',
  v => 'volume',
  l => 'low',
  o => 'open',
);
my @Sorted = qw(date open high low close volume);

sub new {
  my $that = shift;
  my $class = ref($that) || $that;
  my %parms = @_;
  my $self = __PACKAGE__->SUPER::new(%parms);
  bless $self, $class;
  $self->parse_mode('businessweek_javascript');
  $self->labels(
    target_mode => 'quote',
    labels => [ qw(d h c v l o) ],
  );
  $self;
}

sub businessweek_javascript_parser {
  my $self = shift;
  sub {
    my $data = shift;
    return [] unless defined $data;

    my %columns;
    my @pats = sort keys %Label_Map;
    foreach my $line (grep(/arrayDecodeUnpack/i, split(/\s*;\s*/, $data))) {
      next unless $line =~ /(\w+)=arrayDecodeUnpack\s*\(\"([^\"]+)\"\s*\)/i;
      my($varname, $value) = ($1, $2);
      my $label;
      foreach my $pi (0 .. $#pats) {
        my $pat = $pats[$pi];
        if ($varname =~ /^($pat)/i) {
          $label = $Label_Map{$pat};
          splice(@pats, $pi, 1);
          last;
        }
      }
      if (! $label) {
        print STDERR "skipping unknown label $varname\n" if DEBUG;
        next;
      }
      if ($columns{$label}) {
        warn "oops, seen $label, skipping\n" if DEBUG;
        next;
      }
      $columns{$label} = $value;
    }
    my $count = 0;
    foreach my $label (keys %columns) {
      my $decoded = _decode_unpack($columns{$label});
      print STDERR "$label : ", scalar @$decoded, " items\n" if DEBUG;
      $count = @$decoded if @$decoded > $count;
      $columns{$label} = $decoded;
    }
    my @rows;
    foreach my $i (0 .. $count-1) {
      my @row;
      foreach my $label (@Sorted) {
        my $value = $columns{$label}[$i];
        $value = $self->excel_daynum_to_date($value) if $label eq 'date';
        push(@row, $value);
      }
      push(@rows, \@row);
    }
    \@rows;
  };
}

sub granularities { qw( daily weekly monthly ) }

sub url_maker {
  my($self, %parms) = @_;
  my $target_mode = $parms{target_mode} || $self->target_mode;
  my $parse_mode  = $parms{parse_mode}  || $self->parse_mode;

  # *always* block uknown target mode and parse mode combinations in
  # order for cascade to work!
  return undef unless
    ($target_mode eq 'quote') && $parse_mode eq 'businessweek_javascript';

  my $granularity = lc($parms{granularity} || $self->granularity);
  my $grain;
  my ($g) = $granularity =~ /^\s*(\w)/;
  if    ($g eq 'd') { $grain = '1day'   } # daily
  elsif ($g eq 'w') { $grain = '1week'  } # weekly
  elsif ($g eq 'm') { $grain = '1month' } # monthly
  else  { croak "Unknown granularity '$granularity'\n" }

  my($ticker, $start_date, $end_date) =
    @parms{qw(symbol start_date end_date)};
  $start_date ||= $self->start_date;
  $end_date   ||= $self->end_date;

  # businessweek has a one-off error on the start date when using weekly
  # or monthly mode
  if ($self->granularity =~ /^(m|w)/i) {
    if ($1 eq 'w') {
      $start_date = DateCalc($start_date, '- 1 week');
    }
    else {
      $start_date = DateCalc($start_date, '- 1 month');
    }
  }

  my $host = 'investing.businessweek.com';
  my $path = 'businessweek/research/common/charts/update_historical_chart.asp';

  # this also worked
  # my $path = '/research/stocks/snapshot/historical.asp';

  my %query = (
    symbol        => $ticker,
    freq          => $grain,
    dMin          => $self->date_to_excel_daynum($start_date),
    dMax          => $self->date_to_excel_daynum($end_date),
    # dunno what the rest of these do
    duration      => 1096,
    frequency     => '1day', # relic?
    scaling       => 'linear',
    display       => 'mountain',
    exportData    => '1',
    uppers        => '[]',
    lowers        => '[]',
    lastColorUsed => 2,
    action        => '',
    action_value  => '',
  );


  my $url = "http://$host/$path?" .
            join('&', map { "$_=$query{$_}" } sort keys %query);

  print STDERR "URL: $url\n" if DEBUG;

  my @urls = ($url);
  sub { pop @urls };
}

### subroutines to deal with businessweek's wonky data encoding

sub _decode_unpack { _array_unpack(MIME::Base64::decode_base64(shift)) }

sub _array_unpack {
  # inspired by this (who comes up with this stuff?):
  # http://investing.businessweek.com/includes/asplib/ArrayUnpack.js
  my $str = shift;
  my @e;
  my @code = map { ord($_) } split(//, $str);
  my $m = $code[1] | ($code[2] << 8);
  if ($m > 0) {
    my $b = $code[3];
    my $f = 10 ** $code[4];
    my $k = $code[5] | ($code[6] << 8) | ($code[7] << 16) | ($code[8] << 24);
    my $l = (2 ** $b) - 1;
    push(@e, $k/$f);
    my($g, $h) = (0, 0);
    for (my $i = 9; $i < @code; $i++) {
      $g |= $code[$i] << $h;
      $h += 8;
      while ($h >= $b && @e <= $m) {
        my $j = ($g & $l) >> 1;
        $k += ($g & 1) ? -1 * $j : $j;
        push(@e, $k/$f);
        $g >>= $b;
        $h -= $b;
      }
      $g |= $code[$i] >> (8 - $h);
    }
  }
  wantarray ? @e : \@e;
}

### excel daynum conversions

# using locale TZ
#sub excel_daynum_to_date {
#  my $self = shift;
#  my $excel_daynum = shift;
#  my $skew = _excel_daynum_sub_skew($excel_daynum);
#  my $date = _dm_from_epoch(_days_to_secs($skew));
#  my $tzod = _tz_offset_in_days($date);
#  _dm_from_epoch(_days_to_secs($skew - $tzod));
#}

# using GMT
sub excel_daynum_to_date {
  my $self = shift;
  my $excel_daynum = shift;
  my $skew = _excel_daynum_sub_skew($excel_daynum);
  my $date = _dm_from_epoch(_days_to_secs($skew));
  _dm_from_epoch(_days_to_secs($skew));
}

# using locale TZ
#sub date_to_excel_daynum {
#  my $self = shift;
#  my $date = shift;
#  _secs_to_days(Date::Manip::UnixDate($date, "%s")) +
#    (_excel_daynum_add_skew(_tz_offset_in_days($date)));
#}

# using GMT
sub date_to_excel_daynum {
  my $self = shift;
  my $date = shift;
  _excel_daynum_add_skew(_secs_to_days(Date::Manip::UnixDate($date, "%s")));
}

# subroutines

sub _dm_from_epoch {
  my $epoch = shift;
  Date::Manip::ParseDateString("epoch $epoch");
}

# using locale TZ
#sub _tz_offset_in_minutes {
#  my $date = shift;
#  my $tz_offset = Date::Manip::UnixDate($date, "%z");
#  my($sign, $hours, $minutes) = $tz_offset =~ /^(\D?)(\d\d)(\d\d)/;
#  $tz_offset = ($hours*60 + $minutes);
#  $tz_offset *= -1 if $sign eq '-';
#  $tz_offset;
#}

# using locale TZ
#sub _tz_offset_in_days { _tz_offset_in_minutes(@_) / (60 * 24) }

sub _excel_daynum_sub_skew { shift() - 25569 }
sub _excel_daynum_add_skew { shift() + 25569 }

sub _days_to_secs { shift() * 86400 }
sub _secs_to_days { shift() / 86400 }

1;

__END__

=head1 NAME

Finance::QuoteHist::BusinessWeek - Site-specific class for retrieving historical stock quotes.

=head1 SYNOPSIS

  use Finance::QuoteHist::BusinessWeek;
  $q = Finance::QuoteHist::BusinessWeek->new
     (
      symbols    => [qw(IBM UPS AMZN)],
      start_date => '01/01/2005',
      end_date   => 'today',
     );

  foreach $row ($q->quotes()) {
    ($symbol, $date, $open, $high, $low, $close, $volume) = @$row;
    ...
  }

=head1 DESCRIPTION

Finance::QuoteHist::BusinessWeek is a subclass of
Finance::QuoteHist::Generic, specifically tailored to read historical
quotes from the Business Week Online web site
(I<http://investments.businessweek.com/>).

BusinessWeek offers granularities of daily, weekly, or monthly.

BusinessWeek does not currently provide information on dividends or splits.

Please see L<Finance::QuoteHist::Generic(3)> for more details on usage
and available methods. If you just want to get historical quotes and are
not interested in the details of how it is done, check out
L<Finance::QuoteHist(3)>.

=head1 METHODS

The basic user interface consists of a single method, as shown in the
example above. That method is:

=over

=item quotes()

Returns a list of rows (or a reference to an array containing those
rows, if in scalar context). Each row contains the B<Symbol>, B<Date>,
B<Open>, B<High>, B<Low>, B<Close>, and B<Volume> for that date. Quote
values are pre-adjusted for this site.

=back

=head1 REQUIRES

Finance::QuoteHist::Generic(3), MIME::Base64(3), Date::Manip(3)

=head1 DISCLAIMER

The data returned from these modules is in no way guaranteed, nor are
the developers responsible in any way for how this data (or lack
thereof) is used. The interface is based on URLs and page layouts that
might change at any time. Even though these modules are designed to be
adaptive under these circumstances, they will at some point probably be
unable to retrieve data unless fixed or provided with new parameters.
Furthermore, the data from these web sites is usually not even
guaranteed by the web sites themselves, and oftentimes is acquired
elsewhere.

Details for BusinessWeek's terms of use can be found here:
I<http://www.businessweek.com/copyrt.htm>

If you still have concerns, then use another site-specific historical
quote instance, or none at all.

Above all, play nice.

=head1 AUTHOR

Matthew P. Sisk, E<lt>F<sisk@mojotoad.com>E<gt>

=head1 COPYRIGHT

Copyright (c) 2006-2010 Matthew P. Sisk. All rights reserved. All wrongs
revenged. This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 SEE ALSO

Finance::QuoteHist::Generic(3), Finance::QuoteHist(3), perl(1).

=cut
