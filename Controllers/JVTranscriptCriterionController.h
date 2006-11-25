#import "JVChatWindowController.h"

typedef enum JVTranscriptCriterionFormat { // cooresponds to the nib tab view identifiers
	JVTranscriptTextCriterionFormat = 1,
	JVTranscriptDateCriterionFormat,
	JVTranscriptBooleanCriterionFormat,
	JVTranscriptListCriterionFormat
} JVTranscriptCriterionFormat;

typedef enum JVTranscriptCriterionKind { // corresponds to the nib menu tags
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
} JVTranscriptCriterionKind;

typedef enum JVTranscriptCriterionOperation { // corresponds to the nib menu tags
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
} JVTranscriptCriterionOperation;

typedef enum JVTranscriptCriterionQueryUnits { // corresponds to the nib menu tags
	JVTranscriptNoCriterionQueryUnits = 0,
	JVTranscriptSecondCriterionQueryUnits = 1,
	JVTranscriptMinuteCriterionQueryUnits,
	JVTranscriptHourCriterionQueryUnits,
	JVTranscriptDayCriterionQueryUnits,
	JVTranscriptWeekCriterionQueryUnits,
	JVTranscriptMonthCriterionQueryUnits
} JVTranscriptCriterionQueryUnits;

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
+ (id) controller;

- (NSView *) view;

- (JVTranscriptCriterionFormat) format;

- (JVTranscriptCriterionKind) kind;
- (void) setKind:(JVTranscriptCriterionKind) kind;

- (IBAction) selectCriterionKind:(id) sender;
- (IBAction) selectCriterionOperation:(id) sender;
- (IBAction) selectCriterionQueryUnits:(id) sender;
- (IBAction) changeQuery:(id) sender;
- (IBAction) noteOtherChanges:(id) sender;

- (BOOL) changedSinceLastMatch;
- (BOOL) matchMessage:(JVChatMessage *) message fromChatView:(id <JVChatViewController>) chatView ignoringCase:(BOOL) ignoreCase;

- (id) query;
- (void) setQuery:(id) query;

- (JVTranscriptCriterionOperation) operation;
- (void) setOperation:(JVTranscriptCriterionOperation) operation;

- (JVTranscriptCriterionQueryUnits) queryUnits;
- (void) setQueryUnits:(JVTranscriptCriterionQueryUnits) units;

- (BOOL) usesSmartTranscriptCriterion;
- (void) setUsesSmartTranscriptCriterion:(BOOL) use;

- (NSView *) firstKeyView;
- (NSView *) lastKeyView;
@end
