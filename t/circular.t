#!perl

use Test::More tests => 1;
use Data::Clean::JSON;

my $array = [1, 2, 3];
my $data  = { array => $array };
push @$array, $data;

Data::Clean::JSON::->new->clone_and_clean($data);

ok 1;
