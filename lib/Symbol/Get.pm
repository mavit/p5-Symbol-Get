package Symbol::Get;

use strict;
use warnings;

use Call::Context ();

our $VERSION = 0.05;

=encoding utf-8

=head1 NAME

Symbol::Get - Read Perl’s symbol table programmatically

=head1 SYNOPSIS

    package Foo;

    our $name = 'haha';
    our @list = ( 1, 2, 3 );
    our %hash = ( foo => 1, bar => 2 );

    use constant my_const => 'haha';

    sub doit { ... }

    my $name_sr = Symbol::Get::get('$Foo::name');    # \$name
    my $list_ar = Symbol::Get::get('$Foo::list');    # \@list
    my $hash_hr = Symbol::Get::get('$Foo::hash');    $ \%hash

    #Defaults to __PACKAGE__ if none is given:
    my $doit_cr = Symbol::Get::get('&doit');

    #A constant--note the lack of sigil.
    my $const_sr = Symbol::Get::get('Foo::my_const');

    #The below return the same results since get_names() defaults
    #to the current package if none is given.
    my @names = Symbol::Get::get_names('Foo');      # keys %Foo::
    my @names = Symbol::Get::get_names();

=head1 DESCRIPTION

Occasionally I have need to reference a variable programmatically.
This module facilitates that by providing an easy, syntactic-sugar-y,
read-only interface to the symbol table.

The SYNOPSIS above should pretty well cover usage.

=head1 ABOUT PERL CONSTANTS

This construction:

    use constant foo => 'bar';

… does something rather special with the symbol table: while you access
C<foo> as though it were a function (e.g., C<foo()>, or just bareword C<foo>),
the actual symbol table entry is a SCALAR reference, not a GLOB like other
entries.

C<Symbol::Get::get()> expects you to pass in names of constants WITHOUT
trailing parens (C<()>), as in the example above.

List constants are a bit more “interesting”. The following:

    use constant things => qw( a b c );

… will, in Perl versions since 5.20, create an array reference in the symbol
table, analogous to the scalar reference for a single value.
C<Symbol::Get::get()> will return a reference to that array.

B<PRE-5.20 NOTE:> Perl versions prior to 5.20 stored list constants as code
references. If you’re wanting to fetch a list constant in pre-5.20 code,
you’ll need to fetch it as a coderef. An exception is thrown if you try to
access a list constant without a sigil via C<Symbol::Get::get()> in pre-5.20
Perl versions.

=head1 SEE ALSO

=over 4

=item * L<Symbol::Values>

=back

=head1 LICENSE

This module is licensed under the same license as Perl.

=cut

use constant MIN_LIST_CONSTANT_PERL_VERSION => v5.20.0;

my %_sigil_to_type = qw(
    $   SCALAR
    @   ARRAY
    %   HASH
    &   CODE
);

my $sigils_re_txt = join('|', keys %_sigil_to_type);

sub get {
    my ($var) = @_;

    die 'Need a variable or constant name!' if !length $var;

    my $sigil = substr($var, 0, 1);

    goto \&_get_constant if $sigil =~ tr<A-Za-z_><>;

    my $type = $_sigil_to_type{$sigil} or die "Unrecognized sigil: “$sigil”";

    my $table_hr = _get_table_hr( substr($var, 1) );
    return $table_hr && *{$table_hr}{$type};
}

#Refereced in tests.
sub _perl_supports_getting_list_constant_ref { return $^V ge MIN_LIST_CONSTANT_PERL_VERSION() }

sub _get_constant {
    my ($var) = @_;

    my $ref = _get_table_hr($var);

    if ('SCALAR' ne ref($ref) && 'ARRAY' ne ref($ref)) {
        my $msg = "$var is a regular symbol table entry, not a constant.";

        if ( !_perl_supports_getting_list_constant_ref() ) {
            $msg .= " Your Perl version ($^V) stores list constants in the symbol table as CODE references rather than ARRAYs; maybe that’s the issue?";
        }

        die $msg;
    }

    return $ref;
}

sub get_names {
    my ($module) = @_;

    $module ||= (caller 0)[0];

    Call::Context::must_be_list();

    my $table_hr = _get_module_table_hr($module);

    die "Unknown namespace: “$module”" if !$table_hr;

    return keys %$table_hr;
}

#----------------------------------------------------------------------
# To be completed if needed:
#
#sub list_sigils {
#    my ($full_name) = @_;
#
#    Call::Context::must_be_list();
#
#    my ($module, $name) = ($full_name =~ m<(?:(.+)::)?(.+)>);
#
#    my $table_hr = _get_table_for_module_name($module);
#    my $glob = *{$table_hr};
#
#    return
#}
#


#----------------------------------------------------------------------

sub _get_module_table_hr {
    my ($module) = @_;

    my @nodes = split m<::>, $module;

    my $table_hr = \%main::;

    my $pkg = q<>;

    for my $n (@nodes) {
        $table_hr = $table_hr->{"$n\::"};
        $pkg .= "$n\::";
    }

    return $table_hr;
}

sub _get_table_hr {
    my ($name) = @_;

    $name =~ m<\A (?: (.+) ::)? ([^:]+ (?: ::)?) \z>x or do {
        die "Invalid variable name: “$name”";
    };

    my $module = $1 || (caller 1)[0];

    my $table_hr = _get_module_table_hr($module);

    return $table_hr->{$2};
}

1;
