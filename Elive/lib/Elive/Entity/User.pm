package Elive::Entity::User;
use warnings; use strict;

use Mouse;
use Mouse::Util::TypeConstraints;

extends 'Elive::Entity';

use Elive::Entity::Role;
use Elive::Util;

__PACKAGE__->entity_name('User');
__PACKAGE__->collection_name('Users');

has 'userId' => (is => 'rw', isa => 'Str', required => 1,
		 documentation => 'user identifier (numeric, unless LDAP configured)');
__PACKAGE__->primary_key('userId');
__PACKAGE__->params(userName => 'Str');

has 'deleted' => (is => 'rw', isa => 'Bool');

has 'loginPassword' => (is => 'rw', isa => 'Str');

has 'loginName' => (is => 'rw', isa => 'Str',
		    documentation => 'login name - must be unique');
__PACKAGE__->_alias(userName => 'loginName');
		    
has 'email' => (is => 'rw', isa => 'Str',
		documentation => 'users email address');

has 'role' => (is => 'rw', isa => 'Elive::Entity::Role',
	       documentation => 'default user role',
	       coerce => 1);

has 'firstName' => (is => 'rw', isa => 'Str', 
		    documentation => 'users given name');

has 'lastName' => (is => 'rw', isa => 'Str',
		   documentation => 'users surname');

#
# 'groups' and 'domain' propreties made a brief appearence in Elm 9.5.0
# but haven't survived to 9.5.2. Will cull these shortly.
#

has 'groups' => (is => 'rw', isa => 'Str',
		documentation => 'ldap groups?');

has 'domain' => (is => 'rw', isa => 'Str',
		 documentation => 'ldap domain?');

coerce 'Elive::Entity::User' => from 'HashRef'
          => via {Elive::Entity::User->construct($_,
						 %Elive::_construct_opts) };

coerce 'Elive::Entity::User' => from 'Str'
          => via {Elive::Entity::User->construct({userId => $_}, 
						 %Elive::_construct_opts) };

=head1 NAME

Elive::Entity::User - Elluminate Users entity class

=cut

=head1 DESCRIPTION

These are used to query and maintain information on regisisted Elluminate I<Live!> users.

If the site is configured for LDAP, users are mapped to LDAP. Access becomes readonly, and
the C<create()>, C<update>, C<update_password> and C<delete> methods are no longer applicable.

=cut

=head1 METHODS

=cut

sub _readback_check {
    my ($class, $update_ref, $rows, @args) = @_;

    my %updates = %$update_ref;

    #
    # password not included in readback record - skip it
    #

    delete $updates{loginPassword};

    return $class->SUPER::_readback_check(\%updates, $rows, @args, case_insensitive => 1);
}

=head2 get_by_loginName

    my $user = Elive::Entity::User->get_by_loginName('joebloggs');

Retrieve on loginName, which is a co-key for the users table.

Please note that the Elluminate Web Services raise an error if the user
was not found. So, if you're not sure if the user exists:

    my $user = eval {Elive::Entity::User->get_by_loginName('joebloggs')};

=cut

sub get_by_loginName {
    my ($class, $loginName, @args) = @_;
    #
    # The entity name is loginName, but the fetch key is userName.
    #
    my $results = $class->_fetch({userName => $loginName},
				 @args,
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
    my ($class, $data_href, %opt) = @_;

    my $self = $class->SUPER::insert( $data_href, %opt );

    #
    # seems we have to insert a record, then set the password
    #
    my $password = $data_href->{loginPassword};
    if (defined $password and $password ne '') {
	$self->change_password($password);
    }

    return $self;
}

=head2 update

    my $user_obj = Elive::Entity::user->retrieve([$user_id]);

    $user_obj->update({fld => new_val,...}, force => 1);

    $user_obj->update(role => {roleId => 1}); # make the user an app admin
    $user_obj->lastName('Smith');
    $user_obj->update(undef, force => 1);

Update an Elluminate user. Everything can be changed, other than userId.
This includes the loginName. However loginNames must all remain unique.

As a safeguard, you'll need to pass C<force =E<gt> 1> to update:
    (a) users with a Role Id of 0, i.e. system administrator accounts, or
    (b) the login user

=cut

sub update {
    my ($self, $data_href, %opt) = @_;
    my %update_data = %{$data_href || {}};

    unless ($opt{force}) {
	die "Cowardly refusing to update system admin account for ".$self->loginName.": (pass force => 1 to override)"
	    if ($self->role->stringify <= 0);
    }

    $self->set( %update_data)
	if (keys %update_data);
    
    #
    # A password change requires special handling
    #
    my @changed = $self->is_changed;
    my @changed1  = grep {$_ ne 'loginPassword'} @changed;
    my $password_changed = @changed != @changed1;
    my $password = delete $self->{loginPassword};

    my $ret = $self->SUPER::update( undef, %opt, changed => \@changed1 );

    $self->change_password($password)
	if $password_changed;

    return $ret;
}

=head2 change_password

Implements the C<changePassword> SDK method.

    my $user = Elive::Entity::User->retrieve([$user_id]);
    $user->change_password($new_password);

This is equivalent to:

    my $user = Elive::Entity::User->retrieve([$user_id]);
    $user->update({loginPassword => $new_password});    

=cut

sub change_password {
    my ($self, $new_password, %opt) = @_;

    $self->SUPER::update({loginPassword => $new_password},
			 adapter => 'changePassword',
			 %opt,
	)
	if (defined $new_password && $new_password ne '');

    return $self;
}

=head2 delete

    $user_obj->delete();
    $admin_user_obj->delete(force => 1);

Delete user objects. As a safeguard, you need to pass C<force =E<gt> 1> to delete
system administrator accounts, or the login user.

=cut

sub delete {
    my ($self, %opt) = @_;

    unless ($opt{force}) {
	die "Cowardly refusing to delete system admin account for ".$self->loginName.": (pass force => 1 to override)"
	    if (Elive::Util::string($self->role) == 0);

	my $connection = $self->connection;

	my $login = $connection->login;
	die "Not loggged in" unless $login;
	#
	# Less cowardly, methinks!
	#
	die "Refusing to delete the login user ".$login->loginName.": (pass force => 1 to override)"
	    if $login->userId eq $self->userId;   
    }

    return $self->SUPER::delete( %opt );
}

=head1 RESTRICTIONS

Elluminate I<Live!> can be configured to use LDAP for user management and
authentication.

If LDAP is in use, the fetch and retrieve methods will continue to operate
via the Elluminate SOAP command layer. However use access becomes read-only.
The affected methods are: insert, update, delete and change_password.

=cut

1;
