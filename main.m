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

	NSAutoreleasePool *pool = [[NSAutoreleasePool allocWithZone:nil] init];

	NSString *newPreferencesPath = [@"~/Library/Preferences/info.colloquy.plist" stringByExpandingTildeInPath];
	if( ! [[NSFileManager defaultManager] fileExistsAtPath:newPreferencesPath] ) {
		NSString *oldPreferencesPath = [@"~/Library/Preferences/cc.javelin.colloquy.plist" stringByExpandingTildeInPath];
		[[NSFileManager defaultManager] movePath:oldPreferencesPath toPath:newPreferencesPath handler:nil];
	}

	[pool release];

	return NSApplicationMain( count, arg );
}
