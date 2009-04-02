package Elive::Struct;

use Elive;
use Data::Def::Struct;
use base qw{Elive Data::Def::Struct};

use overload
    '""' =>
    sub {shift->stringify}, fallback => 1;

use Elive::Array;
__PACKAGE__->array_class('Elive::Array');

1;
