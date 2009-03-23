package Elive::Entity;

use Elive;
use Data::Entity::Stored;
use base qw{Elive Data::Entity::Stored};
use Elive::Util;

use YAML;
use Scalar::Util qw{weaken};
use UNIVERSAL;

__PACKAGE__->has_metadata('_deleted');

=head1 NAME

    Elive::Entity - Abstract class for Elive Entities

=head1 DESCRIPTION

This is an abstract class that is inherited by all Elive Entity instances.

It provides a simple mapping from the objects to database entities.

=cut

=head2 construct

Construct an Elive entity.

=cut

sub construct {
    my $class = shift;
    my $data = shift;
    my %opt = @_;

    unless ($opt{copy}) {
	my $repository = (delete $opt{connection}
			  || $class->connection);

	$opt{repository} = $repository
	    if $repository;
    }

    $class->SUPER::construct($data, %opt);
}

sub _freeze {
    #
    # _freeze - construct name/value pairs for database inserts or updates
    #
    my $class = shift;
    my $data = shift;

    my %db_data = %$data;

    my @properties = $class->properties;
    my $property_types =  $class->property_types || {};

    foreach (keys %db_data) {

	die "unknown property: $_: expected: @properties"
	    unless exists $property_types->{$_};

	my ($type, $is_array, $is_entity) = Data::Entity::Util::parse_type($property_types->{$_});

	for ($db_data{$_}) {

	    for ($is_array? @$_: $_) {

		if ($is_entity) {

		    if (Scalar::Util::refaddr($_)) {

			$_ = $type->construct(Elive::Util::_clone($_),
			    copy => 1)
			    unless (Scalar::Util::blessed($_));

			$_ = $_->_stringify_self;
		    }
		}
		elsif ($type =~ m{Bool}i) {

		    #
		    # DBize boolean flags..
		    #
		    $_ =  $_ ? 'true' : 'false'
			if defined;
		}

	    }
	}
    } 

    return \%db_data;
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

    warn "path $path: response tag for $class: `$responseTag"
	if $class->debug;

    my $reftype = Elive::Util::_reftype($db_data) || 'Scalar';

    die "parsing $class: expected HASH, found $reftype, path: $path"
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

    #
    # Fix up a couple of anomolies with the fetched data versus the
    # documented schema and the operation of the rest of the system
    # (inserts, updates, querys):
    # 1. Entity names returned capitalised: 'LoginName' => 'loginName
    # 2. Primary key returned as Id, rather than <entity_name>Id
    #

    my %prop_key_map = map {ucfirst($_) => $_} @properties;

    $prop_key_map{Id} = lcfirst($class->entity_name).'Id';

    foreach my $key (keys %$entity_data) {

	my $val = $entity_data->{ $key };
	my $prop_key = $prop_key_map{$key} || $key;

	$data{$prop_key} = $val;
    }

    my $property_types = $class->property_types;

    foreach my $col (grep {exists $data{ $_ }} @properties) {

	my ($type, $expect_array, $is_entity) = Data::Entity::Util::parse_type($property_types->{$col});

	for my $val ($data{$col}) {

	    my $i = 0;

	    if ($expect_array) {

		my $val_type = Elive::Util::_reftype($val) || 'Scalar';

		unless ($val_type eq 'ARRAY') {
		    #
		    # A single value will be returned singly. Convert it to
		    # a one element array
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
		elsif ($is_entity) {

		    $_ = _thaw($type, $_, $path . $idx);

		}
		elsif ($type =~ m{Bool}i) {
		    #
		    # Perlise boolean flags..
		    #
		    $_ = m{true}i ? 1 : 0;
		}
		elsif ($type =~ m{Str}i) {
		    s{^ \s* (.*?) \s* $}{$1}x;
		}
		elsif ($type =~ m{Int}i) {
		    #
		    # well a number really. don't convert or sprintf etc
		    # to avoid overflow. Just normalise it for potential
		    # string comparisions

		    #
		    # l-r trim
		    #
		    s{^ \s* (.*?) \s* $}{$1}x;

		    #
		    # non number
		    #
		    $_ = 0 unless m{^\d+$};

		    #
		    # remove any leading zeros:
		    # +000123 => 123
                    # -00045 => -45
                    # -000 => 0
		    #
		    $_ =~ s{^
                             \+?    # leading plus -discarded 
                             (-?)   # leading minus retained (usually)
                             0*     # leading zeros discarded
                             (\d+)  # number - retained
                             $}
		            {$1$2}x;

		    $_ = 0 if ($_ eq '-0');
		}
		else {
		    die "column $col has unknown type: $type";
		}
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
	# Convert some SOAP/XML constructs to their perl equvalents
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

			$value =  $value->{Entry};
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

	    $results->{$key} =  $class->_unpack_results($value);
	}
	    
    }
    else {
	die "Unhandled type in response body: $results_type";
    }

    return $results;
}

sub _get_results {
    my $class = shift;
    my $som = shift;

    die $som->fault->{ faultstring } if ($som->fault);

    my $result = $som->result;

    warn "result: ".YAML::Dump($result)
	if ($class->debug);

    if(!Elive::Util::_reftype($result)) {
	die "unexpected SOAP response: $result";
    }
    
    #
    # Look for Elluminate-specific errors
    #
    if (my $code = $result->{Code}{Value}) {

	#
	# Elluminate error!
	#
	
	my $reason = $result->{Reason}{Text};

	my $trace = $result->{Detail}{Stack}{Trace};
	my @stacktrace;
	if ($trace) {
	    @stacktrace = (Elive::Util::_reftype($trace) eq 'ARRAY'
			   ? @$trace
			   : $trace);

	}

	my @error = grep {defined} ($code, $reason, @stacktrace);
	die join(' ', @error) || YAML::Dump($result);
    }

    my $results_list;

    $result = $class->_unpack_results($result);

    my $reftype = Elive::Util::_reftype($result);

    if ($reftype eq 'HASH') {

	$results_list = [ $result ];

    }
    elsif ($reftype eq 'ARRAY') {

	$results_list = $result;

    }
    else {

	$results_list = defined ($result)
	    ? [ $result ]
	    : [];

    }

    warn "$class result: ".YAML::Dump($result)
	if ($class->debug >= 2);

    return $results_list;
}

sub _process_results {

    my $class = shift;
    my $soap_results = shift;

    #
    # Thaw our returned SOAP responses to reconstruct the data
    # image.
    #

    my @rows;

    foreach (@$soap_results) {

	my $row = $class->_thaw( $_ );

	push(@rows, $row);
    }

    return \@rows;
}

sub _readback_check {
    my $class = shift;
    my $updates = shift;
    my $rows = shift;

    #
    # Create and upate responses generally return a copy of the
    # record, after applying the updates. This routine may be
    # run to check that the expected updates have been applied
    #

    die "Didn't receive a response for ".$class->entity_name
	unless @$rows;

    die "Received multiple responses for ".$class->entity_name
	if (@$rows > 1);

    my $row = $rows->[0];

    my $property_types = $class->property_types;

    foreach ($class->properties) {

	if (exists $updates->{$_} && exists $row->{$_}) {
	    my $write_val =  $updates->{$_};
	    my $read_val = $row->{$_};

	    if ($class->_cmp_col($_, $write_val,  $read_val)) {
		warn YAML::Dump({read => $read_val, write => $write_val})
		    if ($class->debug);

		foreach ($read_val, $write_val) {
		    bless $_, 'Data::Entity::Array'  # gives a nice stringified digest
			if (Elive::Util::_reftype($_) eq 'ARRAY');
		}
		die "Update consistancy check failed on $_. Wrote:$write_val, read-back:$read_val, column: $_"
	    }
	}
    }
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

=head2 insert

   # Construct object, then insert.
   #
   my $new_user = Elive::Entity::User->construct({userId => 12345, 
                                 loginName => 'demo_user',
                                 role => {roleId => 1},
                               });
   $new_user->insert;

   # Construct and insert in one go
   #
   my $new_user = Elive::Entity::User->insert({userId => 12345, 
                                 loginName => 'demo_user',
                                 role => {roleId => 1},
                               });

Adds a new record to the Elluminate database.

=cut

sub insert {
    my $class = shift;

    if (ref($class)) {
	my $self  = $class;
	#
	# Undo any prior deletion
	#
	$self->_deleted(0);
	return $self->_insert_class($self,@_);
    }

    return $class->_insert_class(@_);
}

sub _insert_class {
    my $class = shift;
    my $insert_data = shift;
    my %opt = @_;

    die "usage: ${class}->insert( \\%data )"
	unless (Elive::Util::_reftype($insert_data) eq 'HASH');

    my $connection = ($opt{connection}
		      || $class->connection);

    my $db_data = $class->_freeze($insert_data, mode => 'insert');

    my $login_password = $connection->pass;

    my $adapter = $opt{adapter} || 'create'.$class->entity_name;

    my $som = $connection->call($adapter,
				 %$db_data,
				 loginPassword => $login_password,
	);

    my $results = $class->_get_results(
	$som,
	);

    #
    # Check that the return response has our inserts
    #
    my $rows =  $class->_process_results( $results );
    $class->_readback_check($insert_data, $rows);

    my $self = $class->construct( $rows->[0], repository => $connection );
    return $self;
}

=head2 update

Apply our updates to the server. This call will commit outstanding
changes to the object and also apply any further updates passed
as parameters.

=head3 examples

    $obj->{foo} = 'Foo';  # change foo directly
    $foo->update;         # save

    $obj->bar('Bar');     # change bar via its accessor
    $obj->update;         # save

    # change and save foo and bar. All in one go.
    $obj->update({foo => 'Foo', bar => 'Bar'});

=cut

sub update {
    my $self = shift;
    my $update_data = shift;
    my %opt = @_;

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
    my @updated_properties = $self->is_changed;

    #
    # Nothing to update
    #
    return $self unless @updated_properties;;

    my %primary_key = map {$_ => 1} ($self->primary_key);

    my %updates;

    foreach (@updated_properties, keys %primary_key) {

	$updates{$_} = $self->{$_};

	die 'primary key field $_ updated - refusing to save'
	    if (exists $primary_key{ $_ }
		&& $self->_cmp_col($_, $self->_db_data->{ $_ }, $updates{ $_ }));
    }

    my $db_updates = $self->_freeze(\%updates, mode => 'update');

    my $adapter = $opt{adapter} || 'update'.$self->entity_name;

    my $som =  $self->connection->call($adapter,
				       %$db_updates);

    my $results = $self->_get_results(
	$som,
	);

    #
    # Check that the return response has our updates
    #
    my $rows =  $self->_process_results( $results );
    $self->_readback_check(\%updates, $rows);
    $self->set( %{ $rows->[0] } );

    #
    # Save the db image
    #
    my $db_data = $self->construct(Elive::Util::_clone($self),
	copy => 1);
    $self->_db_data($db_data);

    return $self;
}

=head2 list

    my $users = Elive::Entity::Users->list(filter => 'surname = smith')

Retrieve a list of objects from a table.

Note: this method is not applicable to Elive::Entity::MeetingParameters
or Elive::Entity::ParticipantList.

Note that 

=cut

sub list {
    my $class = shift;
    my %opt = @_;

    my @params;

    if (my $filter = $opt{filter} ) {
	push( @params, filter => $filter );
    }

    push (@params, adapter => $class->adapter || 'default');

    my $connection = ($opt{connection}
		      || $class->connection
	)
	or die "no connection active";

    my $collection_name = $class->collection_name || $class->entity_name;

    die "class $class has neither a collection_name or entity_name"
	unless $collection_name;

    my $som =  $connection->call('list'.$collection_name, @params);

    my $results = $class->_get_results(
	$som,
	);

    my $rows =  $class->_process_results( $results );

    return [
	map { $class->construct( $_, respository => $connection) }
	@$rows
	];
}

sub _fetch {
    my $class = shift;
    my $db_query = shift;
    my %opt = @_;

    die "usage: ${class}->_fetch( \\%query )"
	unless (Elive::Util::_reftype($db_query) eq 'HASH');

    my $connection = $opt{connection} || $class->connection
	or die "no connection active";

    my $adapter = $opt{adapter} || 'get'.$class->entity_name;

    warn "get: entity name for $class: ".$class->entity_name.", adapter: ".$adapter
	if $class->debug;

    my $som =  $connection->call($adapter,
				 %$db_query);

    my $results = $class->_get_results(
	$som,
	);

    my $rows = $class->_process_results( $results );
    #
    # 0 results => not found
    #
    return []
	unless @$rows;
    #
    # Check that the return matches our query
    #
    my $read_back_query = $opt{readback} || $db_query;

    $class->_readback_check($read_back_query, $rows);
    #
    # Got one!!
    #
    return [map {$class->construct( $_, repository => $connection )} @$rows];
}

=head2 retrieve

    my $user = Elive::Entity::User->retrieve($user_id)

Retrieve a single entity objects by primary key.

=cut

sub retrieve {
    my $class = shift;
    my $vals = shift;
    my %opt = @_;

    die 'usage $class->retrieve_all([$val,..],%opt)'
	unless Elive::Util::_reftype($vals) eq 'ARRAY';
    
    my @key_cols =  $class->primary_key;

    my $complete = 0;

    for (my $n = 0; $n < @key_cols; $n++) {

	die "incomplete primary key value for: $key_cols[$n]"
	    unless defined ($vals->[$n]);
    }

    my $connection = $opt{connection} || $class->connection
	or die "no connected";

    if ($opt{reuse}) {

	#
	# Have we already got the object loaded? if so return it
	#
	my $obj_url = $class->_url(
	    $connection,
	    $class->_stringify(@$vals)
	    );

	my $cached = $class->live_entity($obj_url);
	return $cached if $cached;
    }

    #
    # need to fetch it
    #
    my $all = $class->retrieve_all($vals, %opt);

    #
    # We've supplied a full primary key, so can expect 0 or 1 values
    # to be returned.
    #

    return $all->[0];
}

=head2 retrieve_all

    my $participants
          = Elive::Entity::ParticpiantList->retrieve_all($meeting_id)

Retrieve entity objects by partial primary key.

=cut

sub retrieve_all {
    my $class = shift;
    my $vals = shift;
    my %opt = @_;

    die 'usage $class->retrieve_all([$val,..],%opt)'
	unless Elive::Util::_reftype($vals) eq 'ARRAY';

    my @key_cols =  $class->primary_key;
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

Delete an entity from the datase.

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

    my $som =  $self->connection->call('delete'.$self->entity_name,
				       @params);

    my $results = $self->_get_results(
	$som,
	);

    my $rows =  $self->_process_results( $results );

    #
    # Umm, we do get a read-back of the record, but the contents
    # seem to be dubious. Peform candinality checks, but don't do
    # write-back checks.
    #

    die "Didn't receive a response for ".$self->entity_name
	unless @$rows;

    die "Received multiple responses for ".$self->entity_name
	if (@$rows > 1);

    $self->_deleted(1);
}

sub _not_available {
    my $self = shift;

    die "this operation is not available for ". $self->entity_name;
}

#
# Bring all our kids in
#
use Elive::Entity::Group;
use Elive::Entity::Meeting;
use Elive::Entity::MeetingParameters;
use Elive::Entity::Participant;
use Elive::Entity::ParticipantList;
use Elive::Entity::Recording;
use Elive::Entity::Role;
use Elive::Entity::ServerDetails;
use Elive::Entity::User;

=head1 SEE ALSO

 Entity
 Moose
 overload

=cut

1;
