package Apache::RSS::Encoding;
# $Id$
#
# IKEBE Tomohiro <ikebe@edge.co.jp>
# Livin' On The EDGE, Limited.
# Time-stamp: <2002-05-09 21:49:17 ikebe>

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

 PerlSetVar RSSFindTitle On
 PerlSetVar RSSEncodeHandler Apache::RSS::Encoding::JcodeUTF8

=head1 DESCRIPTION

RSS codeset conversion Handler.

=head1 AUTHOR

Author E<lt>ikebe@edge.co.jpE<gt>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

L<Apache::RSS::Encoding::JcodeUTF8>

=cut
