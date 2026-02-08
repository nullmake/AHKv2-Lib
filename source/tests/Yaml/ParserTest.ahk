#Requires AutoHotkey v2.0

/**
 * @class ParserTest
 * Tests for the _YamlParser class.
 */
class ParserTest {
    /**
     * @method Test_ParseSimpleScalar
     * Verifies that a single scalar produces the correct event stream.
     */
    Test_ParseSimpleScalar() {
        _scanner := _YamlScanner("hello")
        _parser := _YamlParser(_scanner)
        
        Assert.Equal("YamlStreamStartEvent", Type(_parser.NextEvent()))
        Assert.Equal("YamlDocumentStartEvent", Type(_parser.NextEvent()))
        
        _scalarEvent := _parser.NextEvent()
        Assert.Equal("YamlScalarEvent", Type(_scalarEvent))
        Assert.Equal("hello", _scalarEvent.value)
        
        Assert.Equal("YamlDocumentEndEvent", Type(_parser.NextEvent()))
        Assert.Equal("YamlStreamEndEvent", Type(_parser.NextEvent()))
    }
}
