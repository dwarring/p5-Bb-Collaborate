package Elive::StandardV2::Multimedia;
use warnings; use strict;

use Mouse;

extends 'Elive::StandardV2::_Content';

=head1 NAME

Elive::StandardV2::Multimedia - Multimedia entity class

=head1 DESCRIPTION

This class can be used to upload multimedia content, including:

=over 4

=item MPEG files: C<.mpeg>, C<.mpg>, C<.mpe>, C<.m4v>, C<.mp3>, C<.mp4>

=item QuickTime files: C<.mov>, C<.qt>

=item Windows Media files: C<.wmv>

=item Flash files: C<.swf>

=back

=cut

__PACKAGE__->entity_name('Multimedia');

has 'multimediaId' => (is => 'rw', isa => 'Int', required => 1);
__PACKAGE__->primary_key('multimediaId');
__PACKAGE__->params(
    content => 'Str',
    sessionId => 'Int',
    size => 'Int',
    );

has 'description' => (is => 'rw', isa => 'Str');
has 'size' => (is => 'rw', isa => 'Int');
has 'creatorId' => (is => 'rw', isa => 'Str');
has 'filename' => (is => 'rw', isa => 'Str');

=head1 METHODS

=cut

=head2 insert

Uploads content and creates a new multimedia resource. You can either upload
a file, or upload binary data for the multimedia content.

   # 1. upload a local file
    my $multimedia = Elive::StandardV2::Multimedia->insert('c:\\Documents\intro.wav');

    # 2. stream it ourselves
    open (my $fh, '<', $multimedia_path)
        or die "unable to open $multimedia_path: $!";
    $fh->binmode;

    my $content = do {local $/ = undef; <$fh>};
    die "no multimedia data: $multimedia_path"
        unless ($content);

    my $multimedia = Elive::StandardV2::Multimedia->insert(
             {
                    filename => 'demo.wav',
                    creatorId =>  'alice',
                    content => $content,
	     },
         );
=cut

sub insert {
    my ($class, $insert_data, %opt) = @_;

    my $self = $class->SUPER::insert($insert_data,
				     command => 'uploadMultimediaContent',
				     %opt);

    return $self;
}

=head2 list

    my $session_presentations = Elive::StandardV2::Presentation->list(
                                   filter => {sessionId => $my_session->id}
                                );

Lists multimedia. You will need to provide a filter that contains at least one
of: C<creatorId>, C<presentationId>, C<description> or C<multimediaId>.

=cut

sub list {
    my ($self, %opts) = @_;

    return $self->SUPER::list(
	command => sub {
	    my ($_crud, $params) = @_;

	    return $params->{sessionId} ? 'listSessionMultimedia': 'listMultimediaContent'
	},
	%opts);
}

1;
