#!perl -T
use warnings; use strict;
use Test::More tests => 38;
use Test::Warn;
use Test::Exception;

use Elive;
use Elive::Connection;
use Elive::Entity;
use Elive::Entity::User;
use Elive::Entity::Meeting;
use Elive::Entity::Recording;

Elive->connection(Elive::Connection->connect('http://test.org'));

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
ok(!$user1->is_changed, 'freshly constructed user - !changed');
is($user1->userId, $USER_ID, 'user - userId accessor');
is($user1->loginName,  $LOGIN_NAME, 'constructed user - loginName accessor');
ok($user1->_db_data, 'user1 has db data');

ok(!$user1->is_changed, 'is_changed returns false before change');

$user1->set(loginName => $user1->loginName . '_1');

is($user1->loginName,  $LOGIN_NAME .'_1', 'non-key update');
ok($user1->is_changed, 'is_changed returns true after change');

$user1->set(email => 'user@test.org');

is_deeply([sort $user1->is_changed], [qw/email loginName/], 'is_changed properties');

$user1->revert('email');

is_deeply([sort $user1->is_changed], [qw/loginName/], 'is_changed after partial revert');

$user1->revert;

ok(!$user1->is_changed, 'is_changed after full revert');
is($user1->loginName,  $LOGIN_NAME, 'attribute value reverted');

my $user2 = Elive::Entity::User->construct({
	userId => $USER_ID +2,
	loginName => $LOGIN_NAME . '_2',
	loginPassword => $LOGIN_PASS,
	role => {roleId => 0},
     },
    );

is($user2->userId,  $USER_ID +2, 'second constructed user has correct userId value');
is($user2->loginName,  $LOGIN_NAME.'_2', 'second constructed user has correct loginName value');

my $user3 = Elive::Entity::User->construct({
        userId => $USER_ID,  # Note sharing primary key with $user1
        loginName => $LOGIN_NAME .'_3',
        loginPassword => $LOGIN_PASS
      },
    );

ok(!$user3->is_changed, 'is_changed returns false after reconstruction');

is($user3->_refaddr, $user1->_refaddr, 'Objects with common primary key are unified'); 
isnt($user3->_refaddr, $user2->_refaddr, 'Objects with distinct primary are distinguished');

is($user3->userId, $USER_ID, 'object reconstruction - key field saved');
is($user3->loginName, $LOGIN_NAME . '_3', 'object reconstruction - non-key field saved');

$user1->revert;

my $EMAIL = 'tester@test.org';
$user1->set(email => $EMAIL);

is($user1->email, $EMAIL, 'can set additional attributes');
is_deeply([$user1->is_changed], ['email'], 'Setting additional attributes shows as a change');

$user1->set(email => undef);
ok(!$user1->is_changed, 'Undefing newly added attribute undoes change');

$user1->revert;

ok(!$user1->is_changed, 'Revert 1');
$user1->role(3);
is_deeply([$user1->is_changed], ['role'], 'Compound field (role) change recognised');

$user1->revert;
ok(!$user1->is_changed, 'Revert 2');

$user1->deleted(1);
ok($user1->deleted, 'deleted user => deleted');
is_deeply([$user1->is_changed],['deleted'], 'deleted user => changed');

$user1->revert;
ok(!$user1->is_changed, 'Revert 3');
ok(!$user1->deleted, 'undeleted user => !deleted');
ok(!$user1->is_changed, 'undeleted user => !changed');

$user1->revert;

my $meetingId1 = '112233445566';
my $meetingId2 = '223344556677';

my $recording =  Elive::Entity::Recording->construct({
    recordingId => '123456789000_987654321000',
    meetingId => $meetingId1,
    creationDate => time().'000',
    size => '1024',
});

my $meeting_obj =  Elive::Entity::Meeting->construct({
    meetingId => $meetingId2,
    name => 'test meeting',
    start => '1234567890123',
    end => '1231231230123',
});

#
# test setting of object foreign key via reference_object
#
 
ok(!$recording->is_changed, 'recording - not changed before update');

lives_ok(sub{$recording->set(meetingId => $meeting_obj)}, 'setting foreign key via object - lives');

ok($recording->is_changed, 'recording - changed after update');
is($recording->meetingId, $meetingId2,'recording meetingId before revert');

lives_ok(sub{$recording->revert}, 'recording revert - lives');

is($recording->meetingId, $meetingId1,'recording meetingId after revert');
ok(!$recording->is_changed, 'recording - is_changed is false after revert');
