#Requires AutoHotkey v2.0

/**
 * @class YamlTest
 * End-to-end integration tests for the Yaml library.
 */
class YamlTest {
    /**
     * @method Test_LoadSimpleMapping
     */
    Test_LoadSimpleMapping() {
        _input := "name: AHKv2-Lib`nversion: 1.0"
        _obj := Yaml.Load(_input)
        
        Assert.Equal("Map", Type(_obj))
        Assert.Equal("AHKv2-Lib", _obj["name"])
        Assert.Equal("1.0", _obj["version"])
    }

    /**
     * @method Test_LoadNestedMapping
     */
    Test_LoadNestedMapping() {
        _input := "outer:`n  inner: value"
        _obj := Yaml.Load(_input)
        
        Assert.Equal("value", _obj["outer"]["inner"])
    }

    /**
     * @method Test_LoadSimpleSequence
     */
    Test_LoadSimpleSequence() {
        _input := "- a`n- b`n- c"
        _obj := Yaml.Load(_input)
        
        Assert.Equal("Array", Type(_obj))
        Assert.Equal(3, _obj.Length)
        Assert.Equal("a", _obj[1])
        Assert.Equal("c", _obj[3])
    }

    /**
     * @method Test_LoadMappingWithSequence
     */
    Test_LoadMappingWithSequence() {
        _input := "tags:`n  - ahk`n  - yaml"
        _obj := Yaml.Load(_input)
        
        Assert.Equal("ahk", _obj["tags"][1])
        Assert.Equal("yaml", _obj["tags"][2])
    }
}
