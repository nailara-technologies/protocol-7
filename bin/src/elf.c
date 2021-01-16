
// .. has [undocumented] '-v' verbose flag to list arguments seperately .., >;]

#include <stdio.h>
#include <string.h>
#include <stdlib.h>

unsigned long elf(char *sval) { // <-- 'ELFHash' algorithm from Digest::Elf[.xs]
    unsigned long h = 0, g;

    while ( *sval ) {

        h = ( h << 4 ) + *sval++;

        if ( g = h & 0xF0000000 )
            h ^= g >> 24;

        h &= ~g;
    }
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

int main( int argc, char * argv[] ) {
    for( int i=0; i<argc; ++i )
        argv[i]  = argv[i+1];
    --argc; // <-- program name removed

    if ( argc == 0 ) {                            // no argument <-- [000000000]
        printf( "%09u\n", elf( "" ) );

    } else if ( argc == 1 ) {       // only one argument [ hashing single word ]
        printf( "%09u\n", elf( argv[0] ) );

    } else if ( argc > 1 && strcmp( argv[0], "-v" ) == 0 ) { // seperate words.
        printf(":\n");
        for( int arg = 1; arg < argc; arg++ ) {
            printf( ": %13s : [ %09u ]\n", argv[arg], elf( argv[arg] ) );
        }
        printf(":\n");
    } else {                                   // hashing arguments joined [' ']
        printf( "%09u\n", elf( join_str( argv, " " ) ) );
    }
    return 0;
}
