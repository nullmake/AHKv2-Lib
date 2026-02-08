#Requires AutoHotkey v2.0

/**
 * @class ConstructorTest
 * Unit tests for the _YamlConstructor class.
 */
class ConstructorTest {
    /**
    * @method Test_ConstructBoolean
    */
    Test_ConstructBoolean() {
        _ctor := _YamlConstructor()

        ; Plain scalars
        Assert.Equal(true, _ctor.Construct(YamlScalarNode("true", "", "", 0)))
        Assert.Equal(false, _ctor.Construct(YamlScalarNode("false", "", "", 0)))

        ; Quoted scalars must remain strings
        Assert.StrictEqual("true", _ctor.Construct(YamlScalarNode("true", "", "", 1))) ; 1 = SingleQuoted
        Assert.StrictEqual("false", _ctor.Construct(YamlScalarNode("false", "", "", 2))) ; 2 = DoubleQuoted
    }

    /**
    * @method Test_ConstructNull
    */
    Test_ConstructNull() {
        _ctor := _YamlConstructor()

        ; YAML 1.2.2 Null values: null, Null, NULL, ~, (empty)
        Assert.StrictEqual("", _ctor.Construct(YamlScalarNode("null", "", "", 0)))
        Assert.StrictEqual("", _ctor.Construct(YamlScalarNode("~", "", "", 0)))
        Assert.StrictEqual("", _ctor.Construct(YamlScalarNode("", "", "", 0)))
    }

    /**
    * @method Test_ConstructNumbers
    */
    Test_ConstructNumbers() {
        _ctor := _YamlConstructor()

        ; Integers
        Assert.StrictEqual(123, _ctor.Construct(YamlScalarNode("123", "", "", 0)))
        Assert.StrictEqual(-456, _ctor.Construct(YamlScalarNode("-456", "", "", 0)))
        Assert.StrictEqual(0, _ctor.Construct(YamlScalarNode("0", "", "", 0)))

        ; Hexadecimal
        Assert.StrictEqual(26, _ctor.Construct(YamlScalarNode("0x1A", "", "", 0)))

        ; Quoted numbers remain strings
        Assert.StrictEqual("123", _ctor.Construct(YamlScalarNode("123", "", "", 2)))
    }

    /**
    * @method Test_ConstructCasingVariations
    */
    Test_ConstructCasingVariations() {
        _ctor := _YamlConstructor()

        ; Booleans
        Assert.Equal(true, _ctor.Construct(YamlScalarNode("TRUE", "", "", 0)))
        Assert.Equal(true, _ctor.Construct(YamlScalarNode("True", "", "", 0)))
        Assert.Equal(false, _ctor.Construct(YamlScalarNode("FALSE", "", "", 0)))

        ; Nulls
        Assert.StrictEqual("", _ctor.Construct(YamlScalarNode("Null", "", "", 0)))
        Assert.StrictEqual("", _ctor.Construct(YamlScalarNode("NULL", "", "", 0)))
    }
}
