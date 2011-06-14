package Elive::View::Session::_ELM3;
use warnings; use strict;

use Mouse;
use Mouse::Util::TypeConstraints;

extends 'Elive::View::Session';

=head1 NAME

Elive::View::Session::_ELM3 - ELM 3.x Session insert/update support (EXPERIMENTAL)

=head1 DESCRIPTION

** EXPERIMENTAL ** and ** UNDER CONSTRUCTION **

This support class assists with the freezing and thawing of parameters for
the C<createSession> and C<updateSession> commands.

These commands were introduced with Elluminate 3.0, they more-or-less replace
a series of meeting setup commands including: C<createMeeting> C<updateMeeting>,
C<updateMeetingParameters>, C<updateServerParameters>, C<setParticipantList> and
others.

Some of the newer features and more advanced session setup can only be acheived
via these newer commands.

=cut

__PACKAGE__->entity_name('Session3');  # likely to change
__PACKAGE__->collection_name('Sessions3'); # also likely to change
has 'id' => (is => 'rw', isa => 'Int', required => 1);
__PACKAGE__->primary_key('id');

__PACKAGE__->_alias(reservedSeatCount => 'seats', freeze => 1);
__PACKAGE__->_alias(restrictParticipants => 'restrictedMeeting', freeze => 1);

## ELM 3.x mappings follow

=head2 invitedParticipantsList

=cut

sub invitedParticipantsList {
    my $self = shift;
    die 'tba - invitedParticipantsList';
}

=head2 invitedModerators

=cut

sub invitedModerators {
    my $self = shift;
    die 'tba - invitedModerators';
}

=head2 invitedGuests

=cut

sub invitedGuests {
    my $self = shift;
    die 'tba - invitedGuests';
}

__PACKAGE__->_alias(boundaryTime => 'boundaryMinutes', freeze => 1);

__PACKAGE__->_alias(supervisedMeeting => 'supervised', freeze => 1);

__PACKAGE__->_alias(allPermissionsMeeting => 'fullPermissions', freeze => 1);

# tba map this (showTeleconferencing vs enableTeleconferencing)
#__PACKAGE__->_alias(showTeleconferencing => '???', freeze => 1);
#                        documentation => 'Session has telephony information and telephony should be enabled.');

__PACKAGE__->_alias(sessionServerTeleconferenceType => 'telephonyType', freeze => 1);

__PACKAGE__->_alias(enableTeleconferencing => 'enableTelephony', freeze => 1);

__PACKAGE__->_alias(moderatorTeleconferenceAddress => 'moderatorTelephonyAddress', freeze => 1);


__PACKAGE__->_alias(moderatorTeleconferencePIN => 'moderatorTelephonyPIN', freeze => 1);

__PACKAGE__->_alias(participantTeleconferenceAddress => 'participantTelephonyAddress', freeze => 1);

__PACKAGE__->_alias(participantTeleconferencePIN => 'participantTelephonyPIN', freeze => 1);

__PACKAGE__->_alias(serverTeleconferenceAddress => 'serverTelephonyAddress', freeze => 1);

__PACKAGE__->_alias(serverTeleconferencePIN => 'serverTelephonyPIN', freeze => 1);

sub _alias {
    my ($entity_class, $from, $to, %opt) = @_;

    $from = lcfirst($from);
    $to = lcfirst($to);

    die 'usage: $entity_class->_alias(alias, prop, %opts)'
	unless ($entity_class

		&& $from && !ref($from)
		&& $to && !ref($to));

    my $aliases = $entity_class->_get_aliases;

    #
    # Set our entity name. Register it in our parent
    #
    die "$entity_class: attempted redefinition of alias: $from"
	if $aliases->{$from};

    die "$entity_class: can't alias $from it's already a property!"
	if $entity_class->property_types->{$from};

# get this test working
##    die "$entity_class: attempt to alias $from to non-existant property $to - check spelling and declaration order"
##	unless $entity_class->property_types->{$to};

    $opt{to} = $to;
    $aliases->{$from} = \%opt;

    return \%opt;
}

sub _freeze {
    my $self = shift;
    my $data = shift;

    my $delegates = $self->_delegates;

    my %frozen = map {
	$data->{$_}
	  ? %{ $delegates->{$_}->_freeze($data->{$_}, canonical => 1) }
	  : ()
    } (sort keys %$delegates);

    delete $frozen{meetingId};
    if (my $id = $data->{id}) {
	$frozen{id} = Elive::Util::_freeze( $id, 'Int' );
    }

    $self->__apply_freeze_aliases( \%frozen );

    # todo lots more tidying and construction

    return \%frozen;
}

1;
