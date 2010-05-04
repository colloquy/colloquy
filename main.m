#import <libxml/globals.h>
#import <libxml/parser.h>
#import <libxslt/xslt.h>
#import <libexslt/exslt.h>

int main( int count, const char *arg[] ) {
	srandom( time( NULL ) );

	xmlInitParser();
	exsltRegisterAll();
	xmlSubstituteEntitiesDefault( 1 );
	xmlLoadExtDtdDefaultValue = 1;

	return NSApplicationMain( count, arg );
}
