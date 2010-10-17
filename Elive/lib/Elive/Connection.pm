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

use base qw{Class::Accessor Class::Data::Inheritable};

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
                                        'user1' => 'pass1');

    my $connection2
            = Elive::Connection->connect('http://user2:pass2@someserver.com/site2');

=cut

__PACKAGE__->mk_accessors( qw{url user pass _soap debug type} );

=head1 METHODS

=cut

=head2 connect

    my $sdk_c1 = Elive::Connection->connect('http://someserver.com/test',
                                        'user1', 'pass1', debug => 1,
    );

    my $url1 = $sdk_c1->url;   #  'http://someserver.com/test'

    my $sdk_c2 =  Elive::Connection->connect('http://user2:pass2@someserver.com/test', undef, undef);
    my $url2 = $sdk_c2->url;   #  'http://someserver.com/test'

Establishes a SOAP connection.

=cut

sub connect {
    my ($class, $url, $user, $pass, %opt) = @_;
    #
    # for backwards compatibility
    #
    require Elive::Connection::SDK;
    return Elive::Connection::SDK->connect($url, $user => $pass, %opt);
}

sub _connect {
    my ($class, $url, $user, $pass, %opt) = @_;

    my $debug = $opt{debug}||0;

    $url =~ s{/$}{}x;

    my $uri_obj = URI->new($url, 'http');
    my $userinfo = $uri_obj->userinfo;

    if ($userinfo) {

	#
	# extract and remove any credentials from the url
	#

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
    else {
	warn "no credentials in url: $url" if $debug;
    }

    my $uri_path = $uri_obj->path;

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

    my $restful_url = $uri_obj->as_string;

    #
    # ugly
    #
    $restful_url =~ s{\Q${userinfo}\E\@}{} if $userinfo;

    my $self = {};
    bless $self, $class;

    $self->url($restful_url);
    $self->user($user);
    $self->pass($pass);
    $self->debug($debug);

    return $self
}

sub _check_for_errors {
    my $class = shift;
    my $som = shift;

    croak "No response from server"
	unless $som;

    croak $som->fault->{ faultstring } if ($som->fault);

    my $result = $som->result;
    my @paramsout = $som->paramsout;

    warn YAML::Dump({result => $result, paramsout => \@paramsout})
	if ($class->debug);

    my @results = ($result, @paramsout);

    foreach my $result (@results) {
	next unless Scalar::Util::reftype($result);
    
	#
	# Look for Elluminate-specific errors
	#
	if ($result->{Code}
	    && (my $code = $result->{Code}{Value})) {

	    #
	    # Elluminate error!
	    #
	
	    my $reason = $result->{Reason}{Text};

	    my $trace = $result->{Detail}{Stack}{Trace};
	    my @stacktrace;
	    if ($trace) {
		@stacktrace = (Elive::Util::_reftype($trace) eq 'ARRAY'
			       ? @$trace
			       : $trace);

	    }

	    my %seen;

	    my @error = grep {defined($_) && !$seen{$_}++} ($code, $reason, @stacktrace);
	    Carp::croak join(' ', @error) || YAML::Dump($result);
	}
    }
}

=head2 check_command

    my $command1 = Elive->check_command([qw{getUser listUser}])
    my $command2 = Elive->check_command(deleteUser => 'd')

Find the first known command in the list. Raise an error if it's unknown;

See also: elive_lint_config.

=cut

sub check_command {
    my $class = shift;
    my $commands = shift;
    my $crud = shift; #create, read, update or delete

    $commands = [$commands]
	unless Elive::Util::_reftype($commands) eq 'ARRAY';

    my $usage = "usage: \$class->check_command(\$name[,'c'|'r'|'u'|'d'])";
    die $usage unless @$commands && $commands->[0];

    my $known_commands = $class->known_commands;

    die "no known commands for class: $class"
	unless $known_commands && (keys %{$known_commands});

    my ($command) = grep {exists $known_commands->{$_}} @$commands;

    croak "Unknown command(s): @{$commands}"
	unless $command;

    if ($crud) {
	$crud = lc(substr($crud,0,1));
	die $usage
	    unless $crud =~ m{^[c|r|u|d]$}xi;

	my $command_type = $known_commands->{$command};
	die "misconfigured command: $command"
	    unless $command_type &&  $command_type  =~ m{^[c|r|u|d]+$}xi;

	die "command $command. Type mismatch. Expected $crud, found $command_type"
	    unless ($crud =~ m{[$command_type]}i);
    }

    return $command;
}

=head2 known_commands

Returns an array of hash-value pairs for all Elluminate I<Live!> commands
required by Elive. This list is cross-checked by the script elive_lint_config. 

=cut

=head2 call

    my $som = $self->call( $cmd, %params );

Performs an Elluminate SOAP method call. Returns the response as a
SOAP::SOM object.

=cut

sub call {
    my ($self, $cmd, %params) = @_;

    $cmd = $self->check_command($cmd);

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

L<Elive::Connection::SDK> L<Elive::Connection::API> L<SOAP::Lite>

=cut

1;
