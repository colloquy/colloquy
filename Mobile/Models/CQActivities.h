@interface CQActivitiesProvider : NSObject
+ (NSArray /* <CQActivity> */ *)activities;
@end

#pragma mark -

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

CQActivitySubclass(CQChatRoomModesActivity, showRoomInfo)
CQActivitySubclass(CQChatRoomTopicActivity, showRoomTopic)
CQActivitySubclass(CQChatRoomBansActivity, showRoomBans)
CQActivitySubclass(CQChatRoomInvitesActivity, showRoomInvites)

#undef CQActivitySubclass
