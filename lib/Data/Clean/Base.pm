package Data::Clean::Base;

use 5.010;
use strict;
use warnings;
use Log::Any '$log';

use Scalar::Util qw(blessed);

# VERSION

sub new {
    my ($class, %opts) = @_;
    $opts{-ref} //= ['stringify'];
    my $self = bless {opts=>\%opts}, $class;
    $log->tracef("Cleanser options: %s", \%opts);
    $self->_generate_cleanser_code;
    $self;
}

sub command_call_method {
    my ($self, $args) = @_;
    return "{{var}} = {{var}}->$args->[0]";
}

sub command_deref_scalar {
    my ($self, $args) = @_;
    return '{{var}} = ${ {{var}} }';
}

sub command_stringify {
    my ($self, $args) = @_;
    return '{{var}} = "{{var}}"';
}

sub command_replace_with_ref {
    my ($self, $args) = @_;
    return '{{var}} = $ref';
}

sub command_replace_with_str {
    my ($self, $args) = @_;
    return "{{var}} = '$args->[0]'";
}

# test
sub command_die {
    my ($self, $args) = @_;
    return "die";
}

sub _generate_cleanser_code {
    my $self = shift;
    my $opts = $self->{opts};

    my (@code, @ifs_ary, @ifs_hash, @ifs_main);

    my $n = 0;
    my $add_if = sub {
        my ($cond0, $act0) = @_;
        for ([\@ifs_ary, '$e'], [\@ifs_hash, '$h->{$k}'], [\@ifs_main, '$_']) {
            my $act  = $act0 ; $act  =~ s/\Q{{var}}\E/$_->[1]/g;
            my $cond = $cond0; $cond =~ s/\Q{{var}}\E/$_->[1]/g;
            push @{ $_->[0] }, "    ".($n ? "els":"")."if ($cond) { $act }\n";
        }
        $n++;
    };
    my $add_if_ref = sub {
        my ($ref, $act0) = @_;
        $add_if->("\$ref eq '$ref'", $act0);
    };

    for my $on (grep {/\A\w+\z/} sort keys %$opts) {
        my $o = $opts->{$on};
        my $meth = "command_$o->[0]";
        die "Can't handle command $o->[0] for option '$on'" unless $self->can($meth);
        my @args = @$o; shift @args;
        my $act = $self->$meth(\@args);
        $add_if_ref->($on, $act);
    }
    $add_if_ref->("ARRAY", '$process_array->({{var}})');
    $add_if_ref->("HASH" , '$process_hash->({{var}})');

    for my $p ([-obj => 'blessed({{var}})'], [-ref => '$ref']) {
        my $o = $opts->{$p->[0]};
        next unless $o;
        my $meth = "command_$o->[0]";
        die "Can't handle command $o->[0] for option '$p->[0]'" unless $self->can($meth);
        my @args = @$o; shift @args;
        $add_if->($p->[1], $self->$meth(\@args));
    }

    push @code, 'sub {'."\n";
    push @code, 'my $data = shift;'."\n";
    push @code, 'state $process_array;'."\n";
    push @code, 'state $process_hash;'."\n";
    push @code, 'if (!$process_array) { $process_array = sub { my $a = shift; for my $e (@$a) { my $ref=ref($e);'."\n".join("", @ifs_ary).'} } }'."\n";
    push @code, 'if (!$process_hash) { $process_hash = sub { my $h = shift; for my $k (keys %$h) { my $ref=ref($h->{$k});'."\n".join("", @ifs_hash).'} } }'."\n";
    push @code, 'for ($data) { my $ref=ref($_);'."\n".join("", @ifs_main).'}'."\n";
    push @code, '$data'."\n";
    push @code, '}'."\n";

    my $code = join("", @code).";";
    $log->tracef("Cleanser code:\n%s", $code);
    eval "\$self->{code} = $code";
    die "Can't generate code: $@" if $@;
}

sub clean_in_place {
    my ($self, $data) = @_;

    $self->{code}->($data);
}

sub clone_and_clean {
    require Data::Clone;

    my ($self, $data) = @_;
    my $clone = Data::Clone::clone($data);
    $self->clean_in_place($clone);
}

1;
# ABSTRACT: Base class for Data::Clean::*

=head1 METHODS

=head2 new(%opts) => $obj

Create a new instance. Known options:

=over 4

=item *

=back

=head2 $obj->clean_in_place($data) => $cleaned

Clean $data. Modify data in-place.

=head2 $obj->clone_and_clean($data) => $cleaned

Clean $data. Clone $data first.

=cut
