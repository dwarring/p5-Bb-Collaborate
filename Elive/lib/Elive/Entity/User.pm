package Elive::Entity::User;
use warnings; use strict;

use Mouse;
use Mouse::Util::TypeConstraints;

use Elive::Entity;
use base qw{ Elive::Entity };

use Elive::Entity::Role;

__PACKAGE__->entity_name('User');
__PACKAGE__->collection_name('Users');

has 'userId' => (is => 'rw', isa => 'Str|Int', required => 1,
		 documentation => 'user identifier (usually numeric)');
__PACKAGE__->primary_key('userId');

has 'deleted' => (is => 'rw', isa => 'Bool');

has 'loginPassword' => (is => 'rw', isa => 'Str');

has 'loginName' => (is => 'rw', isa => 'Str',
		    documentation => 'login name - must be unique');
		    
has 'email' => (is => 'rw', isa => 'Str',
		documentation => 'users email address');

has 'role' => (is => 'rw', isa => 'Elive::Entity::Role',
	       documentation => 'default user role',
	       coerce => 1);

has 'firstName' => (is => 'rw', isa => 'Str', 
		    documentation => 'users given name');

has 'lastName' => (is => 'rw', isa => 'Str',
		   documentation => 'users surname');


coerce 'Elive::Entity::User' => from 'HashRef'
          => via {Elive::Entity::User->construct($_,
						 %Elive::_construct_opts) };

coerce 'Elive::Entity::User' => from 'Str'
          => via {Elive::Entity::User->construct({userId => $_}, 
						 %Elive::_construct_opts) };

=head1 NAME

    Elive::Entity::User - Elluminate Users entity class

=cut

=head1 METHODS

=cut

sub _readback_check {
    my $class = shift;
    my %updates = %{shift()};

    #
    # password not included in readback record - skip it
    #

    delete $updates{loginPassword};

    $class->SUPER::_readback_check(\%updates, @_);
}

=head2 get_by_loginName

    my $user = Elive::Entity::User->retrieve_loginName('joebloggs');

Retrieve on loginName, which is a co-key for the users table.

=cut

sub get_by_loginName {
    my $class = shift;
    my $loginName = shift;
    #
    # The entity name is loginName, but the fetch key is userName.
    #
    my $results = $class->_fetch({userName => $loginName},
				 readback => {loginName => $loginName},
				 @_,
	);

    return @$results && $results->[0];
}

=head2 insert

    my $new _user = Elive::Entity::User->insert({
	      loginName => ...,
	      loginPassword => ...,
	      firstName => ...,
	      lastName => ...,
	      email => ...,
	      role => {roleId => 0|1|2|3},
	    )};

Insert a new user

=cut

sub insert {
    my $class = shift;
    my %data = %{shift()};
    my %opt = @_;

    my $self = $class->SUPER::insert( \%data, %opt );

    #
    # seems we have to insert a record, then set the password
    #
    my $password = $data{loginPassword};
    if (defined $password and $password ne '') {
	$self->change_password($password);
    }

    return $self;
}

=head2 update

    my $user_obj = Elive::Entity::user->retrieve($user_id);

    $user_obj->update({fld => new_val,...},[force => 1]);

    $user_obj->update(role => {roleId => 1}); # make the user an app admin
    $user_obj->lastName('Smith');
    $user_obj->update(undef,[force => 1]);

Update an Elluminate user. Everything can be changed, other than userId.
This includes the loginName. However loginNames must all remain unique.

As a safeguard, you need to pass force => 1 to update
system administrator accounts

=cut

sub update {
    my $self = shift;
    my %data = %{shift() || {}};
    my %opt = @_;

    unless ($opt{force}) {
	die "Cowardly refusing to update system admin account: (pass force => 1 to override)"
	    if ($self->role->stringify <= 0);
    }

    my $password = $data{loginPassword};

    my $ret = $self->SUPER::update( \%data, %opt );

    #
    # seems we have to insert a record, then set the password
    #
    if (defined $password and $password ne '') {
	$self->change_password($password);
    }

    return $ret;
}

=head2 change_password 

    my $user = Elive::Entity::User->retrieve($user_id);
    my $new_password = Elive::Util::prompt('Password: ', password => 1);
    $user->change_password($new_password);

=cut

sub change_password {
    my $self = shift;
    my $new_password = shift;
    my %opt = @_;

    $self->SUPER::update({loginPassword => $new_password},
			 adapter => 'ChangePasswordCommand',
			 %opt,
	)
	if (defined $new_password && $new_password ne '');
    #
    # Revert to the readback copy. This does not contain a copy of
    # the password. 
    #
    $self->revert;

    return $self;
}

=head2 delete

    $user_obj->delete([force => 1]);

Delete user objects. As a safeguard, you need to pass force => 1 to update
system administrator accounts

=cut

sub delete {
    my $self = shift;
    my %opt = @_;

    unless ($opt{force}) {
	die "Cowardly refusing to deleted system admin account: (pass force => 1 to override)"
	    if ($self->role <= 0);
    }

    return $self->SUPER::delete( %opt );
}

=head1 RESTRICTIONS

An Elluminate server can be configured to use LDAP for user authentication.

If LDAP has been enabled for a server the fetch and retrieve methods will
continue to operate via the Elluminate SOAP/XML layer. However updates are
not currently supported by either Elluminate or Elive. The affected methods
are: insert, update, delete and change_password.

=cut

1;
