package Elive::Connection::SDK;
use warnings; use strict;

use Class::Accessor;
use Class::Data::Inheritable;
use HTML::Entities;
use Scalar::Util;

use Carp;

use Elive::Connection;
use base qw{Elive::Connection};

use Elive;
use Elive::Util;
use Elive::Entity;
use Elive::Entity::User;
use Elive::Entity::ServerDetails;

__PACKAGE__->mk_accessors( qw{_login _server_details} );

our %KnownCommands = (

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

__PACKAGE__->mk_classdata(known_commands => \%KnownCommands);

=head2 connect

    my $ec1 = Elive::Connection::SDK->connect('http://someserver.com/test',
                                        'user1', 'pass1', debug => 1,
    );
    my $url1 = $ec1->url;   #  'http://someserver.com/test'

    my $ec2 =  Elive::Connection::SDK->connect('http://user2:pass2@someserver.com/test', undef, undef, debug => 1);
    my $url2 = $ec2->url;   #  'http://someserver.com/test'

Establishes a SOAP connection. Retrieves the login user, to verify
connectivity and authentication details.

=cut

sub connect {
    my ($class, $url, $user, $pass, %opt) = @_;

    my $self = $class->SUPER::_connect($url, $user, $pass, %opt);
    $self->type($opt{type} || 'SDK');

    bless $self, $class;

    #
    # The login name should be a valid user in the database.
    # retrieve it as a way of authenticating the user and
    # checking basic connectivity.
    #
    $self->login;

    return $self;
}

=head2 disconnect

Closes a connection and frees any resources related to the connection.

=cut

sub disconnect {
    my $self = shift;

    $self->SUPER::disconnect;

    $self->_server_details(undef);
    $self->_login(undef);

    return;
}

=head2 soap

    my $soap_lite_obj = $connection->soap;

Returns the underlying L<SOAP::Lite> object for the connection.

=cut

sub soap {
    my ($self) = shift;

    my $soap = $self->_soap;

    unless ($soap) {

	my $proxy = join('/', $self->url, 'webservice.event');

	my $debug = $self->debug;

	SOAP::Lite::import($debug >= 3
			   ? (+trace => 'debug')
			   : ()
	    );

	warn "connecting to ".$proxy
	    if ($debug);

	$soap = SOAP::Lite->new();

	$soap->proxy($proxy);

	$self->_soap($soap);
    }

    return $soap;
}

=head2 call

    my $som = $self->call( $cmd, %params );

Performs an Elluminate SOAP method call. Returns the response as a
SOAP::SOM object.

=cut

sub call {
    my ($self, $cmd, %params) = @_;
    $params{adapter} ||= 'default';

    die "bad connection type. expected 'SDK', found: ".$self->type
	unless $self->type eq 'SDK';

    return $self->SUPER::call( $cmd, %params );
}

sub _preamble {

    my ($self,$cmd) = @_;

    die "Not logged in"
	unless ($self->user);

    my @user_auth =  (map {HTML::Entities::encode_entities( $_ )}
		      ($self->user, $self->pass));

    my @preamble = (
	(SOAP::Data
	 ->name('request')
	 ->uri('http://www.soapware.org')
	 ->prefix('m')
	 ->value('')),
	);

    push (@preamble, SOAP::Data->name('command')->value($cmd))
	if $cmd;

    my $auth = sprintf (<<'EOD', @user_auth);
    <h:BasicAuth
      xmlns:h="http://soap-authentication.org/basic/2001/10/"
    soap:mustUnderstand="1">
    <Name>%s</Name>
    <Password>%s</Password>
    </h:BasicAuth>
EOD

return (@preamble, SOAP::Header->type(xml => $auth));
};

=head2 login

Returns the login user as an object of type L<Elive::Entity::User>.

=cut

sub login {
    my ($self) = @_;

    my $login_entity = $self->_login;

    unless ($login_entity) {

	my $username = $self->user
	    or return;

	$login_entity = Elive::Entity::User->get_by_loginName($username,
	    connection => $self)
	    or die "unable to get login user: $username\n";

	$self->_login($login_entity);
    }

    return $login_entity;
}

=head2 server_details

Returns the server details as an object of type L<Elive::Entity::ServerDetails>.

=cut

sub server_details {
    my $self = shift;

    my $server_details = $self->_server_details;

    unless ($server_details) {

	$server_details = Elive::Entity::ServerDetails->get(connection => $self);

	$self->_server_details($server_details);
    }

    return $server_details;
}

1;
