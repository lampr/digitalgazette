require File.expand_path(File.dirname(__FILE__) + "/test_helper")

class UglifyHtmlTest < Test::Unit::TestCase
  def assert_renders_uglify(uglify, html, options ={})
    assert_equal uglify, UglifyHtml.new(html, options).make_ugly
  end

  context "add an <br/> at the end of the document if it ends with a table" do
    test "document ending with a table" do
      html = "<h1>header</h1><table><tr><td>col</td></tr></table>"
      uglify = "<h1>header</h1><table><tr><td>col</td></tr></table><br/>"
      assert_renders_uglify uglify, html
    end

    test "document not ending with a table" do
      html = "<h1>header</h1><table><tr><td>col</td></tr></table><p>some</p>"
      uglify = "<h1>header</h1><table><tr><td>col</td></tr></table><p>some</p>"
      assert_renders_uglify uglify, html
    end
  end

  context "allow change only tag names for certain elements" do
    test "convert <ins> to <u> and not convert <u> to <span> later" do
      html = "<p>some text <ins>underlined</ins></p>"
      uglify = "<p>some text <u>underlined</u></p>"
      assert_renders_uglify uglify, html, {:rename_tag => {"ins" => "u"}} 
    end
  end
    
  context "let pass through certain elements" do
    test "pass strong tags, pass em tags" do
      html = "<p>some <strong>bold</strong> text inside a paragraph</p>"
      uglify = "<p>some <strong>bold</strong> text inside a paragraph</p>"
      assert_renders_uglify uglify, html, {:pass_through => ['strong']} 
      html = "<p>some <em>bold</em> text inside a paragraph</p>"
      uglify = "<p>some <em>bold</em> text inside a paragraph</p>"
      assert_renders_uglify uglify, html, {:pass_through => ['em']} 
    end
  end

  context "convert common tags" do
    test "it should convert a simple <strong> tag" do
      html = "<p>some <strong>bold</strong> text inside a paragraph</p>"
      uglify = "<p>some <span style=\"font-weight:bold\">bold</span> text inside a paragraph</p>"
      assert_renders_uglify uglify, html 
    end

    test "it should convert a <strong> nested on a <em>" do
      html = "<p>some <em><strong>em bold</strong></em> text inside a paragraph</p>"
      uglify = "<p>some <span style=\"font-style:italic;font-weight:bold\">em bold</span> text inside a paragraph</p>"
      assert_renders_uglify uglify, html 
    end
    
    test "it should convert a <ins> tag" do
      html = "<p>some <ins>underline</ins> text inside a paragraph</p>"
      uglify = "<p>some <span style=\"text-decoration:underline\">underline</span> text inside a paragraph</p>"
      assert_renders_uglify uglify, html 
    end
    
    test "it should convert a <del> tag" do
      html = "<p>some <del>deleted</del> text inside a paragraph</p>"
      uglify = "<p>some <span style=\"text-decoration:line-through\">deleted</span> text inside a paragraph</p>"
      assert_renders_uglify uglify, html 
    end
    
    test "it should convert a <strike> tag" do
      html = "<p>some <strike>striked</strike> text inside a paragraph</p>"
      uglify = "<p>some <span style=\"text-decoration:line-through\">striked</span> text inside a paragraph</p>"
      assert_renders_uglify uglify, html 
    end
  end

  context "convert lists" do
    test "it should convert a simple ul nested list" do
      html = "<ul><li>item 1</li><li>item 2<ul><li>nested 1 item 1</li></ul></li></ul>"
      uglify = "<ul><li>item 1</li><li>item 2</li><ul><li>nested 1 item 1</li></ul></ul>"
      assert_renders_uglify uglify, html 
    end
    
    test "it should convert a simple ol nested list" do
      html = "<ol><li>item 1</li><li>item 2<ol><li>nested 1 item 1</li></ol></li></ol>"
      uglify = "<ol><li>item 1</li><li>item 2</li><ol><li>nested 1 item 1</li></ol></ol>"
      assert_renders_uglify uglify, html 
    end
  end
end
