package Elive::StandardV2::Presentation;
use warnings; use strict;

use Mouse;

extends 'Elive::StandardV2::_Content';

=head1 NAME

Elive::StandardV2::Presentation - Presentation entity class

=head1 DESCRIPTION

This class can be used to upload presentation content, including Elluminate
I<Live!> plan files (C<*.elpx> etc) and whiteboard content C<*.wbd> etc).

=cut

__PACKAGE__->entity_name('Presentation');

has 'presentationId' => (is => 'rw', isa => 'Int', required => 1);
__PACKAGE__->primary_key('presentationId');
__PACKAGE__->params(
    content => 'Str',
    sessionId => 'Int',
    );

has 'description' => (is => 'rw', isa => 'Str');
has 'size' => (is => 'rw', isa => 'Int');
has 'creatorId' => (is => 'rw', isa => 'Str');
has 'filename' => (is => 'rw', isa => 'Str');

=head1 METHODS

=cut

=head2 insert

Uploads content and creates a new presentation resource. You can either upload
a file, or upload binary data for the presentation.

   # 1. upload a local file
    my $multimedia = Elive::StandardV2::Presentation->insert('c:\\Documents\intro.wbd');

    # 2. stream it ourselves
    open (my $fh, '<', $presentation_path)
        or die "unable to open $presentation_path: $!";
    $fh->binmode;

    my $content = do {local $/ = undef; <$fh>};
    die "no presentation data: $presentation_path"
        unless ($content);

    my $presentation = Elive::StandardV2::Presentation->insert(
             {
                    filename => 'myplan.elpx',
                    creatorId =>  'bob',
                    content => $content,
	     },
         );
=cut

sub insert {
    my ($class, $insert_data, %opt) = @_;

    return $class->SUPER::insert($insert_data,
				     command => 'uploadPresentationContent',
				     %opt);
}

=head2 list

    my $session_presentations = Elive::StandardV2::Presentation->list(
                                   filter => {sessionId => $my_session}
                                );

Lists sessions. You will need to provide a filter that contains at least one
of: C<creatorId>, C<presentationId>, C<description> or C<sessionId>.

=cut

sub list {
    my ($self, %opts) = @_;

    return $self->SUPER::list(
	command => sub {
	    my ($_crud, $params) = @_;

	    return $params->{sessionId} ? 'listSessionPresentation': 'listPresentationContent'
	},
	%opts);
}

1;
