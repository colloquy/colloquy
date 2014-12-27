#import "CQTableViewController.h"

@class CQChatInputStyleViewController;

typedef NS_ENUM(NSInteger, CQTextTrait) {
	CQTextTraitBold,
	CQTextTraitItalic,
	CQTextTraitUnderline
};

typedef NS_ENUM(NSInteger, CQColorPosition) {
	CQColorPositionForeground,
	CQColorPositionBackground
};

@protocol CQChatInputStyleDelegate <NSObject>
@required
- (void) chatInputStyleView:(CQChatInputStyleViewController *) chatInputStyleView didChangeTextTrait:(CQTextTrait) trait toState:(BOOL) state;
- (void) chatInputStyleView:(CQChatInputStyleViewController *) chatInputStyleView didSelectColor:(UIColor *) color forColorPosition:(CQColorPosition) position;
@end

@interface CQChatInputStyleViewController : CQTableViewController
@property (atomic, weak) id <CQChatInputStyleDelegate> delegate;

@property (nonatomic, copy) NSDictionary *attributes;

@property (atomic, assign) BOOL isSelectingRange;
@end
