#import <Foundation/Foundation.h>
#import "JVTunes.h"
#import "MVChatPluginManager.h"
#import "MVChatConnection.h"
#import "JVDirectChat.h"
#import "JVChatRoom.h"

@interface NSScriptObjectSpecifier (NSPrivate)
+ (id) _objectSpecifierFromDescriptor:(NSAppleEventDescriptor *) descriptor inCommandConstructionContext:(id) context;
- (NSAppleEventDescriptor *) _asDescriptor;
@end

@implementation JVTunes
- (id) initWithManager:(MVChatPluginManager *) manager {
	if( ( self = [super init] ) ) {
		_script = [[NSAppleScript alloc] initWithSource:[NSString stringWithContentsOfFile:[[NSBundle bundleForClass:[self class]] pathForResource:@"iTunes" ofType:@"applescript"]]];
		if( ! [_script compileAndReturnError:nil] ) return nil;
	}
	return self;
}

- (void) dealloc {
	[_script release];
	_script = nil;
	[super dealloc];
}

- (BOOL) processUserCommand:(NSString *) command withArguments:(NSAttributedString *) arguments toRoom:(JVChatRoom *) room {
	int pid = [[NSProcessInfo processInfo] processIdentifier];
	NSAppleEventDescriptor *targetAddress = [NSAppleEventDescriptor descriptorWithDescriptorType:typeKernelProcessID bytes:&pid length:sizeof( pid )];
	NSAppleEventDescriptor *event = [NSAppleEventDescriptor appleEventWithEventClass:'cplG' eventID:'pcCX' targetDescriptor:targetAddress returnID:kAutoGenerateReturnID transactionID:kAnyTransactionID];

	[event setParamDescriptor:[NSAppleEventDescriptor descriptorWithString:command] forKeyword:keyDirectObject];
	[event setDescriptor:[NSAppleEventDescriptor descriptorWithString:[arguments string]] forKeyword:'pcC1'];
	[event setDescriptor:[[room objectSpecifier] _asDescriptor] forKeyword:'pcC2'];

	NSAppleEventDescriptor *result = [_script executeAppleEvent:event error:NULL];
	return (BOOL)[result booleanValue];
}

- (BOOL) processUserCommand:(NSString *) command withArguments:(NSAttributedString *) arguments toChat:(JVDirectChat *) chat {
	int pid = [[NSProcessInfo processInfo] processIdentifier];
	NSAppleEventDescriptor *targetAddress = [NSAppleEventDescriptor descriptorWithDescriptorType:typeKernelProcessID bytes:&pid length:sizeof( pid )];
	NSAppleEventDescriptor *event = [NSAppleEventDescriptor appleEventWithEventClass:'cplG' eventID:'pcCX' targetDescriptor:targetAddress returnID:kAutoGenerateReturnID transactionID:kAnyTransactionID];

	[event setParamDescriptor:[NSAppleEventDescriptor descriptorWithString:command] forKeyword:keyDirectObject];
	[event setDescriptor:[NSAppleEventDescriptor descriptorWithString:[arguments string]] forKeyword:'pcC1'];
	[event setDescriptor:[[chat objectSpecifier] _asDescriptor] forKeyword:'pcC2'];

	NSAppleEventDescriptor *result = [_script executeAppleEvent:event error:NULL];
	return (BOOL)[result booleanValue];
}
@end
