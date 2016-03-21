require "dry-validation"
require "dry/validation/schema/form"
require "reform/validation"

module Reform::Form::Dry
  module Validations

    def build_errors
      Reform::Contract::Errors.new(self)
    end

    module ClassMethods
      def validation_group_class
        Group
      end
    end

    def self.included(includer)
      includer.extend(ClassMethods)
    end

    class Group
      def initialize(options = {})
        base = options.fetch(:base, ValidatorSchema)
        dsl_opts = {
          schema_class: Class.new(base.is_a?(Dry::Validation::Schema) ? base.class : base),
          parent: options[:parent]
        }

        @dsl = Dry::Validation::Schema::Value.new(dsl_opts)
      end

      def instance_exec(options = {}, &block)
        dsl = @dsl
        dsl.instance_exec(&block)

        klass = dsl.schema_class
        klass.configure do |config|
          config.rules = config.rules + (options.fetch(:rules, []) + dsl.rules)
          config.checks = config.checks + dsl.checks
          config.path = dsl.path
        end

        @validator = klass.new
      end

      def call(fields, reform_errors, form)
        validator = @validator.with(form: form)

        # a result looks like: output={:confirm_password=>"9"} messages={:confirm_password=>["size cannot be less than 2"]}
        validator.call(fields).messages.each do |field, dry_error|
          dry_error.each do |attr_error|
            reform_errors.add(field, attr_error)
          end
        end
      end
    end

    class ValidatorSchema < Dry::Validation::Schema::Form
      def initialize(rules, options)
        @form = options[:form]
        super
      end

      def form
        @form
      end
    end
  end
end
