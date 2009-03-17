package Elive::Struct;
use warnings; use strict;

use Moose;
use Moose::Util::TypeConstraints;

=head1 NAME 

Elive::Entity::Struct - Entity class for structures

=head1 DESCRIPTION

This is a base class for entities which cannot be accesses directly
but appear with other returned classes.

=cut

use base qw{Elive};

use Elive::Array;
use Elive::Util;

BEGIN {

    __PACKAGE__->mk_classdata('_entities' => {});
    __PACKAGE__->mk_classdata('_entity_name');
    __PACKAGE__->mk_classdata('collection_name');

    subtype 'Pkey' => as 'Int'
	=> where {$_ > 0}
    ;

    subtype 'PkeyStr' => as 'Str'
	=> where {length($_)}
};

use overload
        '""'     => sub { shift->_stringify_self },
        fallback => 1;

sub _stringify {
        my $class = shift;
	my @pkey_data = @_;

        return join "/", @pkey_data;
}

sub _destringify {
    my $class = shift;
    my $string = shift;
    #
    # inverse of stringification. convert back to an object
    #
    my @pkey_data = split('/', $string);
    return $class->retrieve(@pkey_data);
}

sub _stringify_self {
    my $self = shift;
    return $self->_stringify($self->id);
}

sub _refaddr {
    return Scalar::Util::refaddr( shift() );
}

=head2 primary_key

    Return primary key field names(s) for this entity class

    my @pkey = Elive::Entity::User->primary_key

=cut

sub primary_key {
    my $class = shift;

    return (map {$_->accessor}
	    grep {$_->{isa} =~ m{pkey}i}
	    $class->_ordered_attributes);
}

=head2 id

    my @primary_vals = $entity_obj->id

Return primary key values.

=cut

sub id {
    my $self = shift;
    return map {$self->$_} ($self->primary_key );
}

=head2 entity_name

    my $entity_name = Elive::Entity::User->entity_name
    ok($entity_name eq 'user');

=cut

sub entity_name {
    my $entity_class = shift;

    if (my $entity_name = shift) {

	#
	# Set our entity name. Register it in our parent
	#

	$entity_class->_entity_name(ucfirst($entity_name));

	my $entities = $entity_class->_entities;

	die "Entity $entity_name redeclared "
	    if exists $entities->{$entity_name};

	$entities->{lcfirst($entity_name)} = $entity_class;
    }

    return $entity_class->_entity_name;
}

=head2 entities

    my $entities = Elive::Entity->entities

    print "user has entity class: $entities->{user}\n";
    print "meetingParticipant entity class has not been loaded\n"
        unless ($entities->{meetingParticipant});

Return has hash ref of all loaded entity names and classes

=cut

sub entities {
    my $entity_class = shift;

    return $entity_class->_entities;
}

sub _ordered_attributes {
    my $class = shift;

    my $meta = $class->meta;

    #
    # I'm not sure if there's a less clunky way of ordering attributes
    #
    sort {$a->definition_context->{line} <=> $b->definition_context->{line}} $meta->get_all_attributes
}

=head2 properties

   my @properties = Elive::Entity::User->properties;

Return the property accessor names for an entity

=cut

sub properties {
    my $class = shift;
    return map {$_->accessor} ($class->_ordered_attributes);
}

=head2 property_types

   my $user_types = Elive::Entity::User->property_types;
   my ($type,
       $is_array,
       $is_entity,
       $is_pkey) = Elive::Util::parse_type($user_types->{role})

Return a hashref of all the Moose types of properties. These may
include:
    'Int', 'Bool', 'Str', 'Pkey', 'PkeyStr', 'ArrayRef[Type]',
    'Elive::Entity::User', 'Elive::Entity::Role'
    'ArrayRef[Elive::Entity::Participant]'

=cut

sub property_types {
    my $class = shift;

    return {
	map {$_->accessor => $_->{isa}} ($class->_ordered_attributes)
    };
}

=head2 property_doco

    my $user_doc = Elive::Entity::User->property_doc
    my $user_password_doco = $user_doc->{loginPassword}

Return a hashref of documentation for properties

=cut

sub property_doco {
    my $class = shift;

    return {
	map {$_->accessor => $_->documentation} ($class->_ordered_attributes)
    };
}

sub _cmp_col {

    #
    # Compare two values for a property 
    #

    my $class = shift;
    my $col = shift;
    my $_v1 = shift;
    my $_v2 = shift;

    return undef
	unless (defined $_v1 && defined $_v2);

    my $cmp;

    my ($type, $is_array, $is_entity) = Elive::Util::parse_type($class->property_types->{$col});
    my @v1 = ($is_array? @$_v1: ($_v1));
    my @v2 = ($is_array? @$_v2: ($_v2));

    if ($is_entity) {
	#
	# Normalise objects and references to simple strings
	#
	for (@v1, @v2) {
	    #
	    # autobless references
	    if (_refaddr($_)) {

		$_ = $type->construct(Elive::Util::_clone($_))
		    unless (Scalar::Util::blessed($_));

		$_ = $_->_stringify_self;
	    }
	}
    }

    @v1 = sort @v1;
    @v2 = sort @v2;

    #
    # unequal arrays lengths => unequal
    #

    $cmp ||= scalar @v1 <=> scalar @v2;

    if ($cmp) {
    }
    elsif (scalar @v1 == 0) {

	#
	# Empty arrays => equal
	#

	$cmp = undef;
    }
    else {
	#
	# compare values
	#
	for (my $i = 0; $i < @v1; $i++) {

	    my $v1 = $v1[$i];
	    my $v2 = $v2[$i];

	    if ($is_entity || $type =~ m{Str}i) {
		# string comparision. works on simple strings and
		# stringified entities.
		# 
		$cmp ||= $v1 cmp $v2;
	    }
	    elsif ($type =~ m{Bool}i) {
		# boolean comparison
		$cmp ||= ($v1? 1: 0) <=> ($v2? 1: 0);
	    }
	    elsif ($type =~ m{Int}i) {
		# int comparision
		$cmp ||= $v1 <=> $v2
	    }
	    else {
		die "$col has unknown type: $type";
	    }
	}
    }
    return $cmp;
}

=head2 construct

    my $participant = Elive::Entity::Participant->construct(
         {user => {userId => 123456, loginName => 'test_user',
          role => {roled => 2}
    );

Construct a derived entity fronm data.

=cut

sub construct {
    #
    # Recursively bless any sub-entities in the current struct;
    my $class = shift;
    my $obj = shift;
    my %opt = @_;

    my $types = $class->property_types;
    my @properties = $class->properties;

    foreach my $name (keys %$obj) {

	#
	# warn rather than barfing . Better option for forward compatiability
	# with future SDK releases
	#
	unless (exists $types->{$name}) {
	    warn "unknown property: $name, discarding";
	    delete $obj->{$name};
	    next;
	}

	my ($type, $is_array, $is_entity)
	    = Elive::Util::parse_type($types->{$name});

	foreach ($obj->{$name}) {

	    my $val_type = Elive::Util::_reftype($_) || 'Scalar';

	    if ($is_array) {
		die "col: $name: expected ARRAY, found $val_type"
		    unless ($val_type eq 'ARRAY');
		bless $_, 'Elive::Array';
	    }

	    for ($is_array? @$_: $_) {

		my $refaddr = _refaddr($_);

##	    warn "name:$name, type:$type, refaddr: $refaddr, conn: $opt{connection}";

		if ($is_entity && $refaddr) {
			#
			# stantiate a database object. Unify addresses
			# so that we have only a single copy in memory
			# at any one time.
			#
		    $_ = $type->construct($_, %opt);
		}
	    }
	}
    }

    return bless $obj, $class;
}

1;
