package Finance::QuoteHist::Yahoo::Australia;

use strict;
use vars qw(@ISA $VERSION);
use Carp;

$VERSION = '1.00';

use Finance::QuoteHist::Yahoo;
@ISA = qw(Finance::QuoteHist::Yahoo);

# Example for CSV output:
#
# http://au.rd.yahoo.com/finance/quotes/internal/historical/download/*http://ichart.finance.yahoo.com/table.csv?s=BHP.AX&d=5&e=25&f=2007&g=d&a=9&b=25&c=1984&ignore=.csv
#
# Example for dividends:
#
# http://au.rd.yahoo.com/finance/quotes/internal/historical/download/*http://ichart.finance.yahoo.com/table.csv?s=BHP.AX&a=09&b=25&c=1984&d=05&e=25&f=2007&g=v&ignore=.csv
#
#

# override these for other Yahoo sites
sub url_base_csv    { 'http://au.rd.yahoo.com/finance/quotes/internal/historical/download/*http://ichart.finance.yahoo.com/table.csv' }
sub url_base_html   { 'http://au.finance.yahoo.com/q/hp' }
sub url_base_splits { 'http://au.finance.yahoo.com/q/bc' }

1;

__END__

=head1 NAME

Finance::QuoteHist::Yahoo::Australia - Site-specific subclass for retrieving historical stock quotes.

=head1 SYNOPSIS

  use Finance::QuoteHist::Yahoo::Australia;
  $q = Finance::QuoteHist::Yahoo::Australia->new(
    symbols    => [qw(BHP.AX)],
    start_date => '01/01/1999',
    end_date   => 'today',
  );

  # Values
  foreach $row ($q->quotes()) {
    ($symbol, $date, $open, $high, $low, $close, $volume) = @$row;
    ...
  }

  # Splits
  foreach $row ($q->splits()) {
     ($symbol, $date, $post, $pre) = @$row;
  }

  # Dividends
  foreach $row ($q->dividends()) {
     ($symbol, $date, $dividend) = @$row;
  }

=head1 DESCRIPTION

Finance::QuoteHist::Yahoo::Australia is a subclass of
Finance::QuoteHist::Yahoo, specifically tailored to read historical
quotes, dividends, and splits from the Yahoo Australia web site
(I<http://au.finance.yahoo.com/>).

Please see L<Finance::QuoteHist::Yahoo(3)> for more details on usage
and available methods. If you just want to get historical quotes and
are not interested in the details of how it is done, check out
L<Finance::QuoteHist(3)>.

=head1 METHODS

The basic user interface consists of three methods, as seen in the
example above. Those methods are:

=over

=item quotes()

Returns a list of rows (or a reference to an array containing those
rows, if in scalar context). Each row contains the B<Symbol>, B<Date>,
B<Open>, B<High>, B<Low>, B<Close>, and B<Volume> for that date.

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

Finance::QuoteHist::Yahoo

=head1 DISCLAIMER

The data returned from these modules is in no way guaranteed, nor are
the developers responsible in any way for how this data (or lack
thereof) is used. The interface is based on URLs and page layouts that
might change at any time. Even though these modules are designed to be
adaptive under these circumstances, they will at some point probably
be unable to retrieve data unless fixed or provided with new
parameters. Furthermore, the data from these web sites is usually not
even guaranteed by the web sites themselves, and oftentimes is
acquired elsewhere.

If you would like to know more, check out the terms of service from
Yahoo!, which can be found here:

  http://au.docs.yahoo.com/info/terms/

If you still have concerns, then use another site-specific historical
quote instance, or none at all.

Above all, play nice.

=head1 AUTHOR

Matthew P. Sisk, E<lt>F<sisk@mojotoad.com>E<gt>

=head1 COPYRIGHT

Copyright (c) 2010 Matthew P. Sisk. All rights reserved. All wrongs
revenged. This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 SEE ALSO

Finance::QuoteHist::Yahoo(3), Finance::QuoteHist::Generic(3), Finance::QuoteHist(3), perl(1).

=cut
