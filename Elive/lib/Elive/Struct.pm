package Elive::Struct;
use warnings; use strict;

use Elive;
use base qw{Elive};

use overload
    '""' =>
    sub {shift->stringify}, fallback => 1;

use Elive::Array;

BEGIN {
    __PACKAGE__->mk_classdata('_entities' => {});
    __PACKAGE__->mk_classdata('_entity_name');
    __PACKAGE__->mk_classdata('_primary_key', []);
    __PACKAGE__->mk_classdata('collection_name');
};

use Scalar::Util;

sub _refaddr {
    return Scalar::Util::refaddr( shift() );
}

=head1 NAME

Elive::Struct - Base class for entities and simple structures

=head1 DESCRIPTION

Base class for sub-structures within entities, eg Elive::Entity::Role.
This is also used as a base class for Elive::Entity.

=cut

=head1 METHODS

=cut

=head2 stringify

Return a human readable string representation of an object.

=cut

sub _stringify_class {
        my $class = shift;
	my @pkey_data = @_;

        return join "/", @pkey_data;
}

sub stringify {

    if (my $class = ref($_[0])) {
	my $self = shift;
	$class->_stringify_class($self->id);
    }
    else {
	my $class = shift;
	$class->_stringify_class(@_);
    }
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
    my $entity_class = shift;

    if (@_) {

	$entity_class->_primary_key([@_]);

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
    # Sort remaining field alphabetically
    #
    my $atts = $class->meta->get_attribute_map;

    foreach (sort keys %$atts) {
	$order{$_} = ++$rank
	    unless exists $order{$_};
    }

    return sort {$order{$a} <=> $order{$b}} (keys %order);
}

sub _ordered_attributes {
    my $class = shift;

    my $meta = $class->meta;
    my $atts = $meta->get_attribute_map;

    return map {$atts->{$_}} ($class->_ordered_attribute_names);
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
       $is_data) = Elive::Util::parse_type($user_types->{role})

Return a hashref of attribute data types.

=cut

sub property_types {
    my $class = shift;

    my $atts = $class->meta->get_attribute_map;

    return {
	map {$_ => $atts->{$_}->type_constraint} (keys %$atts)
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
    my $self = shift;
    my %data = @_;

    my %entity_column = map {$_ => 1} ($self->properties);
    my %primary_key = map {$_ => 1} ($self->primary_key);

    foreach (keys %data) {

       if ($entity_column{$_}) {

           if (exists $primary_key{ $_ }) {

               my $old_val = $self->{$_};

               if (defined $old_val && !defined $data{$_}) {
                   die "attempt to delete primary key";
               }
               elsif ($self->_cmp_col($old_val, $data{$_})) {
                   die "attempt to update primary key";
               }
           }

           $self->{$_} = $data{$_};
       }
       else {
           die "no such column: $_";
       }
    }

    return $self;
}

1;
