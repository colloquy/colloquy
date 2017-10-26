#include <libxml/globals.h>
#include <libxml/parser.h>
#include <libxslt/xslt.h>
#include <libexslt/exslt.h>

int main( int count, const char *arg[] ) {
	srandom( (unsigned int)time( NULL ) );

	xmlInitParser();
	exsltRegisterAll();
	xmlSubstituteEntitiesDefault( 1 );
	xmlLoadExtDtdDefaultValue = 1;

	return NSApplicationMain( count, arg );
}
