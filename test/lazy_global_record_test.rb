require 'test_helper'
require 'ostruct'

class LazyGlobalRecordTest < ActiveSupport::TestCase

  test "it returns id by default" do
    Value.create(value: "one")

    lazy = LazyGlobalRecord.new(
      relation: -> { Value.where(value: "one") }
    )

    assert lazy.value.present?
    assert_equal lazy.value, Value.where(value: "one").first.id

    one_fetch = lazy.value
    assert_equal one_fetch, lazy.value
  end

  test "it raises on no record when creation not allowed" do
    lazy = LazyGlobalRecord.new(
      relation: -> { Value.where(value: "two") },
      creatable: false
    )

    assert_raise(ActiveRecord::RecordNotFound) { lazy.value }
  end

  test "it creates a record when creation allowed" do
    lazy = LazyGlobalRecord.new(
      relation: -> { Value.where(value: "three") },
      creatable: true
    )

    assert_equal "three", Value.find(lazy.value).value
  end

  test "it does not allow reset when not allowed" do
    lazy = LazyGlobalRecord.new(
      relation: -> { Value.where(value: "four") },
      resettable: false
    )

    lazy.value
    assert_raise(TypeError) { lazy.reset }
  end

  test "it does allow reset when allowed" do
    Value.create(value: "five", other_value: "first")

    lazy = LazyGlobalRecord.new(
      relation: -> { Value.where(value: "five") },
      resettable: true
    )

    lazy.value

    Value.delete_all
    Value.create(value: "five", other_value: "second")

    lazy.reset
    assert_equal "second", Value.find(lazy.value).other_value
  end

  test "it reloads" do
    Value.create(value: "five", other_value: "first")

    lazy = LazyGlobalRecord.new(
      relation: -> { Value.where(value: "five") },
      resettable: true
    )

    lazy.value

    Value.delete_all
    Value.create(value: "five", other_value: "second")

    lazy.reload

    assert_equal "second", Value.find(lazy.value).other_value
  end

  test "it uses custom creation proc" do
    lazy = LazyGlobalRecord.new(
      relation: -> { Value.where(value: "six") },
      create_with: -> {  Value.where(value: "six", other_value: "manual").create! },
      creatable: true
    )

    assert_equal "manual", Value.find(lazy.value).other_value

  end

  test "raises an exception if exceptions are raised" do
    lazy = LazyGlobalRecord.new(
      relation: -> { Value.where(value: "six") ; raise ArgumentError.new("expected") },
    )
    assert_raise(ArgumentError) { lazy.value }

    lazy = LazyGlobalRecord.new(
      relation: -> { Value.where(value: "nonesuch")},
      creatable: true,
      create_with: -> { raise ArgumentError.new("expected")  }
    )
    assert_raise(ArgumentError) { lazy.value }

    # and a second time please
    assert_raise(ArgumentError) { lazy.value }
  end


  test "custom filter" do
    Value.create(:value => "seven", :other_value => "treasure")
    lazy = LazyGlobalRecord.new(
      relation: -> { Value.where(value: "seven") },
      creatable: true,
      filter: ->(v) { OpenStruct.new(:id => v.id, :other_value => v.other_value, :more => "more") }
    )

    struct = lazy.value

    assert_kind_of OpenStruct, struct
    assert struct.frozen?
    assert struct.id.present?
    assert_equal "treasure", struct.other_value
    assert_equal "more", struct.more
  end

  test "raises on exceptions in filter" do
    lazy = LazyGlobalRecord.new(
      relation: -> { Value.where(value: "one") },
      filter: lambda { |original| raise ArgumentError, "intentional" }
    )

    assert_raise(ArgumentError) { lazy.value }
    # and ensure a second time please
    assert_raise(ArgumentError) { lazy.value }
  end

  test "FROZEN_MODEL filter" do
    Value.create(value: "one")

    lazy = LazyGlobalRecord.new(
      relation: -> { Value.where(value: "one") },
      filter: LazyGlobalRecord::FROZEN_MODEL
    )

    value = lazy.value

    assert value.present?
    assert_kind_of Value, value
    assert value.frozen?
    assert value.readonly?
  end
end
