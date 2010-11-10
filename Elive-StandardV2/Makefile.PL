# -*- perl -*-

use strict;
use warnings;
use inc::Module::Install;
perl_version    5.005;

name           ('Elive-StandardV2');
module_name    ('Elive::StandardV2');
author         ('David Warring <david.warring@gmail.com>');
version_from   ('lib/Elive/StandardV2.pm');
license	       ('perl');
abstract       ('Perl binds for the Elluminate Live (c) Standard Bridge V2 API');
install_script ();

requires(
    'Class::Accessor'              => 0,
    'Class::Data::Inheritable'     => 0,
    'Date::Parse'                  => 0,
    'Carp'                         => 0,  # for scripts
    'File::Spec'                   => 0,
    'File::Basename'               => 0,
    'Elive'                        => '0.76',
    'Getopt::Long'                 => 2.35,  # for scripts
    'Mouse'                        => 0.56,
    'Pod::Usage'                   => 0,  # for elive_raise_meeting
    'URI'                          => 0,
    'YAML'                         => 0,
    'XML::Simple'                  => 0,
    );

recommends(

    );

test_requires (
    'Test::Builder'                => 0,
    'Test::More'                   => 0,
    'Test::Warn'                   => 0,
    'Test::Exception'              => 0,
    'version'                      => 0,
    );

#
# Module::Install::Repository magic
#
auto_set_repository();

WriteAll;
