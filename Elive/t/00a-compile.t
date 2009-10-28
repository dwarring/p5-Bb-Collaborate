#!perl -T
use Test::More tests => 17;
use Test::Exception;
use File::Spec;

BEGIN {
    use_ok( 'Elive' );
    use_ok( 'Elive::Connection' );
    use_ok( 'Elive::Array');
    use_ok( 'Elive::Array::Participants');
    use_ok( 'Elive::Entity' );
    use_ok( 'Elive::Entity::Group' );
    use_ok( 'Elive::Entity::Meeting' );
    use_ok( 'Elive::Entity::MeetingParameters' );
    use_ok( 'Elive::Entity::Participant' );
    use_ok( 'Elive::Entity::ParticipantList' );
    use_ok( 'Elive::Entity::Role' );
    use_ok( 'Elive::Entity::ServerDetails' );
    use_ok( 'Elive::Entity::ServerParameters' );
    use_ok( 'Elive::Entity::User' );
}

foreach (qw/elive_query elive_lint_config elive_raise_meeting/) {
    lives_ok(sub {
	local ($@, $!);
	do( File::Spec->catfile('script', $_) );
	for ($@, $!) {die $_ if $_}
    }, "script $_ compiles");
}

diag( "Testing Elive $Elive::VERSION, Perl $], $^X" );
