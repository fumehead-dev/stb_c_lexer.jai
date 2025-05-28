#import "Basic";
#import "File";

CLex :: #import,file "./stb_c_lexer.jai";


print_error :: (format: string, args: .. Any) {
    print(format, ..args);
}


main :: () {
    args := get_command_line_arguments();
    if args.count < 2 {
        print_error("No path supplied.\n");
        return;
    }

    path := args[1];
    filedata, success := read_entire_file(path);

    using CLex;

    if success {
        lexer := Lexer.{input = filedata};

        while get_token(*lexer) {
            if lexer.token >= Token_Type.EOF.(u64) && lexer.token <= Token_Type.FIRST_UNUSED_TOKEN.(u64) {
                token := lexer.token.(Token_Type);
                print(" % \t\t\t", token);
                if token == {
                    case .FLOATLIT; print("%1%2", lexer.real_number, lexer.token_string);
                    case .INTLIT;   print("%", lexer.int_number);
                    case .ID;       print("%", lexer.token_string);
                    case .CHARLIT;  
                        if lexer.int_number.(u8) == " " {
                            print("<empty string>");
                        } else {
                            print_character(lexer.int_number.(u8));
                        }
                }
            } else {
                print(" RAW \t\t\t");
                print_character(lexer.token.(u8));
            }
            print ("\n");
        }

        print("Finished printing file!\n");

    } else {
        print_error("Failed reading file %", path);
    }
}

