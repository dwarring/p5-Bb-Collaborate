package Elive::Struct;
use warnings; use strict;

use Mouse;
use Elive;
use base qw{Elive};

use Elive::Array;
use Elive::Util;

use Carp;

use YAML;

=head1 NAME

Elive::Struct - Base class for Elive::Entity and entity sub-structures

=head1 DESCRIPTION

Base class for sub-structures within entities, eg Elive::Entity::Role.
This is also used as a base class for Elive::Entity.

=cut

=head1 METHODS

=cut

=head2 stringify

Return a human readable string representation of an object. For database
entities, this is the primary key:

    if ($user_obj->stringify eq "11223344") {
        ....
    }

Arrays of sub-items evaluated, in a string context, to a semi-colon separated
string of the individual values sorted.

    my $group = Elive::Entity::Group->retrieve([98765]);
    if ($group->members->stringify eq "11223344;2222222") {
         ....
    }

In particular meeting participants stringify to userId=role, eg

    my $participant_list = Elive::Entity::ParticipantList->retrieve([98765]);
    if ($participant_list->participants->stringify eq "11223344=3;2222222=2") {
         ....
    }

=cut

BEGIN {
    __PACKAGE__->mk_classdata('_entities' => {});
    __PACKAGE__->mk_classdata('_aliases');
    __PACKAGE__->mk_classdata('_entity_name');
    __PACKAGE__->mk_classdata('_primary_key', []);
    __PACKAGE__->mk_classdata('collection_name');
    __PACKAGE__->mk_classdata('isa');
};

use Scalar::Util;

sub _refaddr {
    my $self = shift;
    return Scalar::Util::refaddr( $self );
}

sub BUILDARGS {
    my ($class, $raw, @args) = @_;

    warn "$class - ignoring arguments to new: @args\n"
	if @args;

    if (Elive::Util::_reftype($raw) eq 'HASH') {

	my $types = $class->property_types;

	my %cooked;

	my $aliases = $class->_get_aliases;

	foreach (keys %$raw) {

	    #
	    # apply any aliases
	    #

	    my $prop = (exists $aliases->{$_}
			? ($aliases->{$_}{to} or die "$class has malformed alias: $_")
			: $_);

	    my $value = $raw->{$_};
	    if (my $type = $types->{$prop}) {
		if (ref($value)) {
		    #
		    # inspect the item to see if we need to uncoerce back to
		    # a simpler type. For example we may have been passed an
		    # object, rather than just its primary key.
		    #
		    my (undef, $is_array, $is_struct, $is_ref)
			= Elive::Util::parse_type($type);

		    $value = Elive::Util::string($value, $type)
			unless $is_array || $is_struct || $is_ref;
		}		    
	    }
	    else {
		Carp::carp "$class: unknown property: $prop";
	    }

	    $cooked{$prop} = $value;
	}

	return \%cooked;
    }

    return $raw;
}

sub stringify {
    my $class = shift;
    my $data = shift;

    $data ||= $class
	if ref($class);

    return $data
	unless Elive::Util::_reftype($data);

    return unless $data;

    my $types = $class->property_types;

    my $string = join('/', map {Elive::Util::_freeze($data->{$_},
						     $types->{$_})}
		      $class->primary_key);


    return $string;
}

=head2 entity_name

    my $entity_name = MyApp::Entity::User->entity_name
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

=head2 collection_name

    my $collection_name = MyApp::Entity::User->collecion_name
    ok($collection_name eq 'users');

=cut

# Class::Data::Inheritable property

# _alias, _get_aliases
#
#    MyApp::Entity::Meeting->_set_data_mapping(requiredSeats => 'seats');
#
# Return or set data mappings.
#
# These methods assist with the handling of data inconsistancies that
# sometimes exist between freeze/thaw property names; or between versions.
# These are always trapped at the data level (_freeze & _thaw).
#

sub _alias {
    my ($entity_class, $from, $to, %opt) = @_;

    $from = lcfirst($from);
    $to = lcfirst($to);

    die 'usage: $entity_class->_alias(alias, prop, %opts)'
	unless ($entity_class
		&& $from && !ref($from)
		&& $to && !ref($to));

    my $aliases = $entity_class->_get_aliases;

    #
    # Set our entity name. Register it in our parent
    #
    die "$entity_class: attempted redefinition of alias: $from"
	if $aliases->{$from};

    die "$entity_class: can't alias $from it's already a property!"
	if $entity_class->meta->get_attribute($from);

    die "$entity_class: attempt to alias $from to non-existant property $to - check spelling and declaration order"
	unless $entity_class->meta->get_attribute($to);

    $opt{to} = $to;
    $aliases->{$from} = \%opt;

    return \%opt;
}

sub _get_aliases {

    my $entity_class = shift;

    my $aliases = $entity_class->_aliases;

    unless ($aliases) {
	$aliases = {};
	$entity_class->_aliases( $aliases );
    }

    return $aliases
}

=head2 id

    my @primary_vals = $entity_obj->id

Return primary key values.

=cut

sub id {
    my $self = shift;
    return map {$self->$_} ($self->primary_key );
}

=head2 primary_key

    Setter/getter for primary key field(s) for this entity class

    my @pkey = MyApp::Entity::User->primary_key

=cut

sub primary_key {
    my ($entity_class, @pkey) = @_;

    if (@pkey) {

	$entity_class->_primary_key(\@pkey);

    }

    return @{$entity_class->_primary_key};
}

=head2 entities

    my $entities = Entity::Entity->entities

    print "user has entity class: $entities->{user}\n";
    print "meetingParticipant entity class has not been loaded\n"
        unless ($entities->{meetingParticipant});

Return has hash ref of all loaded entity names and classes

=cut

sub entities {
    my $entity_class = shift;

    return $entity_class->_entities;
}

sub _ordered_attribute_names {
    my $class = shift;

    my %order;
    my $rank;
    #
    # Put primary key fields at the top
    #
    foreach ($class->primary_key) {
	$order{$_} = ++$rank;
    }

    #
    # Sort remaining fields alphabetically
    #
    my @atts = $class->meta->get_attribute_list;

    foreach (sort @atts) {
	$order{$_} ||= ++$rank;
    }

    my @atts_sorted = sort {$order{$a} <=> $order{$b}} (keys %order);
    return @atts_sorted;
}

sub _ordered_attributes {
    my $class = shift;

    my $meta = $class->meta;

    return map {$meta->get_attribute($_)} ($class->_ordered_attribute_names);
}

sub _cmp_col {
    my ($class, $data_type, $_v1, $_v2, %opt) = @_;

    #
    # Compare two values for a property 
    #

    return
	unless (defined $_v1 && defined $_v2);

    my ($type, $is_array, $is_struct) = Elive::Util::parse_type($data_type);
    my @v1 = ($is_array? @$_v1: ($_v1));
    my @v2 = ($is_array? @$_v2: ($_v2));

    my $cmp = scalar @v1 <=> scalar @v2;

    unless ($cmp) {

	#
	# unequal arrays lengths => unequal
	#

	if (scalar @v1 == 0) {

	    #
	    # Empty arrays => equal
	    #

	    $cmp = undef;
	}
	else {
	    #
	    # arrays are of equal lengths. compare values
	    #
	    for (@v1, @v2) {
		#
		# work with normalised frozen values
		#
		$_ = ($is_struct       ? $type->stringify($_)
		      : $type eq 'Ref' ? YAML::Dump($_) # no freeze method avail
		      : Elive::Util::_freeze($_, $type));
	    }

	    if ($is_array) {

		#
		# Order of elements does not matter
		#

		@v1 = sort {$class->_cmp_col($type, $a, $b, %opt)} @v1;
		@v2 = sort {$class->_cmp_col($type, $a, $b, %opt)} @v2;
	    }

	    for (my $i = 0; $i < @v1; $i++) {

		my $v1 = $v1[$i];
		my $v2 = $v2[$i];

		if ($is_struct || $type =~ m{^(Str|Enum|HiResDate)}ix) {
		    #
		    # string comparision. works on simple strings and
		    # stringified entities. Also used for hires dates
		    # integer comparision may result in arithmetic overflow
		    #
		    $cmp ||= ($opt{case_insensitive}
			      ? uc($v1) cmp uc($v2)
			      : $v1 cmp $v2);
		}
		elsif ($type =~ m{^Bool}ix) {
		    # boolean comparison
		    $cmp ||= ($v1 eq 'true'? 1: 0) <=> ($v2 eq 'true'? 1: 0);
		}
		elsif ($type =~ m{^Int}ix) {
		    # int comparision
		    $cmp ||= $v1 <=> $v2;
		}
		elsif ($type =~ m{^Ref}ix) {
		    $cmp ||= YAML::Dump($v1) cmp YAML::Dump($v2);
		}
		else {
		    Carp::croak "class $class: unknown type: $type\n";
		}
	    }
	}
    }

    return $cmp;
}

=head2 properties

   my @properties = MyApp::Entity::User->properties;

Return the property accessor names for an entity

=cut

sub properties {
    my $class = shift;
    return map {$_->name} ($class->_ordered_attributes);
}

=head2 property_types

   my $user_types = MyApp::Entity::User->property_types;
   my ($type,
       $is_array,
       $is_struct) = Elive::Util::parse_type($user_types->{role})

Return a hashref of attribute data types.

=cut

sub property_types {
    my $class = shift;

    my $meta = $class->meta;
    my @atts = $meta->get_attribute_list;

    return {
	map {$_ => $meta->get_attribute($_)->type_constraint} @atts
    };
}

=head2 property_doco

    my $user_doc = MyApp::Entity::User->property_doc
    my $user_password_doco = $user_doc->{loginPassword}

Return a hashref of documentation for properties

=cut

sub property_doco {
    my $class = shift;

    return {
	map {$_->name => $_->{documentation}} ($class->_ordered_attributes)
    };
}

=head2 set

    $obj->set(prop1 => val1, prop2 => val2 [,...])

Assign values to entity properties.

=cut

sub set {
    my ($self, %data) = @_;

    my %entity_column = map {$_ => 1} ($self->properties);
    my %primary_key = map {$_ => 1} ($self->primary_key);

    foreach (keys %data) {

	unless ($entity_column{$_}) {
	    Carp::carp ((ref($self)||$self).": unknown property: $_");
	    next;
	}

	my $type = $self->property_types->{$_}
	   or die ((ref($self)||$self).": unable to determine property type for field: $_");

	if (exists $primary_key{ $_ }) {

	    my $old_val = $self->{$_};

	    if (defined $old_val && !defined $data{$_}) {
		die "attempt to delete primary key";
               }
	    elsif ($self->_cmp_col($type,
				   $old_val, $data{$_})) {
		die "attempt to update primary key";
	    }
	}

	my $meta = $self->meta;
	my $attribute =  $meta->get_attribute($_);
	my $value = $data{$_};

	if (defined $value) {

	    if (ref($value)) {
		#
		# inspect the item to see if we need to uncoerce back to
		# a simpler type. For example we may have been passed an
		# object, rather than just its primary key.
		#
		my (undef, $is_array, $is_struct, $is_ref)
		    = Elive::Util::parse_type($type);
		
		$value = Elive::Util::string($value, $type)
		    unless $is_array || $is_struct || $is_ref;
	    }

	    $self->$_($value);
	}
	else {

	    die ref($self).": attempt to delete required attribute: $_"
		if $attribute->is_required;

	    delete $self->{$_};
	}
    }

    return $self;
}

sub can {
    my ($self, $method) = @_;

    my $subref;

    unless ($subref = $self->SUPER::can($method)) {

	my $aliases = $self->_aliases;

	if ($aliases && $aliases->{$method}
	    && (my $alias_to = $aliases->{$method}{to})) {
	    $subref =  $self->SUPER::can($alias_to);
	}
    }

    return $subref;
}

sub AUTOLOAD {
    my ($self) = @_;

    my @class_path = split('::', ${Elive::Struct::AUTOLOAD});

    my $class = join('::', @class_path);
    my $method = pop(@class_path);
    die "Autoload Dispatch Error: ".${Elive::Struct::AUTOLOAD}
        unless $class && $method;

    my $subref;

    if ($subref = $self->can($method)) {

	{
	    no strict 'refs';
	    *{$class.'::'.$method} = $subref;
	}

	goto $subref;
    }
    else {
	die ref($self).": unknown method $method";
    }
}

1;
