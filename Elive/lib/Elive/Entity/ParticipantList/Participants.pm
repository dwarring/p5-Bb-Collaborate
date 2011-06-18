package Elive::Entity::ParticipantList::Participants;
use warnings; use strict;

use Mouse;
use Mouse::Util::TypeConstraints;

extends 'Elive::Array';

use Elive::Entity::ParticipantList::Participant;
use Elive::Util;

__PACKAGE__->element_class('Elive::Entity::ParticipantList::Participant');

=head1 NAME

Elive::Entity::ParticipantList::Participants - A list of participants

=cut

=head1 METHODS

=cut

sub _build_array {
    my $class = shift;
    my $spec = shift;

    my $type = Elive::Util::_reftype( $spec );

    my @participants;

    if ($type eq 'ARRAY') {
	@participants = @$spec;
    }
    else {
	@participants = split(__PACKAGE__->separator, Elive::Util::string($spec));
    }

    my @args = map {Scalar::Util::blessed($_)
			  ? $_ 
			  : Elive::Entity::ParticipantList::Participant->new($_)
		 } @participants;

    return \@args;
}

=head2 add 

    $participants->add('111111', '222222');

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

sub _collate {
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


1;
