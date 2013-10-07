package Finance::QuoteHist::Investopedia;

use strict;
use vars qw(@ISA $VERSION);
use Carp;

$VERSION = '1.01';

use Finance::QuoteHist::Generic;
@ISA = qw(Finance::QuoteHist::Generic);

use Date::Manip;
Date::Manip::Date_Init("TZ=GMT");

# Example URL:
#
# http://www.investopedia.com/markets/stocks/ibm/historical/?page=1&StartDate=07/01/2012&EndDate=07/01/2013&HistoryType=Daily
#
# for split:
#
# http://www.investopedia.com/markets/stocks/gis/historical/?StartDate=01/01/2009&EndDate=07/01/2013&HistoryType=Splits
#
# for dividend:
#

sub new {
  my $that = shift;
  my $class = ref($that) || $that;
  my %parms = @_;
  my $self = __PACKAGE__->SUPER::new(%parms);
  bless $self, $class;
  $self->parse_mode('html');
  $self;
}

sub labels {
  my($self, %parms) = @_;
  my $target_mode = $parms{target_mode} || $self->target_mode;
  return(qw( date denominator numerator )) if $target_mode eq 'split';
  $self->SUPER::labels(%parms);
}

sub url_maker {
  my($self, %parms) = @_;
  my $target_mode = $parms{target_mode} || $self->target_mode;
  my $parse_mode  = $parms{parse_mode}  || $self->parse_mode;
  # *always* block unknown target/mode cominations
  return undef unless $parse_mode eq 'html';

  my($ticker, $start_date, $end_date) =
    @parms{qw(symbol start_date end_date)};
  $start_date ||= $self->start_date;
  $end_date   ||= $self->end_date;

  my($sy, $sm, $sd) = $self->ymd($start_date);
  my($ey, $em, $ed) = $self->ymd($end_date);
  my @base_parms = (
    "StartDate=$sm/$sd/$sy",
    "EndDate=$em/$ed/$ey",
  );
  my $base_url = join('/', "http://www.investopedia.com/markets/stocks",
                            lc $ticker,
                            'historical/');
  if ($target_mode eq 'quote') {
    push(@base_parms, "HistoryType=Daily");
  }
  elsif ($target_mode eq 'dividend') {
    push(@base_parms, "HistoryType=Dividends");
  }
  elsif ($target_mode eq 'split') {
    push(@base_parms, "HistoryType=Splits");
  }
  my $maker;
  if ($target_mode eq 'quote') {
    push(@base_parms, "HistoryType=Daily");
    my $page = 0;
    $maker = sub {
      my $url = join('?', $base_url, join('&', @base_parms, "page=$page"));
      ++$page;
      $url;
    };
  }
  else {
    my @urls = join('?', $base_url, join('&', @base_parms));
    $maker = sub { pop @urls };
  }
  return $maker;
}

sub splits {
  my $self = shift;
  my @rows;
  for my $r ($self->SUPER::splits()) {
    push(@rows, [$r->[0], $r->[1], join(':', $r->[2], $r->[3])]);
  }
  wantarray ? @rows : \@rows;
}

1;

__END__

=head1 NAME

Finance::QuoteHist::Investopedia - Site-specific class for retrieving historical stock quotes.

=head1 SYNOPSIS

  use Finance::QuoteHist::Investopedia;
  $q = Finance::QuoteHist::Investopedia->new
     (
      symbols    => [qw(IBM UPS AMZN)],
      start_date => '01/01/2009',
      end_date   => 'today',
     );

  foreach $row ($q->quotes()) {
    ($symbol, $date, $open, $high, $low, $close, $volume) = @$row;
    ...
  }

=head1 DESCRIPTION

Finance::QuoteHist::Investopedia is a subclass of
Finance::QuoteHist::Generic, specifically tailored to read historical
quotes, dividends, and splits from the Investopedia web site
(I<http://investopedia.com/>).

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

=item dividends()

Returns a list of rows (or a reference to an array containing those
rows, if in scalar context). Each row contains the B<Symbol>, B<Date>,
and amount of the B<Dividend>, in that order.

=item splits()

Returns a list of rows (or a reference to an array containing those
rows, if in scalar context). Each row contains the B<Symbol>, B<Date>,
B<Post> split shares, and B<Pre> split shares, in that order.

=back

=head1 REQUIRES

Finance::QuoteHist::Generic

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

Details for Investopedia's terms of use can be found here:

  http://www.investopedia.com/corp/terms.asp

If you still have concerns, then use another site-specific historical
quote instance, or none at all.

Above all, play nice.

=head1 AUTHOR

Matthew P. Sisk, E<lt>F<sisk@mojotoad.com>E<gt>

=head1 COPYRIGHT

Copyright (c) 2007-2010 Matthew P. Sisk. All rights reserved. All wrongs
revenged. This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 SEE ALSO

Finance::QuoteHist::Generic(3), Finance::QuoteHist(3), perl(1).

=cut
