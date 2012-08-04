package Data::Clean::JSON;

use 5.010001;
use strict;
use warnings;

use parent qw(Data::Clean::Base);

# VERSION

sub new {
    my ($class, %opts) = @_;
    $opts{DateTime}  //= [call_method => 'epoch'];
    $opts{Regexp}    //= ['stringify'];
    $opts{SCALAR}    //= ['deref_scalar'];
    $opts{-ref}      //= ['replace_with_ref'];
    $opts{-circular} //= ['detect_circular'];
    $class->SUPER::new(%opts);
}

1;
# ABSTRACT: Clean data so it is safe to output to JSON

=head1 SYNOPSIS

 use Data::Clean::JSON;
 my $cleanser = Data::Clean::JSON->new;    # there are some options
 my $data     = { code=>sub {}, re=>qr/abc/i };

 my $cleaned;

 # modifies data in-place
 $cleaned = $cleanser->clean_in_place($data);

 # ditto, but deep clone first, return
 $cleaned = $cleanser->clone_and_clean($data);

 # now output it
 use JSON;
 print encode_json($cleaned); # prints '{"code":"CODE","re":"(?^i:abc)"}'


=head1 DESCRIPTION

This class cleans data from anything that might be problematic when encoding to
JSON. This includes coderefs, globs, and so on.

Data that has been cleaned will probably not be convertible back to the
original, due to information loss (for example, coderefs converted to string
C<"CODE">).

The design goals are good performance, good defaults, and just enough
flexibility. The original use-case is for returning JSON response in HTTP API
service.

This module is significantly faster than L<Data::Rmap> because with Rmap you
repeatedly invoke anonymous subroutine for each data item. This module, on the
other hand, generate a cleanser code using eval(), using native Perl for()
loops.


=head1 METHODS

=head2 new(%opts) => $obj

Create a new instance. For list of known options, see L<Data::Clean::Base>.
Data::Clean::JSON sets some defaults.

    DateTime  => [call_method => 'epoch']
    Regexp    => ['stringify']
    SCALAR    => ['deref_scalar']
    -ref      => ['replace_with_ref']
    -circular => ['detect_circular']

=head2 $obj->clean_in_place($data) => $cleaned

Clean $data. Modify data in-place.

=head2 $obj->clone_and_clean($data) => $cleaned

Clean $data. Clone $data first.


=head1 FAQ

=head2 Why clone/modify? Why not directly output JSON?

So that the data can be used for other stuffs, like outputting to YAML, etc.

=head2 Why is it so slow?

First make sure that you do not construct the Data::Clean::JSON repeatedly, as
it during construction it generates the cleanser code using eval(). A short
benchmark:

 % perl -MBench -MData::Clean::JSON -e'$c=Data::Clean::JSON->new; bench sub { $c->clone_and_clean([1..100]) }, -1'
 31641 calls (30358/s), 1.042s (0.0329ms/call)

 % perl -MBench -MData::Clean::JSON -e'bench sub { Data::Clean::JSON->new->clone_and_clean([1..100]) }, -1'
 2999 calls (2714/s), 1.105s (0.369ms/call)

=cut
