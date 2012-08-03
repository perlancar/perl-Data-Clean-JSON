package Data::Clean::Base;

use 5.010;
use strict;
use warnings;
use Log::Any '$log';

# VERSION

sub new {
    my ($class, %opts) = @_;
    my $self = bless {opts=>\%opts}, $class;
    $log->tracef("Cleaner options: %s", \%opts);
    $self->_generate_cleaner_code;
    $self;
}

sub opt_DateTime {
    my ($self, $on, $o) = @_;
    die "Can only handle stringification for $on" unless $o->[0] eq 'str';
    if ($o->[1] eq 'epoch') {
        return '{{var}} = {{var}}->epoch';
    } else {
        die "Can't handle stringification option for $on: $o->[1]";
    }
}

sub opt_Regexp {
    my ($self, $on, $o) = @_;
    die "Can only handle stringification for $on" unless $o->[0] eq 'str';
    return '{{var}} = "{{var}}->epoch"';
}

sub opt_CODE {
    my ($self, $on, $o) = @_;
    die "Can only handle stringification for $on" unless $o->[0] eq 'str';
    return "{{var}} = '$o->[1]'";
}

sub _generate_cleaner_code {
    my $self = shift;
    my $opts = $self->{opts};

    my (@code, @ifs_ary, @ifs_hash, @ifs_main);

    my $add_if = sub {
        my ($ref, $act0) = @_;
        for ([\@ifs_ary, '$e'], [\@ifs_hash, '$h->{$k}'], [\@ifs_main, '$_']) {
            my $act = $act0;
            $act =~ s/\Q{{var}}\E/$_->[1]/g;
            push @{ $_->[0] }, "    if (\$ref eq '$ref') { $act }\n";
        }
    };

    for my $on (sort keys %$opts) {
        my $meth = "opt_$on";
        die "Can't handle clean option '$on'" unless $self->can($meth);
        my $act = $self->$meth($on, $opts->{$on});
        $add_if->($on, $act);
    }
    $add_if->("ARRAY", '$process_array->({{var}})');
    $add_if->("HASH" , '$process_hash->({{var}})');

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
    $log->tracef("Cleaner code:\n%s", $code);
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
