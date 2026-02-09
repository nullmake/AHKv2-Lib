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

        _tKey := _scanner.FetchToken() ; key
        Assert.Equal("key", _tKey.value)
        Assert.Equal(1, _tKey.column)
        
        _scanner.FetchToken() ; :

        _tChild := _scanner.FetchToken()
        Assert.Equal("Scalar", _tChild.type)
        Assert.Equal("child", _tChild.value)
        Assert.Equal(3, _tChild.column) ; 2 spaces indent = column 3

        _scanner.FetchToken() ; :
        _scanner.FetchToken() ; value

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
    * @method Test_ScanEscapedDoubleQuotes
    */
    Test_ScanEscapedDoubleQuotes() {
        _input := '"line1\nline2\ttab\"quote"'
        _scanner := _YamlScanner(_input)

        _t := _scanner.FetchToken()
        ; Use single quotes to safely contain a double quote character in AHK v2
        _expected := 'line1`nline2`ttab"quote'
        Assert.Equal(_expected, _t.value)
    }

    /**
    * @method Test_ScanBlockScalarChopping
    */
    Test_ScanBlockScalarChopping() {
        ; 1. Strip (-) : Remove all trailing newlines
        _input1 := "literal: |-`n  line`n`n"
        _scanner1 := _YamlScanner(_input1)
        _scanner1.FetchToken() ; literal
        _scanner1.FetchToken() ; :
        Assert.Equal("line", _scanner1.FetchToken().value)

        ; 2. Keep (+) : Preserve all trailing newlines
        _input2 := "literal: |+`n  line`n`n"
        _scanner2 := _YamlScanner(_input2)
        _scanner2.FetchToken() ; literal
        _scanner2.FetchToken() ; :
        Assert.Equal("line`n`n", _scanner2.FetchToken().value)
    }

    /**
    * @method Test_ScanAnchorAndAlias
    */
    Test_ScanAnchorAndAlias() {
        _input := "&anchor *alias"
        _scanner := _YamlScanner(_input)

        _t1 := _scanner.FetchToken()
        Assert.Equal("Anchor", _t1.type)
        Assert.Equal("anchor", _t1.value)

        _t2 := _scanner.FetchToken()
        Assert.Equal("Alias", _t2.type)
        Assert.Equal("alias", _t2.value)
    }

    /**
    * @method Test_ScanTags
    * Verifies that local and global tags are identified.
    */
    Test_ScanTags() {
        _input := "!local !!global"
        _scanner := _YamlScanner(_input)

        _t1 := _scanner.FetchToken()
        Assert.Equal("Tag", _t1.type)
        Assert.Equal("!local", _t1.value)

        _t2 := _scanner.FetchToken()
        Assert.Equal("Tag", _t2.type)
        Assert.Equal("!!global", _t2.value)
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
