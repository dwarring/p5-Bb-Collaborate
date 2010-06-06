#!perl -T
use strict;
use warnings;
use File::Spec;
use Test::More;
use English qw(-no_match_vars);

if ( not $ENV{TEST_AUTHOR} ) {
    my $msg = 'Author test.  Set $ENV{TEST_AUTHOR} to a true value to run.';
    plan( skip_all => $msg );
}

eval { require Test::Perl::Critic; };

if ( $EVAL_ERROR ) {
   my $msg = 'Test::Perl::Critic required to criticise code';
   plan( skip_all => $msg );
}

my $SEVERITY = $ENV{ELIVE_TEST_CRITICAL_LEVEL} || 4;

Test::Perl::Critic->import(
    -severity => $SEVERITY,
    -verbose => 8,
    -exclude => ['ProhibitNoStrict','ProhibitStringyEval','ProhibitBuiltinHomonyms','RequireLocalizedPunctuationVars','ProhibitMixedBooleanOperators']
    );

all_critic_ok();
