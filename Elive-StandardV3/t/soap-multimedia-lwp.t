#!/usr/bin/perl
use warnings; use strict;
use Test::More tests => 3;
use Test::Fatal;

use Elive::StandardV3;
use t::Elive::StandardV3;

for (qw(LWP::UserAgent HTTP::Request::Common)) {
    eval "use $_";
    plan skip_all => "$_ required for lwp level testing" if $@;
}

SKIP: {

    my %result = t::Elive::StandardV3->test_connection();
    my $auth = $result{auth};

    skip ($result{reason} || 'skipping live tests', 3)
	unless $auth;

    my $connection_class = $result{class};
    my $connection = $connection_class->connect(@$auth);
    my $message = do {local $/; <DATA>};
    my $userAgent = LWP::UserAgent->new(agent => 'perl post');
    my $response;

    is ( exception {
	$response = $userAgent
	    ->request(HTTP::Request::Common::POST( $connection->_proxy,
		      Authorization => $connection->_authoriz,
		      Content_Type => 'text/xml',
		      Content => $message))
		  } => undef, "uploadMultimediaContent request post - lives"); 

    ok($response->is_success, 'response is succcess');

    my $response_string = $response->as_string;
    note "==== RESPONSE ====\n".$response_string;

    ok( $response !~ m{error}i, 'Response is not an error');

    $connection->disconnect;
}

__DATA__
<soapenv:Envelope
  xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"
  xmlns:sas="http://sas.elluminate.com/"
  xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <soapenv:Body>
    <sas:UploadRepositoryMultimedia>
        <sas:creatorId>serversupport</sas:creatorId>
        <sas:filename>test.mp3</sas:filename>
        <sas:description>test api3 upload</sas:description>
        <sas:content xsi:type="xs:base64Binary">anVzdCBzb21lIGp1bms=</sas:content>
    </sas:UploadRepositoryMultimedia>
  </soapenv:Body>
</soapenv:Envelope>
