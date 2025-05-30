# frozen_string_literal: false
require 'test/unit'
require 'objspace'

class TestRubyOptimization < Test::Unit::TestCase
  def assert_redefine_method(klass, method, code, msg = nil)
    assert_separately([], "#{<<-"begin;"}\n#{<<~"end;"}")
    begin;
      class #{klass}
        undef #{method}
        def #{method}(*args)
          args[0]
        end
      end
      #{code}
    end;
  end

  def assert_performance_warning(klass, method)
    assert_in_out_err([], "#{<<-"begin;"}\n#{<<~"end;"}", [], ["-:4: warning: Redefining '#{klass}##{method}' disables interpreter and JIT optimizations"])
    begin;
      Warning[:performance] = true
      class #{klass}
        undef #{method}
        def #{method}
        end
      end
    end;
  end

  def disasm(name)
    RubyVM::InstructionSequence.of(method(name)).disasm
  end

  def test_fixnum_plus
    assert_equal 21, 10 + 11
    assert_redefine_method('Integer', '+', 'assert_equal 11, 10 + 11')
    assert_performance_warning('Integer', '+')
  end

  def test_fixnum_minus
    assert_equal 5, 8 - 3
    assert_redefine_method('Integer', '-', 'assert_equal 3, 8 - 3')
    assert_performance_warning('Integer', '-')
  end

  def test_fixnum_mul
    assert_equal 15, 3 * 5
    assert_redefine_method('Integer', '*', 'assert_equal 5, 3 * 5')
    assert_performance_warning('Integer', '*')
  end

  def test_fixnum_div
    assert_equal 3, 15 / 5
    assert_redefine_method('Integer', '/', 'assert_equal 5, 15 / 5')
    assert_performance_warning('Integer', '/')
  end

  def test_fixnum_mod
    assert_equal 1, 8 % 7
    assert_redefine_method('Integer', '%', 'assert_equal 7, 8 % 7')
    assert_performance_warning('Integer', '%')
  end

  def test_fixnum_lt
    assert_equal true, 1 < 2
    assert_redefine_method('Integer', '<', 'assert_equal 2, 1 < 2')
    assert_performance_warning('Integer', '<')
  end

  def test_fixnum_le
    assert_equal true, 1 <= 2
    assert_redefine_method('Integer', '<=', 'assert_equal 2, 1 <= 2')
    assert_performance_warning('Integer', '<=')
  end

  def test_fixnum_gt
    assert_equal false, 1 > 2
    assert_redefine_method('Integer', '>', 'assert_equal 2, 1 > 2')
    assert_performance_warning('Integer', '>')
  end

  def test_fixnum_ge
    assert_equal false, 1 >= 2
    assert_redefine_method('Integer', '>=', 'assert_equal 2, 1 >= 2')
    assert_performance_warning('Integer', '>=')
  end

  def test_float_plus
    assert_equal 4.0, 2.0 + 2.0
    assert_redefine_method('Float', '+', 'assert_equal 2.0, 2.0 + 2.0')
    assert_performance_warning('Float', '+')
  end

  def test_float_minus
    assert_equal 4.0, 2.0 + 2.0
    assert_redefine_method('Float', '-', 'assert_equal 2.0, 4.0 - 2.0')
    assert_performance_warning('Float', '-')
  end

  def test_float_mul
    assert_equal 29.25, 4.5 * 6.5
    assert_redefine_method('Float', '*', 'assert_equal 6.5, 4.5 * 6.5')
    assert_performance_warning('Float', '*')
  end

  def test_float_div
    assert_in_delta 0.63063063063063063, 4.2 / 6.66
    assert_redefine_method('Float', '/', 'assert_equal 6.66, 4.2 / 6.66', "[Bug #9238]")
    assert_performance_warning('Float', '/')
  end

  def test_float_lt
    assert_equal true, 1.1 < 2.2
    assert_redefine_method('Float', '<', 'assert_equal 2.2, 1.1 < 2.2')
    assert_performance_warning('Float', '<')
  end

  def test_float_le
    assert_equal true, 1.1 <= 2.2
    assert_redefine_method('Float', '<=', 'assert_equal 2.2, 1.1 <= 2.2')
    assert_performance_warning('Float', '<=')
  end

  def test_float_gt
    assert_equal false, 1.1 > 2.2
    assert_redefine_method('Float', '>', 'assert_equal 2.2, 1.1 > 2.2')
    assert_performance_warning('Float', '>')
  end

  def test_float_ge
    assert_equal false, 1.1 >= 2.2
    assert_redefine_method('Float', '>=', 'assert_equal 2.2, 1.1 >= 2.2')
    assert_performance_warning('Float', '>=')
  end

  def test_string_length
    assert_equal 6, "string".length
    assert_redefine_method('String', 'length', 'assert_nil "string".length')
    assert_performance_warning('String', 'length')
  end

  def test_string_size
    assert_equal 6, "string".size
    assert_redefine_method('String', 'size', 'assert_nil "string".size')
    assert_performance_warning('String', 'size')
  end

  def test_string_empty?
    assert_equal true, "".empty?
    assert_equal false, "string".empty?
    assert_redefine_method('String', 'empty?', 'assert_nil "string".empty?')
    assert_performance_warning('String', 'empty?')
  end

  def test_string_plus
    assert_equal "", "" + ""
    assert_equal "x", "x" + ""
    assert_equal "x", "" + "x"
    assert_equal "ab", "a" + "b"
    assert_redefine_method('String', '+', 'assert_equal "b", "a" + "b"')
    assert_performance_warning('String', '+')
  end

  def test_string_succ
    assert_equal 'b', 'a'.succ
    assert_equal 'B', 'A'.succ
    assert_performance_warning('String', 'succ')
  end

  def test_string_format
    assert_equal '2', '%d' % 2
    assert_redefine_method('String', '%', 'assert_equal 2, "%d" % 2')
    assert_performance_warning('String', '%')
  end

  def test_string_freeze
    assert_equal "foo", "foo".freeze
    assert_equal "foo".freeze.object_id, "foo".freeze.object_id
    assert_redefine_method('String', 'freeze', 'assert_nil "foo".freeze')
    assert_performance_warning('String', 'freeze')
  end

  def test_string_uminus
    assert_same "foo".freeze, -"foo"
    assert_redefine_method('String', '-@', 'assert_nil(-"foo")')
    assert_performance_warning('String', '-@')
  end

  def test_array_min
    assert_equal 1, [1, 2, 4].min
    assert_redefine_method('Array', 'min', 'assert_nil([1, 2, 4].min)')
    assert_redefine_method('Array', 'min', 'assert_nil([1 + 0, 2, 4].min)')
    assert_performance_warning('Array', 'min')
  end

  def test_array_max
    assert_equal 4, [1, 2, 4].max
    assert_redefine_method('Array', 'max', 'assert_nil([1, 2, 4].max)')
    assert_redefine_method('Array', 'max', 'assert_nil([1 + 0, 2, 4].max)')
    assert_performance_warning('Array', 'max')
  end

  def test_array_hash
    assert_performance_warning('Array', 'hash')
  end

  def test_trace_optimized_methods
    bug14870 = "[ruby-core:87638]"
    expected = [:-@, :max, :min, :+, :-, :*, :/, :%, :==, :<, :<=, :>, :>=, :<<,
                :&, :|, :[], :[]=, :length, :empty?, :nil?, :succ, :!, :=~]
    [:c_call, :c_return].each do |type|
      methods = []
      tp = TracePoint.new(type) { |tp| methods << tp.method_id }
      tp.enable do
        x = "a"; x = -x
        [1].max
        [1].min
        x = 42 + 2
        x = 42 - 2
        x = 42 * 2
        x = 42 / 2
        x = 42 % 2
        y = x == 42
        y = x < 42
        y = x <= 42
        y = x > 42
        y = x >= 42
        x = x << 1
        x = x & 1
        x = x | 1
        x = []; x[1]
        x[1] = 2
        x.length
        x.empty?
        x.nil?
        x = 1; x.succ
        !x
        x = 'a'; x =~ /a/
        x = y
      end
      assert_equal(expected, methods, bug14870)
    end

    methods = []
    tp = TracePoint.new(:c_call, :c_return) { |tp| methods << tp.method_id }
    tp.enable do
      x = 1
      x != 42
    end
    assert_equal([:!=, :==, :==, :!=], methods, bug14870)
  end

  def test_string_freeze_saves_memory
    n = 16384
    data = '.'.freeze
    r, w = IO.pipe
    w.write data

    s = r.readpartial(n, '')
    assert_operator ObjectSpace.memsize_of(s), :>=, n,
      'IO buffer NOT resized prematurely because will likely be reused'

    s.freeze
    assert_equal ObjectSpace.memsize_of(data), ObjectSpace.memsize_of(s),
      'buffer resized on freeze since it cannot be written to again'
  ensure
    r.close if r
    w.close if w
  end

  def test_string_eq_neq
    %w(== !=).each do |m|
      assert_redefine_method('String', m, <<-end)
        assert_equal :b, ("a" #{m} "b").to_sym
        b = 'b'
        assert_equal :b, ("a" #{m} b).to_sym
        assert_equal :b, (b #{m} "b").to_sym
      end
    end

    assert_performance_warning('String', '==')
  end

  def test_string_ltlt
    assert_equal "", "" << ""
    assert_equal "x", "x" << ""
    assert_equal "x", "" << "x"
    assert_equal "ab", "a" << "b"
    assert_redefine_method('String', '<<', 'assert_equal "b", "a" << "b"')
    assert_performance_warning('String', '<<')
  end

  def test_fixnum_and
    assert_equal 1, 1&3
    assert_redefine_method('Integer', '&', 'assert_equal 3, 1&3')
    assert_performance_warning('Integer', '&')
  end

  def test_fixnum_or
    assert_equal 3, 1|3
    assert_redefine_method('Integer', '|', 'assert_equal 1, 3|1')
    assert_performance_warning('Integer', '|')
  end

  def test_array_plus
    assert_equal [1,2], [1]+[2]
    assert_redefine_method('Array', '+', 'assert_equal [2], [1]+[2]')
    assert_performance_warning('Array', '+')
  end

  def test_array_minus
    assert_equal [2], [1,2] - [1]
    assert_redefine_method('Array', '-', 'assert_equal [1], [1,2]-[1]')
    assert_performance_warning('Array', '-')
  end

  def test_array_length
    assert_equal 0, [].length
    assert_equal 3, [1,2,3].length
    assert_redefine_method('Array', 'length', 'assert_nil([].length); assert_nil([1,2,3].length)')
    assert_performance_warning('Array', 'length')
  end

  def test_array_empty?
    assert_equal true, [].empty?
    assert_equal false, [1,2,3].empty?
    assert_redefine_method('Array', 'empty?', 'assert_nil([].empty?); assert_nil([1,2,3].empty?)')
    assert_performance_warning('Array', 'empty?')
  end

  def test_hash_length
    assert_equal 0, {}.length
    assert_equal 1, {1=>1}.length
    assert_redefine_method('Hash', 'length', 'assert_nil({}.length); assert_nil({1=>1}.length)')
    assert_performance_warning('Hash', 'length')
  end

  def test_hash_empty?
    assert_equal true, {}.empty?
    assert_equal false, {1=>1}.empty?
    assert_redefine_method('Hash', 'empty?', 'assert_nil({}.empty?); assert_nil({1=>1}.empty?)')
    assert_performance_warning('Hash', 'empty?')
  end

  def test_hash_aref_with
    h = { "foo" => 1 }
    assert_equal 1, h["foo"]
    assert_redefine_method('Hash', '[]', "#{<<-"begin;"}\n#{<<~"end;"}")
    begin;
      h = { "foo" => 1 }
      assert_equal "foo", h["foo"]
    end;
    assert_performance_warning('Hash', '[]')
  end

  def test_hash_aset_with
    h = {}
    assert_equal 1, h["foo"] = 1
    assert_redefine_method('Hash', '[]=', "#{<<-"begin;"}\n#{<<~"end;"}")
    begin;
      h = {}
      assert_equal 1, h["foo"] = 1, "assignment always returns value set"
      assert_nil h["foo"]
    end;
    assert_performance_warning('Hash', '[]=')
  end

  class MyObj
    def ==(other)
      true
    end
  end

  def test_eq
    assert_equal true, nil == nil
    assert_equal true, 1 == 1
    assert_equal true, 'string' == 'string'
    assert_equal true, 1 == MyObj.new
    assert_equal false, nil == MyObj.new
    assert_equal true, MyObj.new == 1
    assert_equal true, MyObj.new == nil
  end

  def self.tailcall(klass, src, file = nil, path = nil, line = nil, tailcall: true)
    unless file
      loc, = caller_locations(1, 1)
      file = loc.path
      line ||= loc.lineno + 1
    end
    RubyVM::InstructionSequence.new("proc {|_|_.class_eval {#{src}}}",
                                    file, (path || file), line,
                                    tailcall_optimization: tailcall,
                                    trace_instruction: false)
      .eval[klass]
  end

  def tailcall(*args)
    self.class.tailcall(singleton_class, *args)
  end

  def test_tailcall
    bug4082 = '[ruby-core:33289]'

    tailcall("#{<<-"begin;"}\n#{<<~"end;"}")
    begin;
      def fact_helper(n, res)
        if n == 1
          res
        else
          fact_helper(n - 1, n * res)
        end
      end
      def fact(n)
        fact_helper(n, 1)
      end
    end;
    assert_equal(9131, fact(3000).to_s.size, message(bug4082) {disasm(:fact_helper)})
  end

  def test_tailcall_with_block
    bug6901 = '[ruby-dev:46065]'

    tailcall("#{<<-"begin;"}\n#{<<~"end;"}")
    begin;
      def identity(val)
        val
      end

      def delay
        -> {
          identity(yield)
        }
      end
    end;
    assert_equal(123, delay { 123 }.call, message(bug6901) {disasm(:delay)})
  end

  def just_yield
    yield
  end

  def test_tailcall_inhibited_by_block
    tailcall("#{<<-"begin;"}\n#{<<~"end;"}")
    begin;
      def yield_result
        just_yield {:ok}
      end
    end;
    assert_equal(:ok, yield_result, message {disasm(:yield_result)})
  end

  def do_raise
    raise "should be rescued"
  end

  def errinfo
    $!
  end

  def test_tailcall_inhibited_by_rescue
    bug12082 = '[ruby-core:73871] [Bug #12082]'

    EnvUtil.suppress_warning {tailcall("#{<<-"begin;"}\n#{<<~"end;"}")}
    begin;
      def to_be_rescued
        return do_raise
        1 + 2
      rescue
        errinfo
      end
    end;
    result = assert_nothing_raised(RuntimeError, message(bug12082) {disasm(:to_be_rescued)}) {
      to_be_rescued
    }
    assert_instance_of(RuntimeError, result, bug12082)
    assert_equal("should be rescued", result.message, bug12082)
  end

  def test_tailcall_symbol_block_arg
    bug12565 = '[ruby-core:46065]'
    tailcall("#{<<-"begin;"}\n#{<<~"end;"}")
    begin;
      def apply_one_and_two(&block)
        yield(1, 2)
      end

      def add_one_and_two
        apply_one_and_two(&:+)
      end
    end;
    assert_equal(3, add_one_and_two,
                 message(bug12565) {disasm(:add_one_and_two)})
  end

  def test_c_func_with_sp_offset_under_tailcall
    tailcall("#{<<-"begin;"}\n#{<<~"end;"}")
    begin;
      def calc_one_plus_two
        1 + 2.abs
      end

      def one_plus_two
        calc_one_plus_two
      end
    end;
    assert_equal(3, one_plus_two)
  end

  def test_tailcall_and_post_arg
    tailcall(<<~RUBY)
      def ret_const = :ok

      def post_arg(_a = 1, _b) = ret_const
    RUBY

    # YJIT probably uses a fallback on the call to post_arg
    assert_equal(:ok, post_arg(0))
  end

  def test_tailcall_interrupted_by_sigint
    bug12576 = 'ruby-core:76327'
    script = "#{<<-"begin;"}\n#{<<~'end;'}"
    begin;
      RubyVM::InstructionSequence.compile_option = {
        :tailcall_optimization => true,
        :trace_instruction => false
      }

      eval "#{<<~"begin;"}\n#{<<~'end;1'}"
      begin;
        def foo
          foo
        end
        puts("start")
        STDOUT.flush
        foo
      end;1
    end;
    status, _err = EnvUtil.invoke_ruby([], "", true, true, **{}) {
      |in_p, out_p, err_p, pid|
      in_p.write(script)
      in_p.close
      out_p.gets
      sig = :INT
      begin
        Process.kill(sig, pid)
        Timeout.timeout(1) do
          *, stat = Process.wait2(pid)
          [stat, err_p.read]
        end
      rescue Timeout::Error
        if sig == :INT
          sig = :KILL
          retry
        else
          raise
        end
      end
    }
    assert_not_equal("SEGV", Signal.signame(status.termsig || 0), bug12576)
  end unless /mswin|mingw/ =~ RUBY_PLATFORM

  def test_tailcall_condition_block
    bug = '[ruby-core:78015] [Bug #12905]'

    src = "#{<<-"begin;"}\n#{<<~"end;"}", __FILE__, nil, __LINE__+1
    begin;
      def run(current, final)
        if current < final
          run(current+1, final)
        else
          nil
        end
      end
    end;

    obj = Object.new
    self.class.tailcall(obj.singleton_class, *src, tailcall: false)
    e = assert_raise(SystemStackError) {
      obj.run(1, Float::INFINITY)
    }
    level = e.backtrace_locations.size
    obj = Object.new
    self.class.tailcall(obj.singleton_class, *src, tailcall: true)
    level *= 2
    mesg = message {"#{bug}: #{$!.backtrace_locations.size} / #{level} stack levels"}
    assert_nothing_raised(SystemStackError, mesg) {
      obj.run(1, level)
    }
  end

  def test_tailcall_not_to_grow_stack
    bug16161 = '[ruby-core:94881]'

    tailcall("#{<<-"begin;"}\n#{<<~"end;"}")
    begin;
      def foo(n)
        return :ok if n < 1
        foo(n - 1)
      end
    end;
    assert_nothing_raised(SystemStackError, bug16161) do
      assert_equal(:ok, foo(1_000_000), bug16161)
    end
  end

  class Bug10557
    def [](_)
      block_given?
    end

    def []=(_, _)
      block_given?
    end
  end

  def test_block_given_aset_aref
    bug10557 = '[ruby-core:66595]'
    assert_equal(true, Bug10557.new.[](nil){}, bug10557)
    assert_equal(true, Bug10557.new.[](0){}, bug10557)
    assert_equal(true, Bug10557.new.[](false){}, bug10557)
    assert_equal(true, Bug10557.new.[](''){}, bug10557)
    assert_equal(true, Bug10557.new.[]=(nil, 1){}, bug10557)
    assert_equal(true, Bug10557.new.[]=(0, 1){}, bug10557)
    assert_equal(true, Bug10557.new.[]=(false, 1){}, bug10557)
    assert_equal(true, Bug10557.new.[]=('', 1){}, bug10557)
  end

  def test_string_freeze_block
    assert_separately([], "#{<<-"begin;"}\n#{<<~"end;"}")
    begin;
      class String
        undef freeze
        def freeze(&)
          block_given?
        end
      end
      assert_equal(true, "block".freeze {})
      assert_equal(false, "block".freeze)
    end;
  end

  def test_opt_case_dispatch
    code = "#{<<-"begin;"}\n#{<<~"end;"}"
    begin;
      case foo
      when "foo" then :foo
      when true then true
      when false then false
      when :sym then :sym
      when 6 then :fix
      when nil then nil
      when 0.1 then :float
      when 0xffffffffffffffff then :big
      else
        :nomatch
      end
    end;
    check = {
      'foo' => :foo,
      true => true,
      false => false,
      :sym => :sym,
      6 => :fix,
      nil => nil,
      0.1 => :float,
      0xffffffffffffffff => :big,
    }
    iseq = RubyVM::InstructionSequence.compile(code)
    assert_match %r{\bopt_case_dispatch\b}, iseq.disasm
    check.each do |foo, expect|
      assert_equal expect, eval("foo = #{foo.inspect}\n#{code}")
    end
    assert_equal :nomatch, eval("foo = :blah\n#{code}")
    check.each do |foo, _|
      klass = foo.class.to_s
      assert_separately([], "#{<<~"begin;"}\n#{<<~"end;"}")
      begin;
        class #{klass}
          undef ===
          def ===(*args)
            false
          end
        end
        foo = #{foo.inspect}
        ret = #{code}
        assert_equal :nomatch, ret, foo.inspect
      end;
    end
  end

  def test_eqq
    [ nil, true, false, 0.1, :sym, 'str', 0xffffffffffffffff ].each do |v|
      k = v.class.to_s
      assert_redefine_method(k, '===', "assert_equal(#{v.inspect} === 0, 0)")
      assert_performance_warning(k, '===')
    end
  end

  def test_opt_case_dispatch_inf
    inf = 1.0/0.0
    result = case inf
             when 1 then 1
             when 0 then 0
             else
               inf.to_i rescue nil
             end
    assert_nil result, '[ruby-dev:49423] [Bug #11804]'
  end

  def test_nil_safe_conditional_assign
    bug11816 = '[ruby-core:74993] [Bug #11816]'
    assert_ruby_status([], 'nil&.foo &&= false', bug11816)
  end

  def test_peephole_string_literal_range
    code = "#{<<~"begin;"}\n#{<<~"end;"}"
    begin;
      case ver
      when "2.0.0".."2.3.2" then :foo
      when "1.8.0"..."1.8.8" then :bar
      end
    end;
    [ true, false ].each do |opt|
      iseq = RubyVM::InstructionSequence.compile(code,
                                                 frozen_string_literal: opt)
      insn = iseq.disasm
      assert_match %r{putobject\s+#{Regexp.quote('"1.8.0"..."1.8.8"')}}, insn
      assert_match %r{putobject\s+#{Regexp.quote('"2.0.0".."2.3.2"')}}, insn
      assert_no_match(/putstring/, insn)
      assert_no_match(/newrange/, insn)
    end
  end

  def test_peephole_dstr
    code = "#{<<~'begin;'}\n#{<<~'end;'}"
    begin;
      exp = -'a'
      z = 'a'
      [exp, -"#{z}"]
    end;
    [ false, true ].each do |fsl|
      iseq = RubyVM::InstructionSequence.compile(code,
                                                 frozen_string_literal: fsl)
      assert_same(*iseq.eval,
                  "[ruby-core:85542] [Bug #14475] fsl: #{fsl}")
    end
  end

  def test_peephole_array_freeze
    code = "#{<<~'begin;'}\n#{<<~'end;'}"
    begin;
      [1].freeze
    end;
    iseq = RubyVM::InstructionSequence.compile(code)
    insn = iseq.disasm
    assert_match(/opt_ary_freeze/, insn)
    assert_no_match(/duparray/, insn)
    assert_no_match(/send/, insn)
    assert_predicate([1].freeze, :frozen?)
    assert_in_out_err([], <<~RUBY, [":ok"])
      class Array
        prepend Module.new {
          def freeze
            :ok
          end
        }
      end
      p [1].freeze
    RUBY
  end

  def test_peephole_array_freeze_empty
    code = "#{<<~'begin;'}\n#{<<~'end;'}"
    begin;
      [].freeze
    end;
    iseq = RubyVM::InstructionSequence.compile(code)
    insn = iseq.disasm
    assert_match(/opt_ary_freeze/, insn)
    assert_no_match(/duparray/, insn)
    assert_no_match(/send/, insn)
    assert_predicate([].freeze, :frozen?)
    assert_in_out_err([], <<~RUBY, [":ok"])
      class Array
        prepend Module.new {
          def freeze
            :ok
          end
        }
      end
      p [].freeze
    RUBY
  end

  def test_peephole_hash_freeze
    code = "#{<<~'begin;'}\n#{<<~'end;'}"
    begin;
      {a:1}.freeze
    end;
    iseq = RubyVM::InstructionSequence.compile(code)
    insn = iseq.disasm
    assert_match(/opt_hash_freeze/, insn)
    assert_no_match(/duphash/, insn)
    assert_no_match(/send/, insn)
    assert_predicate([1].freeze, :frozen?)
    assert_in_out_err([], <<~RUBY, [":ok"])
      class Hash
        prepend Module.new {
          def freeze
            :ok
          end
        }
      end
      p({a:1}.freeze)
    RUBY
  end

  def test_peephole_hash_freeze_empty
    code = "#{<<~'begin;'}\n#{<<~'end;'}"
    begin;
      {}.freeze
    end;
    iseq = RubyVM::InstructionSequence.compile(code)
    insn = iseq.disasm
    assert_match(/opt_hash_freeze/, insn)
    assert_no_match(/duphash/, insn)
    assert_no_match(/send/, insn)
    assert_predicate([].freeze, :frozen?)
    assert_in_out_err([], <<~RUBY, [":ok"])
      class Hash
        prepend Module.new {
          def freeze
            :ok
          end
        }
      end
      p({}.freeze)
    RUBY
  end

  def test_branch_condition_backquote
    bug = '[ruby-core:80740] [Bug #13444] redefined backquote should be called'
    class << self
      def `(s)
        @q = s
        @r
      end
    end

    @q = nil
    @r = nil
    assert_equal("bar", ("bar" unless `foo`), bug)
    assert_equal("foo", @q, bug)

    @q = nil
    @r = true
    assert_equal("bar", ("bar" if `foo`), bug)
    assert_equal("foo", @q, bug)

    @q = nil
    @r = "z"
    assert_equal("bar", ("bar" if `foo#{@r}`))
    assert_equal("fooz", @q, bug)
  end

  def test_branch_condition_def
    bug = '[ruby-core:80740] [Bug #13444] method should be defined'
    c = Class.new do
      raise "bug" unless def t;:ok;end
    end
    assert_nothing_raised(NoMethodError, bug) do
      assert_equal(:ok, c.new.t)
    end
  end

  def test_branch_condition_defs
    bug = '[ruby-core:80740] [Bug #13444] singleton method should be defined'
    raise "bug" unless def self.t;:ok;end
    assert_nothing_raised(NameError, bug) do
      assert_equal(:ok, t)
    end
  end

  def test_retry_label_in_unreachable_chunk
    bug = '[ruby-core:81272] [Bug #13578]'
    assert_valid_syntax("#{<<-"begin;"}\n#{<<-"end;"}", bug)
    begin;
      def t; if false; case 42; when s {}; end; end; end
    end;
  end

  def bptest_yield &b
    yield
  end

  def bptest_yield_pass &b
    bptest_yield(&b)
  end

  def bptest_bp_value &b
    b
  end

  def bptest_bp_pass_bp_value &b
    bptest_bp_value(&b)
  end

  def bptest_binding &b
    binding
  end

  def bptest_set &b
    b = Proc.new{2}
  end

  def test_block_parameter
    assert_equal(1, bptest_yield{1})
    assert_equal(1, bptest_yield_pass{1})
    assert_equal(1, send(:bptest_yield){1})

    assert_equal(Proc, bptest_bp_value{}.class)
    assert_equal nil, bptest_bp_value
    assert_equal(Proc, bptest_bp_pass_bp_value{}.class)
    assert_equal nil, bptest_bp_pass_bp_value

    assert_equal Proc, bptest_binding{}.local_variable_get(:b).class

    assert_equal 2, bptest_set{1}.call
  end

  def test_block_parameter_should_not_create_objects
    assert_separately [], <<-END
      def foo &b
      end
      h1 = {}; h2 = {}
      ObjectSpace.count_objects(h1) # rehearsal
      GC.start; GC.disable          # to disable GC while foo{}
      ObjectSpace.count_objects(h1)
      foo{}
      ObjectSpace.count_objects(h2)

      assert_equal 0, h2[:T_DATA] - h1[:T_DATA] # Proc is T_DATA
    END
  end

  def test_peephole_optimization_without_trace
    assert_separately [], <<-END
      RubyVM::InstructionSequence.compile_option = {trace_instruction: false}
      eval "def foo; 1.times{|(a), &b| nil && a}; end"
    END
  end

  def test_clear_unreachable_keyword_args
    assert_separately [], <<-END, timeout: 60
      script =  <<-EOS
        if true
        else
          foo(k1:1)
        end
      EOS
      GC.stress = true
      30.times{
        RubyVM::InstructionSequence.compile(script)
      }
    END
  end

  def test_callinfo_unreachable_path
    assert_separately([], "#{<<~"begin;"}\n#{<<~'end;'}")
    begin;
      iseq = RubyVM::InstructionSequence.compile("if false; foo(bar: :baz); else :ok end")
      bin = iseq.to_binary
      iseq = RubyVM::InstructionSequence.load_from_binary(bin)
      assert_instance_of(RubyVM::InstructionSequence, iseq)
      assert_equal(:ok, iseq.eval)
    end;
  end

  def test_side_effect_in_popped_splat
    bug = '[ruby-core:84340] [Bug #14201]'
    eval("{**(bug = nil; {})};42")
    assert_nil(bug)

    bug = '[ruby-core:85486] [Bug #14459]'
    h = {}
    assert_equal(bug, eval('{ok: 42, **h}; bug'))
    assert_equal(:ok, eval('{ok: bug = :ok, **h}; bug'))
    assert_empty(h)
  end

  def test_overwritten_blockparam
    obj = Object.new
    def obj.a(&block)
      block = 1
      return :ok if block
      :ng
    end
    assert_equal(:ok, obj.a())
  end

  def test_blockparam_in_rescue
    obj = Object.new
    def obj.foo(&b)
      raise
    rescue
      b.call
    end
    result = nil
    assert_equal(42, obj.foo {result = 42})
    assert_equal(42, result)
  end

  def test_unconditional_branch_to_leave_block
    assert_valid_syntax("#{<<~"begin;"}\n#{<<~'end;'}")
    begin;
      tap {true || tap {}}
    end;
  end

  def test_jump_elimination_with_optimized_out_block
    x = Object.new
    def x.bug(obj)
      if obj || obj
        obj = obj
      else
        raise "[ruby-core:87830] [Bug #14897]"
      end
      obj
    end
    assert_equal(:ok, x.bug(:ok))
  end

  def test_jump_elimination_with_optimized_out_block_2
    x = Object.new
    def x.bug
      a = "aaa"
      ok = :NG
      if a == "bbb" || a == "ccc" then
        a = a
      else
        ok = :ok
      end
      ok
    end
    assert_equal(:ok, x.bug)
  end

  def test_peephole_jump_after_newarray
    i = 0
    %w(1) || 2 while (i += 1) < 100
    assert_equal(100, i)
  end

  def test_optimized_empty_ensure
    assert_separately([], "#{<<~"begin;"}\n#{<<~'end;'}", timeout: 10)
    begin;
      assert_raise(RuntimeError) {
        begin raise ensure nil if nil end
      }
    end;
  end

  def test_optimized_rescue
    assert_in_out_err("", "#{<<~"begin;"}\n#{<<~'end;'}", [], /END \(RuntimeError\)/)
    begin;
      if false
        begin
          require "some_mad_stuff"
        rescue LoadError
          puts "no mad stuff loaded"
        end
      end

      raise  "END"
    end;
  end

  class Objtostring
  end

  def test_objtostring
    assert_raise(NoMethodError){"#{BasicObject.new}"}
    assert_redefine_method('Symbol', 'to_s', <<-'end')
      assert_match %r{\A#<Symbol:0x[0-9a-f]+>\z}, "#{:foo}"
    end
    assert_redefine_method('NilClass', 'to_s', <<-'end')
      assert_match %r{\A#<NilClass:0x[0-9a-f]+>\z}, "#{nil}"
    end
    assert_redefine_method('TrueClass', 'to_s', <<-'end')
      assert_match %r{\A#<TrueClass:0x[0-9a-f]+>\z}, "#{true}"
    end
    assert_redefine_method('FalseClass', 'to_s', <<-'end')
      assert_match %r{\A#<FalseClass:0x[0-9a-f]+>\z}, "#{false}"
    end
    assert_redefine_method('Integer', 'to_s', <<-'end')
      (-1..10).each { |i|
        assert_match %r{\A#<Integer:0x[0-9a-f]+>\z}, "#{i}"
      }
    end
    assert_equal "TestRubyOptimization::Objtostring", "#{Objtostring}"
    assert_match %r{\A#<Class:0x[0-9a-f]+>\z}, "#{Class.new}"
    assert_match %r{\A#<Module:0x[0-9a-f]+>\z}, "#{Module.new}"
    o = Object.new
    def o.to_s; 1; end
    assert_match %r{\A#<Object:0x[0-9a-f]+>\z}, "#{o}"
  end

  def test_opt_duparray_send_include_p
    [
      'x = :b; [:a, :b].include?(x)',
      '@c = :b; [:a, :b].include?(@c)',
      '@c = "b"; %i[a b].include?(@c.to_sym)',
      '[:a, :b].include?(self) == false',
    ].each do |code|
      iseq = RubyVM::InstructionSequence.compile(code)
      insn = iseq.disasm
      assert_match(/opt_duparray_send/, insn)
      assert_no_match(/\bduparray\b/, insn)
      assert_equal(true, eval(code))
    end

    x, y = :b, :c
    assert_equal(true,  [:a, :b].include?(x))
    assert_equal(false, [:a, :b].include?(y))

    assert_in_out_err([], <<~RUBY, ["1,2", "3,3", "1,2", "4,4"])
      class Array
        prepend(Module.new do
          def include?(i)
            puts self.join(",")
            # Modify self to prove that we are operating on a copy.
            map! { i }
            puts self.join(",")
          end
        end)
      end
      def x(i)
        [1, 2].include?(i)
      end
      x(3)
      x(4)
    RUBY

    # Ensure raises happen correctly.
    assert_in_out_err([], <<~RUBY, ["will raise", "int 1 not 3"])
      class Integer
        undef_method :==
        def == x
          raise "int \#{self} not \#{x}"
        end
      end
      x = 3
      puts "will raise"
      begin
        p [1, 2].include?(x)
      rescue
        puts $!
      end
    RUBY
  end

  def test_opt_newarray_send_include_p
    [
      'b = :b; [:a, b].include?(:b)',
      # Use Object.new to ensure that we get newarray rather than duparray.
      'value = 1; [Object.new, true, "true", 1].include?(value)',
      'value = 1; [Object.new, "1"].include?(value.to_s)',
      '[Object.new, "1"].include?(self) == false',
    ].each do |code|
      iseq = RubyVM::InstructionSequence.compile(code)
      insn = iseq.disasm
      assert_match(/opt_newarray_send/, insn)
      assert_no_match(/\bnewarray\b/, insn)
      assert_equal(true, eval(code))
    end

    x, y = :b, :c
    assert_equal(true,  [:a, x].include?(x))
    assert_equal(false, [:a, x].include?(y))

    assert_in_out_err([], <<~RUBY, ["1,3", "3,3", "1,4", "4,4"])
      class Array
        prepend(Module.new do
          def include?(i)
            puts self.join(",")
            # Modify self to prove that we are operating on a copy.
            map! { i }
            puts self.join(",")
          end
        end)
      end
      def x(i)
        [1, i].include?(i)
      end
      x(3)
      x(4)
    RUBY

    # Ensure raises happen correctly.
    assert_in_out_err([], <<~RUBY, ["will raise", "int 1 not 3"])
      class Integer
        undef_method :==
        def == x
          raise "int \#{self} not \#{x}"
        end
      end
      x = 3
      puts "will raise"
      begin
        p [1, x].include?(x)
      rescue
        puts $!
      end
    RUBY
  end

  def test_opt_new_with_safe_navigation
    payload = nil
    assert_nil payload&.new
  end

  def test_opt_new
    pos_initialize = "
      def initialize a, b
        @a = a
        @b = b
      end
    "
    kw_initialize = "
      def initialize a:, b:
        @a = a
        @b = b
      end
    "
    kw_hash_initialize = "
      def initialize a, **kw
        @a = a
        @b = kw[:b]
      end
    "
    pos_prelude = "class OptNewFoo; #{pos_initialize}; end;"
    kw_prelude = "class OptNewFoo; #{kw_initialize}; end;"
    kw_hash_prelude = "class OptNewFoo; #{kw_hash_initialize}; end;"
    [
      "#{pos_prelude} OptNewFoo.new 1, 2",
      "#{pos_prelude} a = 1; b = 2; OptNewFoo.new a, b",
      "#{pos_prelude} def optnew_foo(a, b) = OptNewFoo.new(a, b); optnew_foo 1, 2",
      "#{pos_prelude} def optnew_foo(*a) = OptNewFoo.new(*a); optnew_foo 1, 2",
      "#{pos_prelude} def optnew_foo(...) = OptNewFoo.new(...); optnew_foo 1, 2",
      "#{kw_prelude} def optnew_foo(**a) = OptNewFoo.new(**a); optnew_foo a: 1, b: 2",
      "#{kw_hash_prelude} def optnew_foo(*a, **b) = OptNewFoo.new(*a, **b); optnew_foo 1, b: 2",
    ].each do |code|
      iseq = RubyVM::InstructionSequence.compile(code)
      insn = iseq.disasm
      assert_match(/opt_new/, insn)
      assert_match(/OptNewFoo:.+@a=1, @b=2/, iseq.eval.inspect)
    end
    [
      'def optnew_foo(&) = OptNewFoo.new(&)',
      'def optnew_foo(a, ...) = OptNewFoo.new(a, ...)',
    ].each do |code|
      iseq = RubyVM::InstructionSequence.compile(code)
      insn = iseq.disasm
      assert_no_match(/opt_new/, insn)
    end
  end
end
