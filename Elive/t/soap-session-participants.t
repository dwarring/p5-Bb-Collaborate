#!perl -T
use warnings; use strict;
use Test::More tests => 30;
use Test::Fatal;
use Test::Builder;
use List::Util;

use lib '.';
use t::Elive;

use Carp; $SIG{__DIE__} = \&Carp::confess;
use version;

use Elive;
use Elive::Entity::ParticipantList;
use Elive::Entity::Session;
use Elive::Entity::User;
use Elive::Entity::Group;
use Elive::Util;

our $t = Test::Builder->new;
our $class = 'Elive::Entity::Session' ;

our $connection;

SKIP: {

    my %result = t::Elive->test_connection( only => 'real');
    my $auth = $result{auth};

    my $skippable = 30;

    skip ($result{reason} || 'skipping live tests', $skippable)
	unless $auth;

    my $connection_class = $result{class};
    my $connection = $connection_class->connect(@$auth);
    Elive->connection($connection);

    my $min_version = '9.5.0';
    my $min_version_num = version->new($min_version)->numify;
    my $server_details =  Elive->server_details
	or die "unable to get server details - are all services running?";

    my $server_version = $server_details->version;
    my $server_version_num = version->new($server_version)->numify;

    if ($server_version_num < $min_version_num) {
	my $reason = "Sessions not available for Elluminate Live $server_version (< $min_version)"; 
	diag "Skipping session tests: $reason";
	skip($reason, $skippable)
    }


    #
    # ELM 3.3.4 / 10.0.2 includes significant bug fixes
    our $elm_3_3_4_or_better =  (version->declare( $connection->server_details->version )->numify
				 > version->declare( '10.0.1' )->numify);

    my $session_start = time();
    my $session_end = $session_start + 900;

    $session_start .= '000';
    $session_end .= '000';

    my $participants_deep_ref = [{user => Elive->login->userId,
				  role => 2}];

    is_deeply($class->_freeze({participants => $participants_deep_ref}),
	      {invitedGuests => '',
	       invitedModerators =>  Elive->login->userId,
	       invitedParticipantsList => '',
	      }, 'freeze single participating user');

    my %session_data = (
	name => 'test session, generated by t/soap-session-participants.t',
	facilitatorId => Elive->login->userId,
	password => 'test', # what else?
	start =>  $session_start,
	end => $session_end,
	privateMeeting => 1,
	participants => $participants_deep_ref,
    );

    my ($session) = $class->insert(\%session_data);

    isa_ok($session, $class, 'session');

    my $participant_list = $session->participantList;

    isa_ok($participant_list, 'Elive::Entity::ParticipantList', '$session->participants');
    is($participant_list->participants->stringify, Elive->login->userId.'=2',
       'insert of single user participant');
    #
    # lets grab some volunteers from the audience!
    #
    my ($participant1, $participant2, @participants);

    is( exception {
	#
	# for datasets with 1000s of entries
	($participant1, $participant2, @participants) = grep {$_->userId ne $session->facilitatorId} @{ Elive::Entity::User->list(filter => 'lastName = Sm*') };
	#
	# for modest test datasets
	($participant1, $participant2, @participants) = grep {$_->userId ne $session->facilitatorId} @{ Elive::Entity::User->list() }
	    unless @participants;
	      } => undef,
	      'get_users - lives');

    note 'got '.(scalar @participants).' participants';

    #
    # only want a handful
    #
    my @participants_sample = @participants > 10
	? @participants[0 .. 9]
	: @participants;

    if (@participants) {

	$session->participants->add($participant1->userId.'=3');

	is( exception {$session->update} => undef, 'setting of participant - lives');

	ok(!$session->is_moderator( $participant1), '!is_moderator($participant1)');

	ok((grep {$_->user->userId eq $participant1->userId} @{ $session->participants }), 'participant 1 found in participant list');
	ok((grep {$_->user->userId eq $participant1->userId && $_->role->roleId == 3} @{ $session->participants }), 'participant 1 is not a moderator');

	$session->participants->add($participant2->userId.'=3');
	$session->update();

      TODO: {
          #
          # is_participant() give variable results on various ELM versions
          # ELM 3.0 - 3.3.4 under LDAP - best to treat is as broken
          #
	  local($TODO) = 'reliable - is_participant()';
	  
	  ok($session->is_participant( $participant1), 'is_participant($participant1)');
	  ok($session->is_participant( $participant2), 'is_participant($participant2)');
	}

 	ok(!$session->is_moderator( $participant2), '!is_moderator($participant2)');

	ok((grep {$_->user->userId eq $participant2->userId} @{ $session->participants }), 'participant 2 found in participant list');
	ok((grep {$_->user->userId eq $participant2->userId && $_->role->roleId == 3} @{ $session->participants }), 'participant 2 is not a moderator');

    }
    else {
	$t->skip('unable to find any other users to act as participants(?)',)
	    for (1..9);
    }

    $session->revert();

    if (@participants_sample) {
	is( exception {$session->update({participants => \@participants_sample}) => undef,
		  } => undef, 'setting up a larger session - lives');
    }
    else {
	$t->skip('insufficient users to run large session tests');
    }

    ok($session->is_participant( Elive->login), 'is_participant($moderator)');
    ok($session->is_moderator( Elive->login), 'is_moderator($moderator)');

    my $gate_crasher = 'gate_crasher_'.t::Elive::generate_id();

    ok(!$session->is_participant( $gate_crasher ), '!is_participant($gate_crasher)');
    ok(!$session->is_moderator( $gate_crasher ), '!is_moderator($gate_crasher)');

    isnt( exception {
	$session->participants->add($gate_crasher.'=3');
	$session->update($gate_crasher.'=3');
	    } => undef,
	    'add of unknown participant - dies');

    is( exception {$session->update({participants => []})} => undef,
	     'clearing participants - lives');

    my $p = $session->participants;

    #
    # check our reset policy. Updating/creating an empty participant
    # list is effectively the same as a reset. Ie, we end up with
    # the facilitator as the sole participant, with a role of moderator (2).
    #

    is(@$p, 1, 'participant_list reset - single participant');

    is($p->[0]->user && $p->[0]->user->userId, $session->facilitatorId,
       'participant_list reset - single participant is the facilitator');

    is($p->[0]->role && $p->[0]->role->roleId, 2,
       'participant_list reset - single participant has moderator role');

    if ( !$participant2 )  {
	$t->skip('not enough participants to run long-list test')
	    for (1 .. 3);
    }
    else { 
	#
	# stress test underlying setParticipantList command we need to do a direct SOAP
	# call to bypass overly helpful readback checks and removal of duplicates.
	#
	my @big_user_list;
	my %expected_users = ($session->facilitatorId => 1);
	my %expected_guests;

      MAKE_BIG_LIST:
	while (1) {
	    foreach my $user ($participant1, $participant2, @participants) {

		if (rand() < .1) {
		    #
		    # include a smattering of random invited guests
		    #	
		    my $guest_name = t::Elive::generate_id();
		    my $guest_spec = sprintf('%s@test.org (%s)', $guest_name, lc $ guest_name );
		    $expected_guests{$guest_spec}++;

		    push (@big_user_list, $guest_spec);
		}

		$expected_users{$user->userId}++;
		push (@big_user_list, $user->userId);

		last MAKE_BIG_LIST
		    if @big_user_list > 500;
	    }
	}

	is( exception {
	  $session->update( {participants => [
				-moderators => Elive->login,
				-others => @big_user_list
				 ] } )
		  } => undef, 'session participants long-list - lives'
	      );

	#
	# refetch the participant list and check that all real users
	# are present
	#
	my @users_in =  (Elive->login, $participant1, $participant2, @participants);
	my @user_ids_in = map {$_->userId} @users_in;

	#
	# retrieve via elm 2.x getParticipantList command
	#
	$participant_list = Elive::Entity::ParticipantList->retrieve($session->id, copy => 1);
	my $participants = $participant_list->participants;

	my @actual_users;
	my @actual_guests;

	foreach my $participant (@$participants) {

	    if (! $participant->type ) { # simple user
		push( @actual_users, $participant->user->stringify );
	    }
	    elsif ($participant->type == 2) { # invited guest
		
		push( @actual_guests, $participant->guest->stringify );
	    }
	    else {
		die "unexpected participant type: ".$participant->type;
	    }
	}

	is_deeply([ sort @actual_users], [sort keys %expected_users], "user participant users as expected");

	is_deeply([ sort @actual_guests], [sort keys %expected_guests], "participant guests as expected");
    }

    my @groups;
    my $group_member;
    #
    # test groups of participants
    #
    is( exception {
	@groups = @{ Elive::Entity::Group->list() } } => undef,
	'list all groups - lives');

    splice(@groups, 10) if @groups > 10;

    #
    # you've got to refetch the group to populate the list of recipients
    my ($group1, $group2) = List::Util::first {$_->retrieve($_); @{ $_->members } } @groups;

    if ($group1 && $group2) {
	my $invited_guest = 'Robert(bob)';
	note "using groups: <".$group1->name.">, <".$group2->name.">";
	is( exception {$session->update({ participants => [$group1, $group2, $participant1, $invited_guest]})} => undef, 'setting of participant groups - lives');
    }
    else {
	$t->skip('no candidates found for group tests');
    }

    #
    # tidy up
    #

    is( exception {$session->delete} => undef, 'session deletion - lives');
}

Elive->disconnect;

