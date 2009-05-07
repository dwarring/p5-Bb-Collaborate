package Elive::Command;
use warnings; use strict;

=head1 NAME

Elive -  Elluminate Live -  Utilities and Commands

=head1 DESCRIPTION

This module contains a number of miscellenous commands. These are as listed
in section 4.1.9 of the Elluminate Live SDK.

=cut

use Elive;
use base qw{Elive};
use Elive::Util;

our %Commands = (
    BuildMeetingJNLPCommand => {},
    BuildRecordingJNLPCommand => {},    
    BuildMeetingJNLPCommand => {},
    DecryptCommand => {},
    EncryptCommand => {},
    GetServiceProviderCommand => {},
    SaveConfigurationCommand => {},
    GetInstalledDAOListCommand => {},
    );
    
1;
