require_relative '../../spec_helper'
require_relative 'fixtures/singleton_method'

describe "BasicObject#singleton_method_added" do
  before :each do
    ScratchPad.clear
  end

  it "is a private method" do
    BasicObject.should have_private_instance_method(:singleton_method_added)
  end

  it "is called when a singleton method is defined on an object" do
    obj = BasicObject.new

    def obj.singleton_method_added(name)
      ScratchPad.record [:singleton_method_added, name]
    end

    def obj.new_singleton_method
    end

    ScratchPad.recorded.should == [:singleton_method_added, :new_singleton_method]
  end

  it "is not called for instance methods" do
    ScratchPad.record []

    Module.new do
      def self.singleton_method_added(name)
        ScratchPad << name
      end

      def new_instance_method
      end
    end

    ScratchPad.recorded.should_not include(:new_instance_method)
  end

  it "is called when a singleton method is defined on a module" do
    class BasicObjectSpecs::SingletonMethod
      def self.new_method_on_self
      end
    end
    ScratchPad.recorded.should == [:singleton_method_added, :new_method_on_self]
  end

  it "is called when a method is defined in the singleton class" do
    class BasicObjectSpecs::SingletonMethod
      class << self
        def new_method_on_singleton
        end
      end
    end
    ScratchPad.recorded.should == [:singleton_method_added, :new_method_on_singleton]
  end

  it "is called when a method is defined with alias_method in the singleton class" do
    class BasicObjectSpecs::SingletonMethod
      class << self
        alias_method :new_method_on_singleton_with_alias_method, :singleton_method_to_alias
      end
    end
    ScratchPad.recorded.should == [:singleton_method_added, :new_method_on_singleton_with_alias_method]
  end

  it "is called when a method is defined with syntax alias in the singleton class" do
    class BasicObjectSpecs::SingletonMethod
      class << self
        alias new_method_on_singleton_with_syntax_alias singleton_method_to_alias
      end
    end
    ScratchPad.recorded.should == [:singleton_method_added, :new_method_on_singleton_with_syntax_alias]
  end

  it "is called when define_method is used in the singleton class" do
    class BasicObjectSpecs::SingletonMethod
      class << self
        define_method :new_method_with_define_method do
        end
      end
    end
    ScratchPad.recorded.should == [:singleton_method_added, :new_method_with_define_method]
  end

  describe "when singleton_method_added is undefined" do
    it "raises NoMethodError for a metaclass" do
      class BasicObjectSpecs::NoSingletonMethodAdded
        class << self
          undef_method :singleton_method_added
        end

        -> {
          def self.foo
          end
        }.should raise_error(NoMethodError, /undefined method [`']singleton_method_added' for/)
      end
    ensure
      BasicObjectSpecs.send(:remove_const, :NoSingletonMethodAdded)
    end

    it "raises NoMethodError for a singleton instance" do
      object = Object.new
      class << object
        undef_method :singleton_method_added

        -> {
          def foo
          end
        }.should raise_error(NoMethodError, /undefined method [`']singleton_method_added' for #<Object:/)

        -> {
          define_method(:bar) {}
        }.should raise_error(NoMethodError, /undefined method [`']singleton_method_added' for #<Object:/)
      end

      -> {
        object.define_singleton_method(:baz) {}
      }.should raise_error(NoMethodError, /undefined method [`']singleton_method_added' for #<Object:/)
    end

    it "calls #method_missing" do
      ScratchPad.record []
      object = Object.new
      class << object
        def method_missing(*args)
          ScratchPad << args
        end

        undef_method :singleton_method_added

        def foo
        end

        define_method(:bar) {}
      end
      object.define_singleton_method(:baz) {}

      ScratchPad.recorded.should == [
        [:singleton_method_added, :foo],
        [:singleton_method_added, :bar],
        [:singleton_method_added, :baz],
      ]
    end
  end
end
