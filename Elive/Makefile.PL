# -*- perl -*-

use strict;
use warnings;
use inc::Module::Install;

perl_version    5.005;

name           ('Elive');
module_name    ('Elive');
author         ('David Warring <david.warring@gmail.com>');
version_from   ('lib/Elive.pm');
license	       ('perl');
abstract       ('Elluminate Live (c) client library');
install_script ('elive_query', 'elive_raise_meeting', 'elive_lint_config');

requires(
    'Class::Accessor'              => 0,
    'Class::Data::Inheritable'     => 0,
    'DateTime'                     => 0,  # for elive_raise_meeting
    'DateTime::Format::ISO8601'    => 0,  # for elive_raise_meeting
    'Carp'                         => 0,  # for scripts
    'File::Spec'                   => 0,
    'Getopt::Long'                 => 0,  # for scripts
    'HTML::Entities'               => 0,
    'IO::Prompt'                   => 0,
    'Mouse'                        => 0,
    'Mouse::Util::TypeConstraints' => 0,
    'Pod::Usage'                   => 0,  # for elive_raise_meeting
    'Scalar::Util'                 => 0,
    'Storable'                     => 0,
    'Term::ReadKey'                => 0,
    'Term::ReadLine'               => 0,
    'SOAP::Lite'                   => 0.69,
    'Storable'                     => 0,
    'YAML'                         => 0,
    'URI'                          => 0,
    'XML::Simple'                  => 0.
    );

recommends(

    );

test_requires (
    'Test::More'                   => 0,
    'Test::Warn'                   => 0,
    );

WriteAll;
