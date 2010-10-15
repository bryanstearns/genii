require File.dirname(__FILE__) + '/helper'

class DummyFeature < Feature
  attr_accessor :name, :option_1, :option_2
  def initialize(options={})
    super(options)
    self.option_2 = "foo"
  end
end

class SimpleParentFeature < Feature
  attr_accessor :child_option
  def create_dependencies
    depends_on :dummy_feature => {
                 :option_1 => child_option
               }
  end
end

class SimpleDummyMachine < Machine
  def create_dependencies
    depends_on :simple_parent_feature => {
                 :child_option => configuration[:child_option]
               }
  end
end

class ComplexParentFeature < Feature
  def initialize(options={})
    super(options)
    depends_on :dummy_feature => {
                 :option_1 => false
               }
    depends_on :dummy_feature => {
                 :option_1 => true
               }
  end
end

class ComplexDummyMachine < Machine
  def create_dependencies
    depends_on :complex_parent_feature
  end
end

class TestFeature < Test::Unit::TestCase
  context "When building a feature" do
    should "assign options" do
      @dummy = DummyFeature.new(:name => "Edgar Bergen")
      assert_equal "Edgar Bergen", @dummy.name
      assert @dummy.option_1.nil?
      assert_equal "foo", @dummy.option_2
    end
  end

  context "With a simple hierarchy, the machine" do
    setup do
      @machine = SimpleDummyMachine.new("hostname", :child_option => true)
      Machine.stubs(:current).returns(@machine)
      @machine.create_dependencies
    end

    should "find a feature by class and options" do
      assert_instance_of DummyFeature,
                         @machine.find_feature(:dummy_feature,
                                               :option_1 => true)
    end

    should "find a child feature by class and options" do
      assert_equal [SimpleParentFeature], @machine.dependencies.map(&:class)
      assert_instance_of DummyFeature,
                         @machine.find_feature(:dummy_feature,
                                               :option_1 => true)
    end
  end

  context "With a hierarchy with two features of the same class" do
    setup do
      @machine = ComplexDummyMachine.new("hostname", {})
      Machine.stubs(:current).returns(@machine)
      @machine.create_dependencies
    end

    context "the parent" do
      should "find the child features by class and options" do
        assert_equal [ComplexParentFeature], @machine.dependencies.map(&:class)
        assert @machine.find_feature(:dummy_feature).nil?
        true_child = @machine.find_feature(:dummy_feature, :option_1 => true)
        false_child = @machine.find_feature(:dummy_feature, :option_1 => false)
        assert true_child != false_child
        assert true_child.option_1
        assert !false_child.option_1
      end
    end

    context "the machine" do
      should "find a feature by class and options" do
        assert @machine.find_feature(:dummy_feature,
                                     :option_1 => true).option_1
        assert !@machine.find_feature(:dummy_feature,
                                     :option_1 => false).option_1
        assert @machine.find_feature(:dummy_feature).nil?
      end

      should "find a feature by class only" do
        assert @machine.find_feature(:dummy_feature, :anything).is_a? DummyFeature
      end
    end
  end
end
