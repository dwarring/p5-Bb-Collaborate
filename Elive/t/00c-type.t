#!perl -T
use warnings; use strict;
use Test::More tests => 20;
use Test::Warn;

use Elive::Struct;
use Elive::Array;
use Elive::Entity::Role;
use Elive::Entity::ParticipantList::Participants;

my @type_spec = Elive::Util::parse_type('Int');
my ($elemental_type, $is_array, $is_struct, $is_ref, $type) = @type_spec;

is($elemental_type => 'Int',
   'parse_type(int); elemental_type as expected');
ok(! $is_array,'parse_type(int); is_array - as expected');
ok(! $is_struct,'parse_type(int); is_struct - as expected');
ok(! $is_ref,'parse_type(int); is_ref - as expected');
is($type => 'Int',
   'parse_type(int); type as expected');

@type_spec = Elive::Util::parse_type('Elive::Array');
($elemental_type, $is_array, $is_struct, $is_ref, $type) = @type_spec;

is($elemental_type => 'Str',
   'parse_type(array); elemental_type as expected');
ok($is_array,'parse_type(array); is_array - as expected');
ok(! $is_struct,'parse_type(array); is_struct - as expected');
ok($is_ref,'parse_type(array); is_ref - as expected');
is($type => 'Elive::Array',
   'parse_type(array); type as expected');

@type_spec = Elive::Util::parse_type('Elive::Entity::Role');
($elemental_type, $is_array, $is_struct, $is_ref, $type) = @type_spec;

is($elemental_type => 'Elive::Entity::Role',
   'parse_type(role); elemental_type as expected');
ok(! $is_array,'parse_type(role); is_array - as expected');
ok($is_struct,'parse_type(role); is_struct - as expected');
ok($is_ref,'parse_type(role); is_ref - as expected');
is($type => 'Elive::Entity::Role',
   'parse_type(role); type as expected');

@type_spec = Elive::Util::parse_type('Elive::Entity::ParticipantList::Participants|Str');
($elemental_type, $is_array, $is_struct, $is_ref, $type) = @type_spec;

is($elemental_type => 'Elive::Entity::ParticipantList::Participant',
   'parse_type(participants); elemental_type as expected');
ok($is_array,'parse_type(participants); is_array - as expected');
ok($is_struct,'parse_type(participants); is_struct - as expected');
ok($is_ref,'parse_type(participants); is_ref - as expected');
is($type => 'Elive::Entity::ParticipantList::Participants',
   'parse_type(participants); type as expected');

