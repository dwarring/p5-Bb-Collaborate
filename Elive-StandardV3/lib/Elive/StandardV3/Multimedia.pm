package Elive::StandardV3::Multimedia;
use warnings; use strict;

use Mouse;

extends 'Elive::StandardV3::_Content';

=head1 NAME

Elive::StandardV3::Multimedia - Multimedia entity class

=head1 DESCRIPTION

This command uploads supported multimedia files into your ELM repository for use by your Elluminate Live! sessions.

Once uploaded, you will need to "attach" the file to one or more Elluminate
Live! sessions using the L<Elive::StandardV3::Session> C<set_multimedia()>
method.

=cut

__PACKAGE__->entity_name('Multimedia');

=head1 PROPERTIES

=head2 multimediaId (Int)

Identifier of the multimedia file in the ELM repository.

=cut

has 'multimediaId' => (is => 'rw', isa => 'Int', required => 1);
__PACKAGE__->primary_key('multimediaId');
__PACKAGE__->params(
    content => 'Str',
    sessionId => 'Int',
    size => 'Int',
    );

=head2 description (Str)

A description of the multimedia content.

=cut

has 'description' => (is => 'rw', isa => 'Str');

=head2 size (Int)

The size of the multimedia file (bytes), once uploaded to the ELM repository.

=cut

has 'size' => (is => 'rw', isa => 'Int');

=head2 creatorId (Str)

The identifier of the owner of the multimedia file.

=cut

has 'creatorId' => (is => 'rw', isa => 'Str');

=head2 filename (Str)

The name of the multimedia file including the file extension.
Elluminate Live! supports the following multimedia file types:

=over 4

=item * MPEG files: C<.mpeg>, C<.mpg>, C<.mpe>, C<.m4v>, C<.mp4>

=item * QuickTime files: C<.mov>, C<.qt>

=item * Windows Media files: C<.wmv>

=item * Flash files: C<.swf>

=item * Audio files: C<.mp3>

=back

The filename must be less than 64 characters (including any file extensions).

=cut

has 'filename' => (is => 'rw', isa => 'Str');

=head1 METHODS

=cut

=head2 upload

Uploads content and creates a new multimedia resource. There are two formats:

    # 1. upload a local file
    my $multimedia = Elive::StandardV3::Multimedia->upload('c:\\Documents\intro.wav');


    # 2. source our own binary content
    open (my $fh, '<', $multimedia_path)
        or die "unable to open $multimedia_path: $!";
    $fh->binmode;

    my $content = do {local $/ = undef; <$fh>};
    die "no multimedia data: $multimedia_path"
        unless ($content);

    my $multimedia = Elive::StandardV3::Multimedia->upload(
             {
                    filename => 'whoops.wav',
                    creatorId =>  'alice',
                    content => $content,
                    description => 'Caravan destroys service station',
	     },
         );

=cut

sub upload {
    my ($class, $upload_data, %opt) = @_;

    my $self = $class->SUPER::upload($upload_data,
				     command => 'UploadRepositoryMultimedia',
				     %opt);

    return $self;
}

=head2 list

    my $session_presentations = Elive::StandardV3::Presentation->list(
                                   filter => {sessionId => $my_session->id}
                                );

Lists multimedia. You will need to provide a filter that contains at least one
of: C<sessionId>, C<creatorId>, C<description> or C<multimediaId>.

=cut

sub list {
    my ($self, %opts) = @_;

    return $self->SUPER::list(
	command => sub {
	    my ($_crud, $params) = @_;

	    return $params->{sessionId} ? 'ListSessionMultimedia': 'ListRepositoryMultimediaContent'
	},
	%opts);
}

=head2 delete

    $multimedia->delete;

Deletes multimedia content from the server and removes it from any associated sessions.

=cut

1;
