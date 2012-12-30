package MooX::CaptainHook;

use 5.008;
use strict;
use warnings;

use Sub::Exporter::Progressive -setup => {
	exports => [qw/ on_application on_inflation /],
};

BEGIN {
	no warnings 'once';
	$MooX::CaptainHook::AUTHORITY = 'cpan:TOBYINK';
	$MooX::CaptainHook::VERSION   = '0.001';
}

our %on_application;
our %on_inflation;

{
	my %already;
	sub _fire
	{
		my (undef, $callbacks, $key, @args) = @_;
		return if $already{$key}++;
		return unless $callbacks;
		for my $cb (@$callbacks)
		{
			local $_ = $args[0];
			$cb->(@args);
		}
	}
}

use constant ON_APPLICATION => do {
	package MooX::CaptainHook::OnApplication;
	use Moo::Role;
	after apply_single_role_to_package => sub
	{
		my ($toolage, $package, $role) = @_;
		'MooX::CaptainHook'->_fire(
			$on_application{$role},
			"OnApplication: $package $role",
			$package,
			$role,
		);
		
		# This stuff is for internals...
		push @{ $on_application{$package} ||= [] }, @{ $on_application{$role} || [] }
			if exists $Role::Tiny::INFO{$package};
		push @{ $on_inflation{$package} ||= [] }, @{ $on_inflation{$role} || [] };
	};
	__PACKAGE__;
};

# This sub makes sure that when a role which has an on_application hook
# gets inflated to a full Moose role (as will happen if the role is
# consumed by a Moose class!) then the generated metarole object will
# have a trait that still triggers the on_application hook.
#
# There are probably numerous edge cases not catered for, but my simple
# tests seem to work.
# 
sub _inflated
{
	my $meta = shift;
	return unless $meta->isa('Moose::Meta::Role');
	require Moose::Util::MetaRole;
	Moose::Util::MetaRole::apply_metaroles(
		for            => $meta->name,
		role_metaroles => {
			role => eval q{
				package MooX::CaptainHook::OnApplication::Moose;
				use Moose::Role;
				after apply => sub {
					my $role    = $_[0]->name;
					my $package = $_[1]->name;
					
					'MooX::CaptainHook'->_fire(
						$on_application{$role},
						"OnApplication: $package $role",
						$package,
						$role,
					);
					
					# This stuff is for internals...
					if ($_[1]->isa('Moose::Meta::Role')) {
						push @{ $on_application{$package} ||= [] }, @{ $on_application{$role} || [] };
						Moose::Util::MetaRole::apply_metaroles(
							for            => $package,
							role_metaroles => {
								role => [__PACKAGE__],
							},
						);
					}
				};
				[__PACKAGE__];
			},
		},
	);
}

sub on_application (&;$)
{
	my ($code, $role) = @_;
	$role = caller unless defined $role;
	push @{$on_application{$role}||=[]}, $code;
	
	'Moo::Role'->apply_single_role_to_package('Moo::Role', ON_APPLICATION)
		unless Role::Tiny::does_role('Moo::Role', ON_APPLICATION);
	
	return;
}

use constant ON_INFLATION => do {
	package MooX::CaptainHook::OnInflation;
	use Moo::Role;
	around inject_real_metaclass_for => sub
	{
		my ($orig, $pkg) = @_;
		my $meta = $orig->($pkg);
		'MooX::CaptainHook'->_fire(
			[
				'MooX::CaptainHook'->can('_inflated'),
				@{$on_inflation{$pkg}||[]}
			],
			"OnInflation: $pkg",
			$meta,
		);
		return $meta;
	};
	__PACKAGE__;
};

sub on_inflation (&;$)
{
	my ($code, $pkg) = @_;
	$pkg = caller unless defined $pkg;
	push @{$on_inflation{$pkg}||=[]}, $_[0];
	
	return;
}

require Moo::HandleMoose;
'Moo::Role'->apply_single_role_to_package('Moo::HandleMoose', ON_INFLATION)
	unless Role::Tiny::does_role('Moo::HandleMoose', ON_INFLATION);

1;

__END__

=head1 NAME

MooX::CaptainHook - hooks for MooX modules

=head1 SYNOPSIS

   {
      package Local::Role;
      use Moo::Role;
      use MooX::CaptainHook qw(on_application);
      
      on_application {
         print "Local::Role applied to $_\n";
      };
   }
   
   {
      package Local::Class;
      use Moo;
      with 'Local::Role'; # "Local::Role applied to Local::Class"
   }

=head1 DESCRIPTION

C<MooX::CaptainHook> provides a couple of hooks which may be of use to
people writing Moo roles and MooX modules.

Callback code for a role will be copied as hooks for any packages that
consume that role.

=over

=item C<on_application>

The C<on_application> hook allows you to run a callback when your role
is applied to a class or other role. Within the callback C<< $_[0] >>
is set to the name of the package that the role is being applied to.

Also C<< $_[1] >> is set to the name of the role being applied, which
may not be the same as the role where the hook was initially defined.
(For example, when role X establishes a hook; role X is consumed by role
Y; and role Y is consumed by class Z. Then the callback code will run
twice, once with C<< @_ = qw(Y X) >> and once with C<< @_ = (Z Y) >>.)

=item C<on_inflation>

The C<on_inflation> hook runs if your class or role is "inflated" to a
full Moose class or role. C<< $_[0] >> is the associated metaclass.

=back

Within callback codeblocks, C<< $_ >> is also available as a convenient
alias to C<< $_[0] >>.

=head2 Installing Hooks for Other Packages

You can pass a package name as an optional second parameter:

   use MooX::CaptainHook;
   
   MooX::CaptainHook::on_application {
      my ($applied_to, $role) = @_;
      ...;
   } 'Your::Role';

=head1 BUGS

Please report any bugs to
L<http://rt.cpan.org/Dist/Display.html?Queue=MooX-CaptainHook>.

=head1 SEE ALSO

L<Moo>.

=head1 AUTHOR

Toby Inkster E<lt>tobyink@cpan.orgE<gt>.

=head1 COPYRIGHT AND LICENCE

This software is copyright (c) 2012 by Toby Inkster.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=head1 DISCLAIMER OF WARRANTIES

THIS PACKAGE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED
WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF
MERCHANTIBILITY AND FITNESS FOR A PARTICULAR PURPOSE.

