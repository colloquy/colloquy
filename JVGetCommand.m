#import "JVGetCommand.h"

@implementation JVGetCommand
- (id) performDefaultImplementation {
	id ret = [super performDefaultImplementation];

	NSAppleEventDescriptor *rtypDesc = [[self appleEvent] paramDescriptorForKeyword:'rtyp'];
	if( rtypDesc ) { // the get command is requesting a coercion (requested type) 
		NSScriptClassDescription *classDesc = [[NSScriptSuiteRegistry sharedScriptSuiteRegistry] classDescriptionWithAppleEventCode:[rtypDesc typeCodeValue]];
		Class class = NULL;

		if( classDesc ) { // found the requested type in the script suites.
			class = NSClassFromString( [classDesc className] );
		} else { // catch some common types that don't have entries in the script suites.
			switch( [rtypDesc typeCodeValue] ) {
				case 'TEXT': class = [NSString class]; break;
				case 'STXT': class = [NSTextStorage class]; break;
				case 'nmbr': class = [NSNumber class]; break;
				case 'reco': class = [NSDictionary class]; break;
				case 'list': class = [NSArray class]; break;
				case 'data': class = [NSData class]; break;
			}
		}

		if( class && class != [ret class] ) {
			id newRet = [[NSScriptCoercionHandler sharedCoercionHandler] coerceValue:ret toClass:class];
			if( newRet ) return newRet;
		}

		// account for basic types that wont have a coercion handler but have common methods we can use.
		if( class == [NSString class] && [ret respondsToSelector:@selector( stringValue )] )
			return [ret stringValue];
		else if( class == [NSString class] )
			return [ret description];
		else if( [rtypDesc typeCodeValue] == 'long' && [ret respondsToSelector:@selector( intValue )] )
			return [NSNumber numberWithLong:[ret intValue]];
		else if( [rtypDesc typeCodeValue] == 'sing' && [ret respondsToSelector:@selector( floatValue )] )
			return [NSNumber numberWithFloat:[ret floatValue]];
		else if( ( [rtypDesc typeCodeValue] == 'doub' || [rtypDesc typeCodeValue] == 'nmbr' ) && [ret respondsToSelector:@selector( doubleValue )] )
			return [NSNumber numberWithDouble:[ret doubleValue]];
	}

	return ret;
}
@end
