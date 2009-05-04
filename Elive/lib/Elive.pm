package Elive;
use warnings; use strict;

=head1 NAME

Elive -  Elluminate Live (c) client library

=head1 VERSION

Version 0.13

=cut

our $VERSION = '0.13';

use base qw{Class::Data::Inheritable};

use Elive::Connection;

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

    Elive->disconnect;

=head1 DESCRIPTION

Elive is designed to assist in then integration and automation of
Elluminate Live sites. In particular, managing users and meetings.

It provides Perl object bindings to entities via the Elluminate Live
SOAP/XML command interface.

=head1 BACKGROUND

Elluminate Live (c) is is a web tool for virtual online classrooms.

It is suitable for online collaboration, demonstrations, meetings, web
conferences, seminars and IT deployment, training and support.

Users, Meetings and other resources are stored in a management database.
These can managed via the Elluminate Live web interface.

Most actions that can be performed via the web interface can also be
driven from Elluminate Live's SOAP/XML command interface.

=cut

__PACKAGE__->mk_classdata('adapter' => 'default');

our $DEBUG;
BEGIN {
    $DEBUG = $ENV{ELIVE_DEBUG};
}

=head1 METHODS

=head2 connect

     my $e1 = Elive->connect('http://myServer.com/test1', user1, pass1);

     Elive->connect('http://myServer.com/test2', user2, pass2);
     my $e2 = Elive->connection;

    Connects to an Elluminate Server instance. Dies if the connection could
    not be established. For example the connection or user login failed.

    The login user must be an Elluminate Live system administrator account.

=cut

sub connect {

    my $class = shift;
    my ($url, $login_name, $pass) = @_;

    die "usage: ${class}->new(url, login_name[, pass])"
	unless ($class && $url && $login_name);

    my $connection = Elive::Connection->connect(
	$url,
	$login_name,
	$pass,
	debug => $class->debug,
	);

    $class->connection($connection);

    #
    # The login name should be a valid user in the database.
    # retrieve it as a way of authenticating the user and
    # checking basic connectivity.
    #
    $connection->login;

    return $connection;
}

=head2 connection

     $e1 = Elive->connection
         or warn 'no elive connection active';

     Returns an Elive connection handle.

=cut

__PACKAGE__->mk_classdata('connection');

=head2 login

return the user entity used to connect to the server

=cut

sub login {
    my $class = shift;
    my %opt = @_;

    my $connection = $opt{connection} || $class->connection;

    die "not connected"
	unless $connection;

    return $connection->login;
}

=head2 server_details

return the server details for entity for the current connection.

=cut

sub server_details {
    my $class = shift;
    my %opt = @_;

    my $connection = $opt{connection} || $class->connection;

    die "not connected"
	unless $connection;

    return $connection->server_details;
}
    
=head2 disconnect

Disconnect from elluminate. It is recommended that you do this prior to
exiting your program

=cut

sub disconnect {
    my $class = shift;

    if (my $connection = $class->connection) {
	$connection->disconnect;
	$class->connection(undef);
    }

    return undef;
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

#
# _test_auth - locate test authorization from the environment
#
sub _get_test_auth {
    my $class = shift;

    my $user = $ENV{ELIVE_TEST_USER};
    my $pass = $ENV{ELIVE_TEST_PASS};
    my $url  = $ENV{ELIVE_TEST_URL};

    my %result;

    if ($user && $pass && $url) {
	$result{auth} = [$url, $user, $pass];
    }
    else {
	$result{reason} = 'need to set $ELIVE_TEST_{USER|PASS|URL}';
    }

    return %result;
}

our %KnownAdapters;

BEGIN {
    @KnownAdapters{qw(
addGroupMember addMeetingPreload attendanceNotification changePassword
checkMeetingPreload createGroup createMeeting createPreload createRecording
createUser deleteGroup deleteMeeting deleteParticipant deleteRecording
deletePreload deleteUser getGroup getMeeting getMeetingParameters getPreload
getPreloadStream getRecording getRecordingStream getServerDetails getServerParameters getUser
importPreload importRecording listGroups listMeetingPreloads listMeetings listParticipants
listPreloads listRecordings listUserMeetingsByDate listUsers resetGroup
resetParticipantList setParticipantList streamPreload streamRecording
updateMeeting updateMeetingParameters updateRecording updateServerParameters
updateUser
)} = undef;
}

=head2 check_adapter

    Elive->check_adapter('getUser')

Asserts that the adapter is valid, i.e. it's in the list of known adapters.

See also: elive_lint_config.

=cut

sub check_adapter {
    my $class = shift;
    my $adapter = shift
	or die 'usage: $class->known_adapter($name)';

    die "Uknown adapter: $adapter"
	unless exists $KnownAdapters{$adapter};

    return $adapter;
}

=head2 known_adapters

    Returns an array of all required Elluminate Live Elive. This
    list is used by the script elive_lint_config. 

=cut

sub known_adapters {
    my $class = shift;
    return sort keys %KnownAdapters;
}

our %Meta_Data;
our %Meta_Data_Accessor;

=head2 has_metadata

Create or reuse an inside-out accessor

=cut

sub has_metadata {

    my $class = shift;
    my $accessor = shift;

    unless (exists $Meta_Data_Accessor{ $accessor }) {

	no strict 'refs';

	$Meta_Data_Accessor{ $accessor } ||= sub {
	    my $self = shift;
	    my $ref = $self->_refaddr
		or return;

	    if (@_) {
		$Meta_Data{ $ref }{ $accessor } = $_[0];
	    }

	    return $Meta_Data{ $ref }{ $accessor };
	};

	*{$class.'::'.$accessor} = $Meta_Data_Accessor{ $accessor }
    }

    return $Meta_Data_Accessor{ $accessor };
}

sub DESTROY {
    my $self = shift;
    delete  $Meta_Data{Scalar::Util::refaddr($self)};
}

{
    #
    # just in case this is a moose/mouse object - grr
    #
    no strict 'refs';

    *{__PACKAGE__.'::DEMOLISH'} = \&DESTROY;
}

=head1 ERROR MESSAGES

Elluminate Services Errors:

=over 4

=item   "Unable to determine a command for the key : listXxxx"

This may indicate that the particular command adaptor is is not available for
your site instance.

Check that your Elluminate server software is up-to-date (Elive has been tested
against Elluminate Live 9.0 and 9.1 only).

If the problem persists, the command entry may be missing from your site
configuration file. Please follow the instructions in the README file
for insrtuctions on detecting and repairing missing adapters.

=back

=head1 SCRIPTS

=head2 elive_query

elive_query is an example simple sql-like script. It is a basic program
for listing and retrieving entities. It serves as a simple demonstration
script, and can be used to confirm basic operation of Elive.

elive_query is simply passing where clauses, but through to the Elluminate
server as filters on SOAP calls.

For example, for the statement

    elive> select * from users where name like smith*

The equivalent Elive method call is:

    my $users = Elive::Entity::User->list(filter => 'name like smith*');

The exception is where clauses of the form C<pkey = val>, where C<pkey> is
the primary key for the entity table. e.g:

    elive> select * from meetingParticpants where meetingId = 1234567

The equivalent Elive method call for the above is

    my $participants =  Elive::Entity::MeetingParticpant->retrieve_all(1234567);

Also be careful to avoid selecting large amounts of data, e.g. all users.

=head2 elive_raise_meeting

This is a demonstration script to create a meeting, set options, assign
participants and upload meeting preloads (whiteboard and media files to be
used to used for the meeting.

For more information, type the command: elive_raise_meeting --help

=head2 elive_lint_config

A utility script that checks your Elluminate server configuration.

=head1 SEE ALSO

Perl Modules:

=over 4

=item Elive::Connection - SOAP/XML connection to Elluminate

=item Elive::Struct - base class for Elive::Entity

=item Elive::Entity - base class for all elive entities

=item Elive::Entity::Group

=item Elive::Entity::Meeting

=item Elive::Entity::MeetingParameters

=item Elive::Entity::ParticipantList

=item Elive::Entity::Preload

=item Elive::Entity::Recording

=item Elive::Entity::ServerDetails

=item Elive::Entity::ServerParameters

=item Elive::Entity::User

=back

Scripts:

=over 4

=item elive_query - simple interactive queries on Elive entities

=item elive_raise_meeting - sample script that create meetings via one-liners

=item elive_lint_config - sanity checker for  Elluminate site configurations

=back

Elluminate Live Documentation. This comes with your distribution

=over 4

=item ELM2.5_SDK.pdf

General Description of SDK's available for Elluminate Live. In particular
see section 4 - the SOAP/XML command toolkit.

=item DatabaseSchema.pdf

Elluminate Database Schema Documentation.

=item InstanceManager.pdf

Describes setting up multiple instances.

=back

=head1 AUTHOR

David Warring, C<< <david.warring at gmail.com> >>

=head1 BUGS AND LIMITATIONS

=over 4

=item Elive is a new module

I have so far run it against a limited number of Elluminate 9.0 and 9.1
installations.

So far it does not implement all SOAP/XML calls, but concentrates on users,
meetings and meeting participants.

=item Database Access

Elluminate SOAP/XML interface doesn't provide for locking or transactional
control. The Elluminate server installs with the Mckoi pure Java database
which supports JDBC access.

The Elluminate Live advanced configuration guide mentions that it can be
configured to use other databases that support a JDBC bridge (most databases
in widespread use do). However, it specifcally mentions SQL Server or Oracle. 

=item LDAP Authentication

Elluminate Live can also be configured to use an LDAP respository for
user authentication.  Users can still be retrieved or listed. However
updates and deletes are not supported by the LDAP DAO adapter. See also
Net::LDAP.

=back

=head1 SUPPORT

Please report any bugs or feature requests to C<bug-elive at rt.cpan.org>,
or through the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Elive>.
I will be notified, and then you'll automatically be notified of progress on
your bug as I make changes.

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

Thanks to Lex Lucas and Simon Haidley for their support and direction
during the construction of this module.

=head1 COPYRIGHT & LICENSE

Copyright 2009 David Warring, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1; # End of Elive
