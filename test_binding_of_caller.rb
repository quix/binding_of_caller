require_relative 'binding_of_caller'
require 'test/unit'

class BindingOfCallerTest < Test::Unit::TestCase
  module Result
    class << self
      def value
        Thread.current[:test_binding_of_caller] ||= Hash.new
      end

      def assign(var)
        Binding.of_caller do |binding|
          value[var] = eval(var.to_s, binding)
        end
      end
    end
  end

  class << self
    def noop(*args)
    end
  end
  def noop(*args)
  end

  def end_body
    x = 33
    Result.assign(:x)
  end

  def test_end_body
    Result.value[:x] = nil
    end_body
    assert_equal 33, Result.value[:x]
  end

  def mid_body
    x = 44
    Result.assign(:x)
    noop
  end

  def test_mid_body
    Result.value[:x] = nil
    mid_body
    assert_equal 44, Result.value[:x]
  end

  def mid_body_2
    x = 55
    Result.assign(:x)
    1.times do
      noop
    end
  end

  def test_mid_body_2
    Result.value[:x] = nil
    mid_body_2
    assert_equal 55, Result.value[:x]
  end

  def test_threads
    threads = (1..200).map {
      Thread.new {
        test_mid_body
      }
    }
    threads.each { |t| t.join }
  end

  def test_lambda_end_body
    error = assert_raises(ScriptError) {
      lambda {
        x = 77
        Result.assign(:x)
      }.call
    }
    assert_match(/Binding\.of_caller/, error.message)
  end

  def test_lambda_mid_body
    lambda {
      x = 88
      Result.assign(:x)
      noop
    }.call
    assert_equal 88, Result.value[:x]
  end

  def test_block_mid_body
    1.times do
      x = 99
      Result.assign(:x)
      nil
    end
    assert_equal 99, Result.value[:x]
  end

  def test_block_end_body
    error = assert_raises(ScriptError) {
      1.times do
        x = 77
        Result.assign(:x)
      end
    }
    assert_match(/Binding\.of_caller/, error.message)
  end

  class A
    y = 99
    Result.assign(:y)
  end

  def test_class_end_body
    assert_equal 99, Result.value[:y]
  end

  class B
    z = 11
    Result.assign(:z)
    1.times { }
  end

  def test_class_mid_body
    assert_equal 11, Result.value[:z]
  end

  def trailing_error
    Binding.of_caller do |binding|
    end
    noop
  end

  def test_trailing_error
    error = assert_raises(ScriptError) {
      trailing_error
    }
    assert_match(/Binding\.of_caller/, error.message)
  end

  def test_inside_method_call
    assert_raises ScriptError do
      x = 22
      noop(Result.assign(:x))
    end
  end
end
