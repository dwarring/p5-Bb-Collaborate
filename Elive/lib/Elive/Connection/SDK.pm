package Elive::Connection::SDK;
use warnings; use strict;

use Class::Accessor;
use Class::Data::Inheritable;
use HTML::Entities;
use Scalar::Util;

use Carp;

use Elive::Connection;
use base qw{Elive::Connection};

use Elive;
use Elive::Util;
use Elive::Entity;
use Elive::Entity::User;
use Elive::Entity::ServerDetails;

__PACKAGE__->mk_accessors( qw{_login _server_details} );

sub connect {
    my ($class, $url, $user, $pass, %opt) = @_;

    my $self = $class->SUPER::connect($url, $user, $pass, %opt);

    bless $self, $class;

    #
    # The login name should be a valid user in the database.
    # retrieve it as a way of authenticating the user and
    # checking basic connectivity.
    #
    $self->login;

    return $self;
}

sub disconnect {
    my $self = shift;

    $self->SUPER::disconnect;

    $self->_server_details(undef);
    $self->_login(undef);

    return;
}

=head2 soap

    my $soap_lite_obj = $connection->soap;

Returns the underlying L<SOAP::Lite> object for the connection.

=cut

sub soap {
    my ($self) = shift;

    my $soap = $self->_soap;

    unless ($soap) {

	my $proxy = join('/', $self->url, 'webservice.event');

	my $debug = $self->debug;

	SOAP::Lite::import($debug >= 3
			   ? (+trace => 'debug')
			   : ()
	    );

	warn "connecting to ".$proxy
	    if ($debug);

	$soap = SOAP::Lite->new();

	$soap->proxy($proxy);

	$self->_soap($soap);
    }

    return $soap;
}

sub call {
    my ($self, $cmd, %params) = @_;
    $params{adapter} ||= 'default';
    return $self->SUPER::call( $cmd, %params );
}

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

1;
