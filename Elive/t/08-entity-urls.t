#!perl -T
use warnings; use strict;
use Test::More tests => 6;
use Test::Warn;

package main;

BEGIN {
    use_ok( 'Elive::Connection' );
    use_ok( 'Elive::Entity::Group' );
    use_ok( 'Elive::Entity::ParticipantList' );
};

use Scalar::Util;

my $URL1 = 'http://test1.org';

my $K1 = '1256168907389';
my $K2 = '112233445566';
my $K3 = '111222333444';
my $C1 = Elive::Connection->connect($URL1);

Elive->connection($C1);

my $user_k1 =  Elive::Entity::User->construct(
    {userId => $K1,
     loginName => 'pete'},
    );

my $user_k2 =  Elive::Entity::User->construct(
    {userId => $K2,
     loginName => 'repeat'},
    );

ok(substr($user_k1->url, 0, length($URL1)) eq $URL1, 'object url is based on connection url');

my $group_k1 = Elive::Entity::Group->construct(
    {
	groupId => $K1,
	name => 'test group',
	members => [$K2, $K3]
    },
    );

ok($user_k1->url ne $user_k2->url, 'distinct entities have distinct urls');
ok($user_k1->url ne $group_k1->url, 'urls distinct between entity classes');
