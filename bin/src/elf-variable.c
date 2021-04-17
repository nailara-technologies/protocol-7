
#include <stdlib.h>
#include <stdio.h>
#include <ctype.h>
#include <string.h>

unsigned int elf_sum( int mode, int start_sum, char *sval, int verbosity ) {

    // verbosity = 1; // <-- debug

    if ( verbosity ) {
        if ( mode == 4 ) { // regular elf hash algorithm
            fprintf( stderr, "\n:: start : '%s'\n:\n", sval );
        } else {
            fprintf( stderr, "\n:: start : '%s' :: MODE -%d ::\n:\n",
                sval, mode );
        }
        if ( start_sum )
            fprintf( stderr, ": -c <start-checksum> : %09d\n:\n", start_sum );
    }
    unsigned int h = start_sum; // 0 if no continuation
    unsigned int g;
    // algorithm configuration
    unsigned int left  = mode;   // 4 == elf hash [ base setting ]
    unsigned int right = 24;

    long pos_0  = (long) sval;
    unsigned int round = 0;

    while ( *sval ) {
        round = (long) sval - pos_0;
        char character = (char) *sval++;

        h = ( h << left ) + character;

        if ( ( g = h & 0xF0000000 ) )
            h ^= g >> right;

        h &= ~g;

        if ( verbosity )
            fprintf( stderr,
                ":: round : %04d : '%c' : %09d\n", round, character, h );
    }

    if ( verbosity )
        fprintf( stderr, "\n" );

    return h;
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

int read_program_mode ( char *program_name ){
    int program_mode = 4; // base elf hash configuration
    int prog_name_len = strlen( program_name );
    int minus_pos = -1;
    for( int i = prog_name_len; i > prog_name_len - 4; i-- ){
        if ( minus_pos < 0 && program_name[i] == 45 )
            minus_pos = i;
    }
    if ( minus_pos == -1 || prog_name_len - minus_pos > 3 ) // not a mode [ 4 ]
        return program_mode;
    program_mode = 0;
    int i = 0;
    for( i = minus_pos + 1; i < prog_name_len; i++ ){
        int digit = program_name[i] - 48;
        if ( prog_name_len - minus_pos == 3 && prog_name_len - i == 2 ) {
            program_mode += 10 * digit;
        } else {
            program_mode += digit;
        }
    }
    if ( program_mode == 0 ) {
        fprintf( stderr,
          "invalid program mode : 0 [ falling back to 4 : elf-hash ]\n" );
        return 4;
    }
    return program_mode;
}

long double nanl(const char *tagp);

long double strtold(const char *nptr, char **endptr);

int main( int argc, char * argv[] ) {

    char *program = argv[0]; // save for later [ implicit mode ]
    int mode = read_program_mode( program );

    // removing program name
    for( int i=0; i<argc; ++i )
        argv[i]  = argv[i+1];
    --argc;

    int verbosity = 0;

    // use getopt [ -v -c -s ] // verbose, continue, single

    if ( argc > 0 && strcmp( argv[0], "-v" ) == 0 ) { // verbose mode
        verbosity = 1;
        for( int i=0; i<argc; ++i )
            argv[i]  = argv[i+1];
        --argc;
    }


    if ( argc == 0 ) {                            // no argument <-- [000000000]

        printf( "%09u\n", elf_sum( mode, 0, "", verbosity ) );

    /* ELF-CHKSUM CONTINUATION */
    } else if ( argc > 0 && strcmp( argv[0], "-c" ) == 0 ) { // start-sum given
        if ( argc == 1 ) {
            fprintf( stderr,
                ":\n: -c expects start hash value [continuation]\n:\n");
            return 2;
        }

        int seed_val = strtold( argv[1], 0 );

        if ( strcmp( argv[1], "000000000" ) != 0 &&
                strcmp( argv[1], "0" ) != 0 && seed_val <= 0 ) {

            fprintf(stderr, ":\n: expected start checksum for -c\n:\n");
            return 2;

        } else if ( seed_val > 999999999 ) {
            fprintf(stderr, ": -c argument must ne valid elf checksum\n:\n" );
            return 2;
        }

        if ( argc == 2 ) { // empty input string case

            printf( "%09d\n", seed_val );
            return 0;

        }

        for( int i=0; i<argc; ++i ) {
            if ( i >= 2 )
                argv[i-2]  = argv[i];
        }
        argc-=2;
        argv[argc] = NULL;

        printf( "%09u\n", elf_sum( mode, seed_val, join_str( argv, " " ),
            verbosity ) );

        return 0;

    } else if ( argc == 1 ) {  // only one argument [ single word ]

        printf( "%09d\n", elf_sum( mode, 0, argv[0], verbosity ) );

    } else if ( argc > 1 && strcmp( argv[0], "-s" ) == 0 ) { // single word mode
        printf(":\n");

        for( int arg = 1; arg < argc; arg++ ) {
            printf( ": %09d : %s\n",
                elf_sum( mode, 0, argv[arg], verbosity ), argv[arg] );
        }
        printf(":\n");

    } else {  // arguments joined [' '] // clean-up ? [ start-checksum : 0 ]

        printf("%09u\n", elf_sum( mode, 0, join_str( argv, " " ), verbosity ));

    }
    return 0;
}
