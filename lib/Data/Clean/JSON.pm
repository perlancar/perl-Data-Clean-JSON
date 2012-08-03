package Data::Clean::JSON;

use 5.010001;
use strict;
use warnings;

use parent qw(Data::Clean::Base);

# VERSION

sub new {
    my ($class, %opts) = @_;
    $opts{CODE}     //= [str => "CODE"];
    $opts{DateTime} //= [str => 'epoch'];
    $opts{Regexp}   //= ['str'];
    $class->SUPER::new(%opts);
}

1;
# ABSTRACT: Clean data so it is safe to output to JSON

=head1 SYNOPSIS

 use Data::Clean::JSON;
 my $cleaner = Data::Clean::JSON->new;    # there are some options
 my $data    = { code=>sub {}, re=>qr/abc/i };

 my $cleaned;

 # modifies data in-place
 $cleaned = $cleaner->clean_in_place($data);

 # ditto, but deep clone first, return
 $cleaned = $cleaner->clone_and_clean($data);

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


=head1 METHODS

=head2 new(%opts) => $obj

Create a new instance. For list of known options, see L<Data::Clean::Base>.
Data::Clean::JSON sets the following options:

 (
     CODE     => [str => "CODE"],   # convert coderef to string "CODE"
     DateTime => [str => 'epoch'],  # convert DateTime object to Unix time
     Regexp   => ['str'],           # stringify Regexp
 )

=head2 $obj->clean_in_place($data) => $cleaned

Clean $data. Modify data in-place.

=head2 $obj->clone_and_clean($data) => $cleaned

Clean $data. Clone $data first.

=cut
