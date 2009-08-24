#!perl -T
use warnings; use strict;
use Test::More tests => 32;
use Test::Warn;

BEGIN {
    use_ok( 'Elive::Struct' );
    use_ok( 'Elive::Entity::Role' );
}

my $class = 'Elive::Struct';

ok($class->_cmp_col('Int', 10, 20) < 0, '_cmp Int <');
ok($class->_cmp_col('Int', 20, 20) == 0, '_cmp Int ==');
ok($class->_cmp_col('Int', 20, '020') == 0, '_cmp Int ==');
ok($class->_cmp_col('Int', 20, 10) > 0, '_cmp Int >');
ok(! defined ($class->_cmp_col('Int', undef, 10)), '_cmp Int undef');
ok(! defined ($class->_cmp_col('Int', 10, undef)), '_cmp undef Int');

ok($class->_cmp_col('HiResDate', '1251063623412', '1251063623413') < 0, '_cmp HiResDate <');
ok($class->_cmp_col('HiResDate', '1251063623413', '1251063623413') == 0, '_cmp HiResDate ==');
ok($class->_cmp_col('HiResDate', '01251063623413', '1251063623413') == 0, '_cmp HiResDate ==');
ok($class->_cmp_col('HiResDate', '1251063623414', '1251063623413') > 0, '_cmp HiResDate >');


ok($class->_cmp_col('Str', 'aaa', 'bbb') < 0, '_cmp Str <');
ok($class->_cmp_col('Str', 'aaa', 'aaa') == 0, '_cmp Str ==');
ok($class->_cmp_col('Str', 'aaa', 'AAA') != 0, '_cmp Str <>');
ok($class->_cmp_col('Str', '    aaa bbb    ', ' AAA BBB ') != 0, '_cmp Str white space');
ok($class->_cmp_col('Str', ' aaa bbb ', 'AAA BBB') != 0, '_cmp Str white space lhs');
ok($class->_cmp_col('Str', 'aaa bbb', ' AAA BBB ') != 0, '_cmp Str white space rhs');
ok($class->_cmp_col('Str', 'aaa', 'AAA', case_insensitive => 1) == 0, '_cmp Str == -i');


ok($class->_cmp_col('enumRecordingStates', 'off', 'off') == 0, '_cmp enum ==');
ok($class->_cmp_col('enumRecordingStates', 'Off', 'off') == 0, '_cmp enum == (case insensitve)');
ok($class->_cmp_col('enumRecordingStates', 'off', 'on') != 0, '_cmp enum !=');

ok($class->_cmp_col('ArrayRef[Int]', [1,2,3],[1,2,3]) == 0, '_cmp [Int] ==');
ok($class->_cmp_col('ArrayRef[Int]', [1,2,3],[3,2,1]) == 0, '_cmp [Int] == (unordered)');
ok($class->_cmp_col('ArrayRef[Int]', [2,3,4],[1,2,3]) > 0, '_cmp [Int] >');
ok($class->_cmp_col('ArrayRef[Int]', [1,2,3],[2,3,4]) < 0, '_cmp [Int] <');

ok($class->_cmp_col('Elive::Entity::Role', {roleId => 2},{roleId => 2}) == 0, '_cmp Entity ==');
ok($class->_cmp_col('Elive::Entity::Role', {roleId => 3},{roleId => 2}) > 0, '_cmp Entity >');
ok($class->_cmp_col('Elive::Entity::Role', {roleId => 2},{roleId => 3}) < 0, '_cmp Entity <');

ok($class->_cmp_col('ArrayRef[Elive::Entity::Role]', [{roleId => 1}, {roleId => 2}], [{roleId => 1},{roleId => 2}]) == 0, '_cmp [Entity] ==');
ok($class->_cmp_col('ArrayRef[Elive::Entity::Role]', [{roleId => 1}, {roleId => 3}],[{roleId => 1}, {roleId => 2}]) > 0, '_cmp [Entity] >');
ok($class->_cmp_col('ArrayRef[Elive::Entity::Role]', [{roleId => 1}, {roleId => 2}],[{roleId => 1}, {roleId => 3}]) < 0, '_cmp [Entity] <');

# todo some complex nested entities

