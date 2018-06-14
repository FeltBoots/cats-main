package CATS::Output;

use strict;
use warnings;

use Exporter qw(import);

our @EXPORT_OK = qw(
    downloads_path
    downloads_url
    init_template
    url_f
);

use Encode();

use CATS::Config qw(cats_dir);
use CATS::Globals qw($cid $contest $sid $t $user);
use CATS::DB;
use CATS::Messages;
use CATS::Settings;
use CATS::Template;
use CATS::Utils qw();
use CATS::Web qw(param);

my ($http_mime_type, %extra_headers);

sub downloads_path { cats_dir() . '../download/' }
sub downloads_url { 'download/' }

sub init_template {
    my ($p, $file_name, $extra) = @_;
    ref $p eq 'CATS::Web' or die;

    my ($base_name, $ext) = $file_name =~ /^(\w+)(?:\.(\w+)(:?\.tt))?$/ or die;
    $ext //= $p->{json} ? 'json' : 'html';

    $http_mime_type = {
        html => 'text/html',
        xml => 'application/xml',
        ics => 'text/calendar',
        json => 'application/json',
    }->{$ext} or die 'Unknown template extension';
    $t = CATS::Template->new("$base_name.$ext.tt", cats_dir(), $extra);

    %extra_headers = (
        ($ext eq 'ics' ?
            ('Content-Disposition' => "inline;filename=$base_name.ics") : ()),
        ($p->{json} ?
            ('Access-Control-Allow-Origin' => '*') : ()),
    );
    $t->param(
        lang => CATS::Settings::lang,
        ($p->{jsonp} ? (jsonp => $p->{jsonp}) : ()),
        messages => CATS::Messages::get,
        user => $user,
        contest => $contest,
        noiface => param('noiface') // 0,
    );
}

sub url_f { CATS::Utils::url_function(@_, sid => $sid, cid => $cid) }

sub generate {
    my ($p, $output_file) = @_;
    defined $t or return; #? undef : ref $t eq 'SCALAR' ? return : die 'Template not defined';
    $contest->{time_since_start} or warn 'No contest from: ', $ENV{HTTP_REFERER} || '';
    $t->param(
        dbi_profile => $dbh->{Profile}->{Data}->[0],
        #dbi_profile => Data::Dumper::Dumper($dbh->{Profile}->{Data}),
    ) unless param('notime');
    $t->param(
        langs => [ map { href => url_f('contests', lang => $_), name => $_ }, @cats::langs ],
    );

    my $cookie = $p->make_cookie(CATS::Settings::as_cookie);
    my $enc = $p->{enc} // 'UTF-8';
    $t->param(encoding => $enc);

    $p->content_type($http_mime_type, $enc);
    $p->headers(cookie => $cookie, %extra_headers);

    my $out = $enc eq 'UTF-8' ?
        $t->output : Encode::encode($enc, $t->output, Encode::FB_XMLCREF);
    $p->print($out);
    if ($output_file) {
        open my $f, '>:utf8', $output_file
            or die "Error opening $output_file: $!";
        print $f $out;
    }
}

1;
