#!perl

use 5.010;
use strict;
use warnings;

use Data::Clean::JSON;
use DateTime;
use JSON;
use Test::More 0.98;

my $c = Data::Clean::JSON->new;
my $data;
my $cdata;

$cdata = $c->clean_in_place({
    bool1  => JSON::true,
    bool2  => JSON::false,
    code   => sub{} ,
    date   => DateTime->from_epoch(epoch=>1001),
    scalar => \1,
    obj    => bless({},"Foo"),
});
is_deeply($cdata, {
    bool1  => 1,
    bool2  => 0,
    code   => "CODE",
    date   => 1001,
    scalar => 1 ,
    obj    => {},
}, "cleaning up");

$data  = [1, [2]]; push @$data, $data;
$cdata = $c->clone_and_clean($data);
#use Data::Dump; dd $data; dd $cdata;
is_deeply($cdata, [1, [2], "CIRCULAR"], "circular")
    or diag explain $cdata;

# XXX test: re

done_testing();
