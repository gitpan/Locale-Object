package Locale::Object::Country;

use strict;
use warnings::register;
use Carp qw(croak);
use vars qw($VERSION);

use Locale::Object::DB;
use Locale::Object::Currency;
use Locale::Object::Continent;
use Locale::Object::Language;

$VERSION = "0.3";

my $db = Locale::Object::DB->new();

# Initialize the hash where we'll keep our continent objects.
my $existing = {};

sub new
{
  my $class = shift;
  my %params = @_;

  my $self = bless {}, $class;
  
  # Initialize the new object or return an existing one.
  $self->init(%params);
}

# Initialize the object.
sub init
{
  my $self   = shift;
  my %params = @_;

  # One parameter is allowed.
  croak "Error: You must specify a single parameter for initialization."
    unless scalar(keys %params) == 1;

  # It's the only key in %params.    
  my $parameter = (keys %params)[0];
  
  # Make a hash of valid parameters.
  my %allowed_params = map { $_ => undef }
    qw(code_alpha2 code_alpha3 code_numeric name);
  
  # Go no further if the specified parameter wasn't one.
  croak "Error: You can only specify a country name, alpha2 code, alpha3 code or numeric code for initialization." unless exists $allowed_params{$parameter};

  # Get the value given for the parameter.
  my $value = $params{$parameter};

  # Look in the database for a match.
  my $result = $db->lookup(
                                    table         => 'country',
                                    result_column => '*',
                                    search_column => $parameter,
                                    value         => $value
                                   );
  
  croak "Error: Unknown $parameter given for initialization: $value" unless $result;

  # Get the values from the result of our database query.
  my $code_alpha2           = @{$result}[0]->{'code_alpha2'}; 
  my $code_alpha3           = @{$result}[0]->{'code_alpha3'}; 
  my $code_numeric          = @{$result}[0]->{'code_numeric'}; 
  my $name                  = @{$result}[0]->{'name'};
  my $dialing_code          = @{$result}[0]->{'dialing_code'};

  # Check for pre-existing objects. Return it if there is one.
  my $country = $self->exists($code_alpha2);
  return $country if $country;

  # If not, make a new object.
  _make_country($self, $code_alpha2, $code_alpha3, $code_numeric, $name, $dialing_code);
  
  # Register the new object.
  $self->register();

  # Return the object.
  $self;
}

# Check if objects exist.
sub exists {
  my $self = shift;
  
  # Check existence of a object with the given parameter or with
  # the alpha2 code of the current object.
  my $code = shift;

  # Return the singleton object, if it exists.
  $existing->{$code};
}

# Register the object in our hash of existing objects.
sub register {
  my $self = shift;
  
  # Do nothing unless the object exists.
  my $code = $self->code_alpha2 or return;
  
  # Put the current object into the singleton hash.
  $existing->{$code} = $self;
}

sub _make_country
{
  my $self       = shift;
  my @attributes = @_;

  # The first attribute we get is the alpha2 country code.
  my $code = $attributes[0];

  # The attributes we want to set.
  my @attr_names = qw(_code_alpha2 _code_alpha3 _code_numeric _name _dialing_code);
  
  # Initialize a loop counter.
  my $counter = 0;
  
  # For each of those attributes,
  foreach my $current_attribute (@attr_names)
  {      
    # set it on the object.
    $self->{$current_attribute} = $attributes[$counter];
    $counter++; 
  }

  # Check there's a continent row matching our current country.
  my $result = $db->lookup(
                                    table         => 'continent',
                                    result_column => '*',
                                    search_column => 'country_code',
                                    value         => $code
                                   );
  
  my $continent = @{$result}[0]->{'name'};
  
  croak "Error: no continent found in the database for country code $code." unless $continent;

  # Make new continent and currency objects as attributes.
  $self->{_continent} = Locale::Object::Continent->new(        name => $continent );
  $self->{_currency}  = Locale::Object::Currency->new( country_code => $code      );
  
}

# Method for retrieving all languages spoken in this country.
sub languages
{
  my $self = shift;

  # No name, no languages.
  return unless $self->{_name};
  
  # Check for countries attribute. Set it if we don't have it.
  _set_languages($self) unless $self->{_languages};

  # Give an array if requested in array context, otherwise a reference.    
  return @{$self->{_languages}} if wantarray;
  return $self->{_languages};
  
}

# Private method to set an attribute with an array of objects for all languages spoken in this country.
sub _set_languages
{
    my $self = shift;

    my @languages;
    
    # If it doesn't, find all countries in this continent and put them in a hash.
    my $result = $db->lookup(
                                      table => 'language_mappings', 
                                      result_column => 'language', 
                                      search_column => 'country', 
                                      value => $self->{'_code_alpha2'}
                                     );

    # Create new country objects and put them into an array.
    foreach my $lang (@{$result})
    {
      my $lang_code = $lang->{'language'};
      
      my $obj = Locale::Object::Language->new( code_alpha3 => $lang_code );
      push @languages, $obj; 
    }
    
    # Set a reference to that array as an attribute.
    $self->{'_languages'} = \@languages;
}

# Small methods that return object attributes.
# Will refactor these into an AUTOLOAD later.

sub code_alpha2
{
  my $self = shift;  
  $self->{_code_alpha2};
}

sub code_alpha3
{
  my $self = shift;  
  $self->{_code_alpha3};
}

sub code_numeric
{
  my $self = shift;  
  $self->{_code_numeric};
}  

sub continent
{
  my $self = shift;  
  $self->{_continent};
}

sub currency
{
  my $self = shift;  
  $self->{_currency};
}

sub dialing_code
{
  my $self = shift;  
  $self->{_dialing_code};
}  

sub name
{
  my $self = shift;  
  $self->{_name};
}  


1;

__END__

=head1 NAME

Locale::Object::Country - country information objects

=head1 VERSION

0.3

=head1 DESCRIPTION

C<Locale::Object::Country> allows you to create objects containing information about countries such as their ISO codes, currencies and so on.

=head1 SYNOPSIS

    use Locale::Object::Country;
    
    my $country = Locale::Object::Country->new( code_alpha2 => 'af' );
    
    my $name         = $country->name;         # 'Afghanistan'
    my $code_alpha3  = $country->code_alpha3;  # 'afg'
    my $dialing_code = $country->dialing_code; # '93'
    
    my $currency     = $country->currency;
    my $continent    = $country->continent;

    my @languages    = $country->languages;

=head1 METHODS

=head2 C<new()>

    my $country = Locale::Object::Country->new( code => 'af' );
    
The C<new> method creates an object. It takes a single-item hash as an argument - valid options to pass are ISO 3166 values - 'code_alpha2', 'code_alpha3', 'code_numeric' and 'name'. See L<Locale::Object::DB::Schemata> for details on these.

The objects created are singletons; if you try and create a country object when one matching your specification already exists, C<new()> will return the original one.

=head2 C<code_alpha2(), code_alpha(), code_numeric(), name(), dialing_code()>

    my $name = $country->name;
    
These methods retrieve the values of the attributes in the object whose name they share.

=head2 C<currency(), continent()>

These methods return L<Locale::Object::Currency> and L<Locale::Object::Continent> objects respectively. Both of those have their own attribute methods, so you can do things like this:

    my $currency      = $country->currency;
    my $currency_name = $currency->name;

See the documentation for those two modules for a listing of currency and continent attributes.

Note: More attributes will be added in a future release; see L<Locale::Object::DB::Schemata> for a full listing of the contents of the database.
    
=head2 C<languages()>

    my @languages = $country->languages;

Returns an array of L<Locale::Object::Language> objects in array context, or a reference in scalar context. The objects have their own attribute methods, so you can do things like this:

    foreach my $lang (@languages)
    {
      print $lang->name, "\n";
    }

If you use the C<official()> method of a L<Locale::Object::Language> object on a country object, it will return a boolean value describing whether the language is official in that country.

=head1 AUTHOR

Earle Martin <EMARTIN@cpan.org>

=over 4 

=item L<http://purl.oclc.org/net/earlemartin/>

=back

=head1 CREDITS

See the credits for L<Locale::Object>.

=head1 LEGAL

Copyright 2003 Fotango Ltd. All rights reserved. L<http://opensource.fotango.com/>

This module is released under the same license as Perl itself, and is provided on an "as is" basis. The author and Fotango Ltd make no warranties of any kind, either expressed or implied, as to the accuracy and/or utility of any results obtained from its use. However, if you do find something wrong with the results, please let the author know. Thanks.

=cut