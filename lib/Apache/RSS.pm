package Apache::RSS;
# $Id: RSS.pm,v 1.4 2002/05/17 10:49:50 ikechin Exp $

use strict;
use Apache::Constants qw(:common &OPT_INDEXES &DECLINE_CMD);
use Time::Piece;
use XML::RSS;
use DirHandle;
use URI;
use DynaLoader ();
use Apache::ModuleConfig;
use Apache::Util qw(escape_html);
use vars qw($VERSION);

$VERSION = '0.04';

if($ENV{MOD_PERL}) {
    no strict;
    @ISA = qw(DynaLoader);
    __PACKAGE__->bootstrap($VERSION);
}

sub handler($$){
    my($class, $r) = @_;
    my $cfg = Apache::ModuleConfig->get($r) || {};
    # check permission
    unless (-d $r->filename) {
	return DECLINED;
    }
    unless ($r->args eq 'index=rss') {
	return DECLINED;
    }
    if (!($r->allow_options & OPT_INDEXES)) {
	$r->log_reason("Options Indexes is off in this directory", $r->filename);
	return FORBIDDEN;
    }

    # open directory
    my $dir = $r->filename;
    my $d = DirHandle->new($dir);
    unless ($d) {
	$r->log_reason("Can't open directory", $dir);
	return FORBIDDEN;
    }
    my $base = base_uri($r);
    my $regexp = $cfg->{'RSSEnableRegexp'} || qr/.*/;
    my @items = ();
    while (my $file = $d->read) {
	next if $file =~ /^\./;
	next unless $file =~ m/$regexp/;
	my $subr = $r->lookup_uri($file);
	next unless -f $subr->filename;
	push @items, Apache::RSS::Item->new({
	    content_type => $subr->content_type,
	    title => $cfg->{'RSSScanHTMLTitle'} ? (find_title($subr, $cfg) || $file) : $file,
	    name => $file,
	    link => URI->new_abs($file, $base),
	    filename => $subr->filename,
	    mtime => (stat $subr->finfo)[9]
	});
    }
    $d->close;
    my $order = $cfg->{'RSSOrderBy'} || "ORDER_BY_FILENAME_ASC";
    if ($order eq "ORDER_BY_FILENAME_ASC") {
	@items = sort {$a->filename cmp $b->filename} @items;
    } 
    elsif ($order eq "ORDER_BY_FILENAME_DESC") {
	@items = sort {$b->filename cmp $a->filename} @items;
    }
    elsif ($order eq "ORDER_BY_MTIME_ASC") {
	@items = sort {$a->mtime <=> $b->mtime} @items;
    }
    elsif ($order eq "ORDER_BY_MTIME_DESC") {
	@items = sort {$b->mtime <=> $a->mtime} @items;
    }

    ## generate RSS
    my $req_time = localtime($r->request_time); # Time::Piece 
    my $channel_title = 
	$cfg->{'RSSChannelTitle'} || sprintf("Index Of %s", $r->uri);
    my $channel_description = 
	$cfg->{'RSSChannelDescription'} || sprintf("Index Of %s", $r->uri);
    my $copyright =
	$cfg->{'RSSCopyRight'} || sprintf("Copyright %d %s", $req_time->year, $r->hostname);
    my $language = $cfg->{'RSSLanguage'} || "en-us";
    my $encoding = $cfg->{'RSSEncoding'} || "UTF-8";

    my $rss = XML::RSS->new(version => '0.91', encoding => $encoding);
    $rss->channel(
	title => escape_html($channel_title),
	link => $base,
	description => escape_html($channel_description),
	webMaster => $r->server->server_admin,
	pubDate => $req_time->datetime,
	lastBuildDate => $req_time->datetime,
	copyright => escape_html($copyright),
	language => $language,
    );
    foreach my $item(@items) {
	$rss->add_item(
	    link => $item->link,
	    title => $item->title,
	);
    }
    # send content
    $r->send_http_header('text/xml');
    $r->print($rss->as_string);
    return OK;
}

sub base_uri {
    my $r = shift;
    my $base = URI->new($r->uri, "http");
    $base->host($r->hostname);
    $base->port($r->server->port) if $r->server->port != 80;
    $base->scheme('http');
    return $base;
}

sub find_title {
    my($subr, $cfg) = @_;
    my $encoder = $cfg->{'RSSEncodeHandler'};
    if ($subr->content_type =~ m#^text/html#) {
	local $/ = undef;
	my $f = IO::File->new($subr->filename, "r") or return undef;
	my $html = <$f>;
	$html =~ m#<title>([^>]+)</title>#i;
	return undef unless $1;
	if ($encoder) {
	    my $enc = $encoder->new;
	    return $enc->encode($1);
	}
	else {
	    return $1;
	}
    }
    return undef;
}

##----------------------------------------------------------------
## Directives
##----------------------------------------------------------------
sub RSSEnableRegexp($$$){
    my($cfg, $params, $arg) = @_;
    $cfg->{RSSEnableRegexp} = eval "qr/$arg/";
    die $@ if $@;
}

sub RSSChannelTitle($$$) {
    my($cfg, $params, $arg) = @_;
    $cfg->{RSSChannelTitle} = $arg;
}

sub RSSChannelDescription($$$) {
    my($cfg, $params, $arg) = @_;
    $cfg->{RSSChannelDescription} = $arg;
}

sub RSSCopyRight($$$) {
    my($cfg, $params, $arg) = @_;
    $cfg->{RSSCopyRight} = $arg;
}

sub RSSHTMLRegexp($$$){
     my($cfg, $params, $arg) = @_;
     warn "RSSHTMLRegexp is obsolete." if $arg;
}

sub RSSScanHTMLTitle($$$){
    my($cfg, $params, $arg) = @_;
    $cfg->{RSSScanHTMLTitle} = $arg;
}

sub RSSLanguage($$$){
    my($cfg, $params, $arg) = @_;
    $cfg->{RSSLanguage} = $arg;
}

sub RSSEncoding($$$){
    my($cfg, $params, $arg) = @_;
    $cfg->{RSSEncoding} = $arg;
}

sub RSSEncodeHandler($$$) {
    my($cfg, $params, $arg) = @_;
    $arg =~ m/([a-zA-Z0-9:]+)/; # untaint
    my $class = $1;
    eval "require $class";
    if ($@ && $@ !~ m/^Can't locate/) {
	die $@;
    }
    $cfg->{RSSEncodeHandler} = $arg;
}

sub RSSOrderBy($$$;$) {
    my($cfg, $params, $type, $order) = @_;
    if (lc($type) eq "mtime") {
	if (uc($order) eq "DESC") {
	    $cfg->{RSSOrderBy} = "ORDER_BY_MTIME_DESC";
	}
	else {
	    $cfg->{RSSOrderBy} = "ORDER_BY_MTIME_ASC";
	}
    }
    elsif (lc($type) eq "filename") {
	if (uc($order) eq "DESC") {
	    $cfg->{RSSOrderBy} = "ORDER_BY_FILENAME_DESC";
	}
	else {
	    $cfg->{RSSOrderBy} = "ORDER_BY_FILENAME_ASC";
	}
    }
    else {
	die "arguments Error - RSSOrderBy <mtime|filename> [DESC|ASC]";
    }
}

sub DIR_CREATE {
    my $class = shift;
    my $self = bless {}, $class;
    $self;
}

sub DIR_MERGE {
    my($parent, $current) = @_;
    my %new = (%$parent, %$current);
    return bless \%new, ref($parent);
}

## ---------------------------------------------------------------- 
## Apache::RSS::Item
## ---------------------------------------------------------------- 
package Apache::RSS::Item;
use strict;

sub new {
    my($class, $args) = @_;
    my $self = bless {
    }, $class;
    $self->{filename} = $args->{filename};
    $self->{content_type} = $args->{content_type};
    $self->{link} = $args->{link};
    $self->{title} = $args->{title};
    $self->{mtime} = $args->{mtime};
    $self;
}

sub mtime {
    my($self, $arg) = @_;
    $self->{mtime} = $arg if defined $arg;
    return $self->{mtime};
}

sub filename {
    my($self, $arg) = @_;
    $self->{filename} = $arg if defined $arg;
    return $self->{filename};
}

sub name {
    my($self, $arg) = @_;
    $self->{name} = $arg if defined $arg;
    return $self->{name};
}

sub link {
    my($self, $arg) = @_;
    $self->{link} = $arg if defined $arg;
    return $self->{link};
}

sub title {
    my($self, $arg) = @_;
    $self->{title} = $arg if defined $arg;
    return $self->{title}
}

sub content_type {
    my($self, $arg) = @_;
    $self->{content_type} = $arg if defined $arg;
    return $self->{content_type}
}

1;

__END__

=head1 NAME

Apache::RSS - generate RSS output for directory Index. 

=head1 SYNOPSIS

setup your httpd.conf

 PerlModule Apache::RSS
 <Diretory /path/to/htdocs>
 Options +Indexes
 PerlHandler Apache::RSS
 RSSEnableRegexp \.html$
 RSSScanHTMLTitle On
 RSSEncoding UTF-8
 RSSEncodeHandler Apache::RSS::Encoding::JcodeUTF8
 </Directory>

and access with QUERY_STRING I<index=rss>

http://yourhost/?index=rss

=head1 DESCRIPTION

Apache::RSS generate RSS output of directory Index.
Just like a mod_index_rss.

http://software.tangent.org/projects.pl?view=mod_index_rss

=head1 DIRECTIVES

=over 4

=item RSSEnableRegexp <regexp>

A regular expression of files which added in RSS. default .*

=item RSSChannelTitle <title>

set channel Title. default "Index Of I<uri>"

=item RSSChannelDescription <description>

set channel description. default "Index Of I<uri>"

=item RSSCopyRight <copyright>

set CopyRight string. default "CopyRight I<current_year> I<hostname>"

=item RSSLanguage <language>

set RSS language. default en-us

=item RSSEncoding <encoding>

set RSS encoding. default UTF-8

=item RSSScanHTMLTitle <On|Off>

scan HTML files and set HTML <title> as RSS <title> or not. default Off

=item RSSEncodeHandler <EncodeHandlerClass>

works with RSSScanHTMLTitle and encode HTML title string.

eg. L<Apache::RSS::Encoding::JcodeUTF8>

=item RSSOrderBy <mtime|filename> [DESC|ASC]

setup RSS items order.
default RSSOrderBy filename ASC

=item RSSHTMLRegexp <regexp>

this directive is obsolete. ignored with warn.

=back

=head1 AUTHOR

IKEBE Tomohiro E<lt>ikebe@edge.co.jpE<gt>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

L<XML::RSS> L<mod_perl>

http://software.tangent.org/projects.pl?view=mod_index_rss

=cut