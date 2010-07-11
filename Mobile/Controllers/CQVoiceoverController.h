@interface CQVoiceoverController : NSObject
+ (CQVoiceoverController *) defaultController;

- (void) postNotificationWithMessage:(NSString *) message user:(NSString *) user channel:(NSString *) channel; // For highlights in background channels
- (void) postNotificationWithMessage:(NSString *) message user:(NSString *) user privately:(BOOL) privately; // For the current channel or in a privmsg/notice
@end
