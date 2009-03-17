package Elive::Array;

use overload
        '""'     => sub { shift->_stringify_self },
        fallback => 1;

sub _stringify_self {
    my $self = shift;

    #
    # Rely on sub entities stringifying and sorting correctly
    #
    return join(';', sort @$self);
}

=head2 add

    my @added = $arr->add(10, 20, 30);

Convenience function to add elements to an array

=cut

sub add {
    my $self = shift;

    my %members;
    @members{@_} = undef;

    foreach (@$self) {
	delete $members{$_};
    }

    push (@$self, keys %members);

    return keys %members;
}

=head2 delete

    $arr->delete(20, 40, 60);

Convenience function to delete elements to an array

=cut

sub delete {
    my $self = shift;

    my %members;
    @members{@_} = undef;

    my @out = grep {!exists $members{$_}} @$self;

    @$self = @$out;
}


1;

