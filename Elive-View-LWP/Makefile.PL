use inc::Module::Install;

name     'Elive-View-LWP';
all_from 'lib/Elive/View/LWP.pm';
author   q{David Warring <david.warring@gmail.com>};
license  'perl';

build_requires 'Test::More';

auto_install;

WriteAll;

