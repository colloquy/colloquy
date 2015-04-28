#import "JVChatWindowController.h"

typedef NS_ENUM(NSInteger, JVChatViewCriterionFormat) { // cooresponds to the nib tab view identifiers
	JVChatViewTextCriterionFormat = 1,
	JVChatViewBooleanCriterionFormat,
	JVChatViewListCriterionFormat
};

typedef NS_ENUM(NSInteger, JVChatViewCriterionKind) { // corresponds to the nib menu tags
	JVChatViewTitleCriterionKind = 1,
	JVChatViewTypeCriterionKind,
	JVChatViewConnectionAddressCriterionKind,
	JVChatViewConnectionTypeCriterionKind,
	JVChatViewOpenMethodCriterionKind,
	JVChatViewEveryPanelCriterionKind
};

typedef NS_ENUM(NSInteger, JVChatViewCriterionOperation) { // corresponds to the nib menu tags
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
};

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
+ (instancetype) controller;

@property (readonly, strong) NSView *view;

@property (readonly) JVChatViewCriterionFormat format;
@property JVChatViewCriterionKind kind;
@property JVChatViewCriterionOperation operation;
@property (strong) id query;

- (IBAction) selectCriterionKind:(id) sender;
- (IBAction) selectCriterionOperation:(id) sender;
- (IBAction) changeQuery:(id) sender;
- (IBAction) noteOtherChanges:(id) sender;

@property (readonly) BOOL changedSinceLastMatch;
- (BOOL) matchChatView:(id <JVChatViewController>) chatView ignoringCase:(BOOL) ignoreCase;

@property (readonly, strong) NSView *firstKeyView;
@property (readonly, strong) NSView *lastKeyView;
@end
