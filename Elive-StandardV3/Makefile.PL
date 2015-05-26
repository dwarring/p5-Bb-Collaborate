# -*- perl -*-

use strict;
use warnings;
use inc::Module::Install;

name           ('Elive-StandardV3');
module_name    ('Elive::StandardV3');
author         ('David Warring <david.warring@gmail.com>');
all_from       ('lib/Elive/StandardV3.pm');
license	       ('perl');
install_script ();

requires(
    'Class::Accessor'              => 0,
    'Class::Data::Inheritable'     => 0,
    'Date::Parse'                  => 0,
    'Carp'                         => 0,
    'File::Spec'                   => 0,
    'File::Basename'               => 0,
    'Elive::DAO'                   => '1.34',
    'Elive::Connection'            => '1.34',
    'Elive::Util'                  => '1.34',
    'MIME::Base64'                 => 0,
    'Mouse'                        => 0.56,
    'SOAP::Lite'                   => 0.712,
    'Try::Tiny'                    => 0,
    'URI'                          => 0,
    'XML::Simple'                  => 0,
    'YAML::Syck'                   => 0,
    );

recommends(

    );

test_requires (
    'Test::Builder'            => 0,
    'Test::More'               => 0,
    'Test::Warn'               => 0,
    'Test::Fatal'              => 0,
    'version'                  => 0,
    );

#
# Module::Install::Repository magic
#
repository("git.code.sf.net/p/elive/git");

WriteAll;
