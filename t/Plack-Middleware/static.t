use strict;
use warnings;
use Test::More;
use Plack::Middleware::Static;
use Plack::Builder;
use Plack::Util;
use HTTP::Request::Common;
use HTTP::Response;
use Cwd;
use Plack::Test;

my $base = cwd;
chdir "t";

my $handler = builder {
    enable "Plack::Middleware::Static",
        path => sub { s!^/share/!!}, root => "$base/share";
    enable "Plack::Middleware::Static",
        path => qr{\.(t|PL|txt)$}i, root => '.';
    sub {
        [200, ['Content-Type' => 'text/plain', 'Content-Length' => 2], ['ok']]
    };
};

my %test = (
    client => sub {
        my $cb  = shift;

        {
            my $path = "00_compile.t";
            my $res = $cb->(GET "http://localhost/$path");
            is $res->content_type, 'application/x-troff', 'ok case';
            like $res->content, qr/use Test::More/;
            is -s $path, length($res->content);
            my $content = do { open my $fh, "<", $path; binmode $fh; join '', <$fh> };
            is $content,$res->content;
        }

        {
            my $res = $cb->(GET "http://localhost/..%2f..%2f..%2fetc%2fpasswd.t");
            is $res->code, 403;
        }

        {
            my $res = $cb->(GET "http://localhost/..%2fMakefile.PL");
            is $res->code, 403, 'directory traversal';
        }

        {
            my $res = $cb->(GET "http://localhost/foo/not_found.t");
            is $res->code, 404, 'not found';
            is $res->content, 'not found';
        }

        {
            my $res = $cb->(GET "http://localhost/share/face.jpg");
            is $res->content_type, 'image/jpeg';
        }

        {
            my $res = $cb->(GET "http://localhost/Plack-Middleware/static.txt");
            is $res->content_type, 'text/plain';
            my($ct, $charset) = $res->content_type;
            is $charset, 'charset=utf-8';
        }
},
    app => $handler,
);

test_psgi %test;

done_testing;
