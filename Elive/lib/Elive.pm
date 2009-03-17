package Elive;

use warnings;
use strict;

=head1 NAME

Elive -  Elluminate Live (c) client library

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

    use Elive;
    use Elive::Entity::User;

    Elive->connect('http://someEllumServer.com/test',
                   'serversupport', 'mypass');

    my $users = Elive::Entity::User->list(filter => "(lastName = 'Smyth')");

    foreach my $user (@$users) {

        printf ("changing last name for user: %s\n", $user->loginName)

        $user->lastName('Smith');
        $user->update;

    }

=head1 DESCRIPTION

This module provides class and object bindings to Elluminate Live
SOAP/XML commands.

It enables basic create/read/update and delete of Users, User Lists,
Meetings and Meeting Participants.

Elluminate Live (c) is a virtual classroom portal largely written in Java.
Session particpants join the meeting via a Java portal back to a central
server.

Elluminate installs with a built-in pure Java database (Mckoi) and provides
language independant SOAP/XML layer. This package implements perl bindings
for this.

=cut

use Moose;

use base qw{Class::Data::Inheritable };

use Elive::Connection;

__PACKAGE__->mk_classdata('_last_connection');
__PACKAGE__->mk_classdata('_login');
__PACKAGE__->mk_classdata('adapter' => 'default');

our $DEBUG = 0;
our $WARN = 1;

=head1 METHODS

=head2 connect

     my $e1 = Elive->connect('http://myServer.com/test1', user1, pass1);

     Elive->connect('http://myServer.com/test2', user2, pass2);
     my $e2 = Elive->connection;

    Connects to an Elluminate Server instance. Dies if the connection could not
    be established. For example the connection or user login failed.

=cut

sub connect {

    my $class = shift;
    my ($url, $login_name, $pass) = @_;

    die "usage: ${class}->new(url, login_name[, pass])"
	unless ($class && $url && $login_name);

    my $connection = Elive::Connection->new(
	$url,
	$login_name,
	$pass,
	debug => $class->debug,
	);

    $class->_last_connection( $connection );

    #
    # The login name should be a valid user in the database
    # retrieve it as a way of authenticating the user and
    # checking basic connectivity.

    eval "use  Elive::Entity::User";
    die $@ if $@;

    my $login_user = Elive::Entity::User->get_by_loginName($login_name);

    die "Unable to connect via user $login_name"
	unless $login_user;

    $class->_login ($login_user);

    return $connection;
}

=head2 connection

     $e1 = Elive->connection
         or warn 'no elive connection active';

     Returns an Elive handle for the last successful connection.

=cut

sub connection {
    my $class = shift;

    return $class->_last_connection;
}

=head2 login

return the connected user entity

=cut

sub login {
    return shift->_login
}
    

=head2 disconnect

Disconnect from elluminate. It is recommended that you do this prior to
exiting your program

=cut

sub disconnect {
    my $class = shift;

    $class->_last_connection(undef);
    $class->_login(undef);
}

=head2 debug

    Elive->debug(1)

    Set or get the debug level.

      0 = no debugging
      1 = dump object and class information 
      2 = also enable SOAP::Lite tracing
      3 = very detailed

=cut

sub debug {
    my $class = shift;

    if (@_) {
	my $debug = shift || 0;

	$DEBUG = $debug;

	SOAP::Lite::import($debug >= 3
			   ? (+trace => 'debug')
			   : ()
	    );
    }

    return $DEBUG || 0;
}

=head1 EXAMPLES

elive_query is an installed script the Elive distribution. It is a simple
program for querying entities and executing queries to an Elluminate server.

	% elive_query http://myserver.com/test -username serversupport
        Password: ********
	connecting to http://myserver.com/test ...done
	Elive 0.01 - type 'help' for help
	elive> help
	...
	elive> describe
	usage: describe group|meeting|meetingParameters|participant|participantList|recording|role|serverDetails|user
	elive> describe user
	user: Elive::Entity::User:
	  userId: pkey Int
	  deleted: Bool
	  loginPassword: Str
	  loginName: Str
	  email: Str
	  role: Elive::Entity::Role
	    roleID:  pkey Int
	  firstName: Str
	  lastName: Str
	elive> select * from users where name like smith*
	userId|deleted|loginPassword|loginName|email|role|firstName|lastName
	182324083157|0||john.smith|john@allthesmiths.net|3|John|Smith
	462298303857|0||sally.smith|sally@smith.id.au|3|Sally|Smith
	elive>

=head2 elive_query Restrictions

elive_query does not attempt parse or interpret where clauses, but simply
passes them through as filter parameters on SOAP calls to the elluminate
server.

For example, for the statement

    elive> select * from users where name like smith*

The equivalent Elive method call is:

    my $users = Elive::Entity::User->list(filter => 'name like smith*');

The exception is where clauses of the form C<pkey = val>, where C<pkey> is
the primary key for the entity table. e.g:

    elive> select * from meetingParticpants where meetingId = 1234567

The equivalent Elive method call for the above is

    my $participants =  Elive::Entity::MeetingParticpant->retrieve_all(1234567);

Also note that we've got no way of enforcing limits via the SOAP interface.
be careful the include a where clauses to limit the amount of data returned
for larger tables. 

As a final note, elive_query doesn't support updates or deletes with the
initial release of Elive 0.1. This may be implemented in the next few
releases.

=head1 BUGS AND LIMITATIONS

(*) Elluminate SOAP/XML interface doesn't locking or transactional control
    and cannot match the robustness of a native database. 
    It's probably a good idea to design your application architecture and
    database updates to minimise the changes of contention. Eg. audit trails
    and/or master copies of the data. Also consider Elluminate Live's backup
    facilties.

(*) The Elluminate server installs with the Mckoi JDBC database, but can
    also connect to other databases that support JDBC and can be readily
    accessed via the Perl DBI. E.g. SQL Server or Oracle. See the Elluminate
    Live advanced adminstration guide.

(*) Elluminate Live can also be configured to use an LDAP respository for
    user authentication.  Users can still be retrieved or listed. However
    updates and deletes are not supported via Elluminate Live or Elive.

=head1 SEE ALSO

  Elive::Connection - SOAP/XML Connection

  Elive::Entity - The base class for all elive entities

  Elive::Entity::Group
  Elive::Entity::Meeting
  Elive::Entity::MeetingParameters
  Elive::Entity::ParticipantList
  Elive::Entity::Recording
  Elive::Entity::ServerDetails
  Elive::Entity::User

  elive_query - simple interactive queries on Elive entities
  elive_raise_meeting - sample script that create meetings via one-liners

The Elluminate Dcoumentation Suite, including:

  ELM2.5_SDK.pdf      - Elive interfaces with the SOAP/XML bindings
                        described in section 4 - the command toolkit.
  DatabaseSchema.pdf  - Elluminate Database Schema Documentation.
  InstanceManager.pdf - Describes setting up multiple instances. You'll
                        probably at least want to set up a test instance!

=head1 AUTHOR

David Warring, C<< <david.warring at gmail.com> >>

=head1 BUGS

The initial v0.01 Elive release:

-- has been tested against Elluminate 9.0 and 9.1 only
-- doesn't implement all SOAP calls. I will try to build this up
   over time. Please let me know your priorities.

Please report any bugs or feature requests to C<bug-elive at rt.cpan.org>,
or through the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Elive>.
I will be notified, and then you'll automatically be notified of progress on
your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Elive

You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Elive>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Elive>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Elive>

=item * Search CPAN

L<http://search.cpan.org/dist/Elive/>

=back

=head1 ACKNOWLEDGEMENTS

Thanks to Lex Lucas and to Simon Haidley their support and direction
with the consrtuction of this module.

=head1 COPYRIGHT & LICENSE

Copyright 2009 David Warring, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut

1; # End of Elive
