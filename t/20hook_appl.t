=head1 PURPOSE

Test C<on_application> hook from L<MooX::CaptainHook>.

=head1 AUTHOR

Toby Inkster E<lt>tobyink@cpan.orgE<gt>.

=head1 COPYRIGHT AND LICENCE

This software is copyright (c) 2012 by Toby Inkster.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

use strict;
use warnings;
use Test::More;

my @output;

{
	package Local::Role;
	use Moo::Role;
	use MooX::CaptainHook qw(on_application);
	
	on_application {
		push @output, "@{$_[0]}";
	};
}

{
	package Local::OtherRole;
	use Moo::Role;
	with 'Local::Role'; # "Local::Role applied to Local::OtherRole"
	1;
}

{
	package Local::Class;
	use Moo;
	with 'Local::OtherRole'; # "Local::OtherRole applied to Local::Class"
	1;
}

is_deeply(
	\@output,
	[
		"Local::OtherRole Local::Role",
		"Local::Class Local::OtherRole",
	],
);

ok(
	!$INC{'Moose.pm'},
	'Did not accidentally load Moose',
);

done_testing;
