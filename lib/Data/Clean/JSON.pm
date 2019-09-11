package Data::Clean::JSON;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;

use parent qw(Data::Clean);

use Exporter qw(import);
our @EXPORT_OK = qw(
                       clean_json_in_place
                       clone_and_clean_json
               );

sub new {
    my ($class, %opts) = @_;

    # from FromJSON
    $opts{"JSON::PP::Boolean"} //= ['one_or_zero'];
    $opts{"JSON::XS::Boolean"} //= ['one_or_zero']; # this doesn't exist though
    $opts{"Cpanel::JSON::XS::Boolean"} //= ['one_or_zero']; # this doesn't exist though

    $opts{DateTime}  //= [call_method => 'epoch'];
    $opts{'Time::Moment'} //= [call_method => 'epoch'];
    $opts{'Math::BigInt'} //= [call_method => 'bstr'];
    $opts{Regexp}    //= ['stringify'];
    $opts{version}   //= ['stringify'];

    $opts{SCALAR}    //= ['deref_scalar'];
    $opts{-ref}      //= ['replace_with_ref'];
    $opts{-circular} //= ['clone'];
    $opts{-obj}      //= ['unbless'];

    $opts{'!recurse_obj'} //= 1;
    $class->SUPER::new(%opts);
}

sub get_cleanser {
    my $class = shift;
    state $singleton = $class->new;
    $singleton;
}

sub clean_json_in_place {
    __PACKAGE__->get_cleanser->clean_in_place(@_);
}

sub clone_and_clean_json {
    __PACKAGE__->get_cleanser->clone_and_clean(@_);
}

1;
# ABSTRACT: (DEPRECATED) Clean data so it is safe to output to JSON

=head1 SYNOPSIS

 use Data::Clean::JSON;
 my $cleanser = Data::Clean::JSON->get_cleanser;
 my $data     = { code=>sub {}, re=>qr/abc/i };

 my $cleaned;

 # modifies data in-place
 $cleaned = $cleanser->clean_in_place($data);

 # ditto, but deep clone first, return
 $cleaned = $cleanser->clone_and_clean($data);

 # now output it
 use JSON;
 print encode_json($cleaned); # prints '{"code":"CODE","re":"(?^i:abc)"}'

Functional shortcuts:

 use Data::Clean::JSON qw(clean_json_in_place clone_and_clean_json);

 # equivalent to Data::Clean::JSON->get_cleanser->clean_in_place($data)
 clean_json_in_place($data);

 # equivalent to Data::Clean::JSON->get_cleanser->clone_and_clean($data)
 $cleaned = clone_and_clean_json($data);


=head1 DESCRIPTION

B<DEPRECATION NOTICE:> This module has been renamed to L<Data::Clean::ForJSON>
for more clarity. This old name is retained because there are distributions
still depending on it.

This class cleans data from anything that might be problematic when encoding to
JSON. This includes coderefs, globs, and so on. Here's what it will do by
default:

=over

=item * Change DateTime and Time::Moment object to its epoch value

=item * Change Regexp and version object to its string value

=item * Change scalar references (e.g. \1) to its scalar value (e.g. 1)

=item * Change other references (non-hash, non-array) to its ref() value (e.g. "GLOB", "CODE")

=item * Clone circular references

With a default limit of 1, meaning that if a reference is first seen again for
the first time, it will be cloned. But if it is seen again for the second time,
it will be replaced with "CIRCULAR".

To change the default limit, customize your cleanser object:

 $cleanser = Data::Clean::JSON->new(
     -circular => ["clone", 4],
 );

or you can perform other action for circular references, see L<Data::Clean> for
more details.

=item * Unbless other types of objects

=back

Cleaning recurses into objects.

Data that has been cleaned will probably not be convertible back to the
original, due to information loss (for example, coderefs converted to string
C<"CODE">).

The design goals are good performance, good defaults, and just enough
flexibility. The original use-case is for returning JSON response in HTTP API
service.

This module is significantly faster than modules like L<Data::Rmap> or
L<Data::Visitor::Callback> because with something like Data::Rmap you repeatedly
invoke callback for each data item. This module, on the other hand, generates a
cleanser code using eval(), using native Perl for() loops.

If C<LOG_CLEANSER_CODE> environment is set to true, the generated cleanser code
will be logged using L<Log::get> at trace level. You can see it, e.g. using
L<Log::ger::Output::Screen>:

 % LOG_CLEANSER_CODE=1 perl -MLog::ger::Output=Screen -MLog::ger::Level::trace -MData::Clean::JSON \
   -e'$c=Data::Clean::JSON->new; ...'


=head1 FUNCTIONS

None of the functions are exported by default.

=head2 clean_json_in_place($data)

A shortcut for:

 Data::Clean::JSON->get_cleanser->clean_in_place($data)

=head2 clone_and_clean_json($data) => $cleaned

A shortcut for:

 $cleaned = Data::Clean::JSON->get_cleanser->clone_and_clean($data)


=head1 METHODS

=head2 CLASS->get_cleanser => $obj

Return a singleton instance, with default options. Use C<new()> if you want to
customize options.

=head2 CLASS->new() => $obj

Create a new instance.

=head2 $obj->clean_in_place($data) => $cleaned

Clean $data. Modify data in-place.

=head2 $obj->clone_and_clean($data) => $cleaned

Clean $data. Clone $data first.


=head1 ENVIRONMENT

LOG_CLEANSER_CODE


=head1 FAQ

=head2 Why clone/modify? Why not directly output JSON?

So that the data can be used for other stuffs, like outputting to YAML, etc.

=head2 Why is it slow?

If you use C<new()> instead of C<get_cleanser()>, make sure that you do not
construct the Data::Clean::JSON object repeatedly, as the constructor generates
the cleanser code first using eval(). A short benchmark (run on my slow Atom
netbook):

 % bench -MData::Clean::JSON -b'$c=Data::Clean::JSON->new' \
     'Data::Clean::JSON->new->clone_and_clean([1..100])' \
     '$c->clone_and_clean([1..100])'
 Benchmarking sub { Data::Clean::JSON->new->clean_in_place([1..100]) }, sub { $c->clean_in_place([1..100]) } ...
 a: 302 calls (291.3/s), 1.037s (3.433ms/call)
 b: 7043 calls (4996/s), 1.410s (0.200ms/call)
 Fastest is b (17.15x a)

Second, you can turn off some checks if you are sure you will not be getting bad
data. For example, if you know that your input will not contain circular
references, you can turn off circular detection:

 $cleanser = Data::Clean::JSON->new(-circular => 0);

Benchmark:

 $ perl -MData::Clean::JSON -MBench -E '
   $data = [[1],[2],[3],[4],[5]];
   bench {
       circ   => sub { state $c = Data::Clean::JSON->new;               $c->clone_and_clean($data) },
       nocirc => sub { state $c = Data::Clean::JSON->new(-circular=>0); $c->clone_and_clean($data) }
   }, -1'
 circ: 9456 calls (9425/s), 1.003s (0.106ms/call)
 nocirc: 13161 calls (12885/s), 1.021s (0.0776ms/call)
 Fastest is nocirc (1.367x circ)

The less number of checks you do, the faster the cleansing process will be.

=head2 Why am I getting 'Not a CODE reference at lib/Data/Clean.pm line xxx'?

[2013-08-07 ] This error message is from Data::Clone::clone() when it is cloning
an object. If you are cleaning objects, instead of using clone_and_clean(), try
using clean_in_place(). Or, clone your data first using something else like
L<Sereal>.


=head1 SEE ALSO

L<Data::Rmap>

L<Data::Visitor::Callback>

L<Data::Abridge> is similar in goal, which is to let Perl data structures (which
might contain stuffs unsupported in JSON) be encodeable to JSON. But unlike
Data::Clean::JSON, it has some (currently) non-configurable rules, like changing
a coderef with a hash C<< {CODE=>'\&main::__ANON__'} >> or a scalar ref with C<<
{SCALAR=>'value'} >> and so on. Note that the abridging process is similarly
unidirectional (you cannot convert back the original Perl data structure).

=cut
