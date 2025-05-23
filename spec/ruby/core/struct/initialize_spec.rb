require_relative '../../spec_helper'
require_relative 'fixtures/classes'

describe "Struct#initialize" do

  it "is private" do
    StructClasses::Car.should have_private_instance_method(:initialize)
  end

  it 'allows valid Ruby method names for members' do
    valid_method_names = [
      :method1,
      :method_1,
      :method_1?,
      :method_1!,
      :a_method
    ]
    valid_method_names.each do |method_name|
      klass = Struct.new(method_name)
      instance = klass.new(:value)
      instance.send(method_name).should == :value
      writer_method = "#{method_name}=".to_sym
      result = instance.send(writer_method, :new_value)
      result.should == :new_value
      instance.send(method_name).should == :new_value
    end
  end

  it "does nothing when passed a set of fields equal to self" do
    car = same_car = StructClasses::Car.new("Honda", "Accord", "1998")
    car.instance_eval { initialize("Honda", "Accord", "1998") }
    car.should == same_car
  end

  it "explicitly sets instance variables to nil when args not provided to initialize" do
    car = StructClasses::Honda.new
    car.make.should == nil # still nil despite override in Honda#initialize b/c of super order
  end

  it "can be overridden" do
    StructClasses::SubclassX.new(:y).new.key.should == :value
  end

  it "can be initialized with keyword arguments" do
    positional_args = StructClasses::Ruby.new("3.2", "OS")
    keyword_args = StructClasses::Ruby.new(version: "3.2", platform: "OS")

    positional_args.version.should == keyword_args.version
    positional_args.platform.should == keyword_args.platform
  end
end
