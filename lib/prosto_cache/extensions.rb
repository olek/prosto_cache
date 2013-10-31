module ProstoCache
  module Extensions
    def lookup_enum_for(name, enum_class=nil)
      raise ArgumentError, "No name provided" unless name
      enum_class = name.to_s.classify.constantize unless enum_class
      define_method("#{name}_with_lookup=") do |o|
        new_value = o
        unless o.is_a?(enum_class)
          new_value = o.blank? ? nil : enum_class[o.to_s]
        end
        self.send("#{name}_without_lookup=", new_value)
      end

      alias_method_chain "#{name}=", :lookup
    end
  end
end
