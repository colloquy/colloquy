#import <AppKit/NSApplication.h>

#include <libxml/globals.h>
#include <libxml/parser.h>
#include <libxslt/xslt.h>
#include <libexslt/exslt.h>

int main( int count, const char *arg[] ) {
	srandom( time( NULL ) & 0x7FFFFFFF );

	xmlInitParser();
	exsltRegisterAll();
	xmlSubstituteEntitiesDefault( 1 );
	xmlLoadExtDtdDefaultValue = 1;

	return NSApplicationMain( count, arg );
}
