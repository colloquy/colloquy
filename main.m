#import <Cocoa/Cocoa.h>
#import <libxml/globals.h>
#import <libxml/parser.h>
#import <libxslt/xslt.h>

int main( int count, const char *arg[] ) {
	int ret = 0;
	srandom( time( NULL ) );
	xmlInitParser();
	xmlSubstituteEntitiesDefault( 1 );
	xmlLoadExtDtdDefaultValue = 1;
	ret = NSApplicationMain( count, arg );
	xsltCleanupGlobals();
	xmlCleanupParser();
	return ret;
}
