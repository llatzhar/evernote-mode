require_relative '../lib/enlocal'
require 'minitest/autorun'

class TestENMLFormatter < Minitest::Test
  def test_text_to_enml
    text = "Hello\nWorld"
    enml = EnLocal::ENMLFormatter.text_to_enml(text)
    
    assert_includes enml, '<?xml version'
    assert_includes enml, '<en-note>'
    assert_includes enml, 'Hello<br clear="none"/>World'
    assert_includes enml, '</en-note>'
  end

  def test_enml_to_text
    enml = '<?xml version="1.0" encoding="UTF-8"?>' \
           '<!DOCTYPE en-note SYSTEM "http://xml.evernote.com/pub/enml2.dtd">' \
           '<en-note>Hello<br clear="none"/>World&nbsp;Test</en-note>'
    
    text = EnLocal::ENMLFormatter.enml_to_text(enml)
    
    assert_equal "Hello\nWorld Test", text
  end

  def test_html_escape
    text = '<script>alert("XSS")</script>'
    enml = EnLocal::ENMLFormatter.text_to_enml(text)
    
    assert_includes enml, '&lt;script&gt;'
    assert_includes enml, '&quot;'
  end

  def test_get_edit_mode_text
    source = 'emacs-enclient {:version => 0.41, :editmode => "TEXT"}'
    mode = EnLocal::ENMLFormatter.get_edit_mode(source)
    
    assert_equal 'TEXT', mode
  end

  def test_get_edit_mode_xhtml
    source = 'emacs-enclient {:version => 0.41, :editmode => "XHTML"}'
    mode = EnLocal::ENMLFormatter.get_edit_mode(source)
    
    assert_equal 'XHTML', mode
  end

  def test_get_edit_mode_default
    source = 'some other app'
    mode = EnLocal::ENMLFormatter.get_edit_mode(source)
    
    assert_equal 'XHTML', mode
  end
end

class TestSerializable < Minitest::Test
  def test_deserialize_string
    nb = EnLocal::Notebook.new
    # Simulate GDBM serialized format
    data = 'guid=abc123,name=VGVzdA==,updateSequenceNum=42,defaultNotebook=true'
    nb.deserialize(data)
    
    assert_equal 'abc123', nb.guid
    assert_equal 'Test', nb.name  # Base64 decoded
    assert_equal 42, nb.updateSequenceNum
    assert_equal true, nb.defaultNotebook
  end

  def test_deserialize_tag
    tag = EnLocal::Tag.new
    # Base64 for "My Tag" = "TXkgVGFn"
    data = 'guid=tag123,name=TXkgVGFn,parentGuid=parent123,updateSequenceNum=10'
    tag.deserialize(data)
    
    assert_equal 'tag123', tag.guid
    assert_equal 'My Tag', tag.name
    assert_equal 'parent123', tag.parentGuid
    assert_equal 10, tag.updateSequenceNum
  end

  def test_deserialize_note_minimal
    note = EnLocal::Note.new
    data = 'guid=note123,title=Tm90ZSBURVNU,notebookGuid=nb123,editMode=TEXT'
    note.deserialize(data)
    
    assert_equal 'note123', note.guid
    assert_equal 'Note TEST', note.title  # Base64 decoded
    assert_equal 'nb123', note.notebookGuid
    assert_equal 'TEXT', note.editMode
  end
end
