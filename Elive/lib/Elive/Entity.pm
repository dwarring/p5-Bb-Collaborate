package Elive::Entity;
use warnings; use strict;
use Mouse;
use Mouse::Util::TypeConstraints;

extends 'Elive::DAO';

=head1 NAME

    Elive::Entity - Base class for Elive Entities

=head1 DESCRIPTION

This class implements the default Elluminate live SDK.

=cut

our %KnownAdapters = (

	addGroupMember => 'c',
	addMeetingPreload => 'c',
	addReport => 'c',

	attendanceNotification => 'r',

	changePassword => 'u',

	buildMeetingJNLP => 'r',
	buildRecordingJNLP => 'r',
        buildReport => 'r',

	checkMeetingPreload => 'r',

	createGroup => 'c',
	createMeeting => 'c',
	createPreload => 'c',
	createRecording => 'c',
	createUser => 'c',

	deleteGroup => 'd',
	deleteMeeting => 'd',
	deleteMeetingPreload => 'd',
	deleteParticipant => 'd',
	deleteRecording => 'd',
	deleteReport => 'd',
	deletePreload => 'd',
	deleteUser => 'd',

	getGroup => 'r',
	getMeeting => 'r',
	getMeetingParameters => 'r',
	getPreload => 'r',
	getPreloadStream => 'r',
	getRecording => 'r',
	getReport => 'r',
	getRecordingStream => 'r',
        getReport          => 'r',
	getServerDetails => 'r',
	getServerParameters => 'r',
	getUser => 'r',

	importPreload => 'c',
	importRecording => 'c',

	isModerator => 'r',
	isParticipant => 'r',

	listGroups => 'r',
	listMeetingPreloads => 'r',
	listMeetings => 'r',
	listParticipants => 'r',
	listPreloads => 'r',
	listRecordings => 'r',
        listReports => 'r',
	listUserMeetingsByDate => 'r',
	listUsers => 'r',

	resetGroup => 'u',
	resetParticipantList => 'u',

	setParticipantList => 'u',

	streamPreload => 'u',
	streamRecording => 'u',

	updateMeeting => 'u',
	updateMeetingParameters => 'u',
	updateRecording => 'u',
	updateReport => 'u',
	updateServerParameters => 'u',
	updateUser => 'u',

	);

__PACKAGE__->mk_classdata(known_adapters => \%KnownAdapters);


=head1 SEE ALSO

 Elive::DAO
 Elive::Struct
 Mouse

=cut

1;
