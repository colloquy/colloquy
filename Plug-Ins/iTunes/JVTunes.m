#import <Foundation/Foundation.h>
#import <Carbon/Carbon.h>
#import "JVTunes.h"
#import "MVChatPluginManager.h"
#import "MVChatPluginManagerAdditions.h"
#import "MVChatConnection.h"
#import "JVChatController.h"
#import "JVDirectChat.h"
#import "JVChatRoom.h"

@implementation JVTunes
- (id) initWithManager:(MVChatPluginManager *) manager {
	self = [super init];
	_script = [[NSString stringWithContentsOfFile:[[NSBundle bundleForClass:[self class]] pathForResource:@"iTunes" ofType:@"applescript"]] retain];
	return self;
}

- (void) dealloc {
	[_script release];
	_script = nil;
	[super dealloc];
}

- (BOOL) processUserCommand:(NSString *) command withArguments:(NSAttributedString *) arguments toRoom:(JVChatRoom *) room {
	if( [command isEqualToString:@"itunes"] ) {
		NSAttributedString *status = [[[NSAttributedString alloc] initWithString:[[self class] executeAppleScriptString:_script]] autorelease];
		[[room connection] sendMessageToChatRoom:[room target] attributedMessage:status withEncoding:[room encoding] asAction:YES];
		[room echoSentMessageToDisplay:status asAction:YES];
		return YES;
	}
	return NO;
}

- (BOOL) processUserCommand:(NSString *) command withArguments:(NSAttributedString *) arguments toChat:(JVDirectChat *) chat {
	if( [command isEqualToString:@"itunes"] ) {
		NSAttributedString *status = [[[NSAttributedString alloc] initWithString:[[self class] executeAppleScriptString:_script]] autorelease];
		[[chat connection] sendMessageToUser:[chat target] attributedMessage:status withEncoding:[chat encoding] asAction:YES];
		[chat echoSentMessageToDisplay:status asAction:YES];
		return YES;
	}
	return NO;
}

+ (NSString *) executeAppleScriptString:(NSString *) string {
	OSAID theResultID = 0;
	ComponentInstance component = OpenDefaultComponent( kOSAComponentType, kAppleScriptSubtype );
	AEDesc theResultDesc = { typeNull, NULL },
	theScriptDesc = { typeNull, NULL };
	id theResultObject = nil;

	if( ( AECreateDesc( typeChar, [string cString], [string cStringLength], &theScriptDesc) ==  noErr ) && ( OSACompileExecute( component, &theScriptDesc, kOSANullScript, kOSAModeNull, &theResultID ) == noErr ) ) {
		if( OSACoerceToDesc( component, theResultID, 'utxt', kOSAModeNull, &theResultDesc ) == noErr ) {
			if( theResultDesc.descriptorType != typeNull ) {
				NSMutableData *theTextData = [NSMutableData dataWithLength:(unsigned int) AEGetDescDataSize( &theResultDesc )];
				if( AEGetDescData( &theResultDesc, [theTextData mutableBytes], [theTextData length] ) != noErr ) theTextData = nil;
				theResultObject = ( ! theTextData ? nil : [[[NSString alloc] initWithData:theTextData encoding:NSUnicodeStringEncoding] autorelease] );
				AEDisposeDesc( &theResultDesc );
			}
		}
		AEDisposeDesc( &theScriptDesc );
		if( theResultID != kOSANullScript )
			OSADispose( component, theResultID );
	}

	return theResultObject;
}
@end
