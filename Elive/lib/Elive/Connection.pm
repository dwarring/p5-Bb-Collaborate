package Elive::Connection;
use warnings; use strict;

use Carp;
use Class::Accessor;
use Class::Data::Inheritable;
use File::Spec::Unix;
use HTML::Entities;
use Scalar::Util;
require SOAP::Lite;
use URI;
use URI::Escape qw{};

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

__PACKAGE__->mk_accessors( qw{url user pass _soap debug type} );

=head1 METHODS

=cut

=head2 connect

    my $ec = Elive::Connection->connect('http://someserver.com/test',
                                        'user1', 'pass1', debug => 1,
                                        type => 'SDK',
    );

    my $url = $ec->url;   # should be 'http://someserver.com/test'

Establishes a logical SOAP connection. Retrieves the login user, to verify
connectivity and authentication details.

=cut

sub connect {
    my ($class, $url, $user, $pass, %opt) = @_;

    my $type = $opt{type} || 'SDK';

    my $connection_class = "Elive::Connection::${type}";

    eval "require ${connection_class}";
    die "unable to require ${connection_class}: $@"
	if $@;

    my $connection = $connection_class->connect($url, $user, $pass, %opt);

    return $connection;
}

sub _connect {
    my ($class, $url, $user, $pass, %opt) = @_;

    $url =~ s{/$}{}x;

    my $uri_obj = URI->new($url, 'http');

    my $uri_path = $uri_obj->path;

    if (my $userinfo = $uri_obj->userinfo) {

	$uri_obj->userinfo('');

	my ($uri_user, $uri_pass) = split(':',$userinfo, 2);

	if ($uri_user) {
	    if ($user && $user ne $uri_user) {
		carp 'ignoring user in URI scheme - overridden';
	    }
	    else {
		$user = URI::Escape::uri_unescape($uri_user);
	    }
	}

	if ($uri_pass) {
	    if ($pass && $pass ne $uri_pass) {
		carp 'ignoring pass in URI scheme - overridden';
	    }
	    else {
		$pass = URI::Escape::uri_unescape($uri_pass);
	    }
	}
    }

    $pass = '' unless defined $pass;

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

    my $restful_url = $uri_obj->as_string;

    my $self = {};
    bless $self, $class;

    $self->url($restful_url);
    $self->user($user);
    $self->pass($pass);
    $self->debug($debug);

    return $self
}

=head2 call

    my $som = ....

Performs an Elluminate SOAP method call. Returns the response as a
SOAP::SOM object.

=cut

sub call {
    my ($self, $cmd, %params) = @_;

    my @soap_params = $self->_preamble($cmd);

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

=head2 disconnect

Closes a connection.

=cut

sub disconnect {
    my $self = shift;
    return;
}

=head2 url

    my $url1 = $connection1->url;
    my $url2 = $connection2->url;

Returns a restful url for the connection.

=cut

sub DESTROY {
    shift->disconnect;
    return;
}

=head1 SEE ALSO

L<SOAP::Lite>

=cut

1;
