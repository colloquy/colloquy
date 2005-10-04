#import <libxml/globals.h>
#import <libxml/parser.h>
#import <libxslt/xslt.h>

int main( int count, const char *arg[] ) {
	srandom( time( NULL ) );

	xmlInitParser();
	xmlSubstituteEntitiesDefault( 1 );
	xmlLoadExtDtdDefaultValue = 1;

	int ret = NSApplicationMain( count, arg );

	xsltCleanupGlobals();
	xmlCleanupParser();
	return ret;
}