#!perl -T
use warnings; use strict;
use Test::More tests => 12;
use Test::Exception;
use Test::Builder;
use version;

use lib '.';
use t::Elive;
use Elive::Util;

use Elive::Entity::Session;

our $t = Test::Builder->new;
our $class = 'Elive::Entity::Session' ;

ok($class->can('enableTelephony'), 'session telephony -sanity');

our $connection;

SKIP: {

    my $skippable = 11;

    my %result = t::Elive->test_connection();
    my $auth = $result{auth};

   skip ($result{reason} || 'skipping live tests', $skippable)
	unless $auth && @$auth;

    skip('Set $ELIVE_TEST_TELEPHONY to run this test', $skippable)
	unless $ENV{ELIVE_TEST_TELEPHONY};

    my $connection_class = $result{class};

    skip ($result{reason} || 'skipping live tests', $skippable)
	if $connection_class->isa('t::Elive::MockConnection');

    $connection = $connection_class->connect(@$auth);
    Elive->connection($connection);

    my $session_start = Elive::Util::next_quarter_hour();
    my $session_end = Elive::Util::next_quarter_hour( $session_start );

    $session_start .= '000';
    $session_end .= '000';

    my %session_data = (
	name => 'test session, generated by soap-session-telephony.t',
	facilitatorId => $connection->login,
	start =>  $session_start,
	end => $session_end,
    );

    my $session = $class->insert(\%session_data);
    my $session_id = $session->id;

    my %telephony_data = (
	moderatorTelephonyAddress => '(03) 5999 1234',
	moderatorTelephonyPIN   => '6342',
	participantTelephonyAddress => '(03) 5999 2234',
	participantTelephonyPIN   => '7722',
	telephonyType => 'PHONE',
	serverTelephonyAddress => '1 6999 2222',
	serverTelephonyPIN => '1234',
	enableTelephony => 1,
	);

    lives_ok(sub {$session->update(\%telephony_data)},'telephony update - lives');

    $session = undef;

    lives_ok(sub {$session = Elive::Entity::Session->retrieve($session_id)},
	     'retrieve session with telephony - lives');

    foreach (keys %telephony_data) {
	is($session->$_, $telephony_data{$_}, "session telephony: $_ - as expected");
    }

    lives_ok(sub {$session->delete},'session deletion - lives');
}

Elive->disconnect;

