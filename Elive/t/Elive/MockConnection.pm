package t::Elive::MockConnection;
use warnings; use strict;

use Elive::Connection;
use base 'Elive::Connection';

use Elive;
use Elive::Entity;
use Elive::Entity::User;
use Elive::Entity::ServerDetails;

use t::Elive::MockSOM;

__PACKAGE__->mk_accessors( qw{mockdb} );

sub connect {
    my ($class, $url,  $user, $pass, %opt) = @_;

    my $self = {};
    bless $self, $class;

    $url ||= 'http://elive_mock_connection';
    $url =~ s{/$}{};
    $self->url($url);

    $self->user($user);
    $self->user('test_user') unless $self->user;

    $self->pass($pass);
    $self->pass('test_pass') unless $self->pass;

    $self->mockdb({});

    Elive::Entity::User->insert(
	{loginName => $self->user,
	 loginPassword => $self->pass,
	 role => {roleId => 0},
	},
	connection => $self,
	);

    $Elive::KnownAdapters{createServerDetails} = 'c';

    Elive::Entity::ServerDetails->insert(
	{serverDetailsId => '__id__',
	 version => '9.6.0',
	 alive => 1,
	},
	connection => $self,
	);

    return $self;
}

sub call {

    my $self = shift;
    my $cmd = shift;

    my %params = @_;

    my %known_adapters = Elive->known_adapters;
    my $entities = Elive::Entity->_entities;
    #
    # Determine an operation for the command
    #
    my $crud = $known_adapters{$cmd};
    die "Uknown command $cmd in mock connection"
	unless $crud;

    my $som = bless {}, 't::Elive::MockSOM';

    if (my ($op, $entity_name) = ($cmd =~ m{^(get|create|delete|update)(.*)$})) {

	$entity_name = lcfirst($entity_name);

	if (my $entity_class = $entities->{$entity_name}) {

	    my @primary_key = @{ $entity_class->_primary_key };

	    $params{$primary_key[0]} ||= '__id__'
		if $entity_name eq 'serverDetails';

	    if ($crud eq 'c') {
		foreach my $fld (@primary_key) {
		    next if defined $params{$fld};

		    $params{$fld} = do {
			my $id;
			my $ctr;
			do {
			    $id = sprintf("%d", rand(32767));
			    die "mockup primary keys exhausted for $entity_name?"
				if (++$ctr > 10000);
			} while exists $self->mockdb->{__IDS__}{$entity_name}{$id};

			$self->mockdb->{__IDS__}{$entity_name}{$id} = $id;
		    }
		}
		$self->mockdb->{$entity_name}{ $primary_key[0] } = \%params;

		my $som = t::Elive::MockSOM->make_result($entity_class, %params);
		return $som;
	    }
	    elsif ($crud eq 'r') {
		my $data;

		if (!$params{$primary_key[0]} && $entity_name eq 'user') {

		    my $user = $params{loginName} || $params{userName};
		    #
		    # try by login name
		    #
		    if ($user) {
			($data) = grep {$_->{loginName} eq $user} values %{  $self->mockdb->{$entity_name} || {} };
			die "user not found: $user"
			    unless $data;
		    }
		    else {
			die "attempt to fetch user without loginName or userId"
		    }
		}
		else {
		    die "get without primary key: $primary_key[0]"
			unless $data || exists $params{ $primary_key[0] };
		}

		$data = $self->mockdb->{$entity_name}{ $primary_key[0] };

		die "entity not found: $entity_name/$params{$primary_key[0]}"
		    unless $data;
		return  t::Elive::MockSOM->make_result($entity_class, %$data);
	    }
	    else {
		die "unable to handle mockup for $cmd";
	    }
	}
    }

    die "tba cmd: $cmd, crud $crud";
}

1;
