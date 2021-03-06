module ObfuscateId
  def obfuscate_id(options = {})
    require 'scatter_swap'

    extend ClassMethods
    include InstanceMethods

    cattr_accessor :obfuscate_id_spin, :clean_url_class_name

    self.obfuscate_id_spin = (options[:spin] || obfuscate_id_default_spin)
    set_clean_url_class_name
  end

  def self.hide(id, name, spin)
    'oid-' + ScatterSwap.hash(id, spin)
  end

  def self.show(id, name, spin)
    ScatterSwap.reverse_hash(id.gsub('oid-', ''), spin)
  end

  module ClassMethods

    def set_clean_url_class_name
      self.clean_url_class_name = self.name.gsub("::", "-").underscore
    end

    def find(*args)
      scope = args.slice!(0)
      options = args.slice!(0) || {}
      if has_obfuscated_id? && !options[:no_obfuscated_id]
        if scope.is_a?(Array)
          scope.map! {|a| deobfuscate_id(a).to_i}
        else
          scope = deobfuscate_id(scope)
        end
      end
      super(scope)
    end

    def has_obfuscated_id?
      true
    end

    def deobfuscate_id(obfuscated_id)
      if obfuscated_id.to_s.start_with? 'oid-'
        ObfuscateId.show(obfuscated_id, self.clean_url_class_name, self.obfuscate_id_spin)
      else
        obfuscated_id
      end
    end

    # Generate a default spin from the Model name
    # This makes it easy to drop obfuscate_id onto any model
    # and produce different obfuscated ids for different models
    def obfuscate_id_default_spin
      alphabet = Array("a".."z")
      number = name.split("").collect do |char|
        alphabet.index(char)
      end

      number.shift(12).join.to_i
    end
  end

  module InstanceMethods
    def to_param
      ObfuscateId.hide(self.id, self.clean_url_class_name, self.class.obfuscate_id_spin)
    end

    # Override ActiveRecord::Persistence#reload
    # passing in an options flag with { no_obfuscated_id: true }
    def reload(options = nil)
      options = (options || {}).merge(no_obfuscated_id: true)

      clear_aggregation_cache
      clear_association_cache

      fresh_object =
        if options && options[:lock]
          self.class.unscoped { self.class.lock(options[:lock]).find(id, options) }
        else
          self.class.unscoped { self.class.find(id, options) }
        end

      @attributes = fresh_object.instance_variable_get('@attributes')
      @new_record = false
      self
    end

    def deobfuscate_id(obfuscated_id)
      self.class.deobfuscate_id(obfuscated_id)
    end
  end
end

ActiveRecord::Base.extend ObfuscateId
