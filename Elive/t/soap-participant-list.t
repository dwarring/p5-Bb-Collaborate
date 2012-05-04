#!perl -T
use warnings; use strict;
use Test::More tests => 38;
use Test::Fatal;
use Test::Warn;

use List::Util;

use lib '.';
use t::Elive;

use Carp;
use version;

use Elive;
use Elive::Entity::ParticipantList;
use Elive::Entity::Meeting;
use Elive::Entity::User;
use Elive::Entity::Group;
use Elive::Util;
use Try::Tiny;

our $t = Test::More->builder;
our $class = 'Elive::Entity::Meeting' ;

use Pod::Usage;
use Getopt::Long qw{};

=head1 NAME

soap-participant-list.t - elm 2.x participant tests (setParticipant etc)

=head1 SYNOPSIS

  prove --lib -v soap-participant-list.t :: \ #<opts>
    -[no]unknowns         # include unknown users in the stress test
    -timeout=sec          # set a timeout on the soap call
    -participant_limit=n  # max no. of participants in the stress-test

=cut
 
my $unknowns = 1;
my $participant_limit = $ENV{ELIVE_TEST_PARTICIPANT_LIMIT} || 500;
my $timeout_sec = $ENV{ELIVE_TEST_PARTICIPANT_TIMEOUT} || 120;

Getopt::Long::GetOptions('u|unknowns!' => \$unknowns,
			 't|timeout=i' => \$timeout_sec,
			 'p|participant_limit=i' => \$participant_limit,
    ) or pod2usage(2);

our $connection;

SKIP: {

    my %result = t::Elive->test_connection( only => 'real', timeout => $timeout_sec);
    my $auth = $result{auth};

    skip ($result{reason} || 'skipping live tests', 38)
	unless $auth;

    my $connection_class = $result{class};
    my $connection = $connection_class->connect(@$auth);
    Elive->connection($connection);
    #
    # - ELM 3.3.4 / 10.0.2 - includes significant bug fixes

    my $server_details =  Elive->server_details
	or die "unable to get server details - are all services running?";
    our $version = version->declare( $server_details->version )->numify;

    our $version_10_0_1 = version->declare( '10.0.1' )->numify;
    our $elm_3_3_4_or_higher =  $version >= $version_10_0_1;

    our $version_11_1_2 = version->declare( '11.1.2' )->numify;
    our $elm_3_5_0_or_higher =  $version >= $version_11_1_2;

    my $meeting_start = time();
    my $meeting_end = $meeting_start + 900;

    $meeting_start .= '000';
    $meeting_end .= '000';

    my %meeting_data = (
	name => 'test meeting, generated by t/soap-participant-list.t',
	facilitatorId => Elive->login->userId,
	password => 'test', # what else?
	start =>  $meeting_start,
	end => $meeting_end,
	privateMeeting => 1,
    );

    my ($meeting) = $class->insert(\%meeting_data);

    isa_ok($meeting, $class, 'meeting');

    my $participants_deep_ref = [{user => Elive->login->userId,
				  role => 2}];
    #
    # NB. not neccessary to insert prior to update, but since we allow it
    is(
	exception {my $_p = Elive::Entity::ParticipantList->insert(
		 {meetingId => $meeting->meetingId,
		  participants => $participants_deep_ref});
	     note ("participants: ".$_p->participants->stringify);
	} => undef,
	'insert of participant deep list - lives');

    my $participant_list = Elive::Entity::ParticipantList->retrieve($meeting->meetingId);

    isa_ok($participant_list, 'Elive::Entity::ParticipantList', 'participant_list');
    is($participant_list->participants->stringify, Elive->login->userId.'=2',
       'participant deep list - set correctly');

    $participant_list->participants([Elive->login->userId.'=1']);
    is($participant_list->participants->stringify, Elive->login->userId.'=1',
       'participant shallow list - set correctly');

    is( exception {$participant_list->update()} => undef, 'participant list update - lives');
    is($participant_list->participants->stringify, Elive->login->userId.'=2',
       'participant list update - has reset moderator privileges');

    $participant_list->update({participants => Elive->login->userId.'=2'});

    note ("participants=".$participant_list->participants->stringify);

    is($participant_list->participants->stringify, Elive->login->userId.'=2',
       'participant string list - set correctly');

    #
    # lets grab some volunteers from the audience!
    #
    my ($participant1, $participant2, @participants);

    is( exception {
	#
	# for datasets with 1000s of entries
	($participant1,$participant2, @participants) = grep {$_->userId ne $meeting->facilitatorId} @{ Elive::Entity::User->list(filter => 'lastName = Sm*') };

	# for middle sized datasets
	($participant1,$participant2, @participants) = grep {$_->userId ne $meeting->facilitatorId} @{ Elive::Entity::User->list(filter => 'lastName = S*') }
	unless @participants+2 >= $participant_limit;
	#
	# for modest test datasets
	($participant1,$participant2, @participants) = grep {$_->userId ne $meeting->facilitatorId} @{ Elive::Entity::User->list() }
	    unless @participants+2 >= $participant_limit;
	      } => undef,
	      'get_users - lives');

    #
    # only want a handful
    #
    my @participants_sample = @participants > 10
	? @participants[0 .. 9]
	: @participants;

    if ($participant2) {

	$participant_list->participants->add($participant1->userId.'=3');

	is( exception {$participant_list->update} => undef, 'adding participant - lives');

	ok(!$meeting->is_moderator( $participant1), '!is_moderator($participant1)');

	ok((grep {$_->user->userId eq $participant1->userId} @{ $participant_list->participants }), 'participant 1 found in participant list');
	ok((grep {$_->user->userId eq $participant1->userId && $_->role->roleId == 3} @{ $participant_list->participants }), 'participant 1 is not a moderator');

	$participant_list->participants->add($participant2->userId.'=3');
	$participant_list->update();

      TODO: {
          #
          # is_participant() give variable results on various ELM versions
          # ELM 3.0 - 3.3.4 under LDAP - best to treat is as broken
          #
	  local($TODO) = 'reliable - is_participant()';

	  ok($meeting->is_participant( $participant1), 'is_participant($participant1)');
	  ok($meeting->is_participant( $participant2), 'is_participant($participant2)');
	}

 	ok(!$meeting->is_moderator( $participant2), '!is_moderator($participant2)');

	ok((grep {$_->user->userId eq $participant2->userId} @{ $participant_list->participants }), 'participant 2 found in participant list');
	ok((grep {$_->user->userId eq $participant2->userId && $_->role->roleId == 3} @{ $participant_list->participants }), 'participant 2 is not a moderator');

    }
    else {
	$t->skip('unable to find any other users to act as participants(?)',)
	    for (1..9);
    }

    # indirect  detection of LDAP integration. We can expect the
    # userId to be mapped to the loginName

    my $looks_like_ldap = $participant2 && $participant2->userId eq $participant2->loginName;
    if ($looks_like_ldap && $elm_3_5_0_or_higher) {
	#
	# Check the following newer features
	# 1. passing participants by name
	# 2. case insensitivity of usernames
	# NB under LDAP loginName :== userId
	$participant_list->reset();
	$participant_list->participants->add(Elive::Entity::User->quote($participant1->loginName).'=3');
	is(exception {$participant_list->update()} => undef, 'adding participant by loginName - lives');
	ok((grep {$_->user->userId eq $participant1->userId} @{ $participant_list->participants }), 'participant by loginName - found in participant list');

	my $login_name_toggled = join('', map {$_ =~ m{[A-Z]}? lc: uc} split('', $participant2->loginName));

	$participant_list->reset();
	$participant_list->participants->add(Elive::Entity::User->quote($login_name_toggled).'=3');
	is(exception {$participant_list->update()} => undef, 'participant by loginName (case insensitive - lives');
	ok((grep {$_->user->userId eq $participant2->userId} @{ $participant_list->participants }), 'participant by loginName (case insensitive) - found in participant list');
    }
    else {
	$t->skip("skipping ldap specific tests")
	    for (1..4);
    }

    $participant_list->reset();

    if (@participants) {
	is( exception {$participant_list->update({participants => \@participants_sample}) => undef,
		  } => undef, 'setting up a larger meeting - lives');
    }
    else {
	$t->skip('insufficent users to run large meeting tests');
    }

    ok($meeting->is_participant( Elive->login), 'is_participant($moderator)');
    ok($meeting->is_moderator( Elive->login), 'is_moderator($moderator)');

    my $gate_crasher = 'gate_crasher_'.t::Elive::generate_id();

    ok(!$meeting->is_participant( $gate_crasher ), '!is_participant($gate_crasher)');
    ok(!$meeting->is_moderator( $gate_crasher ), '!is_moderator($gate_crasher)');

    isnt( exception {
	$participant_list->participants->add($gate_crasher.'=3');
	$participant_list->update($gate_crasher.'=3');
	    } => undef,
	    'add of unknown participant - dies');

    is( exception {$participant_list->update({participants => []})} => undef,
	     'clearing participants - lives');

    my $p = $participant_list->participants;

    #
    # check our reset policy. Updating/creating an empty participant
    # list is effectively the same as a reset. Ie, we end up with
    # the facilitator as the sole participant, with a role of moderator (2).
    #

    is(@$p, 1, 'participant_list reset - single participant');

    is($p->[0]->user && $p->[0]->user->userId, $meeting->facilitatorId,
       'participant_list reset - single participant is the facilitator');

    is($p->[0]->role && $p->[0]->role->roleId, 2,
       'participant_list reset - single participant has moderator role');

    if (! $elm_3_3_4_or_higher ) {
	#
	# The next test verifies bug fixes under ELM 3.3.4/10.0.2. It probably
	# wont work with 10.0.1 or earlier.
	#
	$t->skip('skipping participant long-list test for Elluminate < v10.0.2')
	    for (1..2);
    }
    elsif ( !$participant2 )  {
	$t->skip('not enough participants to run long-list test')
	    for (1..2);
    }
    else { 
	#
	# stress test underlying setParticipantList command we need to do a direct SOAP
	# call to bypass overly helpful readback checks and removal of duplicates.
	#
	my @big_user_list;
	my %expected_users = ($meeting->facilitatorId => 1);

      MAKE_BIG_LIST:
	while (1) {
	    foreach ($participant1, $participant2, @participants) {
		#
		# include a smattering of unknown users
		#
		if ($unknowns && rand() < .1) {
		    #
		    # include a smattering of random unknown users
		    #	
		    my $unknown_user = t::Elive::generate_id();

		    push (@big_user_list, $unknown_user);
		}

		$expected_users{$_->userId}++;
		push (@big_user_list, $_->userId);

		last MAKE_BIG_LIST
		    if @big_user_list >= $participant_limit;
	    }
	}

	note sprintf('stress testing with %d participants (timeout %d sec)...', scalar @big_user_list, $timeout_sec);
	#
	# low level test that the setParticipantList adapter will accept
	# a long list. was a problem prior to elm 3.3.4
	#

	do {
	    is( exception {
		my $participants_str = join(';', 
						Elive->login->userId.'=2',
						map {$_.'=3'} @big_user_list
		    );

		note "participants in: $participants_str";

		# this can hang - add a timeout
		local $SIG{ALRM} = sub { die "test failed to complete after $timeout_sec seconds\n" };
		alarm $timeout_sec;
		my $som = $connection->call('setParticipantList' => (meetingId => $meeting->meetingId, users => $participants_str));
		alarm 0;

		$connection->_check_for_errors( $som );
		} => undef,
		'participants long-list test - lives'
		);
	    #
	    # refetch the participant list and check that all real users
	    # are present
	    #

	    $participant_list = Elive::Entity::ParticipantList->retrieve($meeting->meetingId);
	    my $participants = $participant_list->participants;

	    my @actual_users = sort map {$_->user->userId} @$participants;
	    note "actual users: @actual_users";

	    my %users_out;
	    @users_out{ @actual_users } = undef;

	    is_deeply(\@actual_users, [sort keys %expected_users], "participant list as expected (no repeats or unknown users)")
		or do {

		    foreach (sort keys %expected_users) {
			diag "\t - user $_ has not been accepted as a participant"
			    unless exists $users_out{ $_ }
		    }

		    foreach (sort keys %users_out) {
			diag "\t - user $_ has popped up, out of nowhere!?"
			    unless exists $expected_users{ $_ }
		    }
	    };
	}
    }

    my $group;
    my @groups;
    my $group_member;
    #
    # test groups of participants
    #
    is( exception {
	@groups = @{ Elive::Entity::Group->list() } } => undef,
	'list all groups - lives');

    splice(@groups, 10) if @groups > 10;

    my $invited_guest = 'Robert(bob@acme.org)';
    if (Elive->debug) {
	$t->skip('debugging enable - wont check for warnings');
    }
    else {
	warnings_like(sub {$participant_list->update({ participants => [$participant1, $invited_guest]})}, qr{ignoring}, 'participant guest - "ignored" warning under elm 2.x');
    }
    #
    # you've got to refetch the group to populate the list of recipients
    ($group) = List::Util::first {$_->retrieve($_); @{ $_->members } } @groups;

    if ($group) {
	if (Elive->debug) {
	    $t->skip('debugging enable - wont check for warnings');
	}
	else {
	    note "using group ".$group->name;
	    warnings_like(sub {$participant_list->update({ participants => [$participant1, $group]})}, qr{client side expansion}, 'participant groups - expansion warning under elm 2.x');
	}
    }
    else {
	$t->skip('no candidates found for group tests');
    }

    #
    # tidy up
    #

    is( exception {$meeting->delete} => undef, 'meeting deletion - lives');
}

Elive->disconnect;

