#Requires AutoHotkey v2.0

/**
 * @file _YamlRepresenter.ahk
 * @description Layer 4: Converts native AHK v2 objects to YAML nodes with Intent.
 * @author nullmake
 * @license Apache-2.0
 * Copyright 2026 nullmake
 */

/**
 * Converts native AHK objects to a YAML node graph.
 */
class _YamlRepresenter {
    /** @field {Map} _objectMap - Cache for circular reference detection and anchor generation */
    _objectMap := Map()

    /** @field {YamlOptions} _options - Configuration options */
    _options := unset

    /** @field {_YamlTracer|String} _tracer - Scoped tracer instance */
    _tracer := ""

    /**
     * @param {YamlOptions} [options] - Configuration options
     */
    __New(options := "") {
        this._options := (options is YamlOptions) ? options : YamlOptions(options)
        this._tracer := this._options.CreateTracer("Representer")
    }

    /**
     * Converts a native object to a YAML node.
     * @param {Any} data
     * @returns {YamlNode}
     */
    Represent(data) {
        if (this._tracer) {
            this._tracer.Trace("Representing object")
        }
        this._objectMap := Map()
        return this._Represent(data)
    }

    /**
     * Recursive internal implementation of representation.
     * @param {Any} data
     * @returns {YamlNode}
     */
    _Represent(data) {
        if (this._tracer) {
            this._tracer.Trace("Representing data: " . (IsObject(data) ? "[" . Type(data) . "]" : String(data)))
        }
        if (data == Yaml.Null) {
            return YamlScalarNode("~", "tag:yaml.org,2002:null", , ":")
        }
        if (data == Yaml.True) {
            return YamlScalarNode("true", "tag:yaml.org,2002:bool", , ":")
        }
        if (data == Yaml.False) {
            return YamlScalarNode("false", "tag:yaml.org,2002:bool", , ":")
        }

        if (IsObject(data)) {
            _ptr := ObjPtr(data)
            if (this._objectMap.Has(_ptr)) {
                return this._objectMap[_ptr]
            }

            if (data is Array) {
                _node := YamlSequenceNode("tag:yaml.org,2002:seq")
                this._objectMap[_ptr] := _node
                for _v in data {
                    _node.children.Push(this._Represent(_v))
                }
                return _node
            }

            if (data is Map) {
                _node := YamlMappingNode("tag:yaml.org,2002:map")
                this._objectMap[_ptr] := _node
                _keys := []
                for _k in data {
                    _keys.Push(_k)
                }
                this._SortKeys(_keys)
                for _k in _keys {
                    _node.Add(this._Represent(_k), this._Represent(data[_k]))
                }
                return _node
            }

            _node := YamlMappingNode("tag:yaml.org,2002:map")
            this._objectMap[_ptr] := _node
            _keys := []
            for _k, _v in data.OwnProps() {
                _keys.Push(_k)
            }
            this._SortKeys(_keys)
            for _k in _keys {
                _node.Add(this._Represent(_k), this._Represent(data.%_k%))
            }
            return _node
        }

        return this._RepresentScalar(data)
    }

    /**
     * Converts a primitive value to a scalar node with style analysis.
     * @param {Any} val
     * @param {String} [tag=""]
     * @returns {YamlScalarNode}
     */
    _RepresentScalar(val, tag := "") {
        _strVal := String(val)
        _resolvedTag := tag

        ; 1. Tag Detection
        if (_resolvedTag == "") {
            if (IsInteger(val)) {
                _resolvedTag := "tag:yaml.org,2002:int"
            } else if (IsFloat(val)) {
                _resolvedTag := "tag:yaml.org,2002:float"
            } else {
                _resolvedTag := "tag:yaml.org,2002:str"
            }
        }

        ; 2. Detailed Analysis for Presentation Intent
        analysis := this._AnalyzeString(_strVal)

        node := YamlScalarNode(_strVal, _resolvedTag, , analysis.style)
        node.chomping := analysis.chomping
        node.isMultiline := analysis.isMultiline

        ; Force quotes for stringified numbers/booleans to preserve type
        if (_resolvedTag == "tag:yaml.org,2002:str") {
            if (IsNumber(val) || val ~= "i)^(true|false|null|~)$") {
                node.style := '"'
            }
        }

        return node
    }

    /**
     * Analyzes a string to determine the best YAML style.
     * @param {String} val
     * @returns {Object} {style, chomping, isMultiline}
     */
    _AnalyzeString(val) {
        res := { style: ":", chomping: "clip", isMultiline: false }

        if (val == "") {
            res.style := "'"
            return res
        }

        hasNewline := InStr(val, "`n")
        hasTab := InStr(val, "`t")

        if (hasNewline) {
            res.isMultiline := true
            res.style := "|" ; Prefer Literal for multiline

            ; Determine Chomping
            if (SubStr(val, -1) != "`n") {
                res.chomping := "strip"
            } else {
                ; Count trailing newlines
                if (SubStr(val, -2) == "`n`n") {
                    res.chomping := "keep"
                } else {
                    res.chomping := "clip"
                }
            }
        }

        ; Double Quotes needed for special characters
        if (hasTab || hasNewline || SubStr(val, 1, 1) == " " || SubStr(val, -1) == " ") {
            res.style := '"'
        }

        ; Disallowed plain characters (Control characters)
        if (val ~= "[\x00-\x1F\x7F-\x9F]") {
            res.style := '"'
        }

        ; Indicators at start or reserved words
        if (val ~= "i)^[:#\[\]{},&*!|>'`"%@``]") {
            res.style := '"'
        }

        ; Sequences disallowed in plain scalars
        if (InStr(val, ": ") || InStr(val, ":`t") || InStr(val, ":`n")) {
            res.style := '"'
        }
        if (InStr(val, " #") || InStr(val, "`t#")) {
            res.style := '"'
        }

        return res
    }

    /**
     * Sorts keys for deterministic output using Quicksort algorithm.
     * @param {Array} keys
     */
    _SortKeys(keys) {
        if (keys.Length < 2) {
            return
        }
        this._QuickSort(keys, 1, keys.Length)
    }

    /**
     * Internal Quicksort implementation.
     * @param {Array} arr
     * @param {Integer} left
     * @param {Integer} right
     */
    _QuickSort(arr, left, right) {
        i := left
        j := right
        pivot := arr[left + (right - left) // 2]
        pivotKey := this._GetSortKey(pivot)

        while (i <= j) {
            while (StrCompare(this._GetSortKey(arr[i]), pivotKey) < 0) {
                i++
            }
            while (StrCompare(this._GetSortKey(arr[j]), pivotKey) > 0) {
                j--
            }
            if (i <= j) {
                _tmp := arr[i]
                arr[i] := arr[j]
                arr[j] := _tmp
                i++
                j--
            }
        }

        if (left < j) {
            this._QuickSort(arr, left, j)
        }
        if (i < right) {
            this._QuickSort(arr, i, right)
        }
    }

    /**
     * Generates a deterministic sort key for any value.
     * @param {Any} val
     * @returns {String}
     */
    _GetSortKey(val) {
        if (!IsObject(val)) {
            return String(val)
        }
        if (HasMethod(val, "ToString")) {
            return val.ToString()
        }
        if (val is Array) {
            _s := "["
            for _v in val {
                _s .= (A_Index > 1 ? "," : "") . this._GetSortKey(_v)
            }
            return _s . "]"
        }
        if (val is Map) {
            _s := "{"
            _kList := []
            for _k in val {
                _kList.Push(_k)
            }
            ; We need a stable sort for nested keys too
            this._SortKeys(_kList)
            for _k in _kList {
                _s .= (A_Index > 1 ? "," : "") . this._GetSortKey(_k) . ":" . this._GetSortKey(val[_k])
            }
            return _s . "}"
        }
        return Type(val)
    }
}
