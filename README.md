# LazyGlobalRecord

[![Gem Version](https://badge.fury.io/rb/lazy_global_record.svg)](https://badge.fury.io/rb/lazy_global_record)

Lazy loading of 'interesting' ActiveRecord model id's, thread-safely and with
easy cache reset and lazy creation in testing. Uses ruby-concurrent
as a dependency.

You might find yourself doing this in Rails:

~~~ruby
class Department < ActiveRecord::Base
   # Bad idea, don't do this.
   def self.master_department_id
     @@master_department_id ||= where(name: "master").first.id
   end
   # ...
end
~~~~

A class acessor that looks up a particular record of concern in the db,
and caches it's id.

First of all, if you can find any way to _not_ do this in your architecture,
you'll be happier.  But maybe you can't get out of it.

If you take that naive approach, it ends up raising heck on your test
environment. DatabaseCleaner is cleaning out your db after every
test, so that record that you always expect to be there isn't;
if you switch to `first_or_create`, you still have a problem
because you don't really want to be silently creating the
record in production, and even in test when you silently create
it, it ends up getting cached, but then DatabaseCleaner cleans
it out and the cached value is wrong. And it's none of it thread-safe,
and this is 2016, get with the concurrency program already.

So this gem provides an answer, with a pattern to fetch and cache
an ActiveRecord model `id` (or other values), lazily, thread-safely,
with auto-creation and easy cache reset in test env.

~~~ruby
class Department < ActiveRecord::Base
    @lazy_master_department_id = LazyGlobalRecord.new(
      relation: -> { where(name: "master") }
    )
    def self.master_department_id
      @lazy_master_departent_id.value
    end
end
~~~

Note the `relation` argument is a `proc`.

It won't look up the database until you ask for `value`.
It'll take your relation, call `.first.id` on it, and cache the result.
By default in production, it'll raise an `ActiveRecord::RecordNotFound`
if it can't be found.

## In Test/Dev: Auto-creation, and reset

In development/test, it'll automatically create the record if it's not
found, adding `create!` onto your relation.

You can customize the creation routine:

~~~ruby
class Department < ActiveRecord::Base
    @lazy_master_department_id = LazyGlobalRecord.new(
      relation: -> { where(name: "master") }
      creatable: true # default true unless production

      # Use whatever you want to create!
      create_with: -> { FactoryGirl.create(:master_department) }
    )
end
~~~

Also, in your test setup, you can call `LazyGlobalRecord.reset_all` to
reset *all* LazyGlobalRecord objects to fetch again next time they
are called. *You want to do this* after any `DatabaseCleaner.clean`
in your test setup. You likely have one in a `before(:suite)` and
another in a `before(:each)` in your `spec_helper.rb`. Put
a `LazyGlobalRecord.reset_all` after each and any `DatabaseCleaner.clean`
or `clean_with` calls, to reset cached values when the db is cleaned out.

### Custom transformations

What if you need more than just the `id`?  You can supply a custom
`filter` proc.

We really recommend against cacheing actual ActiveRecord objects, instead
use an OpenStruct to cache whatever values you need.

~~~ruby
class Department < ActiveRecord::Base
    @lazy_master_department_id = LazyGlobalRecord.new(
      relation: -> { where(name: "master") }
      filter: ->(obj) { OpenStruct.new(:id => obj.id, :city => obj.city, :boss_ids => obj.bosses.map(&:id))}
    )
    def self.master_department_id
      @lazy_master_department_id.value.id
    end
    def self.master_department_city
      @lazy_master_department_id.value.city
    end
    def self.master_boss_ids
      @lazy_master_department_id.value.boss_ids
    end
end
~~~

The object you return from a custom `filter` proc will be frozen for you.

Keep in mind anything you do here will ordinarily be cached for the life
of the process, you need to only cache things that won't change, or
deal with cache invalidation by calling `reset` on the LazyGlobalRecord
where appropriate.
