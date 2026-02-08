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

    /**
    * @method Test_ParseSimpleMapping
    * Verifies that a one-level mapping produces MappingStart/End events.
    */
    Test_ParseSimpleMapping() {
        _scanner := _YamlScanner("name: value")
        _parser := _YamlParser(_scanner)

        Assert.Equal("YamlStreamStartEvent", Type(_parser.NextEvent()))
        Assert.Equal("YamlDocumentStartEvent", Type(_parser.NextEvent()))

        Assert.Equal("YamlMappingStartEvent", Type(_parser.NextEvent()))

        _keyEvent := _parser.NextEvent()
        Assert.Equal("YamlScalarEvent", Type(_keyEvent))
        Assert.Equal("name", _keyEvent.value)

        _valEvent := _parser.NextEvent()
        Assert.Equal("YamlScalarEvent", Type(_valEvent))
        Assert.Equal("value", _valEvent.value)

        Assert.Equal("YamlMappingEndEvent", Type(_parser.NextEvent()))
        Assert.Equal("YamlDocumentEndEvent", Type(_parser.NextEvent()))
        Assert.Equal("YamlStreamEndEvent", Type(_parser.NextEvent()))
    }

    /**
    * @method Test_ParseNestedMapping
    * Verifies multi-level block mapping structures.
    */
    Test_ParseNestedMapping() {
        _input := "parent:`n  child: value"
        _scanner := _YamlScanner(_input)
        _parser := _YamlParser(_scanner)

        Assert.Equal("YamlStreamStartEvent", Type(_parser.NextEvent()))
        Assert.Equal("YamlDocumentStartEvent", Type(_parser.NextEvent()))

        ; Outer Mapping
        Assert.Equal("YamlMappingStartEvent", Type(_parser.NextEvent()))
        Assert.Equal("parent", _parser.NextEvent().value)

        ; Inner Mapping
        Assert.Equal("YamlMappingStartEvent", Type(_parser.NextEvent()))
        Assert.Equal("child", _parser.NextEvent().value)
        Assert.Equal("value", _parser.NextEvent().value)
        Assert.Equal("YamlMappingEndEvent", Type(_parser.NextEvent())) ; End child

        ; End Outer
        Assert.Equal("YamlMappingEndEvent", Type(_parser.NextEvent())) ; End parent

                Assert.Equal("YamlDocumentEndEvent", Type(_parser.NextEvent()))

                Assert.Equal("YamlStreamEndEvent", Type(_parser.NextEvent()))

            }



            /**

            * @method Test_ParseSimpleSequence

            */

            Test_ParseSimpleSequence() {

                _input := "- item1`n- item2"

                _scanner := _YamlScanner(_input)

                _parser := _YamlParser(_scanner)



                Assert.Equal("YamlStreamStartEvent", Type(_parser.NextEvent()))

                Assert.Equal("YamlDocumentStartEvent", Type(_parser.NextEvent()))



                Assert.Equal("YamlSequenceStartEvent", Type(_parser.NextEvent()))

                Assert.Equal("item1", _parser.NextEvent().value)

                Assert.Equal("item2", _parser.NextEvent().value)

                Assert.Equal("YamlSequenceEndEvent", Type(_parser.NextEvent()))



                Assert.Equal("YamlDocumentEndEvent", Type(_parser.NextEvent()))

                Assert.Equal("YamlStreamEndEvent", Type(_parser.NextEvent()))

            }



            /**

            * @method Test_ParseMappingWithSequence

            */

            Test_ParseMappingWithSequence() {

                _input := "list:`n  - a`n  - b"

                _scanner := _YamlScanner(_input)

                _parser := _YamlParser(_scanner)



                Assert.Equal("YamlStreamStartEvent", Type(_parser.NextEvent()))

                Assert.Equal("YamlDocumentStartEvent", Type(_parser.NextEvent()))



                ; Outer Mapping

                Assert.Equal("YamlMappingStartEvent", Type(_parser.NextEvent()))

                Assert.Equal("list", _parser.NextEvent().value)



                ; Inner Sequence

                Assert.Equal("YamlSequenceStartEvent", Type(_parser.NextEvent()))

                Assert.Equal("a", _parser.NextEvent().value)

                Assert.Equal("b", _parser.NextEvent().value)

                Assert.Equal("YamlSequenceEndEvent", Type(_parser.NextEvent()))



                Assert.Equal("YamlMappingEndEvent", Type(_parser.NextEvent()))



                Assert.Equal("YamlDocumentEndEvent", Type(_parser.NextEvent()))

                Assert.Equal("YamlStreamEndEvent", Type(_parser.NextEvent()))

            }

        }
