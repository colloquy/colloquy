#import "CQActivities.h"

#import <objc/runtime.h>

@interface UIResponder (Additions)
@end

@implementation UIResponder (Additions)
static __weak id cq_currentFirstResponder;

+ (UIResponder *)cq_currentFirstResponder {
	cq_currentFirstResponder = nil;

	[[UIApplication sharedApplication] sendAction:@selector(cq_findCurrentFirstResponder:) to:nil from:nil forEvent:nil];

	id firstResponder = cq_currentFirstResponder;
	cq_currentFirstResponder = nil;
	return firstResponder;
}

- (void)cq_findCurrentFirstResponder:(id)sender {
	cq_currentFirstResponder = self;
}
@end

#pragma mark -

@implementation CQActivitiesProvider
+ (NSArray *) activities {
	return @[ [[CQRecentMessagesActivity alloc] init],
			  [[CQRoomModesActivity alloc] init], [[CQRoomTopicActivity alloc] init], [[CQRoomBansActivity alloc] init], [[CQRoomInvitesActivity alloc] init],
			  [[CQSaveChatLogToPDFActivity alloc] init] ];
}
@end

#pragma mark -

@implementation CQActivity
- (NSString *) activityType {
	return NSStringFromClass([self class]);
}

- (BOOL) canPerformWithActivityItems:(NSArray *) activityItems {
	return [[UIResponder cq_currentFirstResponder] canPerformAction:[[self class] responderAction] withSender:self];
}

- (void) performActivity {
	[[UIApplication sharedApplication] sendAction:[[self class] responderAction] to:nil from:nil forEvent:nil];
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
	return nil;
}

+ (SEL) responderAction {
	return @selector(showRecentlySentMessages:);
}
@end

@implementation CQRoomModesActivity
- (NSString *) activityTitle {
	return NSLocalizedString(@"Room Modes", @"Room Modes activity title");
}

- (UIImage *) activityImage {
	return nil;
}

+ (SEL) responderAction {
	return @selector(showRoomModes:);
}
@end

@implementation CQRoomTopicActivity
- (NSString *) activityTitle {
	return NSLocalizedString(@"Room Topic", @"Room Topic activity title");
}

- (UIImage *) activityImage {
	return nil;
}

+ (SEL) responderAction {
	return @selector(showRoomTopic:);
}
@end

@implementation CQRoomBansActivity
- (NSString *) activityTitle {
	return NSLocalizedString(@"Ban List", @"Ban List activity title");
}

- (UIImage *) activityImage {
	return nil;
}

+ (SEL) responderAction {
	return @selector(showRoomBans:);
}
@end

@implementation CQRoomInvitesActivity
- (NSString *) activityTitle {
	return NSLocalizedString(@"Invite List", @"Invite List activity title");
}

- (UIImage *) activityImage {
	return nil;
}

+ (SEL) responderAction {
	return @selector(showRoomInvites:);
}
@end

@implementation CQSaveChatLogToPDFActivity
- (NSString *) activityTitle {
	return NSLocalizedString(@"Save Current Transcript", @"Save Current Transcript activity title");
}

- (UIImage *) activityImage {
	return nil;
}

+ (SEL) responderAction {
	return @selector(saveChatLog:);
}
@end
