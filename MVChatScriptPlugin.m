#import <Foundation/Foundation.h>
#import "MVChatPluginManager.h"
#import "MVChatScriptPlugin.h"
#import "NSNumberAdditions.h"

static unsigned long MVChatScriptPluginClass = 'cplG';

@interface NSScriptObjectSpecifier (NSPrivate)
+ (id) _objectSpecifierFromDescriptor:(NSAppleEventDescriptor *) descriptor inCommandConstructionContext:(id) context;
- (NSAppleEventDescriptor *) _asDescriptor;
@end

#pragma mark -

@implementation NSAppleScript (NSAppleScriptIdentifier)
- (NSNumber *) scriptIdentifier {
	return [NSNumber numberWithUnsignedLong:_compiledScriptID];
}
@end

#pragma mark -

@interface NSString (NSAppleEventDescriptor)
- (unsigned long) fourCharCode;
@end

#pragma mark -

@implementation NSString (NSAppleEventDescriptor)
- (unsigned long) fourCharCode {
	unsigned long ret = 0, length = [self length];

	if( length >= 1 ) ret |= ( [self characterAtIndex:0] & 0x00ff ) << 24;
	else ret |= ' ' << 24;
	if( length >= 2 ) ret |= ( [self characterAtIndex:1] & 0x00ff ) << 16;
	else ret |= ' ' << 16;
	if( length >= 3 ) ret |= ( [self characterAtIndex:2] & 0x00ff ) << 8;
	else ret |= ' ' << 8;
	if( length >= 4 ) ret |= ( [self characterAtIndex:3] & 0x00ff );
	else ret |= ' ';

	return ret;
}

- (NSAppleEventDescriptor *) appleEventDescriptor {
	return [NSAppleEventDescriptor descriptorWithString:self];
}
@end

#pragma mark -

@implementation NSValue (NSAppleEventDescriptor)
- (NSAppleEventDescriptor *) appleEventDescriptor {
	void *data[32];
	const char *valueType = [self objCType];
	unsigned long valueKeywordType = 0;
	unsigned long valueSize = 0;
	if( strcmp( valueType, @encode( char ) ) == 0) {
		valueSize = sizeof( char );
		valueKeywordType = typeChar;
	} else if( strcmp( valueType, @encode( BOOL ) ) == 0 ) {
		valueSize = sizeof( BOOL );
		valueKeywordType = typeBoolean;
	} else if( strcmp( valueType, @encode( short ) ) == 0 ) {
		valueSize = sizeof( short );
		valueKeywordType = typeShortInteger;
	} else if( strcmp( valueType, @encode( int ) ) == 0 ) {
		valueSize = sizeof( int );
		switch( valueSize ) {
			case 2: valueKeywordType = typeShortInteger; break;
			case 4: valueKeywordType = typeLongInteger; break;
		}
	} else if( strcmp( valueType, @encode( long ) ) == 0 ) {
		valueSize = sizeof( long );
		valueKeywordType = typeLongInteger;
	} else if( strcmp( valueType, @encode( unsigned long ) ) == 0 ) {
		valueSize = sizeof( unsigned long );
		valueKeywordType = typeMagnitude;
	} else if( strcmp( valueType, @encode( float ) ) == 0 ) {
		valueSize = sizeof( float );
		valueKeywordType = typeShortFloat;
	} else if( strcmp( valueType, @encode( double ) ) == 0 ) {
		valueSize = sizeof( double );
		valueKeywordType = typeLongFloat;
	}

	[self getValue:&data];
	return [NSAppleEventDescriptor descriptorWithDescriptorType:valueKeywordType bytes:data length:valueSize];
}
@end

#pragma mark -

@implementation NSArray (NSAppleEventDescriptor)
- (NSAppleEventDescriptor *) appleEventDescriptor {
	NSAppleEventDescriptor *list = [NSAppleEventDescriptor listDescriptor];
	unsigned int count = 1;
	NSEnumerator *enumerator = [self objectEnumerator];
	id value = nil;

	while( ( value = [enumerator nextObject] ) ) {
		if( [value isKindOfClass:[NSValue class]] || [value isKindOfClass:[NSString class]] || [value isKindOfClass:[NSArray class]] || [value isKindOfClass:[NSDictionary class]] ) {
			[list insertDescriptor:[value appleEventDescriptor] atIndex:count];
			count++;
		} else if( [value isKindOfClass:[NSNull class]] ) {
			[list insertDescriptor:[NSAppleEventDescriptor nullDescriptor] atIndex:count];
			count++;
		} else {
			NSAppleEventDescriptor *descriptor = [[value objectSpecifier] _asDescriptor];
			if( descriptor ) {
				[list insertDescriptor:descriptor atIndex:count];
				count++;
			}
		}
	}

	return list;
}
@end

#pragma mark -

@implementation NSDictionary (NSAppleEventDescriptor)
- (NSAppleEventDescriptor *) appleEventDescriptor {
	NSAppleEventDescriptor *record = [NSAppleEventDescriptor recordDescriptor];
	NSAppleEventDescriptor *descriptor = nil;
	NSEnumerator *enumerator = [self objectEnumerator];
	NSEnumerator *kenumerator = [self keyEnumerator];
	NSString *key = nil;
	id value = nil;

	while( ( key = [kenumerator nextObject] ) && ( value = [enumerator nextObject] ) ) {
		if( [value isKindOfClass:[NSValue class]] || [value isKindOfClass:[NSString class]] || [value isKindOfClass:[NSArray class]] || [value isKindOfClass:[NSDictionary class]] ) {
			descriptor = [value appleEventDescriptor];
		} else if( [value isKindOfClass:[NSNull class]] ) {
			descriptor = [NSAppleEventDescriptor nullDescriptor];
		} else descriptor = [[value objectSpecifier] _asDescriptor];

		if( descriptor ) [record setDescriptor:descriptor forKeyword:[key fourCharCode]];
	}

	return record;
}
@end

#pragma mark -

@implementation MVChatScriptPlugin
- (id) initWithManager:(MVChatPluginManager *) manager {
	if( ( self = [self init] ) ) {
		_doseNotRespond = [[NSMutableSet set] retain];
		_script = nil;
	}
	return self;
}

- (id) initWithScript:(NSAppleScript *) script andManager:(MVChatPluginManager *) manager {
	if( ( self = [self initWithManager:manager] ) )
		_script = [script retain];
	return self;
}

- (void) dealloc {
	[_script release];
	[_doseNotRespond release];

	_script = nil;
	_doseNotRespond = nil;

	[super dealloc];
}

#pragma mark -

- (NSAppleScript *) script {
	return _script;
}

- (id) callScriptHandler:(unsigned long) handler withArguments:(NSDictionary *) arguments {
	int pid = [[NSProcessInfo processInfo] processIdentifier];
	NSAppleEventDescriptor *targetAddress = [NSAppleEventDescriptor descriptorWithDescriptorType:typeKernelProcessID bytes:&pid length:sizeof( pid )];
	NSAppleEventDescriptor *event = [NSAppleEventDescriptor appleEventWithEventClass:MVChatScriptPluginClass eventID:handler targetDescriptor:targetAddress returnID:kAutoGenerateReturnID transactionID:kAnyTransactionID];
	NSEnumerator *enumerator = [arguments objectEnumerator];
	NSEnumerator *kenumerator = [arguments keyEnumerator];
	NSAppleEventDescriptor *descriptor = nil;
	NSString *key = nil;
	id value = nil;

	if( ! _script ) return nil;

	while( ( key = [kenumerator nextObject] ) && ( value = [enumerator nextObject] ) ) {
		if( [value isKindOfClass:[NSValue class]] || [value isKindOfClass:[NSString class]] || [value isKindOfClass:[NSArray class]] || [value isKindOfClass:[NSDictionary class]] ) {
			descriptor = [value appleEventDescriptor];
		} else if( [value isKindOfClass:[NSNull class]] ) {
			descriptor = [NSAppleEventDescriptor nullDescriptor];
		} else descriptor = [[value objectSpecifier] _asDescriptor];

		if( descriptor ) [event setDescriptor:descriptor forKeyword:[key fourCharCode]];
	}

	NSDictionary *errors = nil;
	NSAppleEventDescriptor *result = [_script executeAppleEvent:event error:&errors];

	if( [[errors objectForKey:NSAppleScriptErrorNumber] isEqual:[NSNumber numberWithInt:-1708]] )
		return nil;

	switch( [result descriptorType] ) {
		case typeChar:
		case typeUnicodeText: return [result stringValue];
		case typeBoolean: return [NSNumber numberWithBool:(BOOL)[result booleanValue]];
		case typeTrue: return [NSNumber numberWithBool:YES];
		case typeFalse: return [NSNumber numberWithBool:NO];
		case typeShortInteger: return [NSNumber numberWithInt:(int)[result int32Value]];
		case typeLongInteger: return [NSNumber numberWithLong:(long)[result int32Value]];
		case typeMagnitude: return [NSNumber numberWithUnsignedLong:(unsigned long)[result int32Value]];
		case typeShortFloat: return [NSNumber numberWithBytes:[[result data] bytes] objCType:@encode( float )];
		case typeLongFloat: return [NSNumber numberWithBytes:[[result data] bytes] objCType:@encode( double )];
	}

	return [NSNull null];
}

#pragma mark -

- (BOOL) respondsToSelector:(SEL) selector {
	if( ! _script || [_doseNotRespond containsObject:NSStringFromSelector( selector )] ) return NO;
	return [super respondsToSelector:selector];
}

- (void) doesNotRespondToSelector:(SEL) selector {
	[_doseNotRespond addObject:NSStringFromSelector( selector )];
}
@end
