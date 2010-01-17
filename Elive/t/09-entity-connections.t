#!perl -T
use warnings; use strict;
use Test::More tests => 42;
use Test::Warn;
use Scalar::Util;

package main;

BEGIN {
    use_ok( 'Elive::Connection' );
    use_ok( 'Elive::Entity::Group' );
};

use Scalar::Util;
use lib '.';
use t::Elive::MockConnection;

my $URL1 = 'http://test1.org';
my $URL2 = 'http://test2.org/test_site';

my $K1 = '123456123456';
my $K2 = '112233445566';
my $K3 = '111222333444';

for my $class(qw{Elive::Connection t::Elive::MockConnection}) {

    my $C1 = $class->connect($URL1.'/');
    ok($C1->url eq $URL1, 'connection 1 - has expected url');
    
    my $C2 = $class->connect($URL2);
    ok($C2->url eq $URL2, 'connection 2 - has expected url');

    my $C2_dup = $class->connect($URL2);
    ok($C2_dup->url eq $URL2, 'connection 2 dup - has expected url');

    ok(Scalar::Util::refaddr($C2) ne Scalar::Util::refaddr($C2_dup),
					'distinct connections on common url => distinct objects');

    ok($C2->url eq $C2_dup->url,
       'distinct connections on common url => common url');

    my $group_c1 = Elive::Entity::Group->construct(
	{
	    groupId => $K1,
	    name => 'c1 group',
	    members => [$K2, $K3]
	},
	connection => $C1,
	);
    
    isa_ok($group_c1, 'Elive::Entity::Group', 'constructed ');
    is_deeply($group_c1->connection, $C1, 'group 1 associated with connection 1');

#
# Check for basic caching
#
    my $group_c1_from_cache
	= Elive::Entity::Group->retrieve([$K1],connection => $C1, reuse => 1);
    
    ok(Scalar::Util::refaddr($group_c1) eq Scalar::Util::refaddr($group_c1_from_cache),
       'basic caching on connection 1');
    
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

    isa_ok($group_c2, 'Elive::Entity::Group', 'group');
    is_deeply($group_c2->connection, $C2, 'group 2 associated with connection 2');

    my $group_c2_from_cache
	= Elive::Entity::Group->retrieve([$K1], connection => $C2, reuse => 1);
    
    ok(Scalar::Util::refaddr($group_c2) eq Scalar::Util::refaddr($group_c2_from_cache),
    'basic caching on connection 1');

    ok(Scalar::Util::refaddr($group_c1) ne Scalar::Util::refaddr($group_c2),
    'distinct caches maintained on connections with distinct urls');

    my $group_c2_dup_from_cache = Elive::Entity::Group->retrieve([$K1], connection => $C2_dup, reuse => 1);

    ok(Scalar::Util::refaddr($group_c2_dup_from_cache) eq Scalar::Util::refaddr($group_c2_from_cache),
    'connections with common urls share a common cache');

    ok($group_c1->name eq 'c1 group', 'connection 1 object - name as expected');
    ok($group_c1->members->[1] == $K3, 'connection 1 object - first member as expected');

    ok($group_c2->name eq 'c2 group', 'connection 2 object - name as expected');
    ok($group_c2->members->[1] == $K2, 'connection 2 object - first member as expected');
    
    ok(substr($group_c1->url, 0, length($URL1)) eq $URL1, '1st connection: object url is based on connection url');
    ok(substr($group_c2->url, 0, length($URL2)) eq $URL2, '2nd connection: object url is based on connection url');

    ok(substr($group_c1->url, length($URL1)) eq substr($group_c2->url, length($URL2)), 'common path between connections');
    
    $C1->disconnect;
    $C2->disconnect;
    $C2_dup->disconnect;
}
