# Data

The data module is encoding, hashing, compression and byte packing. None of it touches the screen, so you can use it anywhere.

## Base64 and hex

[`encode`](api/data.md#encode) turns bytes or a string into base64, or into hex when you pass `hex = true`. [`decode`](api/data.md#decode) gives you back the bytes, and [`decodeString`](api/data.md#decodeString) gives back a string for when you know the payload was text.

```nim { .annotate }
let s = encode("hello")               # (1)!
let h = encode("hello", hex = true)   # (2)!
let back = decodeString(s)            # (3)!
```

1.  Encodes the string as base64.
2.  Encodes as hex instead by passing `hex = true`.
3.  Decodes the base64 back to the original string.

## Hashing

[`digest`](api/data.md#digest) returns the hash of a string or bytes as lowercase hex. The function is the first argument: `hfMD5`, `hfSHA1`, `hfSHA256` or `hfSHA512`. [`digestRaw`](api/data.md#digestRaw) gives the raw bytes instead.

```nim
echo digest(hfSHA256, "hello")
```

The proc is called `digest` rather than `hash` so it does not clash with the standard library's `hash` when you import both.

## Compression

[`compress`](api/data.md#compress) shrinks bytes or a string, and [`decompress`](api/data.md#decompress) expands them again. The format is `compZlib`, `compGzip` or `compDeflate`, and an optional level runs from 1 for fastest to 9 for smallest, with -1 as a sensible middle. [`decompressString`](api/data.md#decompressString) gives back a string.

```nim { .annotate }
let packed = compress(bigText, compZlib)        # (1)!
let text = decompressString(packed, compZlib)   # (2)!
```

1.  Shrinks the text with zlib, the chosen format.
2.  Expands it back to a string using the same format.

Use the same format for `decompress` that you used to compress. Deflate has no header to detect, so it has to match.

## Packing

[`pack`](api/data.md#pack) writes integers into bytes following a small format string, and [`unpack`](api/data.md#unpack) reads them back. The codes are `b` and `B` for one byte, `h` and `H` for two, `i` and `I` for four, and `l` and `L` for eight, with the lowercase ones signed. A `<` switches to little-endian and a `>` to big-endian, with little-endian the default, and spaces in the format are ignored.

```nim { .annotate }
let bytes = pack("<i h b", 70000, 513, -3)   # (1)!
let values = unpack("<i h b", bytes)         # (2)!
```

1.  Packs three little-endian integers, four bytes then two then one.
2.  Reads them back in the same format, giving `@[70000, 513, -3]`.

!!! info "See also"
    The runnable [`data` example](https://github.com/nim2d/nim2d/blob/master/examples/data.nim), and the [`data` API reference](api/data.md).
