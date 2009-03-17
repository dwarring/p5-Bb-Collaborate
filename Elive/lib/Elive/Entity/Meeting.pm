package Elive::Entity::Meeting;
use warnings; use strict;

use base qw{ Elive::Entity };
use Moose;

=head1 NAME

Elive::Entity::Meeting - Elluminate Meeting instance class

=head2 DESCRIPTION

=head2 BUGS & LIMITATIONS

Seems that privateMeeting gets ignored on Ellluminate Live 9 & 9.1. If you
try to set it the readback check may fail.

=cut

__PACKAGE__->entity_name('Meeting');
__PACKAGE__->collection_name('Meetings');

has 'meetingId' => (is => 'rw', isa => 'Pkey', required => 1);

has 'password' => (is => 'rw', isa => 'Str',
		   documentation => 'optional meeting password');

has 'deleted' => (is => 'rw', isa => 'Bool');

has 'facilitatorId' => (is => 'rw', isa => 'Int',
			documentation => 'userId of facilator');

has 'start' => (is => 'rw', isa => 'Int', required => 1,
		documentation => 'meeting start time (hires)');

has 'privateMeeting' => (is => 'rw', isa => 'Bool');

has 'end' => (is => 'rw', isa => 'Int', required => 1,
	      documentation => 'meeting end time (hires)');

has 'name' => (is => 'rw', isa => 'Str', required => 1,
	       documentation => 'meeting name',
    );

=head2 list_user_meetings_by_date

=head3 synopsis

   $meetings_array_ref
           =  Elive::Entity::Meeting->list_user_meetings_by_date(
                         [$user_obj_or_id,
                          $hires_start_date,
                          $hires_end_date]
                      );

=head3 example

   my $now = DateTime->now;
   my $next_week = $now->clone->add(days => 7);

   my $meetings = Elive::Entity::Meeting->list_user_meetings_by_date(
    [$user_id, $now->epoch * 1000, $next_week->epoch * 1000]
  )

=head3 description

Lists all meetings for which this user is a participant.

Implements the ListUserMeetingsByDateCommand SDK method.

=cut

sub list_user_meetings_by_date {
    my $class = shift;
    my $params = shift;
    my %opt = @_;

    die 'usage: $class->user_meetings_by_date([$user, $start_date, $end_date])'
	unless (Elive::Util::_reftype($params) eq 'ARRAY'
		&& $params->[0] && @$params <= 3);

    my %fetch;
    @fetch{qw{userId startDate endDate}} = @_; 

    return $class->_fetch(\%fetch,
			  adapter => 'listUserMeetingsByDateCommand',
			  %opt,
	);
}
    

sub _freeze {
    my $class = shift;
    my $data = shift;
    #
    # Meetings are stored as 'facilitor'
    #
    my $frozen = $class->SUPER::_freeze($data, @_);

    if (my $facilitatorId = delete $frozen->{facilitatorId}) {
	$frozen->{facilitator} =  $facilitatorId;
    }

    return $frozen;
}

sub _readback_check {
    my $class = shift;
    my %updates = %{shift()};

    #
    # password not included in readback record - skip it
    #

    delete $updates{password};

    $class->SUPER::_readback_check(\%updates, @_);
}

sub _thaw {
    my $class = shift;
    my $db_data = shift;
    my $data = $class->SUPER::_thaw($db_data, @_);

    if ($data->{Adapter}) {
	#
	# meeting giving us unexpected Adapter property. Turf it
	#

	if ($class->debug) {
	    print STDERR "Stray meeting adaptor found:\n";
	    print STDERR YAML::Dump($data->{Adapter});
	    print STDERR "\n";
	}
	
	delete $data->{Adapter};
    }

    return $data;
}

1;
