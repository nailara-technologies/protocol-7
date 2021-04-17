
#include <stdio.h>
#include <ctype.h>
#include <stdlib.h>
#include <string.h>

// elf-checksum algorithm [ repaired for characters >= ascii 128 ] + added modes

unsigned int elf_sum( int elf_mode, int start_sum, char *str, int verbosity ) {

    if ( verbosity ) {
        if ( elf_mode == 4 ) { // regular elf hash algorithm
            fprintf( stderr, "\n:: input : '%s'\n:\n", str );
        } else {
            fprintf( stderr, "\n:: input : '%s' :: elf_mode -%d ::\n:\n",
                str, elf_mode );
        }
        if ( start_sum )
            fprintf( stderr, ": -c <start-checksum> : %09d\n:\n", start_sum );
    }
    unsigned int result = start_sum; // 0 if no continuation
    unsigned int carryover;
    // algorithm configuration
    unsigned int left  = elf_mode;   // 4 == elf hash [ base setting ]
    unsigned int right = 24;

    long pos_0  = (long) str;
    unsigned int round = 0;

    while ( *str ) {
        round = (long) str - pos_0;
        int character = (int) *str++;
        if ( character < 0 ) // characters >= ascii 128
            character += 256;

        result = ( result << left ) + character;

        if ( ( carryover = result & 0xF0000000 ) )
            result ^= carryover >> right;

        result &= ~carryover;

        if ( verbosity ) {
            if ( character >= 32 && character < 128 ) {
                fprintf( stderr, ":: round : %04d : '%c' : %09d\n",
                    round, character, result );
            } else { // display non-printable characters as ascii values
                fprintf( stderr, ":: round : %04d : %03d : %09d\n",
                    round, character, result );
            }
        }
    }

    if ( verbosity )
        fprintf( stderr, "\n" );

    return result;
}

char* join_str(char **str, const char *delimiters) {
    char *joined_str;
    int i = 1;
    joined_str = realloc(NULL, strlen(str[0])+1);
    strcpy(joined_str, str[0]);
    if (str[0] == NULL){
        return joined_str;
    }
    while (str[i] !=NULL){
        joined_str = (char*)realloc(joined_str, strlen(joined_str)
                        + strlen(str[i]) + strlen(delimiters) + 1);
        strcat(joined_str, delimiters);
        strcat(joined_str, str[i]);
        i++;
    }
    return joined_str;
}

int read_program_elf_mode ( char *program_name ){
    int program_elf_mode = 4; // base elf hash configuration : symlinks override
    int prog_name_len = strlen( program_name );
    int minus_pos = -1;
    for( int i = prog_name_len; i > prog_name_len - 4; i-- ){
        if ( minus_pos < 0 && program_name[i] == 45 )
            minus_pos = i;
    }
    if ( minus_pos == -1 || prog_name_len - minus_pos > 3 ) // not a mode [ 4 ]
        return program_elf_mode;
    program_elf_mode = 0;
    int i = 0;
    for( i = minus_pos + 1; i < prog_name_len; i++ ){
        int digit = program_name[i] - 48;
        if ( prog_name_len - minus_pos == 3 && prog_name_len - i == 2 ) {
            program_elf_mode += 10 * digit;
        } else {
            program_elf_mode += digit;
        }
    }
    if ( program_elf_mode == 0 ) {
        fprintf( stderr,
          "invalid program elf_mode : 0 [ falling back to 4 : elf-hash ]\n" );
        return 4;
    }
    return program_elf_mode;
}

long double nanl(const char *tagp);

long double strtold(const char *nptr, char **endptr);

int main( int argc, char * argv[] ) {

    char *program = argv[0]; // save for later [ implicit elf_mode ]
    int elf_mode = read_program_elf_mode( program );
    int verbosity = 0;
    int start_checksum = 0;

    // removing program name
    for( int i=0; i<argc; ++i )
        argv[i]  = argv[i+1];
    argv[--argc] = NULL;

    if ( argc > 0 && strcmp( argv[0], "-v" ) == 0 ) { // verbose mode
        verbosity = 1;
        for( int i=0; i<argc; ++i )
            argv[i]  = argv[i+1];
        argv[--argc] = NULL;
    }

    if ( argc == 0 ) {             // no argument <-- [000000000]

        printf( "%09u\n", elf_sum( elf_mode, 0, "", verbosity ) );
        return 0;

    } else if ( strcmp( argv[0], "-s" ) == 0 ) { // single word mode
        if ( argc == 1 ) {
            fprintf( stderr, "expected input [word] arguments after -s\n" );
            return 1;
        } else {
            printf(":\n");
            for( int arg = 1; arg < argc; arg++ ) {
                printf( ": %09d : %s\n",
                    elf_sum( elf_mode, 0, argv[arg], verbosity ), argv[arg] );
            }
            printf(":\n");
            return 0;
        }
    }
    /* ELF-CHKSUM CONTINUATION */
    else if ( argc > 0 && strcmp( argv[0], "-c" ) == 0 ) {  // start-sum given
        if ( argc == 1 ) {
            fprintf( stderr,
                ":\n: -c expects start hash value [continuation]\n:\n");
            return 2;
        }
        start_checksum = strtold( argv[1], 0 );

        if ( strcmp( argv[1], "000000000" ) != 0 &&
                strcmp( argv[1], "0" ) != 0 && start_checksum <= 0 ) {

            fprintf(stderr, ":\n: expected start checksum for -c\n:\n");
            return 2;

        } else if ( start_checksum > 999999999 ) {
            fprintf(stderr, ": -c argument must ne valid elf checksum\n:\n" );
            return 2;
        }

        if ( argc == 2 ) {  // empty string string case : return start_checksum
            printf( "%09d\n", start_checksum );
            return 0;
        }

        for( int i=0; i<argc; ++i ) {  // removing start checksum arguments
            if ( i >= 2 )
                argv[i-2]  = argv[i];
        }
        argc = argc-2;
        argv[argc] = NULL;
    }

    if ( argc == 1 ) {  // only one argument [ single word ]
        printf( "%09d\n", elf_sum( elf_mode, start_checksum, argv[0],
            verbosity ) );

    } else {  // multilple arguments [ join with spaces ]

        printf( "%09u\n", elf_sum( elf_mode, start_checksum, join_str(argv," "),
            verbosity ) );
    }

    return 0;
}
