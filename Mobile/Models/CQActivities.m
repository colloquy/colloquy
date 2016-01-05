#import "CQActivities.h"

@interface UIResponder (Additions)
@end

@implementation UIResponder (Additions)
static id __weak cq_currentFirstResponder;

+ (UIResponder *) cq_currentFirstResponder {
	cq_currentFirstResponder = nil;

	[[UIApplication sharedApplication] sendAction:@selector(cq_findCurrentFirstResponder:) to:nil from:nil forEvent:nil];

	UIResponder *firstResponder = cq_currentFirstResponder;
	cq_currentFirstResponder = nil;
	return firstResponder;
}

- (void) cq_findCurrentFirstResponder:(id) sender {
	cq_currentFirstResponder = self;
}
@end

#pragma mark -

@implementation CQActivitiesProvider
+ (NSArray <CQActivity *> *) activities {
	return @[ [[CQRecentMessagesActivity alloc] init], [[CQSaveChatLogToPDFActivity alloc] init],
			  [[CQChatRoomTopicActivity alloc] init], [[CQChatRoomBansActivity alloc] init], [[CQChatRoomModesActivity alloc] init] ];
}
@end

#pragma mark -

@implementation CQActivity
- (NSString *) activityType {
	return NSStringFromClass([self class]);
}

- (BOOL) canPerformWithActivityItems:(NSArray <UIActivity *> *) activityItems {
	UIResponder *responder = [UIResponder cq_currentFirstResponder];
	do {
		BOOL canPerformAction = [responder canPerformAction:[[self class] responderAction] withSender:nil];
		if (canPerformAction)
			return YES;
		responder = responder.nextResponder;
	} while (responder);

	return NO;
}

- (void) performActivity {
	[[UIApplication sharedApplication] sendAction:[[self class] responderAction] to:nil from:nil forEvent:nil];
	[self performSelector:@selector(activityDidFinish:) withObject:@YES afterDelay:0.];
}

+ (SEL) responderAction {
	return NULL;
}
@end

#pragma mark -

@implementation CQRecentMessagesActivity
- (NSString *) activityTitle {
	return NSLocalizedString(@"Sent Messages", @"Sent Messages activity title");
}

- (UIImage *) activityImage {
	return [UIImage imageNamed:@"activityMessageHistory.png"];
}

+ (SEL) responderAction {
	return @selector(showRecentlySentMessages:);
}
@end

@implementation CQChatRoomModesActivity
- (NSString *) activityTitle {
	return NSLocalizedString(@"Chat Room Modes", @"Room Modes activity title");
}

- (UIImage *) activityImage {
	return [UIImage imageNamed:@"activityRoomModes.png"];
}

+ (SEL) responderAction {
	return @selector(showRoomModes:);
}
@end

@implementation CQChatRoomTopicActivity
- (NSString *) activityTitle {
	return NSLocalizedString(@"Chat Room Topic", @"Room Topic activity title");
}

- (UIImage *) activityImage {
	return [UIImage imageNamed:@"activityRoomTopic.png"];
}

+ (SEL) responderAction {
	return @selector(showRoomTopic:);
}
@end

@implementation CQChatRoomBansActivity
- (NSString *) activityTitle {
	return NSLocalizedString(@"Ban List", @"Ban List activity title");
}

- (UIImage *) activityImage {
	return [UIImage imageNamed:@"activityRoomBans.png"];
}

+ (SEL) responderAction {
	return @selector(showRoomBans:);
}
@end

@implementation CQSaveChatLogToPDFActivity
- (NSString *) activityTitle {
	return NSLocalizedString(@"Save Current Transcript", @"Save Current Transcript activity title");
}

- (UIImage *) activityImage {
	return [UIImage imageNamed:@"activitySaveToPDF.png"];
}

+ (SEL) responderAction {
	return @selector(saveChatLog:);
}
@end
