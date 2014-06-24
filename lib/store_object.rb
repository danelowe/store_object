class StoreObject
  include ActiveModel::Validations
  include ActiveRecord::AttributeAssignment
  class_attribute :stored_object_attributes, :attr_defaults
  self.stored_object_attributes = {}

  delegate :persisted?, to: :@parent

  class << self
    def store_object_accessor(*keys)
      keys = keys.flatten

      _store_object_accessors_module.module_eval do
        keys.each do |key|
          define_method("#{key}=") do |value|
            write_store_object_attribute(key, value)
          end

          define_method(key) do
            read_store_object_attribute(key)
          end
        end
      end
    end

    def attr_store(key, options = {})
      store_object_accessor([key])
      opt = {}
      opt[:default] = options[:default] unless options[:default].nil?
      opt[:type] = options[:type] unless options[:type].nil?
      self.stored_object_attributes[key] = opt
    end

    def _store_object_accessors_module
      @_store_object_accessors_module ||= begin
        mod = Module.new
        include mod
        mod
      end
    end


  end

  def defaults
    HashWithIndifferentAccess.new(self.class.attr_defaults)
  end

  def initialize parent, store_attribute
    @parent = parent
    @store_attribute = store_attribute
    column_types = parent.instance_variable_get(:@column_types)
    @accessor = column_types[store_attribute.to_s].accessor
  end

  def update_attributes(attributes = {})
    assign_attributes(attributes)
    save
  end

  def save
    @parent.save
  end

  def attributes
    (@parent.send(@store_attribute)||{}).symbolize_keys
  end

  protected
  def cast value, type
    case type
      when :boolean
        value.nil? ? nil : value == 'true' ? true : false
      else
        value
    end
  end

  def read_store_object_attribute(key)
    cast(@accessor.read(@parent, @store_attribute, key),  stored_object_attributes[key][:type]) || stored_object_attributes[key][:default]
  end

  def write_store_object_attribute(key, value)
    #don't overwrite if same as default.
    return value if value == read_store_object_attribute(key)
    @accessor.write(@parent, @store_attribute, key, value)
  end
end