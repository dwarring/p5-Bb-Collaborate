package Elive::Connection;
use warnings; use strict;

use base qw{ Class::Accessor };

=head1 NAME

Elive::Connection -  Maintain a SOAP/XML connection with an Elluinate Server.

=cut

use SOAP::Lite;
use URI;
use File::Spec;
use HTML::Entities;

__PACKAGE__->mk_accessors( qw{ url user pass soap } );

=head2 new

    my $ec = Elive::Connection->new ('http://someserver.com/test',
                                     'user1', 'pass1',
                                     debug => 1)

=cut

sub new {
    my ($class, $url,  $user, $pass, %opt) = @_;

    my $uri = URI->new($url, 'http');

    my @path = File::Spec->splitdir( $uri->path );

    push (@path, 'webservice.event')
	unless (@path && $path[ -1 ] eq 'webservice.event');

    $uri->path( File::Spec->catdir(@path) );

    warn "connecting to ".$uri->as_string
	if ($opt{debug});

    my $soap = SOAP::Lite->new( proxy => $uri->as_string );
    
    my $self = bless {
	url => $uri->as_string,
	user => $user,
	pass => $pass,
	soap => $soap,
    }, $class;

    return $self
}

=head2 call

    my $resp = $ec->call('listUsers', filter => '(givenName like "john%")')

    Make an Elluminate SOAP/XML method call.

=cut

sub call {
    my $self = shift;
    my $cmd = shift;
    my %params = @_;

    die "usage: \$obj->call(cmd [, %params])" unless $cmd;

    $params{adapter} ||= 'default';

    my @soap_params = (SOAP::Data->name('_')->value(''),
		       SOAP::Header->type(xml => $self->_soap_header_xml()),
		       SOAP::Data->name('command')->value($cmd),
		);

    foreach my $name (keys %params) {

	my $value = $params{$name};

	push (@soap_params,  SOAP::Data->name($name)->value($value));

    }

    my $som = $self->soap->call( @soap_params );

    return $som;
}

sub _soap_header_xml {

    my $self = shift;

    die "Not logged in"
	unless ($self->user);

    my @user_pass =  (map {HTML::Entities::encode_entities( $_ )}
		      ($self->user, $self->pass));

    return sprintf (<<EOD, @user_pass );
<h:BasicAuth
    xmlns:h="http://soap-authentication.org/basic/2001/10/"
    soap:mustUnderstand="1">
    <Name>%s</Name>
    <Password>%s</Password>
</h:BasicAuth>
EOD
};

1;
