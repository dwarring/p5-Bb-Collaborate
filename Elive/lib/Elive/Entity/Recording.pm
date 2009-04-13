package Elive::Entity::Recording;
use warnings; use strict;
use Mouse;

use Elive::Entity;
use base qw{ Elive::Entity };

__PACKAGE__->entity_name('Recording');
__PACKAGE__->collection_name('Recordings');

has 'recordingId' => (is => 'rw', isa => 'Str', required => 1);
__PACKAGE__->primary_key('recordingId');

has 'creationDate' => (is => 'rw', isa => 'Int');
has 'data' => (is => 'rw', isa => 'Str');
has 'facilitator' => (is => 'rw', isa => 'Int', required => 1);
has 'keywords' => (is => 'rw', isa => 'Str');
has 'meetingRoomId' => (is => 'rw', isa => 'Int', required => 1);
has 'open' => (is => 'rw', isa => 'Bool');
has 'roomName' => (is => 'rw', isa => 'Str');
has 'size' => (is => 'rw', isa => 'Int');
has 'version' => (is => 'rw', isa => 'Str');

=head1 NAME

Elive::Entity::Recording - Elluminate Recording Entity class

=cut


1;
