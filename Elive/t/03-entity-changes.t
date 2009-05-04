#!perl -T
use warnings; use strict;
use Test::More tests => 20;
use Test::Warn;

BEGIN {
    use_ok( 'Elive::Connection' );
    use_ok( 'Elive::Entity::User' );
    use_ok( 'Elive::Entity::Group' );
}

Elive->connection(Elive::Connection->connect('http://test.org'));

my @base_members = (100, 101, 102);

my %user_props = (map {$_ => 1} Elive::Entity::User->properties);

ok(exists $user_props{userId}
   && exists $user_props{loginName}
   && exists $user_props{loginPassword},
   'user entity class sane');

my $user1 = Elive::Entity::User->construct({
	userId => 12345,
	loginName => 'someuser',
	loginPassword => 'somepass'
     },
    );
isa_ok($user1, 'Elive::Entity::User');

my %group_props = (map {$_ => 1}  Elive::Entity::Group->properties);

ok(exists $group_props{groupId}
   && exists $group_props{name}
   && exists $group_props{members},
   'group entity class sane');

my $group1 = Elive::Entity::Group->construct({
	groupId => 1,
	name => 'group_with_several_members',
	members => [ @base_members ],
     },
    );

isa_ok($group1, 'Elive::Entity::Group');

ok($group1->id ==  1, 'constructed group - id accessor');
ok($group1->name eq 'group_with_several_members', 'constructed group - name accessor');
isa_ok($group1->members, 'ARRAY', 'group->members');
is_deeply([ @{$group1->members}], \@base_members, 'group members preserved');

ok(!$group1->is_changed, 'is_changed returns false before change');

$group1->members->[-1]++;
ok($group1->is_changed, 'changing array member recognised as a change');

$group1->members->[-1]--;
ok(!$group1->is_changed, 'reverting array member reverts change');

push(@{$group1->members}, 104);			 
ok($group1->is_changed, 'adding array member recognised as a change');

pop(@{$group1->members});
ok(!$group1->is_changed, 'removing member reverts change');

unshift(@{$group1->members}, pop(@{$group1->members}));
ok(!$group1->is_changed, 'shuffling members not recognised as change');

$group1->revert;

my $group2 = Elive::Entity::Group->construct({
	groupId => 2,
	name => 'group_with_no_members',
	members => [],
     },
    );

ok(!$group2->is_changed, 'is_changed returns false before change');

push(@{$group2->members}, 104);			 
ok($group2->is_changed, 'adding array member recognised as a change');

$group2->{members} = [];
ok(!$group2->is_changed, 'is_changed returns false after backout out change');

