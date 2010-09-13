package Elive::Connection::SAS;
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

use Elive::SAS::SchedulingManager;

__PACKAGE__->mk_accessors( qw{_scheduling_manager} );

sub connect {
    my ($class, $url, $user, $pass, %opt) = @_;

    my $self = $class->SUPER::connect($url, $user, $pass, %opt);

    bless $self, $class;

    return $self;
}

sub disconnect {
    my $self = shift;

    $self->SUPER::disconnect;

    return;
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

	$self->_soap($soap);
    }

    return $soap;
}

=head2 scheduling_manager

Returns the server details as an object of type L<Elive::Entity::SchedulingManager>.

=cut

sub scheduling_manager {
    my $self = shift;

    my $scheduling_manager = $self->_scheduling_manager;

    unless ($scheduling_manager) {

	my $scheduling_manager_list = Elive::SAS::SchedulingManager->list(connection => $self);

	die "unable to get server details\n"
	    unless (Elive::Util::_reftype($scheduling_manager_list) eq 'ARRAY'
		    && $scheduling_manager_list->[0]);

	$scheduling_manager = ($scheduling_manager_list->[0]);

	$self->_scheduling_manager($scheduling_manager);
    }

    return $scheduling_manager;
}

sub _preamble {
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

1;
