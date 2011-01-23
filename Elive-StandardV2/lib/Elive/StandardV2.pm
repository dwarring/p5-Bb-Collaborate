package Elive::StandardV2;
use warnings; use strict;

use Mouse;
use Mouse::Util::TypeConstraints;

use Elive '0.76';

extends 'Elive::DAO';

use Carp;

=head1 NAME

Elive::StandardV2 - Perl bindings for the Elluminate Live Standard Bridge (V2)

=head1 VERSION

Version 0.00_3

** DEVELOPER RELEASE - UNDER CONSTRUCTION **


=cut

our $VERSION = '0.00_3';

=head1 SYNOPSIS

** DEVELOPER RELEASE - UNDER CONSTRUCTION **

=head1 DESCRIPTION

Implements Elluminate C<Live!> Standard Bridge V2 API bindings

** DEVELOPER RELEASE - UNDER CONSTRUCTION **

=cut

=head1 METHODS

=head2 data_classes

returns a list of all implemented entity classes

=cut

sub data_classes {
    my $class = shift;
    return qw(
      Elive::StandardV2::Multimedia
      Elive::StandardV2::Presentation
      Elive::StandardV2::Recording
      Elive::StandardV2::SchedulingManager
      Elive::StandardV2::ServerConfiguration
      Elive::StandardV2::ServerVersions
      Elive::StandardV2::Session
      Elive::StandardV2::SessionAttendance
      Elive::StandardV2::SessionTelephony
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

     my $e1 = Elive::StandardV2->connect('http://myServer.com/test1', 'user1', 'pass1');

     Elive::StandardV2->connect('http://user2:pass2@myServer.com/test2');
     my $e2 = Elive::StandardV2->connection;

Connects to an Elluminate server instance. Dies if the connection could not
be established. If, for example, the SOAP connection or authentication failed.

See also Elive::StandardV2::Connection.

=cut

sub connect {
    my ($class, $url, $login_name, $pass, %opts) = @_;

    die "usage: ${class}->connect(url, [login_name], [pass])"
	unless ($class && $url);

    eval {require Elive::StandardV2::Connection};
    die $@ if $@;

    my $connection = Elive::StandardV2::Connection->connect(
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

     $e1 = Elive::StandardV2->connection
         or warn 'no elive connection active';

Returns the default Elive connection handle.

=cut

__PACKAGE__->mk_classdata('connection');

=head2 update

Abstract method to commit outstanding object updates to the server.

    $obj->{foo} = 'Foo';  # change foo attribute directly
    $foo->update;         # save

    $obj->bar('Bar');     # change bar via its accessor
    $obj->update;         # save

Updates may also be passed as parameters.

   # change and save foo and bar. All in one go.
    $obj->update({foo => 'Foo', bar => 'Bar'},
                 command => $cmd,      # soap command to use
                 params => \%params,   # additional soap params,
                 changed => \@props,   # properties to update,
                );

=cut

sub update {
    my ($class, $data, %opt) = @_;

    $opt{command} ||= 'set'.$class->entity_name;

    return $class->SUPER::update($data, %opt);
}

=head2 fetch

=cut

sub _fetch {
    my ($class, $key, %opt) = @_;

    #
    # Let the connection resolve which command to use
    #

    $opt{command} ||=
	['get'.$class->entity_name,
	 'list'.$class->entity_name];

    return $class->SUPER::_fetch($key, %opt);
}

=head2 insert

Abstract method to create new entity instances on the server:

    my $multimedia = Elive::StandardV2::Multimedia->insert(
             {
                    filename => 'demo.wav',
                    creatorId =>  'bob',
                    content => $content,
	     },
         );

=cut

sub insert {
    my ($class, $data, %opt) = @_;

    $opt{command} ||= 'set'.$class->entity_name;

    return $class->SUPER::insert($data, %opt);
}

=head2 list

Abstract list method. Most commands allow a ranging expression to narrow the
selection. This is passed in using the C<filter> option. For example:

    my $bobs_sessions = Elive::StandardV2::Session->list(filter => {userId => 'bob'});

=cut

sub list {
    my ($self, %opt) = @_;

    my $filter = delete $opt{filter} || {};

    $filter = $self->_parse_filter($filter)
	unless Scalar::Util::reftype $filter;

    $opt{command} ||= 'list'.$self->entity_name;

    return $self->_fetch( $filter, %opt );
}

#
# rudimentry parse of expressions of the form:
# <field1> = <val1> and <field2> = <val2>
# A bit of a hack, largely for the benefit of elive_query
#

sub _parse_filter {
    my ($self, $expr) = @_;
    my (%critera) = map {
	my ($field, $val) = m{^ \s* (\w+) \s* [\!=<>]+ (.*?) $}x;
	carp "selection not in format <field> = <val>"
	    unless length($val);
	$field => $val;
    } split(qr{ \s+ and \s+}ix, $expr);

    return \%critera;
}

=head2 delete

Abstract method to delete entities from the server:

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

    my $command = $opt{command} || 'remove'.$self->entity_name;

    my $som = $self->connection->call($command, @params);

    my $results = $self->_get_results(
	$som,
	$self->connection,
	);

    my $success = @$results && $results->[0];
    return $self->_deleted(1)
	if $success;

    carp "deletion failed(?) with 'false' status";
}

=head1 AUTHOR

David Warring, C<< <david.warring at gmail.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-elive-standardv2 at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Elive-StandardV2>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.



=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Elive::StandardV2


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Elive-StandardV2>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Elive-StandardV2>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Elive-StandardV2>

=item * Search CPAN

L<http://search.cpan.org/dist/Elive-StandardV2/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2010 David Warring.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1;
