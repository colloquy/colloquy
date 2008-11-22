#import "JVChatWindowController.h"

typedef enum JVChatViewCriterionFormat { // cooresponds to the nib tab view identifiers
	JVChatViewTextCriterionFormat = 1,
	JVChatViewBooleanCriterionFormat,
	JVChatViewListCriterionFormat
} JVChatViewCriterionFormat;

typedef enum JVChatViewCriterionKind { // corresponds to the nib menu tags
	JVChatViewTitleCriterionKind = 1,
	JVChatViewTypeCriterionKind,
	JVChatViewConnectionAddressCriterionKind,
	JVChatViewConnectionTypeCriterionKind,
	JVChatViewOpenMethodCriterionKind,
	JVChatViewEveryPanelCriterionKind
} JVChatViewCriterionKind;

typedef enum JVChatViewCriterionOperation { // corresponds to the nib menu tags
	JVChatViewNoCriterionOperation = 0,
	JVChatViewTextMatchCriterionOperation = 1,
	JVChatViewTextDoesNotMatchCriterionOperation,
	JVChatViewTextContainsCriterionOperation,
	JVChatViewTextDoesNotContainCriterionOperation,
	JVChatViewTextBeginsWithCriterionOperation,
	JVChatViewTextEndsWithCriterionOperation,
	JVChatViewIsEqualCriterionOperation,
	JVChatViewIsLessThanCriterionOperation,
	JVChatViewIsGreaterThanCriterionOperation,
	JVChatViewIsNotEqualCriterionOperation
} JVChatViewCriterionOperation;

@interface JVChatViewCriterionController : NSObject <NSCopying, NSMutableCopying, NSCoding> {
	@private
	IBOutlet NSView *subview;
	IBOutlet NSTabView *tabView;

	IBOutlet NSMenu *kindMenu;
	IBOutlet NSMenu *viewTypesMenu;
	IBOutlet NSMenu *serverTypesMenu;
	IBOutlet NSMenu *openMethodsMenu;

	IBOutlet NSPopUpButton *textKindButton;
	IBOutlet NSPopUpButton *booleanKindButton;
	IBOutlet NSPopUpButton *listKindButton;

	IBOutlet NSPopUpButton *textOperationButton;
	IBOutlet NSPopUpButton *listOperationButton;

	IBOutlet NSTextField *textQuery;
	IBOutlet NSPopUpButton *listQuery;

	JVChatViewCriterionKind _kind;
	JVChatViewCriterionFormat _format;
	JVChatViewCriterionOperation _operation;

	id _query;

	BOOL _changed;
}
+ (id) controller;

- (NSView *) view;

- (JVChatViewCriterionFormat) format;

- (JVChatViewCriterionKind) kind;
- (void) setKind:(JVChatViewCriterionKind) kind;

- (JVChatViewCriterionOperation) operation;
- (void) setOperation:(JVChatViewCriterionOperation) operation;

- (id) query;
- (void) setQuery:(id) query;

- (IBAction) selectCriterionKind:(id) sender;
- (IBAction) selectCriterionOperation:(id) sender;
- (IBAction) changeQuery:(id) sender;
- (IBAction) noteOtherChanges:(id) sender;

- (BOOL) changedSinceLastMatch;
- (BOOL) matchChatView:(id <JVChatViewController>) chatView ignoringCase:(BOOL) ignoreCase;

- (NSView *) firstKeyView;
- (NSView *) lastKeyView;
@end
