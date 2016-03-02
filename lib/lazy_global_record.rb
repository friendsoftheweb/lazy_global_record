require 'lazy_global_record/version'
require 'concurrent'

class LazyGlobalRecord
  @all_instances = Concurrent::Array.new
  class << self
    def register(instance)
      @all_instances.push instance
    end
    def reset_all
      @all_instances.each { |instance| instance.reset if instance.resettable? }
    end
  end

  def initialize( relation:,
                  filter: nil,
                  create_with: nil,
                  resettable: true,
                  creatable: !Rails.env.production?)

    @resettable     = resettable
    @creatable      = creatable
    @relation_proc  = relation
    @filter         = filter || lambda { |record| record.id }
    @create_proc    = create_with || lambda { @relation_proc.call.reset.create! }

    @slot = Concurrent::AtomicReference.new
    @slot.set( create_delay )

    self.freeze

    self.class.register(self)
  end

  def value
    # double-deref, our atomic slot, and the delay itself.
    # needed so we can #reset in a thread-safe way too.
    delay = @slot.value

    value = delay.value
    if delay.reason
      raise delay.reason
    end
    value
  end

  def resettable?
    !!@resettable
  end

  def creatable?
    !!@creatable
  end

  def reset
    raise TypeError.new("This LazyGlobalRecord object is not resettable") unless resettable?
    @slot.set( create_delay )
  end

  protected

  def create_delay
    Concurrent::Delay.new do
      ActiveRecord::Base.connection_pool.with_connection do
        ActiveRecord::Base.transaction do
          relation = @relation_proc.call.reset
          result = relation.first

          if result.nil? && creatable?
            result = @create_proc.call
          elsif result.nil?
            raise ActiveRecord::RecordNotFound.new("LazyGlobalRecord could not load identified record")
          end

          result = @filter.call(result).freeze

          result
        end
      end
    end
  end
end
