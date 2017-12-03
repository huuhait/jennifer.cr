module Jennifer
  module View
    module ExperimentalMapping
      # Generates getter and setters
      macro __field_declaration
        {% for key, value in COLUMNS_METADATA %}
          @{{key.id}} : {{value[:parsed_type].id}}

          {% if value[:setter] != false %}
            def {{key.id}}=(_{{key.id}} : {{value[:parsed_type].id}})
              @{{key.id}} = _{{key.id}}
            end
          {% end %}

          {% if value[:getter] != false %}
            def {{key.id}}
              @{{key.id}}
            end

            {% if value[:null] != false %}
              def {{key.id}}!
                @{{key.id}}.not_nil!
              end
            {% end %}
          {% end %}

          def self._{{key}}
            c({{key.stringify}})
          end

          {% if value[:primary] %}
            def primary
              @{{key.id}}
            end

            def self.primary
              c({{key.stringify}})
            end

            def self.primary_field_name
              {{key.stringify}}
            end

            def self.primary_field_type
              {{value[:parsed_type].id}}
            end
          {% end %}
        {% end %}
      end

      macro __instance_methods
        # Creates object from `DB::ResultSet`
        def initialize(%pull : DB::ResultSet)
          {{COLUMNS_METADATA.keys.map { |f| "@#{f.id}" }.join(", ").id}} = _extract_attributes(%pull)
        end

        def initialize(values : Hash(String, ::Jennifer::DBAny))
          {{COLUMNS_METADATA.keys.map { |f| "@#{f.id}" }.join(", ").id}} = _extract_attributes(values)
        end

        # Accepts symbol hash or named tuple, stringify it and calls
        # TODO: check how converting affects performance
        def initialize(values : Hash(Symbol, ::Jennifer::DBAny) | NamedTuple)
          initialize(stringify_hash(values, Jennifer::DBAny))
        end

        def initialize(values : Hash | NamedTuple, new_record)
          initialize(values)
        end

        # Extracts arguments due to mapping from *pull* and returns tuple for
        # fields assignment. It stands on that fact result set has all defined fields in a raw
        # TODO: think about moving it to class scope
        # NOTE: don't use it manually - there is some dependencies on caller such as reading tesult set to the end
        #  if eception was raised
        def _extract_attributes(pull : DB::ResultSet)
          {% for key in COLUMNS_METADATA.keys %}
            %var{key.id} = nil
            %found{key.id} = false
          {% end %}
          own_attributes = {{COLUMNS_METADATA.size}}
          pull.each_column do |column|
            break if own_attributes == 0
            case column
            {% for key, value in COLUMNS_METADATA %}
              when {{value[:column_name] ? value[:column_name].id : key.id.stringify}}
                own_attributes -= 1
                %found{key.id} = true
                begin
                  %var{key.id} = pull.read({{value[:parsed_type].id}})
                rescue e : Exception
                  raise ::Jennifer::DataTypeMismatch.new(column, {{@type}}, e) if ::Jennifer::DataTypeMismatch.match?(e)
                  raise e
                end
            {% end %}
            else
              {% if STRICT_MAPPNIG %}
                raise ::Jennifer::BaseException.new("Undefined column #{column} for model {{@type}}.")
              {% else %}
                pull.read
              {% end %}
            end
          end
          pull.read_to_end
          {% if STRICT_MAPPNIG %}
            {% for key in COLUMNS_METADATA.keys %}
              unless %found{key.id}
                raise ::Jennifer::BaseException.new("Column #{{{@type}}}##{{{key.id.stringify}}} hasn't been found in the result set.")
              end
            {% end %}
          {% end %}
          {% if COLUMNS_METADATA.size > 1 %}
            {
            {% for key, value in COLUMNS_METADATA %}
              begin
                %var{key.id}.as({{value[:parsed_type].id}})
              rescue e : Exception
                raise ::Jennifer::DataTypeCasting.new({{key.id.stringify}}, {{@type}}, e) if ::Jennifer::DataTypeCasting.match?(e)
                raise e
              end,
            {% end %}
            }
          {% else %}
            {% key = COLUMNS_METADATA.keys[0] %}
            begin
              %var{key}.as({{COLUMNS_METADATA[key][:parsed_type].id}})
            rescue e : Exception
              raise ::Jennifer::DataTypeCasting.new({{key.id.stringify}}, {{@type}}, e) if ::Jennifer::DataTypeCasting.match?(e)
              raise e
            end
          {% end %}
        end

        # Extracts attributes from gien hash to the tuple. If hash has no some field - will not raise any error.
        def _extract_attributes(values : Hash(String, ::Jennifer::DBAny))
          {% for key in COLUMNS_METADATA.keys %}
            %var{key.id} = nil
            %found{key.id} = true
          {% end %}

          {% for key, value in COLUMNS_METADATA %}
            {% _key = value[:column_name] ? value[:column_name] : key.id.stringify %}
            if !values[{{_key}}]?.nil?
              %var{key.id} = values[{{_key}}]
            else
              %found{key.id} = false
            end
          {% end %}

          {% for key, value in COLUMNS_METADATA %}
            begin
              {% if value[:null] %}
                {% if value[:default] != nil %}
                  %casted_var{key.id} = %found{key.id} ? Jennifer::Model::Mapping.__bool_convert(%var{key.id}, {{value["parsed_type"].id}}) : {{value["default"].id}}
                {% else %}
                  %casted_var{key.id} = %var{key.id}.as({{value[:parsed_type].id}})
                {% end %}
              {% elsif value["default"] != nil %}
                %casted_var{key.id} = %var{key.id}.is_a?(Nil) ? {{value[:default]}} : Jennifer::Model::Mapping.__bool_convert(%var{key.id}, {{value["parsed_type"].id}})
              {% else %}
                %casted_var{key.id} = Jennifer::Model::Mapping.__bool_convert(%var{key.id}, {{value["parsed_type"].id}})
              {% end %}
            rescue e : Exception
              raise ::Jennifer::DataTypeCasting.new({{key.id.stringify}}, {{@type}}, e) if ::Jennifer::DataTypeCasting.match?(e)
              raise e
            end
          {% end %}

          {% if COLUMNS_METADATA.size > 1 %}
            {
            {% for key, value in COLUMNS_METADATA %}
              %casted_var{key.id},
            {% end %}
            }
          {% else %}
            {% key = COLUMNS_METADATA.keys[0] %}
            %casted_var{key}
          {% end %}
        end

        # Reloads all fields from db
        def reload
          this = self
          self.class.all.where { this.class.primary == this.primary }.each_result_set do |rs|
            {{COLUMNS_METADATA.keys.map { |f| "@#{f.id}" }.join(", ").id}} = _extract_attributes(rs)
          end
          self
        end

        # Returns hash with all attributes and symbol keys
        def to_h
          {
            {% for key in COLUMNS_METADATA.keys %}
              :{{key.id}} => @{{key.id}},
            {% end %}
          }
        end

        # Returns hash with all attributes and string keys
        def to_str_h
          {
            {% for key in COLUMNS_METADATA.keys %}
              {{key.stringify}} => @{{key.id}},
            {% end %}
          }
        end

        # Returns field by given name. If object has no such field - will raise `BaseException`.
        # To avoid raising exception set `raise_exception` to `false`.
        def attribute(name : String | Symbol, raise_exception = true)
          case name.to_s
          {% for key, value in COLUMNS_METADATA.keys %}
          when {{key.stringify}}
            @{{key.id}}
          {% end %}
          else
            raise ::Jennifer::BaseException.new("Unknown model attribute - #{name}") if raise_exception
          end
        end

        # NOTE: This is deprecated method - it will be removed in 0.5.0. Use #to_h instead
        def attributes_hash
          hash = to_h
          {% for key, value in COLUMNS_METADATA %}
            {% if value[:primary] %}
              hash.delete({{key}}) unless hash.has_key?({{key}})
            {% end %}
          {% end %}
          hash
        end
      end

      macro included
        macro inherited
          FIELDS = {} of String => Hash(String, String)

          macro finished
            __field_declaration
            __instance_methods
          end
        end
      end

      macro mapping(properties, strict = true)
        STRICT_MAPPNIG = {{strict}}

        @@strict_mapping : Bool?

        def self.strict_mapping?
          @@strict_mapping ||= ::Jennifer::Adapter.adapter.table_column_count(table_name) == field_count
        end

        # Returns field count
        def self.field_count
          {{properties.size}}
        end

        # Returns array of field names
        def self.field_names
          COLUMNS_METADATA.keys.to_a.map(&.to_s)
        end

        {% primary = nil %}

        # generates hash with options
        {% for key, opt in properties %}
          {% _key = key.id.stringify %}
          {% unless opt.is_a?(HashLiteral) || opt.is_a?(NamedTupleLiteral) %}
            {% FIELDS[_key] = {"type" => opt.stringify} %}
            {% properties[key] = {type: opt} %}
          {% else %}
            {% FIELDS[_key] = {} of String => String %}
            {% for attr, value in opt %}
              {% FIELDS[_key][attr.id.stringify] = value.stringify %}
            {% end %}
          {% end %}

          {% stringified_type = properties[key][:stringified_type] = properties[key][:type].stringify %}
          {% if stringified_type == Jennifer::Macros::PRIMARY_32 || stringified_type == Jennifer::Macros::PRIMARY_64 %}
            {%
              properties[key][:primary] = true
              FIELDS[_key]["primary"] = "true"
            %}
          {% end %}
          {% if properties[key][:primary] %}
            {% primary = key %}
          {% end %}
          {% if stringified_type =~ Jennifer::Macros::NILLABLE_REGEXP %}
            {%
              properties[key][:null] = true
              FIELDS[_key]["parsed_type"] = properties[key][:parsed_type] = stringified_type
            %}
          {% else %}
            {%
              properties[key][:parsed_type] = properties[key][:null] || properties[key][:primary] ? stringified_type + "?" : stringified_type
              FIELDS[_key]["parsed_type"] = properties[key][:parsed_type]
            %}
          {% end %}
        {% end %}

        # TODO: find way to allow view definition without any primary field
        {% if primary == nil %}
          {% raise "Model #{@type} has no defined primary field. For now model without primary field is not allowed" %}
        {% end %}

        COLUMNS_METADATA = {{properties}}

        # Returns named tuple of column metadata
        def self.columns_tuple
          COLUMNS_METADATA
        end
      end

      macro mapping(**properties)
        mapping({{properties}})
      end
    end
  end
end
