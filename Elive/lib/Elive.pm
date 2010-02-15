package Elive;
use warnings; use strict;

=head1 NAME

Elive - Elluminate Live! (c) client library

=head1 VERSION

Version 0.62

=cut

our $VERSION = '0.62';

use Class::Data::Inheritable;
use base qw{Class::Data::Inheritable};

use YAML;

=head1 EXAMPLE

The following (somewhat contrived) example sets up a meeting of selected
participants:

    use Elive;
    use Elive::Entity::User;
    use Elive::Entity::Meeting;

    my $MeetingName = 'Meeting of the Smiths';

    Elive->connect('http://someEllumServer.com/test',
                   'serversupport', 'mypass');

    my $participants = Elive::Entity::User->list(filter => "(lastName = 'Smith')");
    die "smithless" unless @$participants;

    my $start = time() + 15 * 60; # starts in 15 minutes
    my $end   = $start + 30 * 60; # runs for half an hour

    my $meeting = Elive::Entity::Meeting->insert({
	 name           => $MeetingName,
	 facilitatorId  => Elive->login,
	 start          => $start . '000',
	 end            => $end   . '000',
	 });

    my $participant_list = $meeting->participant_list;
    $participant_list->participants($participants);
    $participant_list->update;

    Elive->disconnect;

=head1 DESCRIPTION

Elive is a set of Perl modules for the integration and automation of
Elluminate I<Live!> sites. In particular, it aids in the management of
users and meetings.

=head1 BACKGROUND

Elluminate I<Live!> (c) is is a web tool for virtual online classrooms.

It is suitable for online collaboration, demonstrations, meetings, web
conferences, seminars and IT deployment, training and support.

Users, Meetings and other resources are stored in a management database.
These can be accessed via the Elluminate I<Live!> SOAP API.

Most actions that can be performed via the web interface can also be
achieved via the SOAP API. This is known as the I<Command Toolkit> and
is detailed in chapter 4 of the Elluminate I<Live!> Software Developers
Kit.

This module provides Perl object to bindings to Elluminate I<Live!> entities
via the command toolkit.

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

Connects to an Elluminate server instance. Dies if the connection could not
be established. If, for example, the SOAP connection or user login failed.

The login user must be an Elluminate I<Live!> system administrator account.

See also Elive::Connection.

=cut

sub connect {

    my $class = shift;
    my ($url, $login_name, $pass) = @_;

    die "usage: ${class}->new(url, login_name[, pass])"
	unless ($class && $url && $login_name);

    eval "use Elive::Connection";
    die $@ if $@;

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

Returns the default Elive connection handle.

=cut

__PACKAGE__->mk_classdata('connection');

=head2 login

Returns the login user for the default connection.

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

Returns the server details for the default connection.

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

Disconnects the default Elluminate connection. It is recommended that you
do this prior to exiting your program.

=cut

sub disconnect {
    my $class = shift;
    my %opt = @_;

    if (my $connection = $opt{connection} || $class->connection) {
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
	$DEBUG = shift || 0;
    }

    return $DEBUG || 0;
}

our %KnownAdapters;

BEGIN {
    #
    # classify adaptors as create, read, update or delete
    #
    %KnownAdapters = (
	addGroupMember => 'c',
	addMeetingPreload => 'c',
	attendanceNotification => 'r',
	changePassword => 'u',
	buildMeetingJNLP => 'r',
	buildRecordingJNLP => 'r',
	checkMeetingPreload => 'r',
	createGroup => 'c',
	createMeeting => 'c',
	createPreload => 'c',
	createRecording => 'c',
	createUser => 'c',
	deleteGroup => 'd',
	deleteMeeting => 'd',
	deleteMeetingPreload => 'd',
	deleteParticipant => 'd',
	deleteRecording => 'd',
	deletePreload => 'd',
	deleteUser => 'd',
	getGroup => 'r',
	getMeeting => 'r',
	getMeetingParameters => 'r',
	getPreload => 'r',
	getPreloadStream => 'r',
	getRecording => 'r',
	getRecordingStream => 'r',
	getServerDetails => 'r',
	getServerParameters => 'r',
	getUser => 'r',
	importPreload => 'c',
	importRecording => 'c',
	isParticipant => 'r',
	listGroups => 'r',
	listMeetingPreloads => 'r',
	listMeetings => 'r',
	listParticipants => 'r',
	listPreloads => 'r',
	listRecordings => 'r',
	listUserMeetingsByDate => 'r',
	listUsers => 'r',
	resetGroup => 'u',
	resetParticipantList => 'u',
	setParticipantList => 'u',
	streamPreload => 'u',
	streamRecording => 'u',
	updateMeeting => 'u',
	updateMeetingParameters => 'u',
	updateRecording => 'u',
	updateServerParameters => 'u',
	updateUser => 'u',
	);
}

=head2 check_adapter

    Elive->check_adapter('getUser')

Asserts that the adapter is valid, i.e. it's in the list of known adapters.

See also: elive_lint_config.

=cut

sub check_adapter {
    my $class = shift;
    my $adapter = shift;
    my $crud = shift; #create, read, update or delete

    my $usage = "usage: \$class->check_adapter(\$name[,'c'|'r'|'u'|'d'])";
    die $usage unless $adapter;

    my %known_adapters = $class->known_adapters;

    die "Uknown adapter: $adapter"
	unless exists $known_adapters{$adapter};

    if ($crud) {
	$crud = lc(substr($crud,0,1));
	die $usage
	    unless $crud =~ m{^[c|r|u|d]$};

	my $adapter_type = $known_adapters{$adapter};
	die "misconfigured adapter: $adapter"
	    unless $adapter_type &&  $adapter_type  =~ m{^[c|r|u|d]$};

	die "adapter $adapter. Type mismatch. Expected $crud, found $adapter_type"
	    unless ($adapter_type eq $crud);
    }

    return $adapter;
}

=head2 known_adapters

Returns an array of all Elluminate I<Live!> adapters required by Elive.
This list is cross-checked by the script elive_lint_config. 

=cut

sub known_adapters {
    my $class = shift;
    return %KnownAdapters;
}

our %Meta_Data;
our %Meta_Data_Accessor;

=head2 has_metadata

Associate an inside-out property with objects of a given class.

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
    no strict 'refs';

    *{__PACKAGE__.'::DEMOLISH'} = \&DESTROY;
}

=head1 ERROR MESSAGES

Elluminate Services Errors:

=over 4

=item   "Unable to determine a command for the key : listXxxx"

This may indicate that the particular command adaptor is is not available for
your site instance.

Check that your Elluminate I<Live!> server software version; This module
has been tested against 9.0, 9.1 and 9.5.2

If the problem persists, the command entry may be missing from your site
configuration file. Please follow the instructions in the README file
for instructions on detecting and repairing missing adapters.

=back

=cut

sub _check_for_errors {
    my $class = shift;
    my $som = shift;

    die $som->fault->{ faultstring } if ($som->fault);

    my $result = $som->result;
    my @paramsout = $som->paramsout;

    warn "result: ".YAML::Dump($result, @paramsout)
	if ($class->debug);

    if (@paramsout >= 2 && !$paramsout[1]) {
	#
	# error format sometimes seen with elluminate 9.6+. Can occur
	# when request is malformed
	#
	die join(' ', $paramsout[0]);
    }
    elsif(!Elive::Util::_reftype($result)) {
	#
	# Simple scalar - we're done
	#
	return;
    }
    
    #
    # Look for Elluminate-specific errors
    #
    if (my $code = $result->{Code}{Value}) {

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
	die join(' ', @error) || YAML::Dump($result);
    }
}

=head1 SCRIPTS

=head2 elive_query

elive_query is an example simple sql-like script. It is a basic program
for listing and retrieving entities. It serves as a simple demonstration
script, and can be used to confirm basic operation of Elive.

It servers a secondary function of querying entity metadata. For example,
to show the user entity:

    $> elive_query
    Elive query 0.xx  - type 'help' for help

    elive> show
    usage: show group|meeting|meetingParameters|participantList|preload|recording|serverDetails|serverParameters|use

    elive> show meeting
    meeting: Elive::Entity::Meeting:
      meetingId          : pkey Int        
      allModerators      : Bool      -- all participants can moderate
      deleted            : Bool            
      end                : HiResDate -- meeting end time
      facilitatorId      : Str       -- userId of facilitator
      name               : Str       -- meeting name
      password           : Str       -- meeting password
      privateMeeting     : Bool      -- don't display meeting in public schedule
      restrictedMeeting  : Bool      -- Restricted meeting
      start              : HiResDate -- meeting start time

=head2 elive_raise_meeting

This is a demonstration script to create a meeting, set options, assign
participants and upload meeting preloads (whiteboard and media files to be
used to used for the meeting.

For more information, type the command: elive_raise_meeting --help

=head2 elive_lint_config

A utility script that checks your Elluminate server configuration. Please
see the README file.

=head1 SEE ALSO

Perl Modules:

=over 4

=item Elive::Connection - Elluminate SOAP connection

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

Elluminate I<Live!> Documentation. This comes with your distribution

=over 4

=item ELM2.5_SDK.pdf

General Description of SDK's available for Elluminate I<Live!>. In particular
see section 4 - the SOAP command toolkit.

=item DatabaseSchema.pdf

Elluminate Database Schema Documentation.

=item InstanceManager.pdf

Describes setting up multiple site instances.

=back

=head1 USAGE NOTES

=over 4

=item Database Access

The Elluminate I<Live!> advanced configuration guide mentions that it can be
configured to use other databases that support a JDBC bridge (most databases
in widespread use). It specifically mentions SQL Server or Oracle. MySQL
is supported with 9.5.0 

=item LDAP Authentication

Elluminate I<Live!> can also be configured to use an LDAP repository for
user authentication.  Users can still be retrieved or listed.

=over 4

=item * You can map both of the user's I<userId> and I<loginName> to the
LDAP I<uid> attribute.

=item * Updates and deletes are not supported by the LDAP DAO adapter.

=back

=back

=head1 AUTHOR

David Warring, C<< <david.warring at gmail.com> >>

=head1 BUGS AND LIMITATIONS

=over 4

=item Elive is a newish module

I have so far run it against a limited number of Elluminate 9.0, 9.1
and 9.5 installations.

So far it does not implement all SOAP calls, but concentrates on entities
such as users, meetings, preloads and meeting participants.

=item Elive does not support hosted (SAS) systems

The package currently supports only the installed server version of Elluminate
Live which uses the ELM management layer. It does not yet support the hosted
servers deployed with SAS (Session Administration System).

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

Thanks to Lex Lucas and Simon Haidley for their testing, support and
direction during the construction of this module.

=head1 COPYRIGHT & LICENSE

Copyright 2009 David Warring, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1; # End of Elive
