#import "MVChatPluginManager.h"
#import "MVChatScriptPlugin.h"

@interface NSScriptObjectSpecifier (NSScriptObjectSpecifierPrivate) // Private Foundation Methods
+ (id) _objectSpecifierFromDescriptor:(NSAppleEventDescriptor *) descriptor inCommandConstructionContext:(id) context;
- (NSAppleEventDescriptor *) _asDescriptor;
@end

#pragma mark -

@interface NSAEDescriptorTranslator : NSObject // Private Foundation Class
+ (id) sharedAEDescriptorTranslator;
- (NSAppleEventDescriptor *) descriptorByTranslatingObject:(id) object ofType:(id) type inSuite:(id) suite;
- (id) objectByTranslatingDescriptor:(NSAppleEventDescriptor *) descriptor toType:(id) type inSuite:(id) suite;
- (void) registerTranslator:(id) translator selector:(SEL) selector toTranslateFromClass:(Class) class;
- (void) registerTranslator:(id) translator selector:(SEL) selector toTranslateFromDescriptorType:(unsigned int) type;
@end

#pragma mark -

@interface NSString (NSStringFourCharCode)
- (unsigned long) fourCharCode;
@end

#pragma mark -

@implementation NSString (NSStringFourCharCode)
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
@end

#pragma mark -

@interface NSAppleScript (NSAppleScriptPrivate)
+ (struct ComponentInstanceRecord *) _defaultScriptingComponent;
@end

#pragma mark -

@implementation NSAppleScript (NSAppleScriptAdditions)
- (NSNumber *) scriptIdentifier {
	return [NSNumber numberWithUnsignedLong:_compiledScriptID];
}

/* - (BOOL) saveToFile:(NSString *) path {
	FSRef ref;
	FSPathMakeRef( [path UTF8String], &ref, NULL );
	OSAError result = OSAStoreFile( [NSAppleScript _defaultScriptingComponent], _compiledScriptID, typeOSAGenericStorage, kOSAModeNull, &ref );
	return ( result == noErr );
}

- (unsigned long) numberOfProperties {
	AEDescList properties;
	OSAError result = OSAGetPropertyNames( [NSAppleScript _defaultScriptingComponent], kOSAModeNull, _compiledScriptID, &properties );
	if( result != noErr ) return 0;

	long number = -1;
	AECountItems( &properties, &number );
	if( number == -1 ) return 0;

	return number;
} */
@end

#pragma mark -

@implementation MVChatScriptPlugin
- (id) initWithManager:(MVChatPluginManager *) manager {
	if( ( self = [self init] ) ) {
		_doseNotRespond = [[NSMutableSet set] retain];
		_script = nil;
		_path = nil;
		_idleTimer = nil;
	}
	return self;
}

- (id) initWithScript:(NSAppleScript *) script atPath:(NSString *) path withManager:(MVChatPluginManager *) manager {
	if( ( self = [self initWithManager:manager] ) ) {
		_script = [script retain];
		_path = [path copyWithZone:[self zone]];
		[self performSelector:@selector( idle: ) withObject:nil afterDelay:1.];
	}
	return self;
}

- (void) release {
	if( ( [self retainCount] - 1 ) == 1 )
		[_idleTimer invalidate];
	[super release];
}

- (void) dealloc {
	[_script release];
	[_path release];
	[_doseNotRespond release];
	[_idleTimer release];

	_script = nil;
	_path = nil;
	_doseNotRespond = nil;
	_idleTimer = nil;

	[super dealloc];
}

#pragma mark -

- (NSAppleScript *) script {
	return _script;
}

- (NSString *) scriptFilePath {
	return _path;
}

- (id) callScriptHandler:(unsigned long) handler withArguments:(NSDictionary *) arguments forSelector:(SEL) selector {
	if( ! _script ) return nil;

	int pid = [[NSProcessInfo processInfo] processIdentifier];
	NSAppleEventDescriptor *targetAddress = [NSAppleEventDescriptor descriptorWithDescriptorType:typeKernelProcessID bytes:&pid length:sizeof( pid )];
	NSAppleEventDescriptor *event = [NSAppleEventDescriptor appleEventWithEventClass:'cplG' eventID:handler targetDescriptor:targetAddress returnID:kAutoGenerateReturnID transactionID:kAnyTransactionID];

	NSEnumerator *enumerator = [arguments objectEnumerator];
	NSEnumerator *kenumerator = [arguments keyEnumerator];
	NSAppleEventDescriptor *descriptor = nil;
	NSString *key = nil;
	id value = nil;

	while( ( key = [kenumerator nextObject] ) && ( value = [enumerator nextObject] ) ) {
		NSScriptObjectSpecifier *specifier = nil;
		if( [value isKindOfClass:[NSScriptObjectSpecifier class]] ) specifier = value;
		else specifier = [value objectSpecifier];

		if( specifier ) descriptor = [[value objectSpecifier] _asDescriptor]; // custom object, use it's object specitier
		else descriptor = [[NSAEDescriptorTranslator sharedAEDescriptorTranslator] descriptorByTranslatingObject:value ofType:nil inSuite:nil];

		if( ! descriptor ) descriptor = [NSAppleEventDescriptor nullDescriptor];
		[event setDescriptor:descriptor forKeyword:[key fourCharCode]];
	}

	NSDictionary *error = nil;
	NSAppleEventDescriptor *result = [_script executeAppleEvent:event error:&error];
	if( error && ! result ) { // an error
		int code = [[error objectForKey:NSAppleScriptErrorNumber] intValue];
		if( code == errAEEventNotHandled || code == errAEHandlerNotFound )
			[self doesNotRespondToSelector:selector]; // disable for future calls
		return [NSError errorWithDomain:NSOSStatusErrorDomain code:code userInfo:error];
	}

	if( [result descriptorType] == 'obj ' ) { // an object specifier result, evaluate it to the object
		NSScriptObjectSpecifier *specifier = [NSScriptObjectSpecifier _objectSpecifierFromDescriptor:result inCommandConstructionContext:nil];
		return [specifier objectsByEvaluatingSpecifier];
	}

	// a static result evaluate it to the proper object
	return [[NSAEDescriptorTranslator sharedAEDescriptorTranslator] objectByTranslatingDescriptor:result toType:nil inSuite:nil];
}

#pragma mark -

- (void) idle:(id) sender {
	[_idleTimer invalidate];
	[_idleTimer autorelease];

	NSNumber *newTime = [self callScriptHandler:'iDlX' withArguments:nil forSelector:_cmd];
	if( [newTime isMemberOfClass:[NSError class]] ) return;
	if( ! [newTime isKindOfClass:[NSNumber class]] ) _idleTimer = [[NSTimer scheduledTimerWithTimeInterval:5. target:self selector:_cmd userInfo:nil repeats:NO] retain];
	else _idleTimer = [[NSTimer scheduledTimerWithTimeInterval:[newTime doubleValue] target:self selector:_cmd userInfo:nil repeats:NO] retain];
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