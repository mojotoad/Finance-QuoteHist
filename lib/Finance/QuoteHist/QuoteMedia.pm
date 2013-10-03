package Finance::QuoteHist::QuoteMedia;

use strict;
use vars qw(@ISA $VERSION);
use Carp;

$VERSION = '1.05';

use Finance::QuoteHist::Generic;
@ISA = qw(Finance::QuoteHist::Generic);

use constant DEBUG => 0;

use Date::Manip;
Date::Manip::Date_Init("TZ=GMT");

use URI;
use URI::QueryParam;
use HTTP::Request::Common;
use Regexp::Common;
use HTML::TokeParser;

# http://app.quotemedia.com/quotetools/clientForward?targetURL=http%3A%2F%2Fwww.quotemedia.com%2Fresults.php&targetsym=qm_symbol&targettype=null&targetex=&qmpage=true&action=showHistory&symbol=IBM&page=2&startDay=3&startMonth=6&startYear=2007&endDay=3&endMonth=7&endYear=2008&perPage=90

# http://app.quotemedia.com/quotetools/getHistoryDownload.csv?&webmasterId=501&symbol=IBM&startDay=26&startMonth=4&startYear=2005&endDay=26&endMonth=5&endYear=2007

my $Tgt_Host = 'www.quotemedia.com';
my $Results_uri = URI->new("http://$Tgt_Host/results.php");
my $Tgt_Post_uri    = $Results_uri->clone;
my $Tgt_Cookie_uri  = $Results_uri->clone;
$Tgt_Cookie_uri->query_form( action => 'showHistory' );
$Tgt_Post_uri->query_form  ( qmpage => 'true'        );

my $Fwd_Host = 'app.quotemedia.com';
my $Cookie_uri = URI->new("http://$Fwd_Host/quotetools/clientForward");
my $Post_uri   = $Cookie_uri->clone;
$Cookie_uri->query_form( targetURL => $Tgt_Cookie_uri->as_string );
$Post_uri->query_form  ( targetURL => $Tgt_Post_uri->as_string   );

my $CSV_uri = URI->new("http://$Fwd_Host/quotetools/getHistoryDownload.csv");

sub _initialize_cookie_session {
  my $self = shift;
  my $ua = $self->ua;
  if (my $cj = $ua->cookie_jar) {
    # only init cookie once
    return if $cj->scan( sub { $_[4] eq $Fwd_Host } );
  }
  # quotemedia tracks sessions via unique cookies
  $ua->cookie_jar({}); 
  # URL redirects with POST data required as well
  push @{ $ua->requests_redirectable }, 'POST';
  # set up cookie
  print STDERR "HEAD to ",$Cookie_uri->canonical,"\n" if DEBUG;
  my $resp = $ua->head($Cookie_uri);
  croak "Problem establishing cookie : ".$resp->status_line."\n"
    unless $resp->is_success;
  print STDERR $ua->cookie_jar->as_string, "\n" if DEBUG;
  $resp;
}

sub url_maker {
  my($self, %parms) = @_;
  my $start_date = $parms{start_date} ||= $self->start_date;
  my $end_date   = $parms{end_date}   ||= $self->end_date;

  # QM no longer provides CSV

  $parms{parse_mode} = $self->parse_mode('html');
  return $self->_html_url_maker(%parms);
}

sub _html_url_maker {
  my($self, %parms) = @_;
  my $target_mode = $parms{target_mode} || $self->target_mode;
  my $parse_mode  = $parms{parse_mode}  || $self->parse_mode;
  # *always* block unknown target/mode cominations
  return undef unless $target_mode eq 'quote' && $parse_mode eq 'html';

  my($symbol, $start_date, $end_date) =
    @parms{qw(symbol start_date end_date)};

  # cheat if this is just testing capability (avoids bogus session
  # queries)
  return sub {} if $symbol eq 'waggledance';

  $self->_initialize_cookie_session;

  $start_date ||= $self->start_date;
  $end_date   ||= $self->end_date;
  my($sy, $sm, $sd) = $self->ymd($start_date);
  my($ey, $em, $ed) = $self->ymd($end_date);
  --$sm; --$em;

  my($page, $max_page, $per_page) = (1, 0, 90);
  my $referer;
  sub {
    my $resp;
    if ($page == 1) {
      $resp = $self->_post_redirect($symbol, $start_date, $end_date, 1);
      $referer = $resp->previous->header('location');
    }
    else {
      my $uri = $Post_uri->clone;
      $uri->query_form(
        targetsym  => '',
        targettype => 'null',
        targetex   => '',
        qmpage     => 'true',
        action     => 'showHistory',
        symbol     => $symbol,
        page       => $page,
        perPage    => $per_page, # default 25, 90 appears to be maximum
        startDay   => $sd, startMonth => $sm, startYear => $sy,
        endDay     => $ed, endMonth   => $em, endYear   => $ey,
      );
      my $req = GET($uri);
      $req->referer($referer);
      $resp = $self->ua->request($req);
      croak "Problem fetching outer page : ".$resp->status_line."\n"
        unless $resp->is_success;
      $referer = $resp->previous->header('location');
    }
    ++$page;
    my $uri = $self->_extract_quote_src($resp->content);
    my $req = HTTP::Request->new(GET => $uri);
    $req->referer($referer);
    $req;
  };
}

sub html_pre_parser {
  # since our goodies are actually embedded in a javascript
  # document.write statement, we force the document to look more like
  # normal html so HTE can have at it.
  my $self = shift;
  sub {
    my $extracted = '';
    foreach my $dq ($_[0] =~ /$RE{quoted}/g) {
      $extracted .= eval $dq;
      croak "problem evaling double quoted string : $@\n" if $@;
    }
    $extracted;
  };
}

sub _post_redirect {
  my $self = shift;
  my($symbol, $start_date, $end_date) = @_;
  my $ua = $self->ua;
  my($sy, $sm, $sd) = $self->ymd($start_date);
  my($ey, $em, $ed) = $self->ymd($end_date);
  --$sm; --$em;
  my %form = (
    action => 'showHistory',
    symbol => $symbol,
  );
  my $uri = $Post_uri->clone;
  $uri->query_form(
    targetsym  => '',
    targettype => 'null',
    targetex   => '',
    qmpage     => 'true',
  );
  print STDERR "POST to ",$uri->canonical,"\n" if DEBUG;
  my $req = POST($uri, \%form);
  $req->referer($Results_uri);
  my $resp = $ua->request($req);
  croak "Problem establishing cookie : ".$resp->status_line."\n"
    unless $resp->is_success;
  $resp;
}

sub _extract_quote_src {
  my $self = shift;
  my $content = shift;
  my $parser = HTML::TokeParser->new(\$content) || die "oops parser $!\n";
  my @urls;
  while ( my $token = $parser->get_tag( 'script' ) ) {
    my $url = $token->[1]{src} || next;
    my $uri;
    if ($url =~ qw{^/}) {
      $uri = URI->new("http://$Tgt_Host$url");
    }
    else {
      $uri = URI->new($url);
    }
    next unless $uri->host eq $Fwd_Host;
    my %query = $uri->query_form();
    next unless $query{targetURL};
    return $uri;
 }
 return;
}

1;

__END__

=head1 NAME

Finance::QuoteHist::QuoteMedia - Site-specific class for retrieving historical stock quotes.

=head1 SYNOPSIS

  use Finance::QuoteHist::QuoteMedia;
  $q = Finance::QuoteHist::QuoteMedia->new
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

Finance::QuoteHist::QuoteMedia is a subclass of
Finance::QuoteHist::Generic, specifically tailored to read historical
quotes from the QuoteMedia web site (I<http://www.quotemedia.com/>).
Note that Quotemedia is currently the site that provides historical
quote data for such other sites as Silicon Investor, which was the topic
of an earlier module in this distribution.

Quotemedia does not currently provide information on dividends or
splits.

For quote queries in particular, at the time of this writing, the
Quotemedia web site utilizes start and end dates with no apparent limit
on the number of results returned. Results are harvested from HTML
since CSV no longer seems to be supported.

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

Details for Quotemedia's terms of use can be found here:
I<http://www.quotemedia.com/termsofusetools.php>

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
