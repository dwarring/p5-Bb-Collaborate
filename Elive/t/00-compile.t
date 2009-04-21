#!perl -T

use Test::More tests => 15;
use Test::Exception;

BEGIN {
    use_ok( 'Elive' );
    use_ok( 'Elive::Connection' );
    use_ok( 'Elive::Array');
    use_ok( 'Elive::Entity' );
    use_ok( 'Elive::Entity::Group' );
    use_ok( 'Elive::Entity::Meeting' );
    use_ok( 'Elive::Entity::MeetingParameters' );
    use_ok( 'Elive::Entity::Participant' );
    use_ok( 'Elive::Entity::ParticipantList' );
    use_ok( 'Elive::Entity::Role' );
    use_ok( 'Elive::Entity::ServerDetails' );
    use_ok( 'Elive::Entity::User' );

    foreach my $script (qw(elive_lint_config elive_query elive_raise_meeting)) {
	lives_ok(sub{do('script/'.$script)}, "script $script compiles");
    }
}

diag( "Testing Elive $Elive::VERSION, Perl $], $^X" );
