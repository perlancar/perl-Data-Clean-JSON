#!perl

use 5.010;
use strict;
use warnings;

use Data::Clean::FromJSON;
use DateTime;
use JSON;
use Test::More 0.98;

my $c = Data::Clean::FromJSON->new;
my $data;
my $cdata;

$cdata = $c->clean_in_place({
    bool1  => JSON::true,
    bool2  => JSON::false,
});
is_deeply($cdata, {
    bool1  => 1,
    bool2  => 0,
}, "cleaning up");

done_testing();
