package Elive::Array;
use warnings; use strict;
use Carp;
Carp::cluck "Class ".__PACKAGE__." is depreciated - please use Elive::DAO::Array\n";

use parent qw{Elive::DAO::Array};

1;
