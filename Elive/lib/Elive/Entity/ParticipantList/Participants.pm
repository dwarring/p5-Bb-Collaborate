package Elive::Entity::ParticipantList::Participants;
use warnings; use strict;

use Mouse;
use Mouse::Util::TypeConstraints;

extends 'Elive::Array';

use Elive::Entity::ParticipantList::Participant;
use Elive::Util;

__PACKAGE__->element_class('Elive::Entity::ParticipantList::Participant');
__PACKAGE__->mk_classdata('separator' => ';');

=head1 NAME

Elive::Entity::ParticipantList::Participants - A list of participants

=cut

=head1 METHODS

=cut

sub _build_array {
    my $class = shift;
    my $spec = shift;

    my $type = Elive::Util::_reftype( $spec );
    $spec = [$spec] if ($type && $type ne 'ARRAY');

    my @participants;

    if ($type) {
	@participants = @$spec;
    }
    elsif (defined $spec) {
	@participants = split(__PACKAGE__->separator, Elive::Util::string($spec));
    }

    my @args = map {Scalar::Util::blessed($_)
			  ? $_ 
			  : Elive::Entity::ParticipantList::Participant->new($_)
		 } @participants;

    return \@args;
}

=head2 add 

    $participants->add('alice=2', 'bob');

Add additional participants

=cut

sub add {
    my ($self, @elems) = @_;

    my $participants = $self->_build_array( \@elems );

    return $self->SUPER::add( @$participants );
}

our $class = __PACKAGE__;
coerce $class => from 'ArrayRef|Str'
          => via {$class->new($_);};

sub _group_by_type {
    my $self = shift;

    my @raw_participants = @{ $self || [] };

    my %users;
    my %groups;
    my %guests;

    foreach (@raw_participants) {
	my $participant = Elive::Entity::ParticipantList::Participant->BUILDARGS($_);
	my $id;
	my $roleId = Elive::Entity::Role->stringify( $participant->{role} )
	    || 3;

	if (! $participant->{type} ) {
	    $id = Elive::Entity::User->stringify( $participant->{user} );
	    $users{ $id } = $roleId;
	}
	elsif ($participant->{type} == 1) {
	    $id = Elive::Entity::Group->stringify( $participant->{group} );
	    $groups{ $id } = $roleId;
	}
	elsif ($participant->{type} == 2) {
	    $id = Elive::Entity::InvitedGuest->stringify( $participant->{guest} );
	    $guests{ $id } = $roleId;
	}
	else {
	    carp("unknown type: $participant->{type} in participant list: ".$self->id);
	}
    }

    return (\%users, \%groups, \%guests);
}

=head2 tidied

    my $untidy = 'trev;bob=3;bob=2'
    my $participants = Elive::Entity::Participants->new($untidy);
    # outputs: alice=2;bob=3;trev=3
    print $participants->tidy;

Produces a tidied list of participants. These are sorted with duplicates
removed (highest role is retained).

The C<facilitatorId> option can be used to ensure that the meeting facilitator
is included and has a moderator role.
     
=cut

sub tidied {
    my $self = shift;

    my ($_users, $_groups, $_guests) = $self->_group_by_type;

    # weed out duplicates as we go
    my %roles = (%$_users, %$_groups, %$_guests);

    if (wantarray) {

	# elm3.x compat

	my %guests;
	my %moderators;
	my %participants;

	foreach (sort keys %roles) {

	    my $role = $roles{$_};

	    if (exists $_guests->{$_} ) {
		$guests{$_} = $role;
	    }
	    elsif ($role <= 2) {
		$moderators{$_} = $role;
	    }
	    else {
		$participants{$_} = $role;
	    }
	}

	return (Elive::Array->stringify([ keys %guests]),
		Elive::Array->stringify([ keys %moderators]),
		Elive::Array->stringify([ keys %participants])
	    )
    }
    else {
	# elm2.x compat
       return $self->stringify([ map { $_.'='.$roles{$_} } sort keys %roles ]);
    }
}

1;
