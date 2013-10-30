#!perl

use 5.010;
use strict;
use warnings;

use Data::Clean::Base;
use Test::More 0.98;
use Test::Exception;

sub main::f1 { ref($_[0]) x 2 }
subtest "command: call_func" => sub {
    require DateTime;
    my $c = Data::Clean::Base->new(
        -obj => ['call_func', 'main::f1'],
    );
    my $cdata = $c->clean_in_place({a=>bless({}, "foo")});
    is_deeply($cdata, {a=>"foofoo"});
};

subtest "security: check call_func argument" => sub {
    dies_ok {
        Data::Clean::Base->new(
            -obj => ['call_func', 'pos(); system "ls"'],
        );
    };
};

subtest "security: check call_method argument" => sub {
    dies_ok {
        Data::Clean::Base->new(
            -obj => ['call_method', 'isa("a"); system "ls"'],
        );
    };
};

subtest "command: replace_with_str" => sub {
    my $c = Data::Clean::Base->new(
        -obj => ['replace_with_str', "JINNY'S TAIL"],
    );
    my $cdata = $c->clean_in_place({a=>bless({}, "foo")});
    is_deeply($cdata, {a=>"JINNY'S TAIL"});
};

# command: call_method is tested via json
# command: one_or_zero is tested via json
# command: deref_scalar is tested via json
# command: stringify is tested via json
# command: replace_with_ref is tested via json
# command: replace_with_ref is tested via json
# command: unbless is tested via json
# selector: -circular is tested via json
# selector: -obj is tested via json
# XXX selector: -ref

DONE_TESTING:
done_testing();
