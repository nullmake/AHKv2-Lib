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
        
        Assert.Equal("Scalar", _token.type)
        Assert.Equal("hello", _token.value)
    }

    /**
     * @method Test_ScanMappingIndicator
     */
    Test_ScanMappingIndicator() {
        _scanner := _YamlScanner("key: value")
        
        _t1 := _scanner.FetchToken()
        Assert.Equal("Scalar", _t1.type)
        Assert.Equal("key", _t1.value)
        
        _t2 := _scanner.FetchToken()
        Assert.Equal("MappingIndicator", _t2.type)
        
        _t3 := _scanner.FetchToken()
        Assert.Equal("Scalar", _t3.type)
        Assert.Equal("value", _t3.value)
    }

    /**
     * @method Test_ScanIndentation
     */
    Test_ScanIndentation() {
        _input := "key:`n  child: value"
        _scanner := _YamlScanner(_input)
        
        _scanner.FetchToken() ; key
        _scanner.FetchToken() ; :
        
        _tIndent := _scanner.FetchToken()
        Assert.Equal("Indent", _tIndent.type)
        Assert.Equal(2, _tIndent.value)
        
        _scanner.FetchToken() ; child
        _scanner.FetchToken() ; :
        _scanner.FetchToken() ; value
        
        _tDedent := _scanner.FetchToken()
        Assert.Equal("Dedent", _tDedent.type)
        Assert.Equal("StreamEnd", _scanner.FetchToken().type)
    }

    /**
     * @method Test_ScanComment
     */
    Test_ScanComment() {
        ; Full line comment and end-of-line comment with space
        _input := "# comment line`nkey: value # end line comment"
        _scanner := _YamlScanner(_input)
        
        _t1 := _scanner.FetchToken()
        Assert.Equal("Scalar", _t1.type)
        Assert.Equal("key", _t1.value)
        
        _scanner.FetchToken() ; :
        
        _t2 := _scanner.FetchToken()
        Assert.Equal("Scalar", _t2.type)
        Assert.Equal("value", _t2.value)
        
        Assert.Equal("StreamEnd", _scanner.FetchToken().type)
    }

    /**
     * @method Test_ScanMidLineComment
     */
    Test_ScanMidLineComment() {
        ; Case 1: Space before # starts a comment
        _scanner1 := _YamlScanner("val # comment")
        Assert.Equal("val", _scanner1.FetchToken().value)
        Assert.Equal("StreamEnd", _scanner1.FetchToken().type)

        ; Case 2: No space before # is part of scalar
        _scanner2 := _YamlScanner("val#notcomment")
        Assert.Equal("val#notcomment", _scanner2.FetchToken().value)
    }

    /**
     * @method Test_ScanQuotedScalars
     */
    Test_ScanQuotedScalars() {
        _input := '"double": ' . "'single'"
        _scanner := _YamlScanner(_input)
        
        _t1 := _scanner.FetchToken()
        Assert.Equal("Scalar", _t1.type)
        Assert.Equal("double", _t1.value)
        
        _scanner.FetchToken() ; :
        
        _t2 := _scanner.FetchToken()
        Assert.Equal("Scalar", _t2.type)
        Assert.Equal("single", _t2.value)
    }

    /**
     * @method Test_ScanCommentInQuotes
     */
    Test_ScanCommentInQuotes() {
        _scanner := _YamlScanner('"# not a comment"')
        _t := _scanner.FetchToken()
        Assert.Equal("Scalar", _t.type)
        Assert.Equal("# not a comment", _t.value)
    }

    /**
     * @method Test_ScanMultipleDocuments
     */
    Test_ScanMultipleDocuments() {
        _input := "doc1`n---`ndoc2"
        _scanner := _YamlScanner(_input)
        
        Assert.Equal("doc1", _scanner.FetchToken().value)
        Assert.Equal("DocumentStart", _scanner.FetchToken().type)
        Assert.Equal("doc2", _scanner.FetchToken().value)
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