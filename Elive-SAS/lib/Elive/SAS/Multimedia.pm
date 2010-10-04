package Elive::SAS::Multimedia;
use warnings; use strict;

use Mouse;

extends 'Elive::SAS';

use Scalar::Util;
use Carp;

=head1 NAME

Elive::SAS::Multimedia - Scheduling Manager entity class

=cut

__PACKAGE__->entity_name('Multimedia');

has 'multimediaId' => (is => 'rw', isa => 'Int', required => 1);
__PACKAGE__->primary_key('multimediaId');
__PACKAGE__->params(
    content => 'Str'
    );

has 'description' => (is => 'rw', isa => 'Str');
has 'size' => (is => 'rw', isa => 'Int');
has 'creatorId' => (is => 'rw', isa => 'Str');
has 'filename' => (is => 'rw', isa => 'Str');

=head1 METHODS

=cut

=head2 insert

Uploads content and creates a new multimedia resource.

    # get the binary data from somewhere
    open (my $rec_fh, '<', $multimedia_path)
        or die "unable to open $multimedia_path: $!";

    my $content = do {local $/ = undef; <$rec_fh>};
    die "no multimedia data: $multimedia_path"
        unless ($content);

    my $multimedia = Elive::SAS::Multimedia->insert(
             {
                    filename => 'demo.wav',
                    creatorId =>  'bob',
                    content => $content,
	     },
         );

=cut

sub _freeze {
    my $class = shift;
    my $db_data = shift;

    $db_data = $class->SUPER::_freeze( $db_data );

    for (grep {$_} $db_data->{content}) {
	$db_data->{size} ||= Elive::Util::_freeze( length($_), 'Int');

	#
	# (a bit of layer bleed here...). Do we need a seperate daat type
	# for base 64 encoded data?
	#
	eval {require SOAP::Lite}; die $@ if $@;
	$_ = SOAP::Data->type(base64 => $_);
    }
}

sub insert {
    my ($class, $insert_data, %opt) = @_;

    my $self = $class->SUPER::insert($insert_data,
				     adapter => 'uploadMultimediaContent',
				     %opt);

    return $self;
}

1;
