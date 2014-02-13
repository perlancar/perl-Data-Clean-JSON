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

subtest "selector: -circular, command: clone" => sub {
    my ($c, $data, $cdata);

    $data = [1]; push @$data, $data;

    $c = Data::Clean::Base->new(-circular => ['clone', 1]);
    $cdata = $c->clone_and_clean($data);
    is_deeply($cdata, [1, [1, 'CIRCULAR']], 'limit 1');

    $c = Data::Clean::Base->new(-circular => ['clone', 2]);
    $cdata = $c->clone_and_clean($data);
    is_deeply($cdata, [1, [1, [1, 'CIRCULAR']]], 'limit 2');
};

subtest "selector: ''" => sub {
    my $c = Data::Clean::Base->new(
        '' => ['replace_with_str', "X"],
    );
    my $cdata = $c->clean_in_place({a=>[], b=>1, c=>"x", d=>undef});
    is_deeply($cdata, {a=>[], b=>"X", c=>"X", d=>"X"});
};

# command: call_method is tested via json
# command: one_or_zero is tested via json
# command: deref_scalar is tested via json
# command: stringify is tested via json
# command: replace_with_ref is tested via json
# command: replace_with_ref is tested via json
# command: unbless is tested via json
# selector: -obj is tested via json

DONE_TESTING:
done_testing();
