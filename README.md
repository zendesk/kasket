# Kasket

### Puts a cap on your queries
A caching layer for ActiveRecord.

Developed and used by [Zendesk](http://zendesk.com).

## Sponsored by Zendesk - Enlightened Customer Support

## Description

Kasket is a safe way to cache your database queries in memcached.
Designed to be as small and simple as possible, and to get out of the way when it is not safe to cache.

You can configure exactly what models to cache and what type of queries to cache.

### Features

* Declarative configuration
* Collection caching as well as caching of single instances
* Automatic cache expiry on database migration
* Automatic cache expiry in Kasket udates
* Very small code base

## Setting up Kasket

Kasket is set up by simply calling `Kasket.setup` in an initializer script.
This will include the required modules into ActiveRecord.

### Options

#### Max Collection Size

By default, Kasket will cache each instance collection with a maximum length of 100.
You can override this by passing the `:max_collection_size` option to the `Kasket.setup` call:

```ruby
Kasket.setup(max_collection_size: 50)
```

#### Write-Through Caching

By default, when a model is saved, Kasket will invalidate cache entries by deleting them.
You can pass ':write_through => true' to the `Kasket.setup` call to get write-through cache
semantics instead. In this mode, the model will be updated in the cache as well as the database.

```ruby
Kasket.setup(write_through: true)
```

#### Events Callback

You can configure a callable object to listen to events, e.g. `cache_hit`. This can be useful to emit metrics and observe Kasket's behaviour.

```ruby
Kasket.setup(events_callback: -> (event, ar_klass) do
  MyMetrics.increase_some_counter("kasket.#{event}", tags: ["table:#{ar_klass.table_name}"])
end)
```

## Configuring caching of your models

You can configure Kasket for any ActiveRecord model, and subclasses will automatically inherit the caching
configuration.

If you have an `Account` model, you can can do the simplest caching configuration like:

```ruby
Account.has_kasket
```

This will add a caching index on the id attribute of the Account model,
and will make sure that all your calls like `Account.find(1)` and `Account.find_by_id(1)` will be cached.
All other calls (say, `Account.find_by_subdomain('zendesk')`) are untouched.

If you wanted to configure a caching index on the subdomain attribute of the Account model, you would simply write

```ruby
Account.has_kasket_on :subdomain
```

This would add caching to calls like:
* `Account.find_by_subdomain('zendesk')`
* `Account.find_all_by_subdomain('zendesk')`

and all other ways of expressing lookups on subdomain.

## Cache expiry

The goal of Kasket is to be as safe as possible to use, so the cache is expired in a number of situations:
* When you save a model instance
* When your database schema changes
* When you install a new version of Kasket
* After a global or per-model TTL
* When you ask it to

### Cache expiry on instance save

When you save a model instance, Kasket will calculate the cache entries to expire.

### Cache expiry on database schema changes

All Kasket cache keys contain a hash of the column names of the table associated with the model.
If you somehow change your table schema, all cache entries for that table will automatically expire.

### Cache expiry on Kasket upgrades

All Kasket cache keys contain the Kasket version number, so upgrading Kasket will expire all Kasket cache entries.

### Cache expiry by TTL

Sometimes caches like memcache can become incoherent. One layer of mitigation for this problem is to specify the maximum length a value may stay in cache before being expired and re-calculated. You can configure an optional default TTL value at setup:

```ruby
Kasket.setup(default_expires_in: 24.hours)
```

You can further specify per-model TTL values:

```ruby
Account.kasket_expires_in 5.minutes
```

### Manually expiring caches

If you have model methods that update the database behind the back of ActiveRecord, you need to mark these methods
as being dirty.

```ruby
Account.kasket_dirty_methods :update_last_action
```

This will make sure the clear the cache entries for the current instance when you call `update_last_action`.

## How does this work?

## Known issues

We have only used and tested Kasket with MySQL.

Let us know if you find any.

## Isn't this what [Cache Money](https://github.com/nkallen/cache-money) does?

Absolutely, but Cache Money does so much more.
* Cache Money has way more features than what we need.
* The Cache Money code is overly complex.
* Cache Money seems abandoned.

## Development

Run the tests with:

```
$ rake test
```

Access a dev console running on the local test DB:

```
$ bin/console
```

## Note on Patches/Pull Requests

* Fork the project.
* Make your feature addition or bug fix.
* Add tests for it. This is important so I don't break it in a future version unintentionally.
* Commit, do not mess with Rakefile, version, or history.
  (If you want to have your own version, that is fine but bump version in a commit by itself I can ignore when I pull.)
* Send me a pull request. Bonus points for topic branches.

## Copyright and license

Copyright 2013 Zendesk

Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.
