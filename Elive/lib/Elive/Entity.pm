package Elive::Entity;
use warnings; use strict;
use Mouse;
use Mouse::Util::TypeConstraints;

use Elive::Struct;
use base qw{Elive::Struct};

use YAML;
use Scalar::Util qw{weaken};
use UNIVERSAL;
use Scalar::Util;

use Elive::Util;
use Elive::Array;
__PACKAGE__->has_metadata('_deleted');

=head1 NAME

    Elive::Entity - Abstract class for Elive Entities

=head1 DESCRIPTION

This is an abstract class that is inherited by all Elive Entity instances.

It provides a simple mapping from the objects to database entities.

=head2 Stringification

Database entities evalute to their primary key, when used in a string
context.

    if ($user_obj eq "11223344") {
        ....
    }

Arrays of sub-items evaluated, in a string context, to a semi-colon seperated
string of the individual values sorted.

    my $group = Elive::Entity::Group->retrieve([98765]);
    if ($group->members eq "11223344;2222222") {
         ....
    }

In particular meeting participants stringify to userId=role, eg

    my $participant_list = Elive::Entity::ParticipantList->retrieve([98765]);
    if ($participant_list->participants eq "11223344;2222222") {
         ....
    }

=cut

use overload
    '""' =>
    sub {shift->stringify}, fallback => 1;

our %Stored_Objects;

#
# create metadata properties. NB this will be stored inside out to
# ensure our object is an exact image of the data.
#

foreach my $accessor (qw/repository _db_data/) {
    __PACKAGE__->has_metadata($accessor);
}

sub _url {
    my $class = shift;
    my $repository = shift || $class->repository;
    my $path = shift;

    return ($repository->url
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
the url of the repository scring and the entity class name. It is used
internally to uniquely identify and cache objects across repositorys.

=cut

sub url {
    my $self = shift;
    return $self->_url($self->repository, $self->stringify);
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
    my $class = shift;
    my $data = shift;
    my %opt = @_;

    die "usage: ${class}->construct( \\%data )"
	unless (Elive::Util::_reftype($data) eq 'HASH');

    #
    # This method may also be called to coerce sub-entities into existance.
    # Don't seem to have any direct way of passing options through!?

    local (%Elive::_construct_opts) = %opt;

    $opt{repository} = delete $opt{connection} || $class->connection;

    my %known_properties;
    @known_properties{$class->properties} = undef;

    foreach (keys %$data) {
	warn "unknown property $_"
	    unless exists $known_properties{$_};
    }
    
    my $self = Scalar::Util::blessed($data)
	? $data
	: $class->new($data);

    return $self if ($opt{copy});

    my $repository = $opt{repository};
    #
    # Retain one copy of the data for this repository
    #
    die "can't construct objects without a repository"
	unless $repository;

    $self->repository($repository);

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
	    if $cached->is_changed;

	%{$cached} = %{$self};
	$self = $cached;
    }
    else {
	weaken ($Stored_Objects{$obj_url} = $self);
    }

    my $data_copy = Elive::Util::_clone($self);
    $data_copy->_db_data(undef);
    $self->_db_data( $data_copy );

    $self;
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

	my ($type, $is_array, $is_entity) = Elive::Util::parse_type($property_types->{$_});

	for ($db_data{$_}) {

	    for ($is_array? @$_: $_) {

		if ($is_entity) {

		    if (Scalar::Util::refaddr($_)) {

			$_ = $type->new(Elive::Util::_clone($_))
			    unless (Scalar::Util::blessed($_));

			$_ = $_->stringify;
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

	my ($type, $expect_array, $is_entity) = Elive::Util::parse_type($property_types->{$col});

	for my $val ($data{$col}) {

	    my $i = 0;

	    if ($expect_array) {

		my $val_type = Elive::Util::_reftype($val) || 'Scalar';

		unless ($val_type eq 'ARRAY') {
		    #
		    # A single value will be deserialise to a simple
		    # struct. Convert it to a one element array
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
		    die "class $class: column $col has unknown type: $type";
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

sub _check_for_errors {
    my $class = shift;
    my $som = shift;

    die $som->fault->{ faultstring } if ($som->fault);

    my $result = $som->result;

    warn "result: ".YAML::Dump($result)
	if ($class->debug);

    if(!Elive::Util::_reftype($result)) {
	#
	# Simple scalar
	#
	return;
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
}

sub _get_results {
    my $class = shift;
    my $som = shift;

    $class->_check_for_errors($som);

    my $results_list;

    my $result = $class->_unpack_results($som->result);

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
    my %opt = @_;

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
		    bless $_, 'Elive::Array'  # gives a nice stringified digest
			if (Elive::Util::_reftype($_) eq 'ARRAY');
		}
		die "Update consistancy check failed on $_. Wrote:$write_val, read-back:$read_val, column: $_"
	    }
	}
    }

    return $row;
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

    my ($type, $is_array, $is_def) = Elive::Util::parse_type($class->property_types->{$col});
    my @v1 = ($is_array? @$_v1: ($_v1));
    my @v2 = ($is_array? @$_v2: ($_v2));

    if ($is_def) {
	#
	# Normalise objects and references to simple strings
	#
	for (@v1, @v2) {
	    #
	    # autobless references
	    if (Scalar::Util::refaddr($_)) {

		$_ = $type->construct(Elive::Util::_clone($_))
		    unless (Scalar::Util::blessed($_));

		$_ = $_->stringify;
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

	    if ($is_def || $type =~ m{Str}i) {
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
		die "class $class: column $col has unknown type: $type";
	    }
	}
    }
    return $cmp;
}

=head2 is_changed

    Return  a list of properties that have uncommited changes.

=cut

sub is_changed {

    my $self = shift;

    my @updated_properties;
    my $db_data = $self->_db_data;

    #
    # not mapped to a stored data value. either a scratch object or
    # sub entity.
    #
    return unless ($db_data);

    foreach my $col ($self->properties) {

	my $new = $self->$col;
	my $old = $db_data->$col;
	if (defined ($new) != defined ($old)
	    || Elive::Util::_reftype($new) ne Elive::Util::_reftype($old)
	    || $self->_cmp_col($col,$new,$old)) {

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

    if (my $_class = ref($class)) {
	my $self  = $class;
	$class = $_class;
	#
	# Undo any prior deletion
	#
	$self->_deleted(0);
	return $class->_insert_class($self,@_);
    }

    return $class->_insert_class(@_);
}

sub _readback {
    my $class = shift;
    my $som = shift;
    my $sent_data = shift;
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
    my $rows =  $class->_process_results( $results );
    my $row = $class->_readback_check($sent_data, $rows);

    return $row;
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

    $class->check_adapter($adapter);

    my $som = $connection->call($adapter,
				%$db_data,
				%{$opt{param} || {}},
				loginPassword => $login_password,
	);

    my $row = $class->_readback($som, $insert_data);

    my $self = $class->construct( $row, repository => $connection );
    return $self;
}

=head2 live_entity

Entity has already been loaded. Return it for reuse.

=cut

sub live_entity {
    my $class = shift;
    my $url = shift;

    return $Stored_Objects{ $url };
}

=head2 live_entities

Return the list of live entities

=cut

sub live_entities {
    my $class = shift;
    return \%Stored_Objects;
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

    $self->check_adapter($adapter);

    my $som =  $self->connection->call($adapter,
				       %$db_updates,
				       %{$opt{param} || {}},
);

    my $row = $self->_readback($som, \%updates);
    $self->set($row);

    #
    # Save the db image
    #
    my $db_data = $self->construct(Elive::Util::_clone($self),
	copy => 1);
    #
    # Make sure our db data hasn't got db data!
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
    my $class = shift;
    my %opt = @_;

    my @params;

    if (my $filter = $opt{filter} ) {
	push( @params, filter => $filter );
    }

    my $connection = ($opt{connection}
		      || $class->connection
	)
	or die "no connection active";

    my $collection_name = $class->collection_name || $class->entity_name;

    die "class $class has neither a collection_name or entity_name"
	unless $collection_name;

    my $adapter = $opt{adapter} || 'list'.$collection_name;
    $class->check_adapter($adapter);

    my $som =  $connection->call($adapter, @params);

    my $results = $class->_get_results(
	$som,
	);

    my $rows =  $class->_process_results($results, %opt);

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

    $class->check_adapter($adapter);

    my $som =  $connection->call($adapter,
				 %$db_query);

    my $results = $class->_get_results(
	$som,
	);

    my $rows = $class->_process_results($results, %opt);
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

    die 'usage $class->retrieve([$val,..],%opt)'
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
	    $class->stringify(@$vals)
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

    my $adapter = 'delete'.$self->entity_name;
    $self->check_adapter($adapter);

    my $som =  $self->connection->call($adapter,
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

=head2 revert

    $user->revert                        # revert entire entity
    $user->revert(qw/loginName email/);  # revert selected properties

Revert an entity to its last constructed value.

=cut

sub revert {
    my $self = shift;
    my @props = @_;

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
# Bring all our kids in
#
use Elive::Entity::Group;
use Elive::Entity::Meeting;
use Elive::Entity::MeetingParameters;
use Elive::Entity::Participant;
use Elive::Entity::ParticipantList;
use Elive::Entity::Preload;
use Elive::Entity::Recording;
use Elive::Entity::Role;
use Elive::Entity::ServerDetails;
use Elive::Entity::User;

#------ Coercion Rules

# passing some global flags through from our parent conastructor:
# $Elive::_construct_opts       - this is copy don't register it as an abject

#coerce 'Elive::Array' => from 'ArrayRef[Int]'
#          => via {Elive::Array->new($_)};


coerce 'Elive::Entity::Role' => from 'HashRef'
          => via { Elive::Entity::Role->new($_) };

coerce 'Elive::Entity::User' => from 'HashRef'
          => via { Elive::Entity::User->construct($_, %Elive::_construct_opts) };

=head2 DEMOLISH

Standard Moose/Mouse object destructor. Destroying an object with unsaved
changes produces a warning. Call the revert method to suppress this.

=cut

sub DEMOLISH {
    my ($self) = shift;
    my $class = ref($self);

    if (my $db_data = $self->_db_data) {
	if (my @changed = $self->is_changed) {
	    warn("$class $self destroyed without saving changes to: "
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

A single unique object is mained for each entity instance. if you re-retrieve
or re-construct the object, any other copies of the object are also upated.

    my $user = Elive::Entity::User->retrieve([11223344]);
    #
    # returns another reference to user, but refetches from the database
    #
    my $user_copy = Elive::Entity::User->retrieve([11223344]);
    #
    # same as above, however don't refetch if we already have a copy
    #
    my $user_copy2 = Elive::Entity::User->retrieve([11223344], reuse => 1);

=head2 Entity Manipulation

Through the magic of inside-out objects, all objects are simply blessed
structures that contain data and nothing else. You may choose to use the
accessors, or work directly with the object data.

The following are all equivalent, and all ok:

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

=cut

=head1 SEE ALSO

 Elive::Struct
 Mouse
 overload

=cut

1;
