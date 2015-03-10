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

	my $bigdata = join(", ", 0 .. 10_000);
	our $content = <<__HTML__;
<html>
  <head>
    <title>Test Web Page</title>
    <base href="http://www.example.com/">
  </head>
  <body>
    <p>$bigdata</p>
    <p>Cheerilee is the best pony</p>
  </body>
</html>
__HTML__

	sub handle_request {
        my ($self, $cgi) = @_;

        print "HTTP/1.0 200 OK\r\n";
        print "Content-Type: text/html\r\n";
        print "Set-Cookie: test=abc; path=/\r\n";
        print "X-Gotcha: ok\r\n" if $cgi->http("http-x-throw");
        print "\r\n";
        print $content;
    }
}

plan tests => 9;

Test::TCP::test_tcp(
    server => sub {
        my $port = shift;
        my $server = HTTP::Server::Simple::Test->new($port);
        $server->run;
    },
    client => sub {
        my $port = shift;
        {
			# basic
			my $fname = "/tmp/mirror_basic_$$";
            my $ua = AnyEvent::HTTP::LWP::UserAgent->new();
            my $res = $ua->mirror("http://localhost:$port/", $fname);
            ok $res->is_success, 'basic: is_success';
            is $res->content, '', 'basic: empty content';
            is read_file($fname), $HTTP::Server::Simple::Test::content, 'basic: valid file';
			unlink $fname;
		}
        {
			# perl -c
			local $\ = "\n";
			my $fname = "/tmp/mirror_newlines_$$";
            my $ua = AnyEvent::HTTP::LWP::UserAgent->new();
            my $res = $ua->mirror("http://localhost:$port/", $fname);
            ok $res->is_success, 'perl -c: is_success';
            is read_file($fname), $HTTP::Server::Simple::Test::content, 'perl -c: valid file';
			unlink $fname;
		}
        {
			# headers
			my $fname = "/tmp/mirror_defheaders_$$";
            my $ua = AnyEvent::HTTP::LWP::UserAgent->new();
			$ua->default_header("X-Throw" => "1");
            my $res = $ua->mirror("http://localhost:$port/", $fname);
            ok $res->is_success, 'headers: is_success';
            is read_file($fname), $HTTP::Server::Simple::Test::content, 'headers: valid file';
			ok $res->header("X-Gotcha"), "headers: default header was passed and processed";
			unlink $fname;
		}

    },
);

pass "Cheerilee is the best pony";
