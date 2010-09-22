package Elive::SAS::Presentation;
use warnings; use strict;

use Mouse;

extends 'Elive::SAS';

use Scalar::Util;
use Carp;

=head1 NAME

Elive::SAS::Presentation - Scheduling Manager entity class

=cut

__PACKAGE__->entity_name('Presentation');

has 'presentationId' => (is => 'rw', isa => 'Int', required => 1);
__PACKAGE__->primary_key('presentationId');

has 'description' => (is => 'rw', isa => 'Str');
has 'size' => (is => 'rw', isa => 'Int');
has 'creatorId' => (is => 'rw', isa => 'Str');
has 'filename' => (is => 'rw', isa => 'Str');
has 'content' => (is => 'rw', isa => 'Str');

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

    my $presentation = Elive::SAS::Presentation->insert(
             {
                    filename => 'intro.wbd',
                    creatorId =>  'bob',
                    content => $content,
	     },
         );

=cut

sub insert {
    my ($class, $_insert_data, %opt) = @_;

    croak "usage: $class->(\$insert_data, \%opts) - where \$insert_data is a hashref"
	unless (Elive::Util::_reftype($_insert_data) eq 'HASH');

    my %insert_data = %{ $_insert_data };

    my $content = delete $insert_data{content};

    croak "$class - missing mandatory insert field: content"
	unless $content;

    $insert_data{size} ||= length( $content )
	unless Scalar::Util::reftype( $content );
    #
    # (a bit of layer bleed here...)
    # don't have a datatype setup for Binary base 64 encoded data, bypass
    # normal thawing
    #
    eval {require SOAP::Lite}; die $@ if $@;
    $content = SOAP::Data->type(base64 => $content)
	unless (Scalar::Util::blessed($content)
		&& eval {$content->isa('SOAP::Data')});

    my $self = $class->SUPER::insert(\%insert_data,
				     adapter => 'uploadPresentationContent',
				     param => {content => $content},
				     %opt);

    return $self;
}

1;
