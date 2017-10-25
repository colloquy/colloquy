#import <Cocoa/Cocoa.h>
#import "JVChatWindowController.h"

/// corresponds to the nib tab view identifiers
typedef NS_ENUM(NSInteger, JVTranscriptCriterionFormat) {
	JVTranscriptTextCriterionFormat = 1,
	JVTranscriptDateCriterionFormat,
	JVTranscriptBooleanCriterionFormat,
	JVTranscriptListCriterionFormat
};

/// corresponds to the nib menu tags
typedef NS_ENUM(NSInteger, JVTranscriptCriterionKind) {
	JVTranscriptMessageBodyCriterionKind = 1,
	JVTranscriptSenderNameCriterionKind,
	JVTranscriptDateReceivedCriterionKind,
	JVTranscriptSenderInBuddyListCriterionKind,
	JVTranscriptSenderNotInBuddyListCriterionKind,
	JVTranscriptSenderIgnoredCriterionKind,
	JVTranscriptSenderNotIgnoredCriterionKind,
	JVTranscriptMessageIgnoredCriterionKind,
	JVTranscriptMessageNotIgnoredCriterionKind,
	JVTranscriptMessageAddressedToMeCriterionKind,
	JVTranscriptMessageNotAddressedToMeCriterionKind,
	JVTranscriptMessageHighlightedCriterionKind,
	JVTranscriptMessageNotHighlightedCriterionKind,
	JVTranscriptMessageIsActionCriterionKind,
	JVTranscriptMessageIsNotActionCriterionKind,
	JVTranscriptMessageFromMeCriterionKind,
	JVTranscriptMessageNotFromMeCriterionKind,
	JVTranscriptSourceIsChatRoomCriterionKind,
	JVTranscriptSourceIsNotChatRoomCriterionKind,
	JVTranscriptSourceIsPrivateChatCriterionKind,
	JVTranscriptSourceIsNotPrivateChatCriterionKind,
	JVTranscriptSourceNameCriterionKind,
	JVTranscriptSourceServerAddressCriterionKind,
	JVTranscriptEveryMessageCriterionKind
};

/// corresponds to the nib menu tags
typedef NS_ENUM(NSInteger, JVTranscriptCriterionOperation) {
	JVTranscriptNoCriterionOperation = 0,
	JVTranscriptTextMatchCriterionOperation = 1,
	JVTranscriptTextDoesNotMatchCriterionOperation,
	JVTranscriptTextContainsCriterionOperation,
	JVTranscriptTextDoesNotContainCriterionOperation,
	JVTranscriptTextBeginsWithCriterionOperation,
	JVTranscriptTextEndsWithCriterionOperation,
	JVTranscriptIsEqualCriterionOperation,
	JVTranscriptIsLessThanCriterionOperation,
	JVTranscriptIsGreaterThanCriterionOperation,
	JVTranscriptIsNotEqualCriterionOperation
};

/// corresponds to the nib menu tags
typedef NS_ENUM(NSInteger, JVTranscriptCriterionQueryUnits) {
	JVTranscriptNoCriterionQueryUnits = 0,
	JVTranscriptSecondCriterionQueryUnits = 1,
	JVTranscriptMinuteCriterionQueryUnits,
	JVTranscriptHourCriterionQueryUnits,
	JVTranscriptDayCriterionQueryUnits,
	JVTranscriptWeekCriterionQueryUnits,
	JVTranscriptMonthCriterionQueryUnits
};

@class JVChatMessage;

@interface JVTranscriptCriterionController : NSObject <NSCopying, NSMutableCopying, NSCoding> {
	@private
	IBOutlet NSView *subview;
	IBOutlet NSTabView *tabView;

	IBOutlet NSMenu *kindMenu;
	IBOutlet NSMenu *expandedKindMenu;

	IBOutlet NSPopUpButton *textKindButton;
	IBOutlet NSPopUpButton *dateKindButton;
	IBOutlet NSPopUpButton *booleanKindButton;
	IBOutlet NSPopUpButton *listKindButton;

	IBOutlet NSPopUpButton *textOperationButton;
	IBOutlet NSPopUpButton *dateOperationButton;
	IBOutlet NSPopUpButton *listOperationButton;

	IBOutlet NSTextField *textQuery;
	IBOutlet NSTextField *dateQuery;
	IBOutlet NSPopUpButton *listQuery;

	IBOutlet NSPopUpButton *dateUnitsButton;

	JVTranscriptCriterionKind _kind;
	JVTranscriptCriterionFormat _format;
	JVTranscriptCriterionOperation _operation;
	JVTranscriptCriterionQueryUnits _queryUnits;

	id _query;

	BOOL _smartTranscriptCriterion;
	BOOL _changed;
}
+ (instancetype) controller;

@property (readonly, strong) NSView *view;

@property (readonly) JVTranscriptCriterionFormat format;

@property JVTranscriptCriterionKind kind;

- (IBAction) selectCriterionKind:(id) sender;
- (IBAction) selectCriterionOperation:(id) sender;
- (IBAction) selectCriterionQueryUnits:(id) sender;
- (IBAction) changeQuery:(id) sender;
- (IBAction) noteOtherChanges:(id) sender;

@property (readonly) BOOL changedSinceLastMatch;
- (BOOL) matchMessage:(JVChatMessage *) message fromChatView:(id <JVChatViewController>) chatView ignoringCase:(BOOL) ignoreCase;

@property (strong) id query;

@property JVTranscriptCriterionOperation operation;

@property JVTranscriptCriterionQueryUnits queryUnits;

@property BOOL usesSmartTranscriptCriterion;

@property (readonly, strong) NSView *firstKeyView;
@property (readonly, strong) NSView *lastKeyView;
@end
