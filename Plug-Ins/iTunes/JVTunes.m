#import "JVTunes.h"
#import "MVChatConnection.h"
#import "JVChatController.h"
#import "JVDirectChat.h"
#import "JVChatRoom.h"

@implementation JVTunes
- (id) initWithBundle:(NSBundle *) bundle {
	self = [super init];
	_script = [[NSString stringWithContentsOfFile:[bundle pathForResource:@"iTunes" ofType:@"applescript"]] retain];
	return self;
}

- (void) dealloc {
	[_script autorelease];
	_script = nil;
	[super dealloc];
}

- (BOOL) processUserCommand:(NSString *) command withArguments:(NSAttributedString *) arguments toRoom:(NSString *) room forConnection:(MVChatConnection *) connection {
	if( [command isEqualToString:@"itunes"] ) {
		JVChatController *chatController = (JVChatController *)[NSClassFromString( @"JVChatController" ) defaultManager];
		JVChatRoom *rm = [chatController chatViewControllerForRoom:room withConnection:connection ifExists:YES];
		NSAttributedString *status = [[[NSAttributedString alloc] initWithString:[[self class] executeAppleScriptString:_script]] autorelease];
		[connection sendMessageToChatRoom:room attributedMessage:status withEncoding:[rm encoding] asAction:YES];
		[rm echoSentMessageToDisplay:status asAction:YES];
		return YES;
	}
	return NO;
}

- (BOOL) processUserCommand:(NSString *) command withArguments:(NSAttributedString *) arguments toUser:(NSString *) user forConnection:(MVChatConnection *) connection {
	if( [command isEqualToString:@"itunes"] ) {
		JVChatController *chatController = (JVChatController *)[NSClassFromString( @"JVChatController" ) defaultManager];
		JVChatRoom *dc = [chatController chatViewControllerForUser:user withConnection:connection ifExists:YES];
		NSAttributedString *status = [[[NSAttributedString alloc] initWithString:[[self class] executeAppleScriptString:_script]] autorelease];
		[connection sendMessageToUser:user attributedMessage:status withEncoding:[dc encoding] asAction:YES];
		[dc echoSentMessageToDisplay:status asAction:YES];
		return YES;
	}
	return NO;
}

+ (NSString *) executeAppleScriptString:(NSString *) aString {
	OSAID theResultID = 0;
	ComponentInstance component = OpenDefaultComponent( kOSAComponentType, kAppleScriptSubtype );
	AEDesc theResultDesc = { typeNull, NULL },
	theScriptDesc = { typeNull, NULL };
	id theResultObject = nil;

	if( ( AECreateDesc( typeChar, [aString cString], [aString cStringLength], &theScriptDesc) ==  noErr ) && ( OSACompileExecute( component, &theScriptDesc, kOSANullScript, kOSAModeNull, &theResultID ) == noErr ) ) {
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
