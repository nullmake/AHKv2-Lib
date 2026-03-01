#Requires AutoHotkey v2.0

/**
 * @file JsonStringifier.ahk
 * @description Utility to convert AHK objects to canonical minified JSON for testing.
 * @author nullmake
 * @license Apache-2.0
 * Copyright 2026 nullmake
 */

/**
 * Utility class to convert AHK objects to a deterministic, minified JSON string.
 */
class JsonStringifier {
    /**
     * Converts a value to a minified JSON string.
     * @param {Any} val - The value to stringify.
     * @returns {String} Minified JSON string.
     */
    static Stringify(val) {
        if (val == Yaml.Null || val == JSON.Null || (IsObject(val) && Type(val) == "ComValue" && val.Ptr == 0) || (IsObject(val) && val.HasProp("name") && val.name == "null")) {
            return "null"
        }
        if (val == Yaml.True || val == JSON.True) {
            return "true"
        }
        if (val == Yaml.False || val == JSON.False) {
            return "false"
        }
        if (IsInteger(val)) {
            return String(val)
        }
        if (IsFloat(val)) {
            ; If it's a whole number, output as integer to match in.json expectations
            if (val == Floor(val)) {
                return String(Floor(val))
            }
            ; Round to 15 decimal places to avoid tiny precision errors
            _rounded := Round(val, 15)
            if (_rounded == Floor(_rounded)) {
                return String(Floor(_rounded))
            }
            return String(_rounded)
        }
        if (IsObject(val)) {
            if (val.HasProp("name")) {
                if (val.name == "true") {
                    return "true"
                }
                if (val.name == "false") {
                    return "false"
                }
            }
            if (Type(val) == "ComValue") {
                if (val.Type == 0xB) { ; VT_BOOL
                    return val.Value ? "true" : "false"
                }
            }
            if (val is Array) {
                _str := "["
                for _v in val {
                    _str .= (A_Index > 1 ? "," : "") . this.Stringify(_v)
                }
                return _str . "]"
            }
            if (val is Map) {
                ; Sort keys to ensure deterministic output
                _keys := []
                for _k in val {
                    _keys.Push(_k)
                }
                this._SortKeys(_keys)

                _str := "{"
                for _i, _k in _keys {
                    ; JSON keys must be strings. Stringify key objects for comparison.
                    _keyStr := IsObject(_k) ? this.Stringify(_k) : String(_k)
                    _str .= (A_Index > 1 ? "," : "") . "`"" . this._Escape(_keyStr) . "`":" . this.Stringify(val[_k])
                }
                return _str . "}"
            }
        }
        return "`"" . this._Escape(String(val)) . "`""
    }

    /**
     * Sorts keys for deterministic JSON output using Quicksort.
     * @param {Array} keys
     * @private
     */
    static _SortKeys(keys) {
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
     * @private
     */
    static _QuickSort(arr, left, right) {
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
     * @private
     */
    static _GetSortKey(val) {
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
            this._SortKeys(_kList)
            for _k in _kList {
                _s .= (A_Index > 1 ? "," : "") . this._GetSortKey(_k) . ":" . this._GetSortKey(val[_k])
            }
            return _s . "}"
        }
        return Type(val)
    }

    /**
     * Escapes special characters for JSON strings.
     * @param {String} str
     * @returns {String}
     * @private
     */
    static _Escape(str) {
        str := StrReplace(str, "\", "\\")
        str := StrReplace(str, '"', '\"')
        str := StrReplace(str, "`n", "\n")
        str := StrReplace(str, "`r", "\r")
        str := StrReplace(str, "`t", "\t")
        return str
    }
}
