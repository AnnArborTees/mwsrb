# Mwsrb

Welcome to your new gem! In this directory, you'll find the files you need to be able to package up your Ruby library into a gem. Put your Ruby code in the file `lib/mwsrb`. To experiment with that code, run `bin/console` for an interactive prompt.

TODO: Delete this and the text above, and describe your gem

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'mwsrb'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install mwsrb

## Usage

Initialize with debug logging:

```ruby
mws = Amazon::Client.new(debug_log: method(:puts))
mws['Products'].request(...)
```

or

```ruby
mws = Amazon::Client.new
mws['Products', debug_log: method(:puts)].request(...)
```
