#!perl -T
use warnings; use strict;
use Test::More tests => 11;
use Test::Warn;

package main;

BEGIN {
    use_ok( 'Elive::Connection' );
    use_ok( 'Elive::Entity::Group' );
};

use Scalar::Util;

my $URL1 = 'http://test1.org';
my $URL2 = 'http://test2.org';

my $K1 = 123456123456;
my $K2 = 112233445566;
my $K3 = 111222333444;

my $C1 = Elive::Connection->connect($URL1);
my $C2 = Elive::Connection->connect($URL2);

Elive->connection($C1);

my $group_c1 = Elive::Entity::Group->construct(
    {
	groupId => $K1,
	name => 'c1 group',
	members => [$K2, $K3]
    },
    );

diag "group_c1 url: ".$group_c1->url;

isa_ok($group_c1, 'Elive::Entity::Group', 'group');

#
# Same as $group_c1, except for the connection
#
my $group_c2 = Elive::Entity::Group->construct(
    {
	groupId => $K1,
	name => 'c2 group',
	members => [$K3, $K2]
    },
    connection => $C2,
    );

diag "group_c2 url: ".$group_c2->url;

isa_ok($group_c2, 'Elive::Entity::Group', 'group');

ok($group_c1->name eq 'c1 group', 'connection 1 object - intact and distinct');
ok($group_c1->members->[1] == $K3, 'connection 1 object - intact and distinct');

ok($group_c2->name eq 'c2 group', 'connection 1 object - intact and distinct');
ok($group_c2->members->[1] == $K2, 'connection 2 object - intact and distinct');

ok(substr($group_c1->url, 0, length($URL1)) eq $URL1, '1st connection: object url is based on connection url');
ok(substr($group_c2->url, 0, length($URL2)) eq $URL2, '2nd connection: object url is based on connection url');

ok(substr($group_c1->url, length($URL1)) eq substr($group_c2->url, length($URL2)), 'common path between connections');
