package Apache::RSS;

use strict;
use Apache::Constants qw(:common &OPT_INDEXES);
use Time::Piece;
use XML::RSS;
use DirHandle;
use URI;
use DynaLoader ();
use Apache::ModuleConfig;
use vars qw($VERSION);

$VERSION = '0.01';

if($ENV{MOD_PERL}) {
    no strict;
    @ISA = qw(DynaLoader);
    __PACKAGE__->bootstrap($VERSION);
}

sub handler {
    my $r = shift;
    my $cfg = Apache::ModuleConfig->get($r);
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
    my $regexp = $cfg->{'RSSEnableRegexp'};
    my @files = 
	sort { $a cmp $b } 
	    grep { !/^\./ && -f "$dir/$_" && /$regexp/ } $d->read;
    $d->close;

    ## generate RSS
    my $base = base_uri($r);
    my $req_time = localtime($r->request_time); # Time::Piece 
    my $channel_title = 
	$cfg->{'RSSChannelTitle'} || sprintf("Index Of %s", $r->uri);
    my $channel_description = 
	$cfg->{'RSSChannelDescription'} || sprintf("Index Of %s", $r->uri);
    my $copyright =
	$cfg->{'RSSCopyRight'} || sprintf("Copyright %d %s", $req_time->year, $r->hostname);
    my $language = $cfg->{'RSSLanguage'};
    my $encoding = $cfg->{'RSSEncoding'};

    my $rss = XML::RSS->new(version => '0.91', encoding => $encoding);
    $rss->channel(
	title => $channel_title,
	link => $base,
	description => $channel_description,
	webMaster => $r->server->server_admin,
	pubDate => $req_time->datetime,
	lastBuildDate => $req_time->datetime,
	copyright => $copyright,
	language => $language,
    );
    foreach my $file(@files) {
	$rss->add_item(
	    link => URI->new_abs($file, $base),
	    title => $cfg->{'RSSScanHTMLTitle'} ? (find_title($cfg, "$dir/$file") || $file) : $file,
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
    my($cfg, $file) = @_;
    my $encoder = $cfg->{'RSSEncodeHandler'};
    my $html_re = $cfg->{'RSSHTMLRegexp'};
    if ($file =~ m/$html_re/) {
	local $/ = undef;
	my $f = IO::File->new($file, "r") or return undef;
	my $html = <$f>;
	$html =~ m#<title>([^>]+)</title>#i;
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


sub RSSEnableRegexp($$$){
    my($cfg, $params, $arg) = @_;
    $cfg->{RSSEnableRegexp} = eval "qr/$arg/";
    die $@ if $@;
}

sub RSSChannelTitle {
    my($cfg, $params, $arg) = @_;
    $cfg->{RSSChannelTitle} = $arg;
}

sub RSSChannelDescription {
    my($cfg, $params, $arg) = @_;
    $cfg->{RSSChannelDescription} = $arg;
}

sub RSSCopyRight {
    my($cfg, $params, $arg) = @_;
    $cfg->{RSSCopyRight} = $arg;
}

sub RSSHTMLRegexp($$$){
    my($cfg, $params, $arg) = @_;
    $cfg->{RSSHTMLRegexp} = eval "qr/$arg/";
    die $@ if $@;
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

sub RSSEncodeHandler {
    my($cfg, $params, $arg) = @_;
    $arg =~ m/([a-zA-Z0-9:]+)/;
    my $class = $1;
    eval "require $class";
    if ($@ && $@ !~ m/^Can't locate/) {
	return $@;
    }
    $cfg->{RSSEncodeHandler} = $arg;
}

sub DIR_CREATE {
    my $class = shift;
    my $self = bless {}, $class;
    $self->{RSSChannelTitle} ||= undef;
    $self->{RSSChannelDescription} ||= undef;
    $self->{RSSCopyRight} ||= undef;
    $self->{RSSEnableRegexp} ||= '.*';
    $self->{RSSHTMLRegexp} ||= '\.html?$';
    $self->{RSSLanguage} ||= 'en-us';
    $self->{RSSEncoding} ||= 'UTF-8';
    $self->{RSSScanHTMLTitle} ||= 0;
    $self->{RSSEncodeHandler} ||= undef;
    $self;
}

1;

__END__

=head1 NAME

Apache::RSS - generate RSS output for directory Index. 

=head1 SYNOPSIS

setup your httpd.conf

 PerlModule Apache::RSS
 <Diretory /path/to/htdocs>
 Options +Indexex
 PerlHandler Apache::RSS
 PerlSetVar RSSEnableRegexp \.html$
 PerlSetVar RSSHTMLRegexp \.html$
 PerlSetVar RSSScanHTMLTitle On
 PerlSetVar RSSEncoding UTF-8
 PerlSetVar RSSEncodeHandler Apache::RSS::Encoding::JcodeUTF8
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

=item RSSHTMLRegexp <regexp>

A regular exporession of HTML files. default \.html?$

=item RSSEncodeHandler <EncodeHandlerClass>

work with RSSFindTitle and encode HTML title string.

eg. L<Apache::RSS::Encoding::JcodeUTF8>

=back

=head1 AUTHOR

IKEBE Tomohiro E<lt>ikebe@edge.co.jpE<gt>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

L<XML::RSS> L<mod_perl>

http://software.tangent.org/projects.pl?view=mod_index_rss

=cut
