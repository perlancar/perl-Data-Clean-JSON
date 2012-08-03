#!perl

use 5.010;
use strict;
use warnings;

use Data::Clean::JSON;
use DateTime;
use Test::More 0.96;

my $c = Data::Clean::JSON->new;

is_deeply($c->clone_and_clean({code=>sub{} , date=>DateTime->from_epoch(epoch=>1001), scalar=>\1, obj=>bless({},"Foo")}),
          {                    code=>"CODE", date=>1001,                              scalar=>1 , obj=>"Foo"}, "#1");

# XXX test: re

done_testing();
