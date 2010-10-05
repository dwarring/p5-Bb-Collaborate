package Elive::API;
use warnings; use strict;

use Mouse;
use Mouse::Util::TypeConstraints;

use Elive '0.74_1';

extends 'Elive::DAO';

use Carp;

=head1 NAME

    Elive::API - Base class for the Elive Standard Bridge API (V2)

=head1 VERSION

Version 0.00_1

=cut

our $VERSION = '0.00_1';

=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    use Elive::API;

    my $foo = Elive::API->new();
    ...

=head1 DESCRIPTION

Implements Elive Standard Bridge V2 (API) API bindings

=cut

our %KnownAdapters = (

    buildSessionUrl => 'r',
    buildRecordingUrl => 'r',

    getSchedulingManager => 'r',
    getServerConfiguration => 'r',
    getServerVersions => 'r',
 
    listPresentationContent => 'r',
    listRecordingLong => 'r',
    listRecordingShort => 'r',
    listSession => 'r',
    listSessionAttendance => 'r',
    listSessionTelephony => 'r',

    removeSession => 'r',

    setSession => 'cu',
    setSessionMultimedia => 'u',
    setSessionTelephony => 'u',

    uploadMultimediaContent => 'c',
    uploadPresentationContent => 'c',

    );

__PACKAGE__->mk_classdata(known_adapters => \%KnownAdapters);

sub _get_results {
    my $class = shift;
    my $som = shift;
    my $connection = shift;

    $connection->_check_for_errors($som);

    my @result = ($som->result, $som->paramsout);

    return \@result;

}

=head1 SUBROUTINES/METHODS

=head1 METHODS

=head2 connect

     my $e1 = Elive::API->connect('http://myServer.com/test1', 'user1', 'pass1');

     Elive::API->connect('http://user2:pass2@myServer.com/test2');
     my $e2 = Elive::API->connection;

Connects to an Elluminate server instance. Dies if the connection could not
be established. If, for example, the SOAP connection or authentication failed.

See also Elive::Connection::API.

=cut

sub connect {
    my ($class, $url, $login_name, $pass, %opts) = @_;

    die "usage: ${class}->connect(url, [login_name], [pass])"
	unless ($class && $url);

    eval {require Elive::Connection::API};
    die $@ if $@;

    my $connection = Elive::Connection::API->connect(
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

     $e1 = Elive::API->connection
         or warn 'no elive connection active';

Returns the default Elive connection handle.

=cut

__PACKAGE__->mk_classdata('connection');

=head2 update

=cut

sub update {
    my ($class, $data, %opt) = @_;

    $opt{adapter} ||= 'set'.$class->entity_name;

    return $class->SUPER::update($data, %opt);
}

=head2 fetch

=cut

sub _fetch {
    my ($class, $key, %opt) = @_;

    $opt{adapter} ||= $class->check_adapter(
	['get'.$class->entity_name,
	 'list'.$class->entity_name],
	'r');				    

    return $class->SUPER::_fetch($key, %opt);
}

=head2 insert

=cut

sub insert {
    my ($class, $data, %opt) = @_;

    $opt{adapter} ||= 'set'.$class->entity_name;

    return $class->SUPER::insert($data, %opt);
}

=head2 list

Generic list method. Most adapters allow a ranging expression to narrow the
selection. This is passed in using the C<filter> option. For example:

    my $bobs_sessions = Elive::API::Session->list(filter => {userId => 'bob'});

=cut

sub list {
    my ($self, %opt) = @_;

    my $filter = delete $opt{filter};

    $opt{adapter} ||= $self->check_adapter('list'.$self->entity_name);

    return $self->_fetch( $self->_freeze($filter), %opt );
}

=head2 delete

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

    my $adapter = $opt{adapter} || 'remove'.$self->entity_name;
    $self->check_adapter($adapter);

    my $som = $self->connection->call($adapter,
				      @params);

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

Please report any bugs or feature requests to C<bug-elive-api at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Elive-API>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.



=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Elive::API


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Elive-API>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Elive-API>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Elive-API>

=item * Search CPAN

L<http://search.cpan.org/dist/Elive-API/>

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
