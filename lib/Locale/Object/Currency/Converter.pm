package Locale::Object::Currency::Converter;

use strict;
use warnings::register;
use Carp qw(croak);
use vars qw($VERSION);

use Scalar::Util qw(looks_like_number);

$VERSION = "0.1";

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
  
  # Make a hash of valid parameters.
  my %allowed_params = map { $_ => undef }
    qw(service from to);

  foreach my $key (keys %params)
  {
    # Go no further if the specified parameter wasn't one.
    croak "Error: You can only specify a service to use and currencies to convert between for initialization." unless exists $allowed_params{$key};
  }

  # Set an attribute of the chosen currency conversion service.
  if ($params{service})
  {
    croak "Error: Values for service can be 'XE' or 'Yahoo'; you said $params{service}." unless $params{service} =~ /^Yahoo$|^XE$/;
    
    $self->{service} = $params{service};
  }
  
  # Set an attribute of the currency to convert from.
  if ($params{from})
  {
    croak "Error: you can only use a Locale::Object::Currency object to convert from." unless $params{from}->isa('Locale::Object::Currency');
    
    $self->{from} = $params{from};
  }

  # Set an attribute of the currency to convert to.
  if ($params{to})
  {
    croak "Error: you can only use a Locale::Object::Currency object to convert from." unless $params{to}->isa('Locale::Object::Currency');

    $self->{to} = $params{to};
  }
  
  # Return the object.
  $self;
}

# Set currency service to be used.
sub service
{
  my $self = shift;
  my $service = shift;
  
  croak "Error: Values for service can be 'XE' or 'Yahoo'; you said $service." unless $service =~ /^Yahoo$|^XE$/;
    
  $self->{service} = $service;
}

# Set currency to be converted from.
sub from
{
  my $self = shift;
  my $from = shift;

  croak "Error: you can only use a Locale::Object::Currency object to convert from." unless $from->isa('Locale::Object::Currency');
    
  $self->{from} = $from;
}

# Set currency to converted to.
sub to
{
  my $self = shift;
  my $to   = shift;

  croak "Error: you can only use a Locale::Object::Currency object to convert to." unless $to->isa('Locale::Object::Currency');
    
  $self->{to} = $to;

}

# Do currency conversions.
sub convert
{
  my $self = shift;
  my $value = shift;
  
  # Test if $value is numeric with Scalar::Util.
  croak "Error: Argument '$value' to convert not numeric" unless looks_like_number($value);

  croak "Error: No currency set to convert from" unless $self->{from};
  croak "Error: No currency set to convert to" unless $self->{to};
  croak "Error: No service specified for conversion" unless $self->{service};

  my $result;
  
  if ($self->{service} eq 'Yahoo')
  {
    $result = _yahoo($self, $value);
  }
  elsif ($self->{service} eq 'XE')
  {
    $result = _xe($self, $value);
  }
  
  $result;
}

# Internal method to do Yahoo! currency conversions.
sub _yahoo
{
  my $self  = shift;
  my $value = shift;
  
  use Finance::Currency::Convert::Yahoo;

  # We're not in a talkative mood.
  $Finance::Currency::Convert::Yahoo::CHAT = undef;

  my $result = Finance::Currency::Convert::Yahoo::convert($value,$self->{from}->code,$self->{to}->code);

  $result;
}

# Internal method to do XE currency conversions.
sub _xe
{
  my $self = shift;
  my $value = shift;
  
  use Finance::Currency::Convert::XE;

  my $xe = Finance::Currency::Convert::XE->new() or croak "Error: Couldn't create Finance::Currency::Convert::XE object: $!";

  return $xe->convert(
                      'source' => $self->{from}->code,
                      'target' => $self->{to}->code,
                      'value'  => $value
                     ) || croak $xe->error;
}

# Give the exchange rate of the currencies.
sub rate
{
  my $self = shift;

  # If there's no rate stored, set one.
  $self->refresh unless $self->{rate};

  return $self->{rate};
}

# Give the time that the rate was stored.
sub timestamp
{
  my $self = shift;
 
  if ($self->{timestamp})
  {
    return $self->{timestamp};
  }
  else
  {
    return undef;
  }
}

# Update the exchange rate.
sub refresh
{
  my $self = shift;

  # Do a conversion to get the rate.
  my $rate = $self->convert(1);

  # Make a note of the rate and the time.
  $self->{rate}      = $rate;
  $self->{timestamp} = time;  
}

1;

__END__

=head1 NAME

Locale::Object::Currency::Converter - convert between currencies

=head1 VERSION

0.1

=head1 DESCRIPTION

C<Locale::Object::Currency::Converter> allows you to convert between values of currencies represented by L<Locale::Object::Currency> objects.

=head1 SYNOPSIS

    use Locale::Object::Currency;
    use Locale::Object::Currency::Converter;
    
    my $usd = Locale::Object::Currency->new( code => 'USD' );
    my $gbp = Locale::Object::Currency->new( code => 'GBP' );
    my $eur = Locale::Object::Currency->new( code => 'EUR' );
    my $jpy = Locale::Object::Currency->new( code => 'JPY' );
    
    my $converter = Locale::Object::Currency::Converter->new(
                                                from    => $usd,
                                                to      => $gbp,
                                                service => 'XE'
                                               );

    my $result    = $converter->convert(5);
    my $rate      = $converter->rate;
    my $timestamp = $converter->timestamp;
    
    $converter->from($eur);
    $converter->to($jpy);
    $converter->service('Yahoo');

    $converter->refresh;

=head1 PREREQUISITES

This module requires L<Finance::Currency::Convert::XE> and L<Finance::Currency::Convert::Yahoo>.
    
=head1 METHODS

=head2 C<new()>

    my $converter = Locale::Object::Currency::Converter->new();

Creates a new converter object. With no arguments, creates a blank object. Possible arguments are C<from>, C<to> and C<service>, all or none of which may be given. C<from> and C<to> must be L<Locale::Object::Currency> objects. C<service> must be one of either 'XE' or 'Yahoo', to specify the conversion should be done by L<http://xe.com/ucc/> or L<http://finance.yahoo.com/> respectively.

=head2 C<from()>

    $converter->from($eur);

Sets a currency to do conversions from. Takes a L<Locale::Object::Currency> object.

=head2 C<to()>

    $converter->to($jpy);

Sets a currency to do conversions to. Takes a L<Locale::Object::Currency> object.

=head2 C<service()>

    $converter->service('Yahoo');

Sets which currency conversion service to use.

=head2 C<convert()>

    my $result = $converter->convert(5);

Does the currency conversion. Takes a numeric argument representng the amount of the 'from' currency to convert into the 'to' currency, gives the result. Will croak if you didn't select a conversion service, 'from' and 'to' currency when you did C<new()> or afterwards with the associated methods (see above).

=head2 C<rate()>

    my $rate = $converter->rate;

Returns the conversion rate between your 'from' currency and your 'to' currency, as of the time you last did a conversion. If you haven't done any conversions yet, will do one first (the result for converting 1 unit of a currency into another currency is the rate) and give you that.

=head2 C<timestamp()>

    my $timestamp = $converter->timestamp;

Returns the L<time> timestamp of the last time the currency exchange rate was stored, either the last time you did a C<convert()> or a C<refresh()>.

=head2 C<refresh()>

    $converter->refresh;
    
Will update the stored conversion rate and timestamp by doing another conversion. Doesn't return anything.

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

