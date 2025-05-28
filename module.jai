// THIS JAI CODE IS BASED ON PRE-EXISTING C CODE:
//      stb_c_lexer.h - v0.12 - public domain Sean Barrett 2013
//      lexer for making little C-like languages with recursive-descent parsers

// This lexer uses dynamic arrays to construct identifiers nd does not free (since it gives you the tokens, duh). You should probably push context with an allocator of choice and then reset it when you're done lexin' around. Memory pool allocator would mimic the original (original required a block of memory of an arbitrary size).


/*

The original exported a great deal of defines.
I did not feel comfortable making them into module parameters, as they'd require extensive testing before I could declare them working.
So, instead, there's only one parameter, which is the new option I added to ignore unsupported char literals.
I'm assumming most people using this lexer simply want to transform some C code and not write a new language. If you're doing the latter, please acquiant yourself with the constant declared at the top of the file here after #module_parameters, they are commented and all functionality is provided, just not tested. That said, it should not require too much work to get it working. 
Note that the original code was not much tested either as stated by STB himself in the comments.

I have confirmed this lexer successfully lexes my large C++ codebase, so it should be reasonably stable.

*/

/* PORT CHANGES: 
    1. Removed the commented out  STB_C_LEX_ISWHITE(str) and its mention as it wasn't clear what it was supposed to do (this was not docummented by the original author) Presumably this might've been to aid people making whitespace languages ala Python. Too bad!
    2. Remove 0_IS_EOF flag because it makes no sense for this language.
    3. Removed string_storage. Push an allocator instead
    4. Removed c stdlib on/off toggle, using 
                string_to_float and string_to_int instead
    5. Renamed string to token_string in the lexer struct
    6. Removed \f escape sequence support
    7. Turned on suffixes by default and added "f" as a default suffix string
    8. Added IGNORE_UNSUPPORTED_CHAR_LITERALS option. On by default.
*/

#module_parameters(
IGNORE_UNSUPPORTED_CHAR_LITERALS := true
        // silently skip chars that are not supported by the lexer
        // for char literals this means you will get singular tokens of ' or " instead, followed by whatever escape sequence
        // for strings, this means those characters will simply be skipped
)();
                                        
C_DECIMAL_INTS :: true;                   //  "0|[1-9][0-9]*"                        CLEX_intlit
C_HEX_INTS :: true;                       //  "0x[0-9a-fA-F]+"                       CLEX_intlit
C_OCTAL_INTS :: true;                     //  "[0-7]+"                               CLEX_intlit
C_DECIMAL_FLOATS :: true;                 //  "[0-9]*(.[0-9]*([eE][-+]?[0-9]+)?)     CLEX_floatlit
C99_HEX_FLOATS :: false;                  //  "0x{hex}+(.{hex}*)?[pP][-+]?{hex}+     CLEX_floatlit
C_IDENTIFIERS :: true;                    //  "[_a-zA-Z][_a-zA-Z0-9]*"               CLEX_id
C_DQ_STRINGS :: true;                     //  double-quote-delimited strings with escapes  CLEX_dqstring
C_SQ_STRINGS :: false;                    //  single-quote-delimited strings with escapes  CLEX_ssstring
C_CHARS :: true;                          //  single-quote-delimited character with escape CLEX_charlits
C_COMMENTS :: true;                       //  "/* comment */"
CPP_COMMENTS :: true;                     //  "// comment to end of line\n"
C_COMPARISONS :: true;                    //  "==" CLEX_eq  "!=" CLEX_noteq   "<=" CLEX_lesseq  ">=" CLEX_greatereq
C_LOGICAL :: true;                        //  "&&"  CLEX_andand   "||"  CLEX_oror
C_SHIFTS :: true;                         //  "<<"  CLEX_shl      ">>"  CLEX_shr
C_INCREMENTS :: true;                     //  "++"  CLEX_plusplus "--"  CLEX_minusminus
C_ARROW :: true;                          //  "->"  CLEX_arrow
EQUAL_ARROW :: false;                     //  "=>"  CLEX_eqarrow
C_BITWISEEQ :: true;                      //  "&="  CLEX_andeq    "|="  CLEX_oreq     "^="  CLEX_xoreq
C_ARITHEQ :: true;                        //  "+="  CLEX_pluseq   "-="  CLEX_minuseq
                                            //  "*="  CLEX_muleq    "/="  CLEX_diveq    "%=" CLEX_modeq
                                            //  if both STB_C_LEX_SHIFTS & STB_C_LEX_ARITHEQ:
                                            //                      "<<=" CLEX_shleq    ">>=" CLEX_shreq
PARSE_SUFFIXES :: true; // letters after numbers are parsed as part of those numbers, and must be in suffix list below
DECIMAL_SUFFIXES::  ""; // decimal integer suffixes e.g. "uUlL" -- these are returned as-is in string storage
HEX_SUFFIXES    ::  ""; // e.g. "uUlL"
OCTAL_SUFFIXES  ::  ""; // e.g. "uUlL"
FLOAT_SUFFIXES  ::  "f";
INTEGERS_AS_DOUBLES :: false; // parses integers as doubles so they can be larger than 'int', but only if STB_C_LEX_STDLIB==N
MULTILINE_DSTRINGS :: false; // allow newlines in double-quoted strings
MULTILINE_SSTRINGS :: false; // allow newlines in single-quoted strings
DOLLAR_IDENTIFIER :: true; // allow $ as an identifier character
FLOAT_NO_DECIMAL :: true; // allow floats that have no decimal point if they have an exponent
DEFINE_ALL_TOKEN_NAMES :: false; // if Y, all CLEX_ token names are defined, even if never returned
                                // leaving it as N should help you catch config bugs
DISCARD_PREPROCESSOR :: true;  // discard C-preprocessor directives (e.g. after prepocess
                // still have #line, #pragma, etc)


Lexer :: struct {
   // lexer variables
    input: string;
    parse_point: s64;

    where_firstchar: s64;
    where_lastchar: s64;

   // lexer token variables
    token: u64;
    real_number: float64;
    int_number: s64;
    token_string: string;
};

Lexer_Location :: struct {
    line_number: s64;
    line_offset: s64;
};


Token_Type :: enum u64 {
    EOF :: 256;
    PARSE_ERROR;
    INTLIT        ;
    FLOATLIT      ;
    ID            ;
    DQSTRING      ;
    SQSTRING      ;
    CHARLIT       ;
    EQ            ;
    NOTEQ         ;
    LESSEQ        ;
    GREATEREQ     ;
    ANDAND        ;
    OROR          ;
    SHL           ;
    SHR           ;
    PLUSPLUS      ;
    MINUSMINUS    ;
    PLUSEQ        ;
    MINUSEQ       ;
    MULEQ         ;
    DIVEQ         ;
    MODEQ         ;
    ANDEQ         ;
    OREQ          ;
    XOREQ         ;
    ARROW         ;
    EQARROW       ;
    SHLEQ         ;
    SHREQ         ;
    FIRST_UNUSED_TOKEN;
};

/*
This function has a C-like interface to make porting existing stb_c_lexer code easy. 
                                                                                      
    returns true if token was successfully parsed.

inspect lexer's contents to get anything useful:
    token  if within range of Token_Type enum, interpret as that, if not -- interpret as u8 character.
    int_number is an integer constant for CLEX_intlit if !STB_C_LEX_INTEGERS_AS_DOUBLES, or character for CLEX_charlit
    real_number  is a double constant value for CLEX_floatlit, or CLEX_intlit if STB_C_LEX_INTEGERS_AS_DOUBLES    
    string_token is a string for .DQSTRING or .SQSTRING or .IDENTIFIER
*/

make_eof :: (lexer: *Lexer) -> success: bool {
    lexer.token = Token_Type.EOF.(u64);
    return false;

}


// this inefficient function returns the line number and character offset of a
// given location in the file as returned by stb_lex_token. Because it's inefficient,
// you should only call it for errors, not for every token.
// For error messages of invalid tokens, you typically want the location of the start
// of the token (which caused the token to be invalid). For bugs involving legit
// tokens, you can report the first or the range.
//    Output:
//    - loc.line_number is the line number in the file, counting from 1, of the location
//    - loc.line_offset is the char-offset in the line, counting from 0, of the location
get_location :: (lexer: *Lexer, cursor: s64, loc: *Lexer_Location) {
   //char *p = lexer->input_stream;
   //int line_number = 1;
   //int char_offset = 0;
   //while (*p && p < where) {
   //   if (*p == '\n' || *p == '\r') {
   //      p += (p[0]+p[1] == '\r'+'\n' ? 2 : 1); // skip newline
   //      line_number += 1;
   //      char_offset = 0;
   //   } else {
   //      ++p;
   //      ++char_offset;
   //   }
   //}
   //loc->line_number = line_number;
   //loc->line_offset = char_offset;
}

make_token :: (lexer: *Lexer, token_type: u64, start: s64, end: s64) -> success: bool {
    lexer.token = token_type;
    lexer.where_firstchar = start;
    lexer.where_lastchar = end;
    lexer.parse_point = end+1;
    return true;
}

make_token :: (lexer: *Lexer, token_type: Token_Type, start: s64, end: s64) -> success: bool {
    return make_token(lexer, token_type.(u64), start, end);
}

parse_char :: (lexer: *Lexer, cursor: s64, end: *s64) -> (character: u8, success: bool = true) {
    if lexer.input[cursor] == "\\" {
        end.* = cursor + 2; // tentatively guess we'll parse two characters

        if lexer.input[cursor+1] == {
            case "\\"; return "\\";
            case "'"; return "'";
            case "\""; return "\"";
            case "t"; return "\t";
            case "n"; return "\n";
            case "r"; return "\r";
            case "0"; return "\0"; // @TODO ocatal constants
            case "f"; #through; //What the hell is \f? I'm too young for this shit.
            case "v"; #through;
            case "x"; #through;
            case "X"; #through; // @TODO hex constants
            case "u"; return 0, success = false; // @TODO unicode constants
            case;
                #if IGNORE_UNSUPPORTED_CHAR_LITERALS {
                    return 0, success = false;
                } else {
                    print_character(lexer.input[cursor]);
                assert(
                    false, 
                    "Unsupported char literal.", lexer.input[cursor]);
        }
                }

    }

    end.* = cursor + 1;
    return lexer.input[cursor];
}

parse_string :: (lexer: *Lexer, cursor: s64, token_type: Token_Type) -> success: bool {
    out: [..] u8;
    start := cursor;
    delim := lexer.input[cursor];
    cursor += 1;

    while lexer.input[cursor] != delim {
        n : u8;
        if lexer.input[cursor] == "\\" {
            end: int;
            success: bool;
            n, success = parse_char(lexer, cursor, *end);
            cursor = end;
            #if IGNORE_UNSUPPORTED_CHAR_LITERALS {
                if !success continue;
            } else {
                if !success return make_token(lexer, .PARSE_ERROR, start, cursor);
            }
        } else {
            n = lexer.input[cursor];
            cursor += 1;
        }
        array_add(*out, n);
    }

    lexer.token_string.data = out.data;
    lexer.token_string.count = out.count;

    return make_token(lexer, token_type, start, cursor);
}

parse_float :: (lexer: *Lexer, cursor: s64, end: *s64) -> number: float64  {
    view := lexer.input;
    view.data += cursor;
    view.count -= cursor;
    val, success, remainder := string_to_float(view);
    end.* = remainder.data - lexer.input.data;
    return val;
}

parse_int_of_base :: (lexer: *Lexer, cursor: s64, end: *s64, base: int) -> number: s64  {
    view := lexer.input;
    view.data += cursor;
    view.count -= cursor;
    val, success, remainder := string_to_int(view, base, s64);
    end.* = remainder.data - lexer.input.data;
    return val;
}

character_is_one_of :: (char: u8, in_string: string) -> bool {
    for in_string  if it == char return true;

    return false;
}

parse_suffixes :: (lexer: *Lexer, token_type: Token_Type, cursor: s64, end: *s64, suffixes: string) -> success: bool {
    new_end := end.*;
    #if PARSE_SUFFIXES {
        suffix : [..] u8;

        while (lexer.input[new_end] >= "a" && lexer.input[new_end] <= "z")
                || (lexer.input[new_end] >= "A" && lexer.input[new_end] <= "Z") {
            if character_is_one_of(lexer.input[new_end], suffixes) {
                array_add(*suffix, lexer.input[new_end]);
                new_end += 1;
            } else {
                return make_token(lexer, .PARSE_ERROR, cursor, new_end);
            }
        }

        lexer.token_string.data = suffix.data;
        lexer.token_string.count = suffix.count;
    }
    end.* = new_end;
    return make_token(lexer, token_type, cursor, end.* - 1);
}

get_token :: (lexer: *Lexer) -> token_parsed: bool {
    p := lexer.parse_point;

    while 1 {
        while p < lexer.input.count && is_space(cast,no_check(u8) lexer.input[p]) {
            p += 1;
        }

        #if CPP_COMMENTS {
            if p < lexer.input.count 
                && lexer.input[p] == #char "/" 
                && lexer.input[p+1] == #char "/"
            {
                while p < lexer.input.count 
                    && lexer.input[p] != #char "\r" 
                    && lexer.input[p] != #char "\n" {
                    p += 1;
                }

                continue;
            }
        }

      #if C_COMMENTS {
          if p < lexer.input.count
              && lexer.input[p] == #char "/"
              && lexer.input[p+1] == #char "*" 
                                          {
            start := p;
            p += 2;
            while p < lexer.input.count 
                && lexer.input[p] != #char "*"
                && lexer.input[p+1] != #char "/"
                    {
                p += 1;
            }
            if p >= lexer.input.count {
                return make_token(lexer, .PARSE_ERROR, start, p-1);
            }

            p += 2;
            continue;
          }
      }

      #if DISCARD_PREPROCESSOR {
         // STB'S ORIGINAL @TODO here: this discards everything after a '#', regardless
         // of where in the line the # is, rather than requiring it
         // be at the start. (because this parser doesn't otherwise
         // check for line breaks!)
         if p < lexer.input.count && lexer.input[p] == #char "#" {
             while p < lexer.input.count && lexer.input[p] != #char "\n" && lexer.input[p] != #char "\r" {
                 p += 1;
             }
             continue;
         }
      }
      break;
   }

   if (p >= lexer.input.count)      return make_eof(lexer);

   is_valid_ident_symbol :: (cursor: s64, $also_numbers: bool = false) -> bool #expand {
       char := `lexer.input[cursor];
       retval := (char >= "a" && char <= "z")
           || (char >= "A" && char <= "Z")
           || char == "_" || char.(u8) >= 128; // >= 128 is UTF8 char
       #if DOLLAR_IDENTIFIER {
           retval = retval || char == "$";
       }

       #if also_numbers {
           retval = retval || (char >= "0" && char <= "9");
       }

       return retval;
   }

   single_char :: () -> bool #expand { // originally a C goto for some reason.
       return make_token(`lexer, `lexer.input[`p], `p, `p);
   }

    char_between :: (cursor: s64, start: u8, end: u8) -> bool #expand {
        return lexer.input[cursor] >= start && lexer.input[cursor] <= end;
    }

   if lexer.input[p] == {
       case;
           if is_valid_ident_symbol(p) {
               identifier: [..] u8;
               n := 0;

               while is_valid_ident_symbol(p+n, true) {
                   array_add(*identifier, lexer.input[p+n]);
                   n += 1;
               }

               lexer.token_string.data = identifier.data;
               lexer.token_string.count = identifier.count;

               return make_token(lexer, .ID, p, p+n-1);
           }
           // not an identifier, return the character as itself
           return single_char();
       case "+";
           if (p + 1) < lexer.input.count {
               #if C_INCREMENTS {
                   if lexer.input[p+1] == "+" {
                       return make_token(lexer, .PLUSPLUS, p, p+1);
                   }
               }
               #if C_ARITHEQ {
                   if lexer.input[p+1] == "=" {
                       return make_token(lexer, .PLUSEQ, p, p+1);
                   }
               }

           }
           return single_char();
       case "-";
           if (p+1) < lexer.input.count {
               #if C_INCREMENTS {
                   if lexer.input[p+1] == "-" {
                       return make_token(lexer, .MINUSMINUS, p, p+1);
                   }
               }
               #if C_ARITHEQ {
                   if lexer.input[p+1] == "=" {
                       return make_token(lexer, .MINUSEQ, p, p+1);
                   }
               }
               #if C_ARROW {
                   if lexer.input[p+1] == ">" {
                       return make_token(lexer, .ARROW, p, p+1);
                   }
               }
           }
           return single_char();
        case "&";
            if (p+1) < lexer.input.count {
                #if C_LOGICAL {
                    if lexer.input[p+1] == "&" {
                        return make_token(lexer, .ANDAND, p, p+1);
                    }
                }
                #if C_BITWISEEQ {
                    if lexer.input[p+1] == "=" {
                        return make_token(lexer, .ANDEQ, p, p+1);
                    }
                }
            }

            return single_char();
        case "|";
            if (p+1) < lexer.input.count {
                #if C_LOGICAL {
                    if lexer.input[p+1] == "|" {
                        return make_token(lexer, .OROR, p, p+1);
                    }
                }
                #if C_BITWISEEQ {
                    if lexer.input[p+1] == "=" {
                        return make_token(lexer, .OREQ, p, p+1);
                    }
                }
            }

            return single_char();
        case "=";
            if (p+1) < lexer.input.count {
                #if C_COMPARISONS {
                    if lexer.input[p+1] == "=" {
                        return make_token(lexer, .EQ, p, p+1);
                    }
                }
                #if EQUAL_ARROW {
                    if lexer.input[p+1] == ">" {
                        return make_token(lexer, .EQARROW, p, p+1);
                    }
                }
            }

            return single_char();
        case "!";
            if (p+1) < lexer.input.count {
                #if C_COMPARISONS {
                    if lexer.input[p+1] == "=" {
                        return make_token(lexer, .NOTEQ, p, p+1);
                    }
                }
            }

            return single_char();
        case "^";
            if (p+1) < lexer.input.count {
                #if C_BITWISEEQ {
                    if lexer.input[p+1] == "=" {
                        return make_token(lexer, .XOREQ, p, p+1);
                    }
                }
            }

            return single_char();
        case "%";
            if (p+1) < lexer.input.count {
                #if C_ARITHEQ {
                    if lexer.input[p+1] == "=" {
                        return make_token(lexer, .MODEQ, p, p+1);
                    }
                }
            }

            return single_char();
        case "*";
            if (p+1) < lexer.input.count {
                #if C_ARITHEQ {
                    if lexer.input[p+1] == "=" {
                        return make_token(lexer, .MULEQ, p, p+1);
                    }
                }
            }

            return single_char();
        case "/";
            if (p+1) < lexer.input.count {
                #if C_ARITHEQ {
                    if lexer.input[p+1] == "=" {
                        return make_token(lexer, .DIVEQ, p, p+1);
                    }
                }
            }

            return single_char();
        case "<";
            if (p+1) < lexer.input.count {
                #if C_COMPARISONS {
                    if lexer.input[p+1] == "=" {
                        return make_token(lexer, .LESSEQ, p, p+1);
                    }
                }
                #if C_SHIFTS {
                    if lexer.input[p+1] == "<" {
                        #if C_ARITHEQ {
                            if (p+2) < lexer.input.count && lexer.input[p+2] == "=" {
                                return make_token(lexer, .SHLEQ, p, p+1); // shrek's brother
                            }
                        }
                        return make_token(lexer, .SHL, p, p+1);
                    }
                }
            }

            return single_char();
        case ">";
            if (p+1) < lexer.input.count {
                #if C_COMPARISONS {
                    if lexer.input[p+1] == "=" {
                        return make_token(lexer, .GREATEREQ, p, p+1);
                    }
                }
                #if C_SHIFTS {
                    if lexer.input[p+1] == ">" {
                        #if C_ARITHEQ {
                            if (p+2) < lexer.input.count && lexer.input[p+2] == "=" {
                                return make_token(lexer, .SHREQ, p, p+1); // the man himself
                            }
                        }
                        return make_token(lexer, .SHR, p, p+1);
                    }
                }
            }

            return single_char();
        case "\"";
            #if C_DQ_STRINGS {
                return parse_string(lexer, p, .DQSTRING);
            }
            single_char();
        case "'";
            #if C_SQ_STRINGS {
                return parse_string(lexer, p, .SQSTRING);
            }
            #if C_CHARS {
                start := p;
                end: int;
                escaped_char, success := parse_char(lexer, p+1, *p);
                #if IGNORE_UNSUPPORTED_CHAR_LITERALS {
                    if success {
                        lexer.int_number = escaped_char;
                        return make_token(lexer, .CHARLIT, start, p+1);
                    }
                } else {
                    if !success {
                        return make_token(lexer, .PARSE_ERROR, start, start);
                    } else if p >= lexer.input.count || lexer.input[p] != "'" {
                        return make_token(lexer, .PARSE_ERROR, start, p);
                    } else {
                        return make_token(lexer, .CHARLIT, start, p+1);
                    }
                }
            }
            return single_char();
        case "0";
            #if C_HEX_INTS || C99_HEX_FLOATS {
                if (p+1) < lexer.input.count && (lexer.input[p+1] == "x" || lexer.input[p+1] == "X") {
                    q := p + 2;

                    #if C99_HEX_FLOATS {

                        while q < lexer.input.count && 
                                 (         char_between(q, "0", "9") 
                                        || char_between(q, "a", "f") 
                                        || char_between(q, "A", "F")    ) {
                            q += 1;
                        }

                        if q < lexer.input.count {
                            check := lexer.input[q] == ".";

                            #if FLOAT_NO_DECIMAL {
                                check ||= lexer.input[q] == "p" || lexer.input[q] == "P";
                            }

                            if check {
                                lexer.real_number = parse_float(lexer, p, *q);
                                if p == q   return make_token(lexer, .PARSE_ERROR, p, q);
                                return parse_suffixes(lexer, .FLOATLIT, p, *q, FLOAT_SUFFIXES);
                            }
                        }
                    }

                    #if C_HEX_INTS {
                        // q should contain cursor at the end of the hex int
                        lexer.int_number = parse_int_of_base(lexer, p, *q, 16);
                        if q == p +2  {
                            return make_token(lexer, .PARSE_ERROR, p-2, p-1);
                        }

                        return parse_suffixes(lexer, .INTLIT, p, *q, HEX_SUFFIXES);
                    }
                }
            }
            #through;
        case "1"; #through;
        case "2"; #through;
        case "3"; #through;
        case "4"; #through;
        case "5"; #through;
        case "6"; #through;
        case "7"; #through;
        case "8"; #through;
        case "9";
            #if C_DECIMAL_FLOATS {
                q := p;

                while q < lexer.input.count && char_between(q, "0", "9") {
                    q += 1;
                }

                if q < lexer.input.count {
                    check := lexer.input[q] == ".";

                    #if FLOAT_NO_DECIMAL {
                        check ||= lexer.input[q] == "e" || lexer.input[q] == "E";
                    }

                    if check {
                        lexer.real_number = parse_float(lexer, p, *q);
                        return parse_suffixes(lexer, .FLOATLIT, p, *q, FLOAT_SUFFIXES);
                    }

                }
            }

            #if C_OCTAL_INTS {
                if lexer.input[p] == "0" {
                    q := p;
                    lexer.int_number = parse_int_of_base(lexer, p, *q, 8);
                    return parse_suffixes(lexer, .INTLIT, p, *q, OCTAL_SUFFIXES);
                }
            }

            #if C_DECIMAL_INTS { {
                q := p;
                lexer.int_number = parse_int_of_base(lexer, p, *q, 10);

                return parse_suffixes(lexer, .INTLIT, p, *q, OCTAL_SUFFIXES);
            } }

            return single_char();
   }
}

#import "Basic";
/*

I just translated Sean's code to The Language. Here's the original license.
Am I supposed to provide another license for my translation? I don't quite know.
Do whatever you want with this.

------------------------------------------------------------------------------
This software is available under 2 licenses -- choose whichever you prefer.
------------------------------------------------------------------------------
ALTERNATIVE A - MIT License
Copyright (c) 2017 Sean Barrett
Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
of the Software, and to permit persons to whom the Software is furnished to do
so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
------------------------------------------------------------------------------
ALTERNATIVE B - Public Domain (www.unlicense.org)
This is free and unencumbered software released into the public domain.
Anyone is free to copy, modify, publish, use, compile, sell, or distribute this
software, either in source code form or as a compiled binary, for any purpose,
commercial or non-commercial, and by any means.
In jurisdictions that recognize copyright laws, the author or authors of this
software dedicate any and all copyright interest in the software to the public
domain. We make this dedication for the benefit of the public at large and to
the detriment of our heirs and successors. We intend this dedication to be an
overt act of relinquishment in perpetuity of all present and future rights to
this software under copyright law.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
------------------------------------------------------------------------------
*/
