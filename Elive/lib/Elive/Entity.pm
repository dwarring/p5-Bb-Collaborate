package Elive::Entity;
use warnings; use strict;
use Mouse;
use Mouse::Util::TypeConstraints;

extends 'Elive::Struct';

use YAML;
use Scalar::Util qw{weaken};
require UNIVERSAL;
use Storable qw{dclone};

use Elive::Util;
use Elive::Array;
__PACKAGE__->has_metadata('_deleted');

=head1 NAME

    Elive::Entity - Base class for Elive Entities

=head1 DESCRIPTION

This is an abstract class that is inherited by all Elive Entity instances.

It provides a simple mapping from the objects to database entities.

=cut

our %Stored_Objects;

#
# create metadata properties. NB this will be stored inside out to
# ensure our object is an exact image of the data.
#

foreach my $accessor (qw/_connection _db_data/) {
    __PACKAGE__->has_metadata($accessor);
}

=head2 connection

    my $default_connection = Elive::Entity::User->connection;
    my $connection = $entity_obj->connection;

Return a connection. Either the actual connection associated with a entity
instance, or the default connection that will be used.

=cut

sub connection {
    my $self = shift;

    my $connection;

    if (ref($self)) {
	$self->_connection(shift)
	    if @_;
	$connection = $self->_connection;
    }

    return $connection || $self->SUPER::connection;
}

sub _url {
    my $class = shift;
    my $connection = shift || $class->connection;
    my $path = shift;

    return ($connection->url
	    . '/'
	    . $class->entity_name
	    .'/'.
	    $path);
}

=head1 METHODS

=cut

=head2 url

    my $url = $user->url

Return a restful url for an object instance. This will include both
the url of the connection string and the entity class name. It is used
internally to uniquely identify and cache objects across repositories.

=cut

sub url {
    my $self = shift;
    return $self->_url($self->connection, $self->stringify);
}

=head2 construct

    my $user = Entity::User->construct(
            {userId = 123456,
             loginName => 'demo_user',
             role => {
                roleId => 1
             });

Construct an entity from data.

=cut

sub construct {
    my ($class, $data, %opt) = @_;

    die "usage: ${class}->construct( \\%data )"
	unless (Elive::Util::_reftype($data) eq 'HASH');

    #
    # Ugly use of package globals!
    #

    local (%Elive::_construct_opts) = %opt;

    my %known_properties;
    @known_properties{$class->properties} = undef;

    warn YAML::Dump({construct => $data})
	if (Elive->debug > 1);
    
    my $self = Scalar::Util::blessed($data)
	? $data
	: $class->new($data);

    return $self if ($opt{copy});

    my $connection = delete $opt{connection} || $class->connection
	or die "not connected";

    die "can't construct objects without a connection"
	unless $connection;

    $self->connection($connection);

    my %primary_key_data = map {$_ => $data->{ $_ }} ($class->primary_key);

    foreach (keys %primary_key_data) {
	unless (defined $primary_key_data{ $_ }) {
	    die "can't construct $class without value for primary key field: $_";
	}
    }

    my $obj_url = $self->url;

    if (my $cached = $Stored_Objects{ $obj_url }) {

	#
	# Overwrite the cached object, then reuse it.
	#
	die "attempted overwrite of object with unsaved changes ($obj_url)"
	    if !$opt{overwrite} && $cached->is_changed;

	%{$cached} = %{$self};
	$self = $cached;
    }
    else {
	weaken ($Stored_Objects{$obj_url} = $self);
    }

    my $data_copy = Elive::Util::_clone($self);
    $data_copy->_db_data(undef);
    $self->_db_data( $data_copy );

    return $self;
}

sub _freeze {
    #
    # _freeze - construct name/value pairs for database inserts or updates
    #
    my $class = shift;
    my $db_data = Storable::dclone(shift);

    my @properties = $class->properties;
    my $property_types =  $class->property_types || {};

    foreach (keys %$db_data) {

	my $property = $property_types->{$_};

	die "$class: unknown property: $_: expected: @properties"
	    unless $property;

	my ($type, $is_array, $_is_struct) = Elive::Util::parse_type($property);

	for ($db_data->{$_}) {

	    for ($is_array? @$_: $_) {

		$_ = Elive::Util::_freeze($_, $type);

	    }
	}
    } 

    #
    # apply any freeze alias mappings
    #

    my $aliases = $class->_get_aliases;

    foreach my $alias (keys %$aliases) {
	if ($aliases->{$alias}{freeze}) {
	    my $to = $aliases->{$alias}{to}
	    or die "malformed alias: $alias";
	    #
	    # Freeze with this alias
	    #
	    $db_data->{ $alias } = delete $db_data->{ $to }
	    if exists $db_data->{ $to };
	}
    }

    return $db_data;
}

sub _thaw {
    #
    # _thaw - perform database to perl type conversions
    #
    my $class = shift;
    my $db_data = shift;
    my $path = shift || '';

    $path .= '/';

    my $responseTag = $class->entity_name.'Adapter';

    warn "path $path: response tag for $class: $responseTag"
	if $class->debug;

    my $reftype = Elive::Util::_reftype($db_data) || 'Scalar';

    die "parsing $class: expected HASH, found $reftype ($db_data), path: $path"
	unless ($reftype eq 'HASH');

    my $entity_data = $db_data->{$responseTag};

    die "path $path: struct did not contain: $responseTag (keys: ".join(',', keys %$db_data).')'
	unless $entity_data;

    $path .= $responseTag;

    my $data_type = Elive::Util::_reftype($entity_data) || 'Scalar';
    die "thawing $class. expected $responseTag to contain HASH data. found: $data_type"
	unless ($data_type eq 'HASH');

    my %data;
    my @properties = $class->properties;
    my $aliases = $class->_get_aliases;

    #
    # Fix up a couple of inconsistancies with the fetched data versus
    # the documented schema and the operation of the rest of the system
    # (inserts, updates, querys):
    # 1. Entity names returned capitalised: 'LoginName' => 'loginName
    # 2. Primary key returned as Id, rather than <entity_name>Id
    # 3. Aliases. Usually a result of name changes between versions
    #
    my %prop_key_map = map {ucfirst($_) => $_} @properties;

    my @primary_key = $class->primary_key;

    $prop_key_map{Id} = lcfirst($primary_key[0])
	if @primary_key;

    foreach my $alias (keys %$aliases) {
	my $to = $aliases->{$alias}{to}
	|| die "malformed alias: $alias";

	$prop_key_map{ ucfirst($alias) } = $to;
    }

    foreach my $key (keys %$entity_data) {

	my $val = $entity_data->{ $key };
	my $prop_key = $prop_key_map{$key} || $key;
	$data{$prop_key} = $val;
    }

    my $property_types = $class->property_types;

    foreach my $col (grep {defined $data{ $_ }} @properties) {

	my ($type, $expect_array, $is_struct) = Elive::Util::parse_type($property_types->{$col});

	for my $val ($data{$col}) {

	    my $i = 0;

	    if ($expect_array) {

		my $val_type = Elive::Util::_reftype($val) || 'Scalar';

		unless ($val_type eq 'ARRAY') {
		    #
		    # A single value deserialises to a simple
		    # struct. Coerce it to a one element array
		    #
		    $val = [$val];
		    warn "thawing $class coerced element into array for $col"
			if ($class->debug);
		}
	    }

	    foreach ($expect_array? @$val: $val) {

		my $idx = $expect_array? '['.$i.']': '';

		if (!defined) {
		}
		elsif ($is_struct) {

		    $_ = _thaw("$type", $_, $path . $idx);

		}
		else {
		    $_ = Elive::Util::_thaw($_, $type);
		}
	    }

	    if ($expect_array) {
		@$val = grep {defined $_} @$val;
	    }

	    #
	    # don't store null values, just omit the property.
	    # saves a heap of work in Moose/Mouse constraints
	    #
	    if (defined $val) {
		$data{$col} = $val;
	    }
	    else {
		delete $data{$col};
	    }
	} 
    }

    if ($class->debug) {
	warn "thawed: $class: ".YAML::Dump(
	    {db => $db_data,
	     data => \%data}
	    );
    }
    
    return \%data;
}

#
# Normalise our data and reconstruct arrays.
#
# See t/05-entity-unpack.t for examples and further explanation.
#

sub _unpack_results {
    my $class = shift;
    my $results = shift;

    my $results_type = Elive::Util::_reftype($results);

    if (!$results_type) {
	return $results;
    }
    elsif ($results_type eq 'ARRAY') {
	return [map {$class->_unpack_results($_)} @$results];
    }
    elsif ($results_type eq 'HASH') {
	#
	# Convert some SOAP/XML constructs to their perl equivalents
	#
	foreach my $key (keys %$results) {
	    my $value = $results->{$key};

	    if ($key eq 'Collection') {

		if (Elive::Util::_reftype($value) eq 'HASH'
		    && exists ($value->{Entry})) {
		    $value = $value->{Entry};
		}
		else {
		    $value = [];
		}
		#
		# Throw away our parse of this struct. It only exists to
		# house this collection
		#
		return $class->_unpack_results($value);
	    }
	    elsif ($key eq 'Map') {

		if (Elive::Util::_reftype($value) eq 'HASH') {

		    if (exists ($value->{Entry})) {

			$value = $value->{Entry};
			#
			# Looks like we've got Key, Value pairs.
			# Throw array the key and reference the value,
			# that's all we're interested in.
			#
			if (Elive::Util::_reftype ($value) eq 'ARRAY') {
		    
			    $value = [map {$_->{Value}} @$value];
			}
			else {
			    $value = $value->{Value};
			}
		    }
		}
		else {
		    $value = [];
		}
		#
		# Throw away our parse of this struct it only exists to
		# house this collection
		#
		return $class->_unpack_results($value);
	    }

	    $results->{$key} = $class->_unpack_results($value);
	}
	    
    }
    else {
	die "Unhandled type in response body: $results_type";
    }

    return $results;
}

sub _unpack_as_list {
    my $class = shift;
    my $result = shift;

    $result = $class->_unpack_results($result);

    my $reftype = Elive::Util::_reftype($result);

    my $results_list;

    if ($reftype eq 'HASH') {

	$results_list = [ $result ];

    }
    elsif ($reftype eq 'ARRAY') {

	$results_list = $result;

    }
    elsif ($reftype) {
	die "unknown type in result set: $reftype";
    }
    else {

	$results_list = defined($result) && $result ne ''
	    ? [ $result ]
	    : [];

    }

    warn "$class result: ".YAML::Dump($result)
	if ($class->debug >= 2);

    return $results_list;
}

sub _get_results {
    my $class = shift;
    my $som = shift;

    $class->_check_for_errors($som);

    my $results_list = $class->_unpack_as_list($som->result);

    return $results_list;
}

sub _process_results {
    my ($class, $soap_results, %opt) = @_;

    #
    # Thaw our returned SOAP responses to reconstruct the data
    # image.
    #

    my @rows;

    foreach (@$soap_results) {

	my $row = $class->_thaw($_);

	push(@rows, $row);
    }

    return \@rows;
}

sub _readback_check {
    my ($class, $updates, $rows, %opt) = @_;

    #
    # Create and update responses generally return a copy of the
    # record, after performing the update. This routine may be
    # run to check that the expected updates have been applied
    #
    die "Didn't receive a response for ".$class->entity_name
	unless @$rows;

    foreach my $row (@$rows) {

	my $property_types = $class->property_types;

	foreach ($class->properties) {

	    if (exists $updates->{$_} && exists $row->{$_}) {
		my $write_val = $updates->{$_};
		my $read_val = $row->{$_};
		my $property_type = $class->property_types->{$_};

		if ($class->_cmp_col($property_type,
				     $write_val,  $read_val, %opt)) {

		    warn YAML::Dump({read => $read_val, write => $write_val})
			if ($class->debug);

		    die "${class}: Update consistancy check failed on $_ (${property_type}), wrote:".Elive::Util::string($write_val, $property_type).", read-back:".Elive::Util::string($read_val, $property_type);
		}
	    }
	}
    }

    return @$rows;
}

=head2 is_changed

Returns a list of properties that have been changed since the entity was
last retrieved or saved.

=cut

sub is_changed {
    my $self = shift;

    my @updated_properties;
    my $db_data = $self->_db_data;

    unless ($db_data) {
	#
	# not mapped to a stored data value. scratch object?, sub entity?
	#
	warn ref($self)."->is_changed called on non-database object (".$self->stringify.")";
	return;
    }

    foreach my $col ($self->properties) {

	my $new = $self->$col;
	my $old = $db_data->$col;
	if (defined ($new) != defined ($old)
	    || Elive::Util::_reftype($new) ne Elive::Util::_reftype($old)
	    || $self->_cmp_col($self->property_types->{$col}, $new, $old)) {

	    push (@updated_properties, $col);
	}
    }

    return @updated_properties;
}

=head2 set

    $obj->set(prop1 => val1, prop2 => val2 [,...])

Set entity properties.

=cut

sub set {
    my $self = shift;

    die "attempted to modify  data in a deleted record"
	if ($self->_deleted);

    return $self->SUPER::set(@_);
}

sub _readback {
    my ($class, $som, $sent_data, $_connection) = @_;
    #
    # Inserts and updates normally return a copy of the entity
    # after an insert or update. Confirm that the output record contains
    # the updates and return it.

    my $results = $class->_get_results(
	$som,
	);
    #
    # Check that the return response has our inserts
    #
    my $rows = $class->_process_results( $results );
    $class->_readback_check($sent_data, $rows);

    return @$rows;
}

=head2 insert

   my $new_user = Elive::Entity::User->insert( 
                                 loginName => 'demo_user',
                                 email => 'demo.user@test.org',
                                 role => 1,
                               });

   print "inserted user with id: ".$new_user->userId."\n";

Inserts a new entity. The primary key should not be specified. It is
generated for you and returned with the newly created object.

=cut

sub insert {
    my ($class, $insert_data, %opt) = @_;

    my $connection = $opt{connection}
		      || $class->connection
			  or die "not connected";

    my $db_data = $class->_freeze($insert_data, mode => 'insert');

    my $login_password = $connection->pass;

    my $adapter = $opt{adapter} || 'create'.$class->entity_name;

    $class->check_adapter($adapter, 'c');

    my $som = $connection->call($adapter,
				%$db_data,
				%{$opt{param} || {}},
##				loginPassword => $login_password,
	);

    my @rows = $class->_readback($som, $insert_data, $connection);

    my @objs = (map {$class->construct( $_, connection => $connection )}
		@rows);
    #
    # Not a big fan of wantarry, but 99% we expect to return a single
    # record on insert. Only exception is recurring meetings.
    #
    return wantarray? @objs : $objs[0];
}

=head2 live_entity

    my $user_ref
      = Elive::Entity->live_entity('http://test.org/User/1234567890');

Returns a reference to an object in the Elive::Entity in-memory cache. 

=cut

sub live_entity {
    my $class = shift;
    my $url = shift;

    return $Stored_Objects{ $url };
}

=head2 live_entities

    my $live_entities = Elive::Entity->live_entities;

    my $user_ref
      = $live_entities->{'http://test.org/User/1234567890'};

Returns the contents of Elive::Entity in-memory cache. 

=cut

sub live_entities {
    my $class = shift;
    return \%Stored_Objects;
}

=head2 update

Apply our updates to the server. This call will commit outstanding
changes to the object and also apply any further updates passed
as parameters.

    $obj->{foo} = 'Foo';  # change foo directly
    $foo->update;         # save

    $obj->bar('Bar');     # change bar via its accessor
    $obj->update;         # save

    # change and save foo and bar. All in one go.
    $obj->update({foo => 'Foo', bar => 'Bar'});

=cut

sub update {
    my ($self, $update_data, %opt) = @_;

    die "attempted to update deleted record"
	if ($self->_deleted);

    if ($update_data) {

	die 'usage: $obj->update( \%data )'
	    unless (Elive::Util::_reftype($update_data) eq 'HASH');

	$self->set( %$update_data)
	    if (keys %$update_data);
    }

    #
    # Write only changed properties.
    #
    my @updated_properties = ($opt{changed}
			      ? @{$opt{changed}} 
			      : $self->is_changed);
    #
    # Nothing to update
    #
    return $self unless @updated_properties 
	|| $opt{param};

    my %primary_key = map {$_ => 1} ($self->primary_key);

    my %updates;

    foreach (@updated_properties, keys %primary_key) {

	$updates{$_} = $self->{$_};

	die 'primary key field $_ updated - refusing to save'
	    if (exists $primary_key{ $_ }
		&& $self->_cmp_col($self->property_types->{$_},
				   $self->_db_data->{ $_ },
				   $updates{ $_ }));
    }

    my $db_updates = $self->_freeze(\%updates, mode => 'update');

    my $adapter = $opt{adapter} || 'update'.$self->entity_name;

    $self->check_adapter($adapter);

    my $som = $self->connection->call($adapter,
				       %$db_updates,
				       %{$opt{param} || {}},
	);

    my $class = ref($self);

    my @rows = $class->_readback($som, \%updates, $self->connection);
    #
    # refresh the object from the database read-back
    #
    $class->construct($rows[0], overwrite => 1, connection => $self->connection)
	if (@rows && Elive::Util::_reftype($rows[0]) eq 'HASH');

    #
    # Save the db image
    #
    my $db_data = $self->construct(Elive::Util::_clone($self),
	copy => 1);
    #
    # Make sure our db data doesn't have db data!
    #
    $db_data->_db_data(undef);
    $self->_db_data($db_data);

    return $self;
}

=head2 list

    my $users = Elive::Entity::Users->list(filter => 'surname = smith')

Retrieve a list of objects from a table.

Note: this method is not applicable to Elive::Entity::MeetingParameters
or Elive::Entity::ParticipantList.

=cut

sub list {
    my ($class, %opt) = @_;

    my @params;

    if (my $filter = delete $opt{filter} ) {
	push( @params, filter => $filter );
    }

    my $connection = $opt{connection}
		      || $class->connection
	or die "no connection active";

    my $collection_name = $class->collection_name || $class->entity_name;

    die "misconfigured class $class - has neither a collection_name or entity_name"
	unless $collection_name;

    my $adapter = $opt{adapter} || 'list'.$collection_name;
    $class->check_adapter($adapter);

    my $som = $connection->call($adapter, @params);

    my $results = $class->_get_results(
	$som,
	);

    my $rows = $class->_process_results($results, %opt);

    return [
	map { $class->construct( $_, connection => $connection) }
	@$rows
	];
}

sub _fetch {
    my ($class, $db_query, %opt) = @_;

    die "usage: ${class}->_fetch( \\%query )"
	unless (Elive::Util::_reftype($db_query) eq 'HASH');

    my $connection = $opt{connection} || $class->connection
	or die "no connection active";

    my $adapter = $opt{adapter} || 'get'.$class->entity_name;

    warn "get: entity name for $class: ".$class->entity_name.", adapter: ".$adapter
	if $class->debug;

    $class->check_adapter($adapter);

    my $som = $connection->call($adapter,
				 %$db_query);

    my $results = $class->_get_results(
	$som,
	);

    my $rows = $class->_process_results($results, %opt);
    return $rows if $opt{raw};
    #
    # 0 results => not found. Would be treated by readback as an error,
    # but perfectly valid here. Just means we didn't find a matching entity.
    #
    return []
	unless @$rows;
    #
    # Check that the return matches our query
    #
    my $read_back_query = $opt{readback} || $db_query;

    $class->_readback_check($read_back_query, $rows);
    return [map {$class->construct( $_, connection => $connection )} @$rows];
}

=head2 retrieve

    my $user = Elive::Entity::User->retrieve($user_id)

Retrieve a single entity objects by primary key.

=cut

sub retrieve {
    my ($class, $vals, %opt) = @_;

    die 'usage $class->retrieve([$val,..],%opt)'
	unless Elive::Util::_reftype($vals) eq 'ARRAY';
    
    my @key_cols = $class->primary_key;

    for (my $n = 0; $n < @key_cols; $n++) {

	die "incomplete primary key value for: $key_cols[$n]"
	    unless defined ($vals->[$n]);
    }

    my $connection = $opt{connection} || $class->connection
	or die "no connected";

    if ($opt{reuse}) {
	#
	# Have we already got the object cached? If so return it
	#
	my %pkey;
	@pkey{$class->primary_key} = @$vals;

	my $obj_url = $class->_url(
	    $connection,
	    $class->stringify(\%pkey)
	    );

	my $cached = $class->live_entity($obj_url);
	return $cached if $cached;
    }

    #
    # need to fetch it
    #
    my $all = $class->_retrieve_all($vals, %opt);

    #
    # We've supplied a full primary key, so can expect 0 or 1 values
    # to be returned.
    #
    return $all->[0];
}

# _retrieve_all() - Retrieve entity objects by partial primary key.
#
#    my $participants
#          = Elive::Entity::ParticipantList->_retrieve_all($meeting_id)
#

sub _retrieve_all {
    my ($class, $vals, %opt) = @_;

    die 'usage $class->_retrieve_all([$val,..],%opt)'
	unless Elive::Util::_reftype($vals) eq 'ARRAY';

    my @key_cols = $class->primary_key;
    my @vals = @$vals;

    my %fetch;

    while (@vals && @key_cols) {
	my $key = shift(@key_cols);
	my $val = shift(@vals);

	$fetch{$key} = $val
	    if (defined $val);
    }

    die "nothing to retrieve"
	unless (keys %fetch);

    return $class->_fetch($class->_freeze(\%fetch), %opt, mode => 'fetch');
}

=head2 delete

    $user_obj->delete;

Delete an entity from the database.

=cut

sub delete {
    my $self = shift;

    my @primary_key = $self->primary_key;
    my @id = $self->id;

    die "entity lacks a primary key - can't delete"
	unless (@primary_key > 0);

    my @params = map {
	$_ => shift( @id );
    } @primary_key;

    my $adapter = 'delete'.$self->entity_name;
    $self->check_adapter($adapter);

    my $som = $self->connection->call($adapter,
				       @params);

    my $results = $self->_get_results(
	$som,
	);

    my $rows = $self->_process_results( $results );

    #
    # Umm, we did get a read-back of the record, but the contents
    # seem to be dubious. Perform candinality checks, but don't do
    # write-back checks.
    #

    die "Didn't receive a response for ".$self->entity_name
	unless @$rows;

    die "Received multiple responses for ".$self->entity_name
	if (@$rows > 1);

    return $self->_deleted(1);
}

=head2 revert

    $user->revert                        # revert entire entity
    $user->revert(qw/loginName email/);  # revert selected properties

Revert an entity to its last constructed value.

=cut

sub revert {
    my ($self, @props) = @_;

    my $db_data = $self->_db_data
	|| die "object doesn't have db-data!? - can't cope";

    if (@props) {

	for (@props) {

	    if (exists $db_data->{$_}) {
		$self->{$_} = $db_data->{$_};
	    }
	    else {
		delete $self->{$_};
	    }
	}
    }
    else {
	%{ $self } = %{ $db_data };
    }

    return $self;
}

sub _not_available {
    my $self = shift;

    die "this operation is not available for ". $self->entity_name;
}

#
# Shared subtypes
#
BEGIN {

    subtype 'HiResDate'
	=> as 'Int'
	=> where {m{^\d+$}
		    && 
			(!$_ || length($_) > 10
			 or warn "doesn't look like a hi-res date: $_")}
        => message {"invalid date: $_"};
}

# passing some global flags through from our parent constructor:
# $Elive::_construct_opts       - this is copy don't register it as an object

sub DEMOLISH {
    my ($self) = shift;
    my $class = ref($self);

    if (my $db_data = $self->_db_data) {
	if (my @changed = $self->is_changed) {
	    my $self_string = Elive::Util::string($self);
	    warn("$class $self_string destroyed without saving or reverting changes to: "
		 . join(', ', @changed));
	}
	#
	# Destroy this objects data
	#
	$self->_db_data(undef);
    }
}

=head1 ADVANCED

=head2 Object Reuse

An in-memory object cache is used to maintain a single unique copy of
each object for each entity instance. All references to an entity instance
are unified. Hence, if you re-retrieve or re-construct the object, any other
references to the object will see the updates.

    my $user = Elive::Entity::User->retrieve([11223344]);
    #
    # returns the same reference, but refetches from the database
    #
    my $user_copy = Elive::Entity::User->retrieve([11223344]);
    #
    # same as above, however don't refetch if we already have a copy
    #
    my $user_copy2 = Elive::Entity::User->retrieve([11223344], reuse => 1);

You can access the in-memory cache using the C<live_entity> and C<live_entities>
methods.

=head2 Entity Manipulation

Through the magic of inside-out objects, all objects are simply blessed
structures that contain data and nothing else. You may choose to use the
accessors, or work directly with the object data.

The following are all equivalent, and are all ok:

    my $p_list = Elive::Entity::ParticipantList->retrieve([98765]);
    my $user = Elive::Entity::User->retrieve([11223344]);

    $p_list->participants->add($user);
    push (@{ $p_list->participants        }, $user);
    push (@{ $p_list->{participants}      }, $user);
    push (@{ $p_list->get('participants') }, $user);

=head2 Extending and Subclassing Entities

Entity instance classes are simply Mouse objects that use this class
(Elive::Entity) as base. It should be quite possible to extend existing
entity classes.

Mouse is being used instead of Moose, at this stage, it does the job, is
smaller, faster (at this stage) and has far fewer dependencies.

=cut

=head1 SEE ALSO

 Elive::Struct
 Mouse

=cut

1;
