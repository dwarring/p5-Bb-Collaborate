use inc::Module::Install;

name     'Elive-LWP-Session';
all_from 'lib/Elive/LWP/Session.pm';
author   q{David Warring <david.warring@gmail.com>};
license  'perl';

build_requires 'Test::More';

auto_install;

WriteAll;

