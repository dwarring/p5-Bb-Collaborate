package Elive::Connection;
use warnings; use strict;

use Class::Accessor;
use Class::Data::Inheritable;

use base qw{Class::Accessor};

=head1 NAME

Elive::Connection -  Manage an Elluminate SOAP/XML Connection

=cut

use SOAP::Lite;
use URI;
use File::Spec;
use HTML::Entities;

__PACKAGE__->mk_accessors( qw{ url user pass soap _login _server_details} );

=head1 METHODS

=cut

=head2 connect

    my $ec = Elive::Connection->connect('http://someserver.com/test',
    'user1', 'pass1',
    debug => 1)

=cut

sub connect {
    my ($class, $url,  $user, $pass, %opt) = @_;

    my $uri_obj = URI->new($url, 'http');

    my @path = File::Spec->splitdir($uri_obj->path);

    pop (@path)
	if (@path && $path[-1] eq 'webservice.event');

    $uri_obj->path(File::Spec->catdir(@path));
    my $restful_url = $uri_obj->as_string;

    $uri_obj->path(File::Spec->catdir(@path, 'webservice.event'));
    my $soap_url = $uri_obj->as_string;

    warn "connecting to ".$soap_url
	if ($opt{debug});

    my $soap = SOAP::Lite->new(proxy => $soap_url );

    my $self = {};
    bless $self, $class;

    $self->url($restful_url);
    $self->user($user);
    $self->pass($pass);
    $self->soap($soap);

    return $self
}

=head2 disconnect

Close a connection;

=cut

sub disconnect {
    my $self = shift;

    $self->_server_details(undef);
    $self->_login(undef);
}

=head2 call

    my $som = $ec->call('listUsers', filter => '(givenName like "john%")')

    Makes an Elluminate SOAP/XML method call. Returns the response as a
    SOAP::SOM object.

=cut

sub call {
    my $self = shift;
    my $cmd = shift;
    my %params = @_;

    die "usage: \$obj->call(cmd [, %params])" unless $cmd;

    $params{adapter} ||= 'default';

    my @soap_params = (SOAP::Data->name('_')->uri('')->value(''),
		       SOAP::Header->type(xml => $self->_soap_header_xml()),
		       SOAP::Data->name('command')->value($cmd),
	);

    foreach my $name (keys %params) {

	my $value = $params{$name};

	my $soap_param = UNIVERSAL::isa($value, 'SOAP::Data')
	    ? $value->name($name)
	    : (SOAP::Data
	       ->name($name)
	       ->type('string')
	       ->value($value));

	push (@soap_params, $soap_param);

    }

    my $som = $self->soap->call( @soap_params );

    return $som;
}

=head2 login

    Return an elive user entity instance for the login user

=cut

sub login {
    my $self = shift;

    my $login_entity = $self->_login;

    unless ($login_entity) {

	my $username = $self->user
	    or return;

	eval "use  Elive::Entity::User";
	die $@ if $@;

	$login_entity = Elive::Entity::User->get_by_loginName($username)
	    or die "unable to get login user: $username";

	$self->_login($login_entity);
    }

    return $login_entity;
}

=head2 server_details

    Return an elive server_details entity instance for the connection.

=cut

sub server_details {
    my $self = shift;

    my $server_details = $self->_server_details;

    unless ($server_details) {

	eval "use  Elive::Entity::ServerDetails";
	die $@ if $@;

	my $server_details_list = Elive::Entity::ServerDetails->list();

	die "unable to get server details"
	    unless (Elive::Util::_reftype($server_details_list) eq 'ARRAY'
		    && $server_details_list->[0]);

	$server_details = ($server_details_list->[0]);

	$self->_server_details($server_details);
    }

    return $server_details;
}


sub _soap_header_xml {

    my $self = shift;

    die "Not logged in"
	unless ($self->user);

    my @user_auth =  (map {HTML::Entities::encode_entities( $_ )}
		      ($self->user, $self->pass));

    return sprintf (<<EOD, @user_auth);
    <h:BasicAuth
      xmlns:h="http://soap-authentication.org/basic/2001/10/"
    soap:mustUnderstand="1">
    <Name>%s</Name>
    <Password>%s</Password>
    </h:BasicAuth>
EOD
};

sub DESTROY {
    shift->disconnect;
}

1;
