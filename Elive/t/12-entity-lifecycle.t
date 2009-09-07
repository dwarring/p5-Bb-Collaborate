#!perl -T
use warnings; use strict;
use Test::More tests => 9;
use Test::Warn;

package main;

my $meta_data_tab = \%Elive::Meta_Data;

BEGIN {
    use_ok( 'Elive' );
    use_ok( 'Elive::Connection' );
    use_ok( 'Elive::Entity' );
    use_ok( 'Elive::Entity::User' );
};

use Scalar::Util;

my $URL1 = 'http://test1.org';

my $K1 = 123456123456;
my $C1 = Elive::Connection->connect($URL1);

Elive->connection($C1);

my $user =  Elive::Entity::User->construct(
    {userId => $K1,
     loginName => 'pete'},
    );

my $url = $user->url;
my $is_live = defined(Elive::Entity->live_entity($url));
ok($is_live, 'entity is live');

#
# NB _refaddr uses Scalar::Util::refaddr - doesn't count as a reference.
#
my $refaddr = $user->_refaddr;;

ok(defined($meta_data_tab->{$refaddr}), 'entity has metadata');

#
# right, lets get rid of the object
#

$user = undef;

ok($refaddr, 'object destroyed => refaddr still valid');

my $is_dead = !(Elive::Entity->live_entity($url));
ok($is_dead, 'object destroyed => entity is dead');
ok(!defined($meta_data_tab->{$refaddr}), 'object destroyed => entity metadata purged');

