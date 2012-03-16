package Elive::StandardV3::Presentation;
use warnings; use strict;

use Mouse;

extends 'Elive::StandardV3::_Content';

=head1 NAME

Elive::StandardV3::Presentation - Presentation entity class

=head1 DESCRIPTION

This command uploads presentation files, such as Elluminate C<Live!> whiteboard files or Elluminate I<Plan!> files into your ELM repository for use by your Elluminate Live! sessions.

Once uploaded, you will need to "attach" the file to one or more Elluminate
Live! sessions using the L<Elive::StandardV3::Session> C<set_presentation()>
method.

=cut

__PACKAGE__->entity_name('Presentation');

=head1 PROPERTIES

=head2 presentationId (Int)

Identifier of the presentation file in the ELM repository.

=cut

has 'presentationId' => (is => 'rw', isa => 'Int', required => 1);
__PACKAGE__->primary_key('presentationId');
__PACKAGE__->params(
    content => 'Str',
    sessionId => 'Int',
    );

=head2 description (Str)

A description of the presentation content.

=cut

has 'description' => (is => 'rw', isa => 'Str');

=head2 size (Int)

The size of the presentation file (bytes), once uploaded to the ELM repository.

=cut

has 'size' => (is => 'rw', isa => 'Int');

=head2 creatorId (Str)

The identifier of the owner of the presentation file.

=cut

has 'creatorId' => (is => 'rw', isa => 'Str');

=head2 filename (Str)

The name of the presentation file including the file extension.

Elluminate Live! supports the following presentation file types:

=over 4

=item * Elluminate Live! Whiteboard files: C<.wbd>, C<.wbp>

=item * Elluminate Plan! files: C<.elp>, C<.elpx>.

=back

Note: The filename must be less than 64 characters (including any file extensions)

=cut

has 'filename' => (is => 'rw', isa => 'Str');

=head1 METHODS

=cut

=head2 upload

Uploads content and creates a new presentation resource. You can either upload
a file, or upload binary data for the presentation.

    # 1. upload a local file
    my $presentation = Elive::StandardV3::Presentation->upload('c:\\Documents\intro.wbd');

    # 2. source our own binary content
    open (my $fh, '<', $presentation_path)
        or die "unable to open $presentation_path: $!";
    $fh->binmode;

    my $content = do {local $/ = undef; <$fh>};
    die "no presentation data: $presentation_path"
        unless ($content);

    my $presentation = Elive::StandardV3::Presentation->upload(
             {
                    filename => 'myplan.elpx',
                    creatorId =>  'bob',
                    content => $content,
	     },
         );
=cut

=head2 list

    my $session_presentations = Elive::StandardV3::Presentation->list(
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

	    return $params->{sessionId} ? 'ListSessionPresentation': 'ListRepositoryPresentation'
	},
	%opts);
}

=head2 delete

    $presentation->delete;

Deletes presentation content from the server  and removes it from any associated sessions.

=cut


1;
