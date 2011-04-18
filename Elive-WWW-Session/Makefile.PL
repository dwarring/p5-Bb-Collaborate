use inc::Module::Install;

name     'Elive-WWW-Session';
all_from 'lib/Elive/WWW/Session.pm';
author   q{David Warring <david.warring@gmail.com>};
license  'perl';

build_requires 'Test::More';

auto_install;

WriteAll;

