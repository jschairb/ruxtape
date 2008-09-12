require File.dirname(__FILE__) + "/../lib/mosquito"

class TestHelpers < Camping::ModelTest
  # http://rubyforge.org/tracker/index.php?func=detail&aid=8921&group_id=351&atid=1416
  def test_supports_old_style_and_new_style_fixture_generation
    assert self.respond_to?(:create_fixtures), "Oldstyle method should work"
    assert self.class.respond_to?(:fixtures), "Newstyle method should work"
  end
  
  def test_stash_and_unstash
    someval = {:foo => "bar"}
    assert_nothing_raised do
      assert_equal someval, Mosquito::stash(someval)
    end
    
    retr = Mosquito.unstash
    assert_nil Mosquito.unstash, "There is nothing stashed now"
    assert_equal retr, someval, "The value should be retrieved"
  end
end