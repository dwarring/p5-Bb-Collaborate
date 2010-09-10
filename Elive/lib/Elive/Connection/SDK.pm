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
