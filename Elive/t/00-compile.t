#!perl -T

use Test::More tests => 16;
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
    use_ok( 'Elive::Entity::ServerParameters' );
    use_ok( 'Elive::Entity::User' );
}

foreach (qw/elive_query elive_lint_config elive_raise_meeting/) {
    lives_ok(\&{$_.'::load'}, "script $_ compiles");
}

diag( "Testing Elive $Elive::VERSION, Perl $], $^X" );

package elive_query;
sub load{do('script/elive_query')};

package elive_lint_config;
sub load{do('script/elive_lint_config')};

package elive_raise_meeting;
sub load{do('script/elive_raise_meeting')};




