package Elive::StandardV3;
use warnings; use strict;

use Mouse;
use Mouse::Util::TypeConstraints;

use Elive::DAO '1.34';
extends 'Elive::DAO';

use Carp;

=head1 NAME

Elive::StandardV3 - Perl bindings for the Blackboard Collaborate Standard Bridge (V3)

=head1 VERSION

Version 0.01_7

=cut

our $VERSION = '0.01_7';

=head1 DESCRIPTION

Blackboard Collaborate is software for virtual online classrooms. It is
suitable for meetings, demonstrations web conferences, seminars, general
training and support.

Elive-StandardV3 is a set of Perl bindings and entity definitions for the
Collaborate V3 SOAP services, both on SAS (externally hosted) and ELM
(self hosted) servers.

=cut

use 5.008003;

=head1 EXAMPLE

    use Elive::StandardV3;
    use Elive::StandardV3::Session;
    use Elive::Util;

    my $connection = Elive::StandardV3->connect(
                                'http://myserver/mysite',
                                'some_user' => 'some_pass' );

    # Sessions must start and end on the quarter hour.

    my $session_start = Elive::Util::next_quarter_hour();
    my $session_end = Elive::Util::next_quarter_hour( $session_start );

    my %session_data = (
	sessionName   => 'My Demo Session',
	creatorId     => $connection->user,
	startTime     => $session_start . '000',
	endTime       => $session_end . '000',
	openChair     => 1,
	mustBeSupervised => 0,
	permissionsOn => 1,
        nonChairList  => [qw(alice bob)],
	groupingList  => [qw(mechanics sewing)],
    );

    my $session = Elive::StandardV3::Session->insert(\%session_data);

    my $url = $session->session_url( userId => 'bob', displayName => 'Robert');
    print "bob's session link is: $url\n";

=head1 DESCRIPTION

Implements Blackboard Collaborate Standard Bridge V3 API bindings

** DEVELOPER RELEASE - UNDER CONSTRUCTION **

=cut

=head1 METHODS

=head2 data_classes

returns a list of all implemented entity classes

=cut

sub data_classes {
    my $class = shift;
    return qw(
      Elive::StandardV3::Multimedia
      Elive::StandardV3::Presentation
      Elive::StandardV3::Recording
      Elive::StandardV3::SchedulingManager
      Elive::StandardV3::ServerConfiguration
      Elive::StandardV3::ServerVersion
      Elive::StandardV3::Session
      Elive::StandardV3::SessionAttendance
      Elive::StandardV3::SessionTelephony
   );
}

sub _get_results {
    my $class = shift;
    my $som = shift;
    my $connection = shift;

    $connection->_check_for_errors($som);

    my @result = ($som->result, $som->paramsout);

    return \@result;

}

=head2 connect

     use Elive::StandardV3;
     use Elive::StandardV3::Connection;

     #
     # Setup the default connection
     Elive::StandardV3->connect('http://myServer.com/test1', 'user1', 'pass1');
     my $c1 = Elive::StandardV3->connection;
     #
     # Setup a secondary connection
     my $c2 = Elive::StandardV3::Connection->connect('http://user2:pass2@myServer.com/test2');

Connects to a server instance. Dies if the connection could not be established. If, for example,
the SOAP connection or authentication failed.

See also Elive::StandardV3::Connection.

=cut

sub connect {
    my ($class, $url, $login_name, $pass, %opts) = @_;

    die "usage: ${class}->connect(url, [login_name], [pass])"
	unless ($class && $url);

    require Elive::StandardV3::Connection;

    my $connection = Elive::StandardV3::Connection->connect(
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

     $e1 = Elive::StandardV3->connection
         or warn 'no elive connection active';

Returns the default Elive connection handle.

=cut

=head2 update

Abstract method to commit outstanding object updates to the server.

    $obj->{foo} = 'Foo';  # change foo attribute directly
    $foo->update;         # save

    $obj->bar('Bar');     # change bar via its accessor
    $obj->update;         # save

Updates may also be passed as parameters.

   # change and save foo and bar. All in one go.
    $obj->update({foo => 'Foo', bar => 'Bar'});

=cut

sub update {
    my ($class, $data, %opt) = @_;

    $opt{command} ||= 'Set'.$class->entity_name;

    return $class->SUPER::update($data, %opt);
}

sub _fetch {
    my ($class, $key, %opt) = @_;

    #
    # Let the connection resolve which command to use
    #

    $opt{command} ||=
	['Get'.$class->entity_name,
	 'List'.$class->entity_name];

    return $class->SUPER::_fetch($key, %opt);
}

=head2 insert

Abstract method to create new entity instances on the server:

    my $multimedia = Elive::StandardV3::Multimedia->insert(
             {
                    filename => 'demo.wav',
                    creatorId =>  'bob',
                    content => $content,
	     },
         );

=cut

sub insert {
    my ($class, $data, %opt) = @_;

    $opt{command} ||= 'Set'.$class->entity_name;
    #
    # allow for recurring sessions
    #
    my @sessions =  $class->SUPER::insert($data, %opt);

    return wantarray? @sessions : $sessions[0];
}

=head2 list

Abstract selection method. Most commands allow a ranging expression to narrow
the selection. This is passed in using the C<filter> option. For example:

    my $bobs_sessions = Elive::StandardV3::Session->list( filter => {userId => 'bob'});

=cut

sub list {
    my $self = shift;

    unshift @_, 'filter' if @_ % 2;
    my %opt = @_;

    my $filter = delete $opt{filter};

    $filter = $self->_parse_filter($filter)
	unless Scalar::Util::reftype $filter;

    $opt{command} ||= 'List'.$self->entity_name;

    return $self->_fetch( $filter, %opt );
}

#
# rudimentry parse of expressions of the form:
# <field1> = <val1> and <field2> = <val2>
# A bit of a hack, largely for the benefit of elive_query
#

sub _parse_filter {
    my ($self, $expr) = @_;
    my %selection;

    return unless defined $expr;

    foreach ( split(qr{ \s+ and \s+}ix, $expr) ) {
	my ($field, $op, $val) = m{^ \s* (\w+) \s* ([\!=<>]+) \s* (.*?) \s* $}x;

	unless (defined($val) && length($val) && $op eq '=') {
	    carp "selection expression '$_' not in format <field> = <val>";
	    next;
	}

	$selection{$field} = $val;
    }

    return \%selection;
}

=head2 delete

Abstract method to delete entities:

    $multimedia->delete;

=cut

sub delete {
    my ($self, %opt) = @_;

    my @primary_key = $self->primary_key;
    my @id = $self->id;

    die "entity lacks a primary key - can't delete"
	unless (@primary_key > 0);

    my @params = map {
	$_ => shift( @id );
    } @primary_key;

    my $command = $opt{command} || 'Remove'.$self->entity_name;

    my $som = $self->connection->call($command, @params);

    my $results = $self->_get_results( $som, $self->connection );

    my $success = @$results && $results->[0];

    return $self->_deleted(1)
	if $success;

    carp "deletion failed(?) with 'false' status";
    return;
}


=head1 SEE ALSO

L<Elive::StandardV3::Connection>
L<Elive::StandardV3::Multimedia>
L<Elive::StandardV3::Session>
L<Elive::StandardV3::SessionAttendance>
L<Elive::StandardV3::SessionTelephony>
L<Elive::StandardV3::Presentation>
L<Elive::StandardV3::SchedulingManager>
L<Elive::StandardV3::ServerConfiguration>
L<Elive::StandardV3::ServerVersion>
L<Elive::StandardV3::Recording>

=head1 AUTHOR

David Warring, C<< <david.warring at gmail.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-elive-StandardV3 at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Elive-StandardV3>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Elive::StandardV3


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Elive-StandardV3>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Elive-StandardV3>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Elive-StandardV3>

=item * Search CPAN

L<http://search.cpan.org/dist/Elive-StandardV3/>

=back

=head1 SEE ALSO

I<Standard Integration API Guide V3 for ELM.pdf> - this contains essential
background information and a full description of the available commands.

=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2012-2015 David Warring.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1;
