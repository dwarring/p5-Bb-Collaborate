use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Elive::View::LWP',
    AUTHOR              => q{David Warring <david.warring@gmail.com>},
    VERSION_FROM        => 'lib/Elive/View/LWP.pm',
    ABSTRACT_FROM       => 'lib/Elive/View/LWP.pm',
    ($ExtUtils::MakeMaker::VERSION >= 6.3002
      ? ('LICENSE'=> 'perl')
      : ()),
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Elive-View-LWP-*' },
);
