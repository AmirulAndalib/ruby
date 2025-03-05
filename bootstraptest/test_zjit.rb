# Tests of Ruby methods that ZJIT can currently compile.
# make btest BTESTS=bootstraptest/test_zjit.rb RUN_OPTS="--zjit"

assert_equal 'nil', %q{
  def test = nil
  test; test.inspect
}

assert_equal '1', %q{
  def test = 1
  test; test
}

assert_equal '3', %q{
  def test = 1 + 2
  test; test
}
