package Elive::API::Presentation;
use warnings; use strict;

use Mouse;

extends 'Elive::API';

use Scalar::Util;
use Carp;

=head1 NAME

Elive::API::Presentation - Scheduling Manager entity class

=cut

__PACKAGE__->entity_name('Presentation');

has 'presentationId' => (is => 'rw', isa => 'Int', required => 1);
__PACKAGE__->primary_key('presentationId');
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

Uploads content and creates a new presentation resource.

    # get the binary data from somewhere
    open (my $rec_fh, '<', $presentation_path)
        or die "unable to open $presentation_path: $!";

    my $content = do {local $/ = undef; <$rec_fh>};
    die "no presentation data: $presentation_path"
        unless ($content);

    my $presentation = Elive::API::Presentation->insert(
             {
                    filename => 'intro.wav',
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
##	$db_data->{size} ||= Elive::Util::_freeze( length($_), 'Int');

	#
	# (a bit of layer bleed here...). Do we need a seperate daat type
	# for base 64 encoded data?
	#
	eval {require SOAP::Lite}; die $@ if $@;
	$_ = SOAP::Data->type(base64 => $_);
##	use MIME::Base64;
##	chomp($_ = MIME::Base64::encode_base64( $_ ));
	
    }

    return $db_data;
}

sub insert {
    my ($class, $insert_data, %opt) = @_;

    my $self = $class->SUPER::insert($insert_data,
				     command => 'uploadPresentationContent',
				     %opt);

    return $self;
}

1;
