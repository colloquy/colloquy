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
	JVTranscriptMessageNotFromMeCriterionKind
} JVTranscriptCriterionKind;

@class JVChatMessage;

@interface JVTranscriptCriterionController : NSObject {
	@private
	IBOutlet NSView *subview;
	IBOutlet NSTabView *tabView;

	IBOutlet NSMenu *kindMenu;

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

	BOOL _changed;
}
+ (id) controller;

- (NSView *) view;

- (JVTranscriptCriterionFormat) format;

- (JVTranscriptCriterionKind) kind;
- (void) setKind:(JVTranscriptCriterionKind) kind;

- (IBAction) selectCriterionKind:(id) sender;
- (IBAction) noteOtherChanges:(id) sender;

- (BOOL) changedSinceLastMatch;
- (BOOL) matchMessage:(JVChatMessage *) message ignoreCase:(BOOL) ignoreCase;
@end