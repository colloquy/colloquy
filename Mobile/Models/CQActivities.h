@interface CQActivity : UIActivity
@end

#define CQActivitySubclass(Name, protocolMethod) \
	@interface Name : CQActivity \
	@end \
\
	@interface NSObject (Name) \
	- (void) protocolMethod:(id) sender; \
	@end

CQActivitySubclass(CQRecentMessagesActivity, showRecentlySentMessages)
CQActivitySubclass(CQSaveChatLogToPDFActivity, saveChatLog)

CQActivitySubclass(CQChatRoomModesActivity, showRoomModes)
CQActivitySubclass(CQChatRoomTopicActivity, showRoomTopic)
CQActivitySubclass(CQChatRoomBansActivity, showRoomBans)

#undef CQActivitySubclass

#pragma mark -

@interface CQActivitiesProvider : NSObject
+ (NSArray <CQActivity *> *)activities;
@end
