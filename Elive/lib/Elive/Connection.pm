package Elive::Connection;
use warnings; use strict;

use Class::Accessor;
use Class::Data::Inheritable;
use HTML::Entities;
use Scalar::Util;

use Carp;

use base qw{Class::Accessor};

use Elive;
use Elive::Util;
use Elive::Entity;
use Elive::Entity::User;
use Elive::Entity::ServerDetails;

=head1 NAME

Elive::Connection -  Manage Elluminate SOAP connections.

=head1 DESCRIPTION

This module handles logical connections to Elluminate I<Live!> sites.

Most of the time, you won't need to use this module directly, rather
you'll create a default connection via L<Elive>:

    Elive->connect('http://someserver.com', 'someuser', 'somepass');

However, if you need to manage multiple sites and/or servers. You can
have multiple connections:

    my $connection1
            = Elive::Connection->connect('http://someserver.com/site1',
                                        'someUser', 'somePass');

    my $connection2
            = Elive::Connection->connect('http://someserver.com/site2',
                                         'anotherUser', 'anotherPass');

All entity constructor and retrieval methods support an optional connection
parameter. For example:

     my $user = Entity::User->retrieve(
                     [userId => 123456789000],
                     connection => $connection1,
                    );

The C<connection> option can be used on all of the following entity methods:
C<create>, C<insert>, C<list> and C<retrieve>.

=cut

require SOAP::Lite;
use URI;
use File::Spec::Unix;
use HTML::Entities;

__PACKAGE__->mk_accessors( qw{url user pass _soap _soap_v2 _login _server_details dao_class} );

=head1 METHODS

=cut

=head2 connect

    my $ec = Elive::Connection->connect('http://someserver.com/test',
                                        'user1', 'pass1', debug => 1);

    my $url = $ec->url;   # should be 'http://someserver.com/test'

Establishes a logical SOAP connection. Retrieves the login user, to verify
connectivity and authentication details.

=cut

sub connect {
    my ($class, $url, $user, $pass, %opt) = @_;

    $url =~ s{/$}{}x;

    my $uri_obj = URI->new($url, 'http');

    my $uri_path = $uri_obj->path;

    my @path = File::Spec::Unix->splitdir($uri_path);

    shift (@path)
	if (@path && !$path[0]);

    pop (@path)
	if (@path && $path[-1] eq 'webservice.event');

    #
    # normalise the connection url by removing suffixes. The following
    # all reduce to http://mysite/myinst:
    # -- http://mysite/myinst/webservice.event
    # -- http://mysite/myinst/v2
    # -- http://mysite/myinst/v2/webservice.event
    # -- http://mysite/myinst/default
    # -- http://mysite/myinst/default/webservice.event
    #
    # there's some ambiguity, they've named an instance v1 ... v9 - yikes!
    #

    if (@path && $path[-1] =~ m{^v(\d+)$}) {
	croak "unsupported standard bridge version v${1}, endpoint path: ". File::Spec::Unix->catdir(@path, 'webservice.event')
	    unless $1 == 2;
	pop(@path);
    }

    $uri_obj->path(File::Spec::Unix->catdir(@path));

    my $debug = $opt{debug}||0;

    SOAP::Lite::import($debug >= 3
		       ? (+trace => 'debug')
		       : ()
	);

    my $restful_url = $uri_obj->as_string;

    warn "connecting to ".$restful_url
	if ($debug);

    my $self = {};
    bless $self, $class;

    $self->url($restful_url);
    $self->user($user);
    $self->pass($pass);

    return $self
}

=head2 disconnect

Closes a connection.

=cut

sub disconnect {
    my $self = shift;

    $self->_server_details(undef);
    $self->_login(undef);

    return;
}

=head2 call

    my $som = $ec->call('listUsers', filter => '(givenName like "john*")')

Performs an Elluminate SOAP method call. Returns the response as a
SOAP::SOM object.

=cut

sub call {
    my ($self, $cmd, %params) = @_;

    my @soap_params = $self->_preamble($cmd);

    $params{adapter} ||= 'default';

    foreach my $name (keys %params) {

	my $value = $params{$name};

	$value = SOAP::Data->type(string => Elive::Util::string($value))
	    unless (Scalar::Util::blessed($value)
		    && eval {$value->isa('SOAP::Data')});

	my $soap_param = $value->name($name);

	push (@soap_params, $soap_param);
    }

    my $som = $self->soap->call( @soap_params );

    return $som;
}

sub soap {
    my ($self) = shift;

    my $soap = $self->_soap;

    unless ($soap) {
	$soap = SOAP::Lite->new();

	my $proxy = join('/', $self->url, 'webservice.event');
	$soap->proxy($proxy);

	$self->_soap($soap);
    }

    return $soap;
}

sub soap_v2 {
    my ($self) = shift;

    my $soap_v2 = $self->_soap_v2;

    unless ($soap_v2) {
	$soap_v2 = SOAP::Lite->new();
	$soap_v2->ns( "http://schemas.xmlsoap.org/soap/envelope" => "soapenv");
	$soap_v2->ns( "http://sas.elluminate.com/" => "sas");

	my $proxy_v2 = join('/', $self->url, 'v2', 'webservice.event');

	$soap_v2->proxy($proxy_v2);

	$self->_soap_v2($soap_v2);
    }

    return $soap_v2;
}

=head2 login

Returns the login user as an object of type L<Elive::Entity::User>.

=cut

sub login {
    my ($self) = @_;

    my $login_entity = $self->_login;

    unless ($login_entity) {

	my $username = $self->user
	    or return;

	$login_entity = Elive::Entity::User->get_by_loginName($username,
	    connection => $self)
	    or die "unable to get login user: $username\n";

	$self->_login($login_entity);
    }

    return $login_entity;
}

=head2 server_details

Returns the server details as an object of type L<Elive::Entity::ServerDetails>.

=cut

sub server_details {
    my $self = shift;

    my $server_details = $self->_server_details;

    unless ($server_details) {

	my $server_details_list = Elive::Entity::ServerDetails->list(connection => $self);

	die "unable to get server details\n"
	    unless (Elive::Util::_reftype($server_details_list) eq 'ARRAY'
		    && $server_details_list->[0]);

	$server_details = ($server_details_list->[0]);

	$self->_server_details($server_details);
    }

    return $server_details;
}

=head2 url

    my $url1 = $connection1->url;
    my $url2 = $connection2->url;

Returns a restful url for the connection.

=cut

=head2 soap

    my $soap_lite_obj = $connection->soap;

Returns the underlying L<SOAP::Lite> object for the connection.

=cut

sub _preamble {

    my ($self,$cmd) = @_;

    die "Not logged in"
	unless ($self->user);

    my @user_auth =  (map {HTML::Entities::encode_entities( $_ )}
		      ($self->user, $self->pass));

    my @preamble = (
	(SOAP::Data
	 ->name('request')
	 ->uri('http://www.soapware.org')
	 ->prefix('m')
	 ->value('')),
	);

    push (@preamble, SOAP::Data->name('command')->value($cmd))
	if $cmd;

    my $auth = sprintf (<<'EOD', @user_auth);
    <h:BasicAuth
      xmlns:h="http://soap-authentication.org/basic/2001/10/"
    soap:mustUnderstand="1">
    <Name>%s</Name>
    <Password>%s</Password>
    </h:BasicAuth>
EOD

return (@preamble, SOAP::Header->type(xml => $auth));
};

sub _preamble_v2 {
    my ($self, $cmd) = @_;

    die "Not logged in"
	unless ($self->user);

    my @user_auth =  (map {HTML::Entities::encode_entities( $_ )} ($self->user, $self->pass));

    my @preamble = (
    );

    push (@preamble, SOAP::Data->prefix('sas')->name($cmd))
	if $cmd;

    my $auth = sprintf(<<'EOD', @user_auth);
<sas:BasicAuth>
<sas:Name>%s</sas:Name>
<sas:Password>%s</sas:Password>
</sas:BasicAuth>
EOD

return (@preamble, SOAP::Header->type(xml => $auth));
};

sub DESTROY {
    shift->disconnect;
    return;
}

=head1 SEE ALSO

L<SOAP::Lite>

=cut

1;
