package Apache::RSS::Encoding;
# $Id: Encoding.pm,v 1.2 2002/05/10 07:41:56 ikechin Exp $
#
# IKEBE Tomohiro <ikebe@edge.co.jp>
# Livin' On The EDGE, Limited.
# Time-stamp: <2002-05-10 11:17:07 ikebe>

use strict;
use Carp;

sub new {
    my $class = shift;
    my $self = bless {}, $class;
    $self;
}

sub encode {
    croak "ABSTRACT METHOD!!";
}

1;

__END__

=head1 NAME 

Apache::RSS::Encoding - ABSTRACT CLASS.

=head1 SYNOPSIS

 RSSScanHTMLTitle On
 RSSEncodeHandler Apache::RSS::Encoding::JcodeUTF8

=head1 DESCRIPTION

RSS codeset conversion Handler.

=head1 AUTHOR

IKEBE Tomohiro E<lt>ikebe@edge.co.jpE<gt>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

L<Apache::RSS::Encoding::JcodeUTF8>

=cut
