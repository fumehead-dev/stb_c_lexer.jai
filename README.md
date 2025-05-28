THIS JAI CODE IS BASED ON PRE-EXISTING C CODE:
`stb_c_lexer.h` - v0.12 - public domain Sean Barrett 2013
lexer for making little C-like languages with recursive-descent parsers

[Original File](https://github.com/nothings/stb/blob/master/stb_c_lexer.h)

You can see the example usage in the `example.jai`. Compile the program and provide a file as a text argument to see the debug output of the example program.
The basic idea is:
```
lexer := Lexer.{input = some_string_with_code};
while get_token(*lexer)  {
         // ... do stuff
}
```

This lexer uses dynamic arrays to construct identifiers and does not free (since it gives you the tokens, duh). 
You should probably push context with an allocator of choice and then reset it when you're done lexin' around. 
Memory pool allocator would mimic the original, which required a pointer to a block of memory.

## Changes from original

This lexer is mostly useful for lexing C(reasonably ++) code, therefore it does not expose the variety of super finicky defines like the original does. That said, these are still present in the form of constants. All code was ported, but not every parameter combination was tested (just like the original).

I have confirmed this lexer successfully lexes my large C++ codebase, so it should be reasonably stable and useful.

You can read more on difference of implementation in `module.jai`
