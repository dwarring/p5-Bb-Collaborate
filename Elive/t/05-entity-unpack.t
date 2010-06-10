#!perl -T

=head1 NAME

05-entity-unpack.t

=head1 DESCRIPTION

The unpacking pass precedes thawing. It involves interpreting both
'Collection and 'Map' within the data. These are both converted back
to arrays.

=cut

use warnings; use strict;
use Test::More tests => 8;
use Test::Warn;

use Storable;

BEGIN {
    use_ok( 'Elive::Entity' );
};

my %user = (
	'FirstName' => 'Blinky',
	'Role' => {
	    'RoleAdapter' => {
		'RoleId' => '0'
	    }
	},
	'Id' => '123456789000',
	'LoginPassword' => 'a&b',
	'LastName' => 'Bill',
	'Deleted' => 'false',
	'LoginName' => 'bbill',
	'Email' => 'bbill@test.org'
    );

my $canonical = {
    'UserAdapter' => \%user
};

my $canonical_encoded = {
    'UserAdapter' => {
                   %user,
    },
};

#
# The following should all unpack to canoncial
#

#------ Simple value

my $simple_unpacked = Elive::Entity->_unpack_as_list(Storable::dclone($canonical_encoded));
isa_ok($simple_unpacked, 'ARRAY');
is_deeply($canonical, $simple_unpacked->[0], 'Simple unpacking');

#------ Collection

my $collection = {
    Collection => {
	Entry => [
	    Storable::dclone($canonical_encoded),
	]
    }
};

my $collection_unpacked = Elive::Entity->_unpack_as_list($collection);
is_deeply($canonical, $collection_unpacked->[0], 'Collection unpacking');

#------ Collection - singular

my $collection1 = {
    Collection => {
	Entry => Storable::dclone($canonical_encoded),
    }
};

my $collection1_unpacked = Elive::Entity->_unpack_as_list($collection1);
is_deeply($canonical, $collection1_unpacked->[0], 'Collection unpacking');

#------ Hash Map

my $hash_map = {
    Map => {
	Entry => [
	    {
		Key   => 123456789000,
		Value => Storable::dclone($canonical_encoded),
	    },
	],
    }
};

my $hash_map_unpacked = Elive::Entity->_unpack_as_list($hash_map);
is_deeply($canonical, $hash_map_unpacked->[0], 'Hash Map unpacking');

#------ Hash Map - singular

my $hash_map1 = {
    Map => {
	Entry => {
		Key   => 123456789000,
		Value => Storable::dclone($canonical_encoded),
	    },
    }
};

my $hash_map1_unpacked = Elive::Entity->_unpack_as_list($hash_map1);
is_deeply($canonical, $hash_map1_unpacked->[0], 'Hash Map unpacking');

#------ Empty Collection (no results)

my $empty_collection = {
    Collection => ''
};

my $empty_collection_unpacked = Elive::Entity->_unpack_as_list($empty_collection);
is_deeply([], $empty_collection_unpacked, 'Empty collection unpacking');
