package Elive::API::SessionTelephony;
use warnings; use strict;

use Mouse;

extends 'Elive::API';

use Scalar::Util;
use Carp;

use Elive::Util;

=head1 NAME

Elive::API::SessionTelephony - Elluminate SessionTelephony instance class

=head1 DESCRIPTION

This is the main entity class for session telephony.

=cut

__PACKAGE__->entity_name('SessionTelephony');

has 'sessionId' => (is => 'rw', isa => 'Int', required => 1);
__PACKAGE__->_isa('Session');
__PACKAGE__->primary_key('sessionId');

has 'chairPhone' => (is => 'rw', isa => 'Str',
		     documentation => 'The phone number for the session chair'
    );

has 'chairPIN' => (is => 'rw', isa => 'Str',
		   documentation => 'The PIN for the chairPhone'
    );

has 'nonChairPhone' => (is => 'rw', isa => 'Str',
		     documentation => 'The phone number for the non-chair participants'
    );

has 'nonChairPIN' => (is => 'rw', isa => 'Str',
		      documentation => 'The PIN for the nonChairPhone participants'
    );

has 'isPhone' => (is => 'rw', isa => 'Bool',
		  documentation => 'true if a simple phone, false if also using Session Initiation Protocol (SIP)?',
    );

has 'sessionSIPPhone' => (is => 'rw', isa => 'Str',
		     documentation => 'The phone number used by SIP participants'
    );

has 'sessionPIN' => (is => 'rw', isa => 'Str',
		      documentation => 'The PIN number for SIP participants',
    );

=head1 METHODS

=cut

1;
