=head1 PURPOSE

Check L<MooX::ClassAttribute> compiles.

=head1 AUTHOR

Toby Inkster E<lt>tobyink@cpan.orgE<gt>.

=head1 COPYRIGHT AND LICENCE

This software is copyright (c) 2013 by Toby Inkster.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

use Test::More;

package Local::XXX;
use Moo;
use MooX::ClassAttribute;

::pass();
::done_testing();

q{
	# CPANTS likes this...
	use Test::Pod;
	use Test::Pod::Coverage;
} or 1;
