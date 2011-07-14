package Elive;
use warnings; use strict;

=head1 NAME

Elive - Elluminate Live! (c) Command Toolkit bindings

=head1 VERSION

Version 0.99

=cut

our $VERSION = '0.99';

use 5.008003;

use parent qw{Class::Data::Inheritable};
use Scalar::Util;

use YAML;
use Carp;
use Try::Tiny;

=head1 EXAMPLE

The following (somewhat contrived) example sets up a meeting of selected
participants:

    use Elive;
    use Elive::Entity::User;
    use Elive::Entity::Preload;
    use Elive::View::Session;

    my $meeting_name = 'Meeting of the Smiths';

    Elive->connect('http://someEllumServer.com/test',
                   'serversupport', 'mypass');

    my $participants = Elive::Entity::User->list(filter => "(lastName = 'Smith')");
    die "smithless" unless @$participants;

    my $start = time() + 15 * 60; # starts in 15 minutes
    my $end   = $start + 30 * 60; # runs for half an hour

    # upload whiteboard content
    #
    my $preload = Elive::Entity::Preload->upload('welcome.wbd');

    my $meeting = Elive::View::Session->insert({
	 name           => $meeting_name,
	 facilitatorId  => Elive->login,
	 start          => $start . '000',
	 end            => $end   . '000',
         participants   => $participants,
         add_preload    => $preload,
	 });

    Elive->disconnect;

=head1 DESCRIPTION

Elive is a set of Perl bindings and entity definitions for the Elluminate
I<Live!> Command Toolkit; in particular, the entity commands.

These commands are available as a SOAP web service and can be used to automate
the raising, management and connection to meetings; and other related entities,
including users, groups, preloads and recordings.

=head1 BACKGROUND

Elluminate I<Live!> (c) is software for virtual online classrooms.

It is suitable for meetings, demonstrations web conferences, seminars
and IT deployment, training and support.

Most actions that can be performed via the web interface can also be
achieved via SOAP web services. This is known as the I<Command Toolkit> and
is detailed in chapter 4 of the Elluminate I<Live!> Software Developers
Kit (SDK).

Users, Meetings and other resources are stored in a management database.
These can be accessed and manipulated via the Entity Commands in the
Command Toolkit.

=cut

our $DEBUG;
BEGIN {
    $DEBUG = $ENV{ELIVE_DEBUG};
}

=head1 METHODS

=head2 connect

     my $e1 = Elive->connect('http://myServer.com/test1', 'user1', 'pass1');

     Elive->connect('http://myServer.com/test2', 'user2', 'pass2');
     my $e2 = Elive->connection;

Connects to an Elluminate server instance. Dies if the connection could not
be established. If, for example, the SOAP connection or user login failed.

The login user must either be an Elluminate I<Live!> system administrator
account, or a user that has been configured to access the Command Toolkit
via web services.

See also: The L<README> file; L<Elive::Connection::SDK>.

=cut

sub connect {
    my ($class, $url, $login_name, $pass, %opts) = @_;

    die "usage: ${class}->new(url, [login_name] [, pass])"
	unless ($class && $url);

    try {require Elive::Connection};
    catch { die $_};

    my $connection = Elive::Connection->connect(
	$url,
	$login_name,
	$pass,
	debug => $class->debug,
	%opts,
	);

    $class->connection($connection);

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
    my ($class, %opt) = @_;

    my $connection = $opt{connection} || $class->connection;

    die "not connected"
	unless $connection;

    return $connection->login;
}

=head2 server_details

Returns the server details for the default connection.

=cut

sub server_details {
    my ($class, %opt) = @_;

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
    my ($class, %opt) = @_;

    if (my $connection = $class->connection) {
	$connection->disconnect;
	$class->connection(undef);
    }

    return;
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
    my ($class, $level) = @_;

    if (defined $level) {
	$DEBUG = $level;
    }

    return $DEBUG || 0;
}

our %Meta_Data;

#
# create metadata properties. NB this will be stored inside out to
# ensure our object is an exact image of the data.
#

sub _refaddr {
    my $self = shift;
    return Scalar::Util::refaddr( $self );
}

=head2 has_metadata

Associate an inside-out property with objects of a given class.

=cut

sub has_metadata {

    my $class = shift;
    my $accessor = shift;

    my $accessor_fun = $class->can($accessor);

    unless ($accessor_fun) {

	no strict 'refs';

	$accessor_fun = sub {
	    my $self = shift;
	    my $ref = $self->_refaddr
		or return;

	    if (@_) {
		$Meta_Data{ $ref }{ $accessor } = $_[0];
	    }

	    return $Meta_Data{ $ref }{ $accessor };
	};

	*{$class.'::'.$accessor} = $accessor_fun;
    }

    return $accessor_fun;
}

sub DEMOLISH {
    my $self = shift;
    delete $Meta_Data{Scalar::Util::refaddr($self)};
    return;
}

=head1 ERROR MESSAGES

Elluminate Services Errors:

=over 4

=item   "Unable to determine a command for the key : Xxxx"

This may indicate that the particular command is is not available for your
site instance. Please follow the instructions in the README file for
detecting and repairing missing adapters.

=item   "User [<username>], not permitted to access the command {<command>]"

Please ensure that the user is a system administrator account and/or the
user has been configured to access commands via web services. See also the
L<README> file.

=back

=cut

=head1 SCRIPTS

=head2 elive_query

elive_query is an example simple sql-like script. It is a basic program
for listing and retrieving entities. It serves as a simple demonstration
script, and can be used to confirm basic operation of Elive.

It server a secondary function of querying entity metadata. For example,
to show the user entity:

    % elive_query
    Elive query 0.xx  - type 'help' for help

    elive> show
    usage: show group|meeting|meetingParameters|participantList|preload|recording|serverDetails|serverParameters|session|users

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

=head2 Modules in the Elive distribution

=over 4

=item L<Elive::Connection::SDK> - Elluminate SOAP connection

=item L<Elive::View::Session>

=item L<Elive::Entity::Group>

=item L<Elive::Entity::ParticipantList>

=item L<Elive::Entity::Preload>

=item L<Elive::Entity::Recording>

=item L<Elive::Entity::Report>

=item L<Elive::Entity::User>

=back

=head2 Scripts in the Elive Distribution

=over 4

=item L<elive_query> - simple interactive queries on Elive entities

=item L<elive_raise_meeting> - sample script that create meetings via one-liners

=item L<elive_lint_config> - sanity checker for Elluminate server configurations

=back

=head2 Related CPAN Modules

L<Elive::StandardV2> - This is a separate CPAN module that implements the alternate Elluminate I<Live!> Standard Bridge API (v2). 

=head2 Elluminate Documentation

The following is either installed with Elluminate I<Live!> Documentation, or
can be obtained from Elluminate.

=over 4

=item ELM2.5_SDK.pdf

General Description of SDK development for Elluminate I<Live!>. In particular
see section 4 - the SOAP Command Toolkit. This module concentrates on
implementing the Entity Commands described in section 4.1.8.

=item DatabaseSchema.pdf

Elluminate Database Schema Documentation.

=item InstanceManager.pdf

Describes setting up multiple site instances.

=back

=head1 AUTHOR

David Warring, C<< <david.warring at gmail.com> >>

=head1 BUGS AND LIMITATIONS

=over 4

=item (*) Elive does not support hosted (SAS) systems

The Elive distribution only supports the Elluminate SDK which is implemented
by ELM (Elluminate Live Manager) session manager. This SDK is not supported by
SAS (Session Administration System).

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

Thanks to Lex Lucas and Simon Haidley for their ongoing support and
assistance with the development of this module.

=head1 COPYRIGHT & LICENSE

Copyright 2009-2011 David Warring, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1; # End of Elive
