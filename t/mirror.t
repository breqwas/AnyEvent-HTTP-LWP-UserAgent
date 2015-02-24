use strict;
use Test::More;
use File::Slurp qw(read_file);
use AnyEvent::HTTP::LWP::UserAgent;

BEGIN {
    eval q{ require Test::TCP } or plan skip_all => 'Could not require Test::TCP';
    eval q{ require HTTP::Server::Simple::CGI } or plan skip_all => 'Could not require HTTP::Server::Simple::CGI';
}

{
    package HTTP::Server::Simple::Test;
    our @ISA = 'HTTP::Server::Simple::CGI';

    sub print_banner { }

    sub handle_request {
        my ($self, $cgi) = @_;

        print "HTTP/1.0 200 OK\r\n";
        print "Content-Type: text/html\r\n";
        print "Set-Cookie: test=abc; path=/\r\n";
        print "\r\n";
        print <<__HTML__;
<html>
  <head>
    <title>Test Web Page</title>
    <base href="http://www.example.com/">
  </head>
  <body>
    <p>Cheerilee is the best pony</p>
  </body>
</html>
__HTML__
    }
}

plan tests => 7;

Test::TCP::test_tcp(
    server => sub {
        my $port = shift;
        my $server = HTTP::Server::Simple::Test->new($port);
        $server->run;
    },
    client => sub {
        my $port = shift;
        {
			my $fname = "/tmp/mirror_async_$$";
            my $ua = AnyEvent::HTTP::LWP::UserAgent->new();
            my $res = $ua->mirror_async("http://localhost:$port/", $fname)->recv;
            ok $res->is_success, 'is_success';
            is $res->content, '', 'empty content';
            like read_file($fname), qr{<p>Cheerilee is the best pony</p>}, 'valid file';
			unlink $fname;
        }
        {
			my $fname = "/tmp/mirror_$$";
            my $ua = AnyEvent::HTTP::LWP::UserAgent->new();
            my $res = $ua->mirror("http://localhost:$port/", $fname);
            ok $res->is_success, 'is_success';
            is $res->content, '', 'empty content';
            like read_file($fname), qr{<p>Cheerilee is the best pony</p>}, 'valid file';
			unlink $fname;
		}
    },
);

pass "Cheerilee is the best pony";
