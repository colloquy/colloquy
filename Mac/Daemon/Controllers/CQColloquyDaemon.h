extern NSString * const CQColloquyDaemonWillTerminateNotification;

@interface CQColloquyDaemon : NSObject {
@private
	BOOL _running;
	NSUInteger _disableAutomaticTerminationCount;
}
+ (CQColloquyDaemon *) sharedDaemon;

- (void) terminate;

- (void) disableAutomaticTermination;
- (void) enableAutomaticTermination;
@end

int CQColloquyDaemonMain(int argc, const char *argv[]);
