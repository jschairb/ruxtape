require File.dirname(__FILE__) + "/../lib/mosquito"

class TestMockUpload < Test::Unit::TestCase
  include Mosquito
  
  def setup
    @mock_jpeg = MockUpload.new("stuff.JPG")
    @mock_png = MockUpload.new("stuff.png")
    @mock_gif = MockUpload.new("stuff.gif")
    @mock_pdf = MockUpload.new("doc.pdf")
  end
  
  def test_generation
    [@mock_jpeg, @mock_png, @mock_gif].each do | obj |
      assert_kind_of StringIO, obj
      assert obj.respond_to?(:content_type)
      assert obj.respond_to?(:local_path)
      assert obj.respond_to?(:original_filename)
      assert File.exist?(obj.local_path)
    end
  end
  
  def test_extensions_extracted_properly
    assert_equal 'jpg', @mock_jpeg.extension
    assert_equal 'png', @mock_png.extension
    assert_equal 'gif', @mock_gif.extension
    assert_equal 'pdf', @mock_pdf.extension
  end
  
  def test_content_types_detected_properly
    assert_equal 'image/jpeg', @mock_jpeg.content_type
    assert_equal 'image/png', @mock_png.content_type
    assert_equal 'image/gif', @mock_gif.content_type
    assert_equal 'application/pdf', @mock_pdf.content_type
  end
  
  def test_inspekt
    desc = @mock_png.inspect
    assert desc.include?("@content_type='image/png'")
  end
  
  def test_original_filenames_overridden_properly
    assert_equal "stuff.JPG", @mock_jpeg.original_filename
    assert_equal "stuff.png", @mock_png.original_filename
    assert_equal "stuff.gif", @mock_gif.original_filename
    assert_equal "doc.pdf", @mock_pdf.original_filename
  end
  
  def test_proper_garbage_put_into_files
    garbage_bins = [@mock_jpeg, @mock_png, @mock_gif].map{|u| u.read }
    garbage_bins.map do | chunk |
      assert_equal 122, chunk.size, "Should be this amount of random data"
    end
  end
end