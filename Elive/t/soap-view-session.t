#!perl
use warnings; use strict;
use Test::More tests => 30;
use Test::Exception;
use Test::Builder;

use lib '.';
use t::Elive;

use Carp;

use Elive;
use Elive::View::Session;

use XML::Simple;

our $t = Test::Builder->new;
our $class = 'Elive::View::Session' ;

our $connection;

SKIP: {

    my %result = t::Elive->test_connection();
    my $auth = $result{auth};

    my $connection_class = $result{class};
    skip ($result{reason} || 'skipping live tests', 30)
	if $connection_class->isa('t::Elive::MockConnection');

    $connection = $connection_class->connect(@$auth);
    Elive->connection($connection);

    my $session_start = time();
    my $session_end = $session_start + 900;

    $session_start .= '000';
    $session_end .= '000';

    my %session_data = (
	name => 'test session, generated by t/soap-view-session.t',
	facilitatorId => Elive->login->userId,
	password => 'test', # what else?
	start =>  $session_start,
	end => $session_end,
	privateMeeting => 1,
	costCenter => 'testing',
	moderatorNotes => 'test moderator notes. Here are some entities: & > <',
	userNotes => 'test user notes; some more entities: &gt;',
	recordingStatus => 'remote',
	raiseHandOnEnter => 1,
	maxTalkers => 3,
	inSessionInvitation => 1,
	boundaryMinutes => 15,
	fullPermissions => 1,
	supervised => 1,
	seats => 2,
    );

    my $session_id;

    do {

	my ($session) = $class->insert(\%session_data);

	isa_ok($session, $class, 'session');

	foreach (keys %session_data) {
	    next if $_ eq 'password';  # the password is not echoed by readback
	    is($session->$_, $session_data{$_}, "session $_ as expected");
	}

	$session_id = $session->id;

	my %update_data = (
	    costCenter => 'testing again',
	    boundaryMinutes => 30,
	    );

	$session->update(\%update_data);

	foreach (keys %update_data) {
	    is($session->$_, $update_data{$_}, "updated $_ as expected");
	}

	#
	# high level check of our aliasing. updating inSessionInvitations should
	# be equivalent to updating inSessionInvitation
	#
	lives_ok( sub {$session->update({inSessionInvitations => 0})}, "update inSessionInvitations (alias) - lives");
	ok( ! $session->inSessionInvitation, "update inSessionInvitation via alias - as expected" );
    
	do {
	    #
	    # some cursory checks on jnlp construction. Could be a lot
	    # more detailed.
	    #
	    my $sessionJNLP;
	    lives_ok(sub {$sessionJNLP = $session->buildJNLP(
			      version => '8.0',
			      displayName => 'Elive Test',
			      )},
		     '$session->buildJNLP - lives');

	    ok($sessionJNLP && !ref($sessionJNLP), 'got session JNLP');
	    lives_ok(sub {XMLin($sessionJNLP)}, 'JNLP is valid XML (XHTML)');
	};

	ok(my $web_url = $session->web_url, 'got session web_url()');

	my (@participants);

	#
	# try to gather some users as participants

	lives_ok( sub {
	    #
	    # for datasets with 1000s of entries
	    @participants = grep {$_->userId ne $session->facilitatorId} @{ Elive::Entity::User->list(filter => 'lastName = Sm*') };
	    #
	    # for modest test datasets
	    @participants = grep {$_->userId ne $session->facilitatorId} @{ Elive::Entity::User->list() }
	    unless @participants >= 2;
		  },
		  'get_users - lives');

	#
	# only want a handful
	#
	@participants = @participants[0 .. 9]
	if (@participants > 10);

	if (@participants >= 2) {
# see todo list in Elive::Entity::ParticipantList
	    lives_ok( sub {$session->update({participants => \@participants}),
		  }, 'setting participants - lives');

	    ok( @{ $session->participants } >= @participants, 'session has the expected number of participants' );
	}
	else {
	$t->skip('insufficent users to test particpants')
	    for 1 .. 2;
	}

    };

    # drop out of scope - cull objects

    do {
	#
	# start to tidy up
	#
	my %update_data = (
	    costCenter => 'testing view session',
	    boundaryMinutes => 45,
	    );

	my $session = Elive::View::Session->retrieve($session_id);
	#
	# also try a different variation of update. set properties before-hand,
	# then do a parameterless update
	#
	foreach (sort keys %update_data) {
	    $session->$_( $update_data{$_} );
	}

	$session->update;

	lives_ok(sub {$session->delete},'session deletion');

	my $deleted_session;
	eval {$deleted_session = Elive::View::Session->retrieve([$session_id])};

	ok($@ || ($deleted_session && $deleted_session->deleted),
	   'session showing as deleted');
    };
}

Elive->disconnect;

