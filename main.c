/*
** SCCS ID: @(#)main.c	2.3        11/28/22
**
** File:    main.c
**
** Author:  K. Reek
**
** Contributor: Warren R. Carithers
**
** Description: Dummy main program
*/
#include "cio.h"
#include "support.h"

int main( void ) {

    /* initialize our interrupt vector */
    __init_interrupts();

    /* initialize the console i/o module */
    __cio_init( 0 );

    /* say hello */
    __cio_puts( "Hello, world!\n" );

    return( 0 );
}
