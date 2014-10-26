use strict;
use Test::More tests => 4;

use Apache::RSS;
use Apache::Constants qw(:common);
use Apache::ModuleConfig;

{
    *Apache::Constants::DECLINED = sub {-1};
    *Apache::Constants::FORBIDDEN = sub {403};
    *Apache::Constants::OK = sub {0};
    *Apache::Constants::OPT_INDEXES = sub {1};
    *Apache::Util::escape_html = sub{shift};
}


{
    package Apache::ModuleConfig;
    sub get{
	my $conf = Apache::RSS::DIR_CREATE('MockConf');
	$conf->{RSSScanHTMLTitle} = 1;
	return $conf;
    }
}

{
    package Apache::RSS::TestServer;
    sub port {80}
    sub server_admin { 'admin@example.com' }
}

{
    package Apache::RSS::TestSubReq;
    sub new { 
	my($class, $uri) = @_;
	my $self = bless {
	    uri => $uri
	}, $class;
	$self;
    }
    sub filename { my $self = shift; return "./t/test_dir/$self->{uri}"; }
    sub content_type{'text/html';}
    sub args{ return 'index=rss'; }
    sub allow_options{ 1; }
    sub log_reason{ }
    sub hostname{ 'www.example.com' }
    sub uri { '/' }
    sub server { bless {}, 'Apache::RSS::TestServer'; }
    sub AUTOLOAD{}
}

my $output;
{
    package Apache::RSS::TestRequest;
    sub new { bless {}, shift; }
    sub filename { return './t/test_dir/'; }
    sub args{ return 'index=rss'; }
    sub allow_options{ 1; }
    sub log_reason{ }
    sub hostname{ 'www.example.com' }
    sub uri { '/' }
    sub server { bless {}, 'Apache::RSS::TestServer'; }
    sub lookup_uri{shift; Apache::RSS::TestSubReq->new(shift)}
    sub AUTOLOAD{}
    sub print { shift; $output = shift; } 
}

is(Apache::RSS::handler(Apache::RSS::TestRequest->new), OK);
like($output, qr@<link>http://www.example.com/1.html</link>@);
like($output, qr@<title>Hello World</title>@);
like($output, qr@<title>foo\.txt</title>@);
