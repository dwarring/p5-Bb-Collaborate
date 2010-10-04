package Elive::Connection::SAS;
use warnings; use strict;

use Class::Accessor;
use Class::Data::Inheritable;
use Scalar::Util;

use SOAP::Lite;
use MIME::Base64;

use Carp;

use Elive::Connection;
use base qw{Elive::Connection};

use Elive;
use Elive::Util;

#
# cache singleton records
#
__PACKAGE__->mk_accessors( qw{_scheduling_manager _server_configuration _server_versions} );

sub connect {
    my ($class, $url, $user, $pass, %opt) = @_;

    my $self = $class->SUPER::_connect($url, $user, $pass, %opt);
    $self->type('SAS');

    bless $self, $class;

    return $self;
}

sub disconnect {
    my $self = shift;

    $self->SUPER::disconnect;

    return;
}

sub call {
    my ($self, $cmd, %params) = @_;

    die "bad connection type. expected 'SAS', found: ".$self->type
	unless $self->type eq 'SAS';

    return $self->SUPER::call( $cmd, %params );
}

sub soap {
    my ($self) = shift;

    my $soap = $self->_soap;

    unless ($soap) {

	my $proxy = join('/', $self->url, 'v2', 'webservice.event');

	my $debug = $self->debug;

	SOAP::Lite::import($debug >= 3
			   ? (+trace => 'debug')
			   : ()
	    );

	warn "connecting to ".$proxy
	    if ($debug);

	$soap = SOAP::Lite->new();
	$soap->ns( "http://schemas.xmlsoap.org/soap/envelope" => "soapenv");
	$soap->ns( "http://sas.elluminate.com/" => "sas");

	$soap->proxy($proxy);

	my $authoriz = 'Basic '.MIME::Base64::encode_base64($self->user.':'.$self->pass);

	$soap->transport->http_request->headers->push_header('Authorization'=>$authoriz);

	$self->_soap($soap);
    }

    return $soap;
}

=head2 scheduling_manager

Returns the scheduling manager for this connection (see L<Elive::Entity::SchedulingManager>).

=cut

sub scheduling_manager {
    my $self = shift;

    my $scheduling_manager = $self->_scheduling_manager;

    unless ($scheduling_manager) {

	eval {require Elive::SAS::SchedulingManager};
	die $@ if $@;

	$scheduling_manager = Elive::SAS::SchedulingManager->get(connection => $self);
	$self->_scheduling_manager($scheduling_manager);
    }

    return $scheduling_manager;
}

=head2 server_configuration

Returns the server configuration for this connection (see L<Elive::Entity::ServerConfiguration>).

=cut

sub server_configuration {
    my $self = shift;

    my $server_configuration = $self->_server_configuration;

    unless ($server_configuration) {

	eval {require Elive::SAS::ServerConfiguration};
	die $@ if $@;

	$server_configuration = Elive::SAS::ServerConfiguration->get(connection => $self);
	$self->_server_configuration($server_configuration);
    }

    return $server_configuration;
}

=head2 server_versions

Returns the server versions for this connection (see L<Elive::Entity::ServerVersions>).

=cut

sub server_versions {
    my $self = shift;

    my $server_versions = $self->_server_versions;

    unless ($server_versions) {

	eval {require Elive::SAS::ServerVersions};
	die $@ if $@;

	$server_versions = Elive::SAS::ServerVersions->get(connection => $self);
	$self->_server_versions($server_versions);
    }

    return $server_versions;
}

sub _preamble {
    my ($self, $cmd) = @_;

    die "Not logged in"
	unless ($self->user);

    my @preamble = (
    );

    push (@preamble, SOAP::Data->prefix('sas')->name($cmd))
	if $cmd;

    return @preamble;
};

1;
