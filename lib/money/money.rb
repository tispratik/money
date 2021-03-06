require 'money/variable_exchange_bank'

# Represents an amount of money in a certain currency.
class Money
  unloadable # <= That's the ticket!
  include Comparable

  attr_reader :cents, :currency, :bank
  
  class << self
    # Each Money object is associated to a bank object, which is responsible
    # for currency exchange. This property allows one to specify the default
    # bank object.
    #
    #   bank1 = MyBank.new
    #   bank2 = MyOtherBank.new
    #   
    #   Money.default_bank = bank1
    #   money1 = Money.new(10)
    #   money1.bank  # => bank1
    #   
    #   Money.default_bank = bank2
    #   money2 = Money.new(10)
    #   money2.bank  # => bank2
    #   money1.bank  # => bank1
    #
    # The default value for this property is an instance if VariableExchangeBank.
    # It allows one to specify custom exchange rates:
    #
    #   Money.default_bank.add_rate("USD", "CAD", 1.24515)
    #   Money.default_bank.add_rate("CAD", "USD", 0.803115)
    #   Money.us_dollar(100).exchange_to("CAD")  # => Money.ca_dollar(124)
    #   Money.ca_dollar(100).exchange_to("USD")  # => Money.us_dollar(80)
    attr_accessor :default_bank
    
    # The default currency, which is used when <tt>Money.new</tt> is called
    # without an explicit currency argument. The default value is "USD".
    attr_accessor :default_currency
  end
  
  self.default_bank = VariableExchangeBank.instance
  self.default_currency = "USD"
  
  
  # Create a new money object with value 0.
  def self.empty(currency = default_currency)
    Money.new(0, currency)
  end

  # Creates a new Money object of the given value, using the Canadian dollar currency.
  def self.ca_dollar(cents)
    Money.new(cents, "CAD")
  end

  # Creates a new Money object of the given value, using the American dollar currency.
  def self.us_dollar(cents)
    Money.new(cents, "USD")
  end
  
  # Creates a new Money object of the given value, using the Euro currency.
  def self.euro(cents)
    Money.new(cents, "EUR")
  end
  
  def self.add_rate(from_currency, to_currency, rate)
    Money.default_bank.add_rate(from_currency, to_currency, rate)
  end
  
  
  # Creates a new money object. 
  #  Money.new(100) 
  # 
  # Alternativly you can use the convinience methods like 
  # Money.ca_dollar and Money.us_dollar 
  def initialize(cents, currency = Money.default_currency, bank = Money.default_bank)
    @cents = cents.round
    @currency = currency
    @bank = bank
  end

  # Do two money objects equal? Only works if both objects are of the same currency
  def ==(other_money)
    other_money = other_money.to_money
    cents == other_money.cents && bank.same_currency?(currency, other_money.currency)
  end

  def <=>(other_money)
    other_money = other_money.to_money
    if bank.same_currency?(currency, other_money.currency)
      cents <=> other_money.cents
    else
      cents <=> other_money.exchange_to(currency).cents
    end
  end

  def +(other_money)
    other_money = other_money.to_money
    if currency == other_money.currency
      Money.new(cents + other_money.cents, other_money.currency)
    else
      Money.new(cents + other_money.exchange_to(currency).cents,currency)
    end
  end

  def -(other_money)
    other_money = other_money.to_money
    if currency == other_money.currency
      Money.new(cents - other_money.cents, other_money.currency)
    else
      Money.new(cents - other_money.exchange_to(currency).cents, currency)
    end
  end

  # get the cents value of the object
  def cents
    @cents
  end

  # multiply money by fixnum
  def *(fixnum)
    Money.new(cents * fixnum, currency)
  end

  # divide money by fixnum
  def /(fixnum)
    Money.new(cents / fixnum, currency)
  end
  
  # Test if the money amount is zero
  def zero?
    cents == 0
  end


  # Creates a formatted price string according to several rules. The following
  # options are supported: :display_free, :with_currency, :no_cents, :symbol
  # and :html.
  #
  # === +:display_free+
  #
  # Whether a zero amount of money should be formatted of "free" or as the
  # supplied string.
  #
  #  Money.us_dollar(0).format(:display_free => true)      => "free"
  #  Money.us_dollar(0).format(:display_free => "gratis")  => "gratis"
  #  Money.us_dollar(0).format => "$0.00"
  #
  # === +:with_currency+
  #
  # Whether the currency name should be appended to the result string.
  #
  #  Money.ca_dollar(100).format => "$1.00"
  #  Money.ca_dollar(100).format(:with_currency => true) => "$1.00 CAD"
  #  Money.us_dollar(85).format(:with_currency => true)  => "$0.85 USD"
  #
  # === +:no_cents+
  #
  # Whether cents should be omitted.
  #
  #  Money.ca_dollar(100).format(:no_cents => true) => "$1"
  #  Money.ca_dollar(599).format(:no_cents => true) => "$5"
  #  
  #  Money.ca_dollar(570).format(:no_cents => true, :with_currency => true) => "$5 CAD"
  #  Money.ca_dollar(39000).format(:no_cents => true) => "$390"
  #
  # === +:symbol+
  #
  # Whether a money symbol should be prepended to the result string. The default is true.
  # This method attempts to pick a symbol that's suitable for the given currency.
  #
  #  Money.new(100, "USD")  => "$1.00"
  #  Money.new(100, "GBP")  => "£1.00"
  #  Money.new(100, "EUR")  => "€1.00"
  #  
  #  # Same thing.
  #  Money.new(100, "USD").format(:symbol => true)  => "$1.00"
  #  Money.new(100, "GBP").format(:symbol => true)  => "£1.00"
  #  Money.new(100, "EUR").format(:symbol => true)  => "€1.00"
  #
  # You can specify a false expression or an empty string to disable prepending
  # a money symbol:
  #
  #  Money.new(100, "USD").format(:symbol => false)  => "1.00"
  #  Money.new(100, "GBP").format(:symbol => nil)    => "1.00"
  #  Money.new(100, "EUR").format(:symbol => "")     => "1.00"
  #
  #  
  # If the symbol for the given currency isn't known, then it will default
  # to "$" as symbol:
  #
  #  Money.new(100, "AWG").format(:symbol => true)  => "$1.00"
  #
  # You can specify a string as value to enforce using a particular symbol:
  #
  #  Money.new(100, "AWG").format(:symbol => "ƒ")   => "ƒ1.00"
  #
  # === +:html+
  #
  # Whether the currency should be HTML-formatted. Only useful in combination with +:with_currency+.
  #
  #  Money.ca_dollar(570).format(:html => true, :with_currency => true)
  #    =>  "$5.70 <span class=\"currency\">CAD</span>"
  def format(*rules)
    # support for old format parameters
    rules = normalize_formatting_rules(rules)
    
    if cents == 0
      if rules[:display_free].respond_to?(:to_str)
        return rules[:display_free]
      elsif rules[:display_free]
        return "free"
      end
    end

    if !rules.has_key?(:symbol) || rules[:symbol] === true
        symbol = SYMBOLS[currency] || "$"
    elsif rules[:symbol]
      symbol = rules[:symbol]
    else
      symbol = ""
    end

    if rules[:no_cents]
      formatted = sprintf("#{symbol}%d", cents.to_f / 100)
    else
      formatted = sprintf("#{symbol}%.2f", cents.to_f / 100)
    end
    
    # Commify ("10000" => "10,000")
    unless rules[:no_commas]
      formatted.gsub!(/(\d)(?=\d{3}+(?:\.|$))(\d{3}\..*)?/,'\1,\2')
    end
    
    if rules[:with_currency]
      formatted << " "
      formatted << '<span class="currency">' if rules[:html]
      formatted << currency
      formatted << '</span>' if rules[:html]
    end
    formatted
  end  
  
  # Returns the amount of money as a string.
  #
  #  Money.ca_dollar(100).to_s => "1.00"
  def to_s
    sprintf("%.2f", cents / 100.00)
  end
  
  # Recieve the amount of this money object in another currency.
  def exchange_to(other_currency)
    Money.new(@bank.exchange(self.cents, currency, other_currency), other_currency)
  end  
  
  # Recieve a money object with the same amount as the current Money object
  # in american dollar 
  def as_us_dollar
    exchange_to("USD")
  end
  
  # Recieve a money object with the same amount as the current Money object
  # in canadian dollar 
  def as_ca_dollar
    exchange_to("CAD")
  end
  
  # Recieve a money object with the same amount as the current Money object
  # in euro
  def as_euro
    exchange_to("EUR")
  end
  
  # Conversation to self
  def to_money
    self
  end
  
  private
  
  def normalize_formatting_rules(rules)
    if rules.size == 1
      rules = rules.pop
      rules = { rules => true } if rules.is_a?(Symbol)
    else
      rules = rules.inject({}) do |h,s|
        h[s] = true
        h
      end
    end
    rules
  end
end
