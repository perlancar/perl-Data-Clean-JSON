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

    my $circ = $opts->{-circular};
    if ($circ) {
        $add_if->('$ref && $refs{ {{var}} }++', '{{var}} = "CIRCULAR"; last');
    }

    for my $on (grep {/\A\w+\z/} sort keys %$opts) {
        my $o = $opts->{$on};
        next unless $o;
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
    push @code, 'state %refs;'."\n" if $circ;
    push @code, 'state $process_array;'."\n";
    push @code, 'state $process_hash;'."\n";
    push @code, 'if (!$process_array) { $process_array = sub { my $a = shift; for my $e (@$a) { my $ref=ref($e);'."\n".join("", @ifs_ary).'} } }'."\n";
    push @code, 'if (!$process_hash) { $process_hash = sub { my $h = shift; for my $k (keys %$h) { my $ref=ref($h->{$k});'."\n".join("", @ifs_hash).'} } }'."\n";
    push @code, '%refs = ();'."\n" if $circ;
    push @code, 'for ($data) { my $ref=ref($_);'."\n".join("", @ifs_main).'}'."\n";
    push @code, '$data'."\n";
    push @code, '}'."\n";

    my $code = join("", @code).";";
    $log->tracef("Cleanser code:\n%s", $code) if $ENV{LOG_CLEANSER_CODE};
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

Create a new instance.

Options specify what to do with problematic data. Option keys are either
reference types or class names, or C<-obj> (to refer to objects, a.k.a. blessed
references), C<-circular> (to refer to circular references), C<-ref> (to refer
to references, used to process references not handled by other options). Option
values are arrayrefs, the first element of the array is command name, to specify
what to do with the reference/class. The rest are command arguments. Available
commands:

=over 4

=item * ['stringify']

This will stringify a reference like C<{}> to something like C<HASH(0x135f998)>.

=item * ['replace_with_ref']

This will replace a reference like C<{}> with C<HASH>.

=item * ['replace_with_str', STR]

This will replace a reference like C<{}> with I<STR>.

=item * ['call_method']

This will call a method and use its return as the replacement. For example:
DateTime->from_epoch(epoch=>1000) when processed with [call_method => 'epoch']
will become 1000.

=item * ['deref_scalar']

This will replace a scalar reference like \1 with 1.

=back

Special commands for C<-circular>:

=over 4

=item * ['detect_circular']

Keep a count for each reference. When a circular reference is found, replace it
with <"CIRCULAR">.

=back

Default options:

 -ref => 'stringify'

Note that arrayrefs and hashrefs are always walked into, so it's not trapped by
C<-ref>.

=head2 $obj->clean_in_place($data) => $cleaned

Clean $data. Modify data in-place.

=head2 $obj->clone_and_clean($data) => $cleaned

Clean $data. Clone $data first.


=head1 ENVIRONMENT

=over

=item * LOG_CLEANSER_CODE => BOOL (default: 0)

Can be enabled if you want to see the generated cleanser code. It is logged at
level C<trace>.

=back

=cut
