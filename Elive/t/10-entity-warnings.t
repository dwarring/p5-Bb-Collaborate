#!perl -T
use warnings; use strict;
use Test::More tests => 11;
use Test::Warn;

use Elive;
use Elive::Connection;
use Elive::Entity;
use Elive::Entity::User;
use Elive::Entity::Meeting;
use Elive::Entity::Preload;
use Elive::Entity::Recording;

Elive->connection(Elive::Connection->connect('http://test.org'));

my $meeting;

warnings_like (sub {$meeting = meeting_with_lowres_dates()},
	      qr{doesn't look like a hi-res date},
	      'low-res dates gives warning'
    );

warnings_like (\&do_unsaved_update,
	      qr{destroyed without saving .* changes},
	      'unsaved change gives warning'
    );

my $user_1;

warnings_like(
    sub {$user_1 = construct_unknown_property()},
    qr{unknown property},
    'constructing unknown property gives warning',
    );

ok(!(exists $user_1->{junk1}),"construct discards unknown property");

my $user_2;

warnings_like(
sub {$user_2 = set_unknown_property()},
    qr{unknown property},
    "setting unknown property gives warning"
    );

ok(!(exists $user_2->{junk2}),"set discards unknown property");

my $thawed_data;

my $preload_data = {
    PreloadAdapter => {
	Id => '1122334455667',
	Name => 'test.bin',
	Type => 'MEdia',
	Mimetype => 'application/octet-stream',
	OwnerId => '123456789000',
	Size => 42,
    },
};

$thawed_data = Elive::Entity::Preload->_thaw($preload_data);
ok($thawed_data->{type} eq 'media', "valid media type conversion");

warnings_like(
    sub {$thawed_data = thaw_with_bad_preload_type($preload_data)},
    qr(ignoring unknown media type),
    "thawing unknown media type gives warning"
    );

ok(!exists $thawed_data->{type}, "unknown media type filtered from data");

my $meeting_parameter_data = {
    MeetingParametersAdapter => {
	Id => '11111222233334444',
	RecordingStatus => 'rEMoTE',
    },
};

$thawed_data = Elive::Entity::MeetingParameters->_thaw($meeting_parameter_data);
ok($thawed_data->{recordingStatus} eq 'remote', "valid recording status conversion");

warnings_like(
    sub {$thawed_data = thaw_with_bad_recording_status($meeting_parameter_data)},
    qr(ignoring unknown recording status),
    "thawing unknown media type gives warning"
    );

exit(0);

########################################################################

sub meeting_with_lowres_dates {

    my $meeting = Elive::Entity::Meeting->construct
	({
	    meetingId => 11223344,
	    name => 'test meeting',
	    start => '1234567890',  #too short
	    end => '1244668890000', #good
         },
	);
}

sub do_unsaved_update {

    my $user = Elive::Entity::User->construct
	({
	    userId => 123456,
	    loginName => 'some_user',
	    loginPassword => 'some_pass',
         },
	);

    $user->loginName($user->loginName . 'x');
    $user = undef;
}

sub construct_unknown_property {
    my $user = Elive::Entity::User->construct
	({  userId => 1234,
	    loginName => 'user',
	    loginPassword => 'pass',
	    junk1 => 'abc',
	 });

    return $user;
}

sub set_unknown_property {
    my $user = Elive::Entity::User->construct
	({  userId => 5678,
	    loginName => 'user',
	    loginPassword => 'pass',
	});
    $user->set(junk2 => 'xyz');
    return $user;
}

sub thaw_with_bad_preload_type {
    my $preload_data = shift;

    local $preload_data->{PreloadAdapter}{Type} = 'guff';

    return Elive::Entity::Preload->_thaw($preload_data);
}

sub thaw_with_bad_recording_status {
    my $preload_data = shift;

    local $preload_data->{MeetingParametersAdapter}{RecordingStatus} = 'guff';

    return Elive::Entity::MeetingParameters->_thaw($preload_data);
}
