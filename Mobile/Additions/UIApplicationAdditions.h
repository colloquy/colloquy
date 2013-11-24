typedef NS_ENUM(NSInteger, CQReachabilityState) {
	CQReachabilityStateNotReachable,
	CQReachabilityStateWiFi,
	CQReachabilityStateWWAN
};

extern NSString *const CQReachabilityStateDidChangeNotification;
extern NSString *const CQReachabilityNewStateKey;
extern NSString *const CQReachabilityOldStateKey;

@interface UIApplication (Additions)
@property (nonatomic, readonly) CQReachabilityState cq_reachabilityState; // KVO'able

- (void) cq_beginReachabilityMonitoring;
- (void) cq_endReachabilityMonitoring;
@end
