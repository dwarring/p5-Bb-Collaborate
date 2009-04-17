#!perl -T

=head1 NAME

05-entity-unpack.t

=head1 DESCRIPTION

By the time we've got through two languages, XML and the command packing and
process, we end up with quite a few variations with exactly how the data is
packed.

Extraneous data nodes are eliminated  are all normalised back to simple arrays,
extraneous intermediate nodes are eliminated.

=cut

use warnings; use strict;
use Test::More tests => 6;
use Test::Warn;

use Storable;

BEGIN {
    use_ok( 'Elive::Entity' );
};

my $simple = {
    'UserAdapter' => {
	'FirstName' => 'Blinky',
	'Role' => {
	    'RoleAdapter' => {
		'RoleId' => '0'
	    }
	},
	'Id' => '123456789000',
	'LoginPassword' => '',
	'LastName' => 'Bill',
	'Deleted' => 'false',
	'LoginName' => 'bbill',
	'Email' => 'bbill@test.org'
    }
};

#
# The following should all unpack to canoncial
#

my $simple_unpacked = Elive::Entity->_unpack_as_list($simple);
isa_ok($simple_unpacked, 'ARRAY');
is_deeply($simple, $simple_unpacked->[0], 'Simple unpacking');

my $collection = {
    Collection => {
	Entry => [
	    Storable::dclone($simple),
	]
    }
};

my $collection_unpacked = Elive::Entity->_unpack_as_list($collection);
is_deeply($simple, $collection_unpacked->[0], 'Collection unpacking');

my $hash_map = {
    Map => {
	Entry => [
	    {
		Key   => 123456789000,
		Value => Storable::dclone($simple),
	    },
	],
    }
};

my $hash_mapped_unpacked = Elive::Entity->_unpack_as_list($hash_map);
is_deeply($simple, $hash_mapped_unpacked->[0], 'Hash Map unpacking');

#
# An empty result decodes like this

my $empty_result = {
    Collection => ''
};

my $empty_result_unpacked = Elive::Entity->_unpack_as_list($empty_result);
is_deeply([], $empty_result_unpacked, 'Empty result unpacking');



