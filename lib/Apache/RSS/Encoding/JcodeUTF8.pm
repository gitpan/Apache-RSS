package Apache::RSS::Encoding::JcodeUTF8;
# $Id$
#
# IKEBE Tomohiro <ikebe@edge.co.jp>
# Livin' On The EDGE, Limited.
# Time-stamp: <2002-05-09 21:59:50 ikebe>

use strict;
use Jcode;
use base qw(Apache::RSS::Encoding);

sub encode {
    my($self, $str) = @_;
    return Jcode->new(\$str)->utf8;
}

1;

__END__

=head1 NAME 

Apache::RSS::Encoding::JcodeUTF8 - encode Japanese <title>..</title> string to utf8.

=head1 SYNOPSIS

 PerlSetVar RSSFindTitle On
 PerlSetVar RSSEncodeHandler Apache::RSS::Encoding::JcodeUTF8

=head1 DESCRIPTION

Apache::RSS HTML encoding Handler.
encode Japanese charset to UTF-8. using L<Jcode>.

=head1 AUTHOR

Author E<lt>ikebe@edge.co.jpE<gt>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

L<Jcode>

=cut

