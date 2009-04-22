#!perl -T
use warnings; use strict;
use Test::More tests => 27;
use Test::Warn;

BEGIN {
    use_ok( 'Elive' );
    use_ok( 'Elive::Connection' );
    use_ok( 'Elive::Entity' );
    use_ok( 'Elive::Entity::User' );
}

Elive->connection(Elive::Connection->new('http://test.org'));

my %user_props = (map {$_ => 1} Elive::Entity::User->properties);

ok(exists $user_props{userId}
   && exists $user_props{loginName}
   && exists $user_props{loginPassword},
   'user entity class sane');

my $LOGIN_NAME = 'test_user';
my $LOGIN_PASS = 'test_pass';
my $USER_ID = '1234';

my $user1 = Elive::Entity::User->construct({
	userId => $USER_ID,
	loginName => $LOGIN_NAME,
	loginPassword => $LOGIN_PASS,
	role => {roleId => 0},
     },
    );

isa_ok($user1, 'Elive::Entity::User');
ok($user1->userId ==  $USER_ID, 'user - userId accessor');
ok($user1->loginName eq  $LOGIN_NAME, 'constructed user - loginName accessor');
ok($user1->_db_data, 'user1 has db data');

ok(!$user1->is_changed, 'is_changed returns false before change');

$user1->set(loginName => $user1->loginName . '_1');

ok($user1->loginName eq  $LOGIN_NAME .'_1', 'non-key update');
ok($user1->is_changed, 'is_changed returns true after change');

$user1->set(email => 'user@test.org');
ok($user1->is_changed, 'is_changed returns true after 2nd change');

is_deeply([sort $user1->is_changed], [qw/email loginName/], 'is_changed properties');

$user1->revert('email');

is_deeply([sort $user1->is_changed], [qw/loginName/], 'is_changed after partial revert');

$user1->revert;

ok(!$user1->is_changed, 'is_changed after full revert');
ok($user1->loginName eq  $LOGIN_NAME, 'attribute value reverted');

my $user2 = Elive::Entity::User->construct({
	userId => $USER_ID +2,
	loginName => $LOGIN_NAME . '_2',
	loginPassword => $LOGIN_PASS,
	role => {roleId => 0},
     },
    );

ok($user2->userId ==  $USER_ID +2, 'second constructed user has correct userId value');
ok($user2->loginName eq  $LOGIN_NAME.'_2', 'second constructed user has correct loginName value');

my $user3 = Elive::Entity::User->construct({
        userId => $USER_ID,  # Note sharing primary key with $user1
        loginName => $LOGIN_NAME .'_3',
        loginPassword => $LOGIN_PASS
      },
    );

ok(!$user3->is_changed, 'is_changed returns false after reconstruction');

ok($user3->_refaddr eq $user1->_refaddr, 'Objects with common primary key are unified'); 
ok($user3->_refaddr ne $user2->_refaddr, 'Objects with distinct primary are distinguished');

ok($user3->userId ==  $USER_ID, 'object reconstruction - key field saved');
ok($user3->loginName eq  $LOGIN_NAME . '_3', 'object reconstruction - non-key field saved');

$user1->revert;

my $EMAIL = 'tester@test.org';
$user1->set(email => $EMAIL);

ok($user1->email eq $EMAIL, 'can set additional attributes');
ok($user1->is_changed, 'Setting additional attributes shows as a change');

$user1->set(email => undef);
ok(!$user1->is_changed, 'Undefing newly added attribute undoes change');

$user1->revert;

