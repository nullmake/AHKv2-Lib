#Requires AutoHotkey v2.0

/**
 * @class ScannerTest
 * Tests for the _YamlScanner class.
 */
class ScannerTest {
    /**
     * @method Test_ScanSimpleScalar
     */
    Test_ScanSimpleScalar() {
        _scanner := _YamlScanner("hello")
        _token := _scanner.FetchToken()
        
        Assert.Equal("Scalar", _token.Type)
        Assert.Equal("hello", _token.Value)
    }

    /**
     * @method Test_ScanMappingIndicator
     */
    Test_ScanMappingIndicator() {
        _scanner := _YamlScanner("key: value")
        
        _t1 := _scanner.FetchToken()
        Assert.Equal("Scalar", _t1.Type)
        Assert.Equal("key", _t1.Value)
        
        _t2 := _scanner.FetchToken()
        Assert.Equal("MappingIndicator", _t2.Type)
        
        _t3 := _scanner.FetchToken()
        Assert.Equal("Scalar", _t3.Type)
        Assert.Equal("value", _t3.Value)
    }

    /**
     * @method Test_ScanIndentation
     * Verifies Indent and Dedent tokens.
     */
    Test_ScanIndentation() {
        _input := "key:`n  child: value"
        _scanner := _YamlScanner(_input)
        
        _scanner.FetchToken() ; key
        _scanner.FetchToken() ; :
        
        ; Indent of 2 spaces
        _tIndent := _scanner.FetchToken()
        Assert.Equal("Indent", _tIndent.Type)
        Assert.Equal(2, _tIndent.Value)
        
        _scanner.FetchToken() ; child
        _scanner.FetchToken() ; :
        _scanner.FetchToken() ; value
        
        ; End of stream unrolls indentation
        _tDedent := _scanner.FetchToken()
        Assert.Equal("Dedent", _tDedent.Type)
        
        Assert.Equal("StreamEnd", _scanner.FetchToken().Type)
    }

    /**
     * @method Test_ScanMultipleDocuments
     */
    Test_ScanMultipleDocuments() {
        _input := "doc1`n---`ndoc2"
        _scanner := _YamlScanner(_input)
        
        Assert.Equal("doc1", _scanner.FetchToken().Value)
        
        _tDocStart := _scanner.FetchToken()
        Assert.Equal("DocumentStart", _tDocStart.Type)
        
        Assert.Equal("doc2", _scanner.FetchToken().Value)
    }

    /**
     * @method Test_TabIndentationError
     */
    Test_TabIndentationError() {
        _input := "key:`n`tchild: value"
        _scanner := _YamlScanner(_input)
        _scanner.FetchToken() ; key
        _scanner.FetchToken() ; :
        
        try {
            _scanner.FetchToken()
            Assert.Fail("Should have thrown YamlError for tab indentation")
        } catch YamlError as _e {
            Assert.True(InStr(_e.Message, "Tab"), "Error should mention tabs")
            Assert.Equal(2, _e.line)
        }
    }
}
