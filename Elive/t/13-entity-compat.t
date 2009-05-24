#!perl -T
use warnings; use strict;
use Test::More tests => 6;
use Test::Warn;

package main;

BEGIN {
    use_ok( 'Elive::Entity::User' );
    use_ok( 'Elive::Entity::Recording' );
    use_ok( 'Elive::Entity::MeetingParameters' );
};

#
# These tests largely check some of the more subtle edge cases
# with different elluminate versions and deployment configurations
#
my $user_types = Elive::Entity::User->property_types;
#
# User Ids can be non-numeric when configured to use LDAP for 
# user management
#
ok($user_types->{userId} eq 'Str', 'non-numeric userIds permitted (LDAP compat)');

my $recording_types = Elive::Entity::Recording->property_types;
#
# SOAP API lets users supply their own recording ids. Quite happy to accept
# non-numeric ids.
#
ok($recording_types->{recordingId} eq 'Str', "non-numeric recordingId's permitted");

my $meeting_parameter_types = Elive::Entity::MeetingParameters->property_types;
#
# inSessionInvitation present in elm 9.0, but not 9.1?
#
ok(exists $meeting_parameter_types->{inSessionInvitation},
   'inSessionInvitation declared for meeting parameters (9.0 compat)');
