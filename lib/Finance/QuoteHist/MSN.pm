package Finance::QuoteHist::MSN;

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
# HTML:
# http://moneycentral.msn.com/investor/charts/chartdl.asp?Symbol=ibm&CP=0&PT=5&C5=1&C6=&C7=1&C8=&C9=0&CE=0&CompSyms=&D4=1&D5=0&D7=&D6=&D3=0&ShowTablBt=Show+Table
#
# CSV:
# http://data.moneycentral.msn.com/scripts/chrtsrv.dll?Symbol=ibm&FileDownload=&C1=2&C2=&C5=1&C6=1980&C7=12&C8=1995&C9=0&CE=0&CF=0&D3=0&D4=1&D5=0
# http://data.moneycentral.msn.com/scripts/chrtsrv.dll?symbol=ibm&E1=0&C1=1&C2=0&C3=6&C4=2&D5=0&D2=0&D4=1&width=612&height=258&CE=0&filedownload=
#
# Looks like about a 4 year window on csv

sub new {
  my $that = shift;
  my $class = ref($that) || $that;
  my %parms = @_;
  my $self = __PACKAGE__->SUPER::new(%parms);
  bless $self, $class;
  $self->parse_mode('csv');
  $self;
}

sub granularities { qw( daily weekly monthly ) }

sub url_maker {
  my($self, %parms) = @_;
  my $target_mode = $parms{target_mode} || $self->target_mode;
  my $parse_mode  = $parms{parse_mode}  || $self->parse_mode;
  # *always* block unknown target/mode combinations
  return undef unless $target_mode eq 'quote' && $parse_mode eq 'csv';
  my $granularity = lc($parms{granularity} || $self->granularity);
  # C9 = 0, 1, or 2 (also 3 but we don't use that)
  my $grain = 0;
  $granularity =~ /^\s*(\w)/;
  if    ($1 eq 'w') { $grain = 1 }
  elsif ($1 eq 'm') { $grain = 2 }
  my($ticker, $start_date, $end_date) =
    @parms{qw(symbol start_date end_date)};
  $start_date ||= $self->start_date;
  $end_date   ||= $self->end_date;

  my $host = 'data.moneycentral.msn.com';
  my $cgi  = 'scripts/chrtsrv.dll';

  my $url_str_maker = sub {
    my($d1, $d2) = @_;
    my($sy, $sm, $sd) = $self->ymd($d1);
    my($ey, $em, $ed) = $self->ymd($d2);
    my $base_url = "http://$host/$cgi?";
    my @base_parms = (
      "Symbol=$ticker",
      "FileDownload=",
      "C1=2", "C2=", 
      "C5=$sm", "C6=$sy",
      "C7=$em", "C8=$ey",
      "C9=$grain", "CE=0", "CF=0", "D3=0", "D4=1", "D5=0"
    );
    $base_url .  join('&', @base_parms);
  };

  my $date_iterator = $self->date_iterator(
    start_date => $start_date,
    end_date   => $end_date,
    increment  => 4,
    units      => 'years',
  );

  sub {
    while (my($d1, $d2) = $date_iterator->()) {
      return $url_str_maker->($d1, $d2);
    }
    undef;
  }
}

1;

__END__

=head1 NAME

Finance::QuoteHist::MSN - Site-specific class for retrieving historical stock quotes.

=head1 SYNOPSIS

  use Finance::QuoteHist::MSN;
  $q = Finance::QuoteHist::MSN->new
     (
      symbols    => [qw(IBM UPS AMZN)],
      start_date => '01/01/1999',
      end_date   => 'today',
     );

  foreach $row ($q->quotes()) {
    ($symbol, $date, $open, $high, $low, $close, $volume) = @$row;
    ...
  }

=head1 DESCRIPTION

Finance::QuoteHist::MSN is a subclass of
Finance::QuoteHist::Generic, specifically tailored to read historical
quotes from the MSN financial web site
(I<http://moneycentral.msn.com/>). Note that Quotemedia is currently the
site that provides historical quote data for such other sites as Silicon
Investor, which was the target of a module in an earlier release of this
distribution.

MSN does not currently provide information on dividends or splits.

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

Details for MSN's terms of use can be found here:
I<http://privacy2.msn.com/tou/en-us/default.aspx>

If you still have concerns, then use another site-specific historical
quote instance, or none at all.

Above all, play nice.

=head1 AUTHOR

Matthew P. Sisk, E<lt>F<sisk@mojotoad.com>E<gt>

=head1 COPYRIGHT

Copyright (c) 2006 Matthew P. Sisk. All rights reserved. All wrongs
revenged. This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 SEE ALSO

Finance::QuoteHist::Generic(3), Finance::QuoteHist(3), perl(1).

=cut
