@class HTMLFramesetView;
@class HTMLNode;
@class HTMLFrameset;
@class HTMLMarkedItem;
@class HTMLTree;
@class HTMLTextView;
@class HTMLView;
@class HTMLDocument;
@class HTMLAnchorMarkAttachmentCell;
@class HTMLLabel;
@class HTMLOutliningCell;
@class HTMLProxyViewAttachmentCell;
@class HTMLSemanticEngine;
@class HTMLProxyAttachmentCell;
@class HTMLTable;
@class HTMLTableAttachmentCell;
@class HTMLRenderingState;
@class HTMLTableCaption;
@class HTMLItem;
@class HTMLSelection;

struct _HTMLTableDimension {
	int width;
	int height;
};

@protocol HTMLEmbedding <NSObject>
- paramValueString:fp12;
- sourceUrl;
- sourceUrlString;
@end

@protocol HTMLTextAlignableItem
- (int)textAlignment;
@end

@protocol HTMLOptionContainer
- options;
@end

@protocol HTMLTargetFinding
- findViewForTarget:fp12;
@end

@protocol HTMLMouseTrackingAttachment
- (void)mouseExited;
- mouseMoved:fp12 inFrame:(struct _NSRect)fp16;
- mouseEntered;
@end

@protocol HTMLFrame <NSObject>
- (int)scrolling;
- (char)frameBorder;
- (int)marginWidth;
- (int)marginHeight;
- (char)hasSource;
- sourceUrl;
@end

@protocol HTMLViewEmbedding
- (void)willDetachFromItem:fp12;
- (struct _NSSize)preferredSize;
- initWithFrame:(struct _NSRect)fp16 andItem:fp32;
@end

@protocol HTMLSelectOption
- displayString;
- (void)configureBrowserCell:fp12;
- (void)addMenuItemToPopUp:fp12;
@end

@interface HTMLContextMenu:NSMenu
{
}

- (void)_popUpContextMenu:fp12 withEvent:fp16 forView:fp20;

@end

@interface NSMutableAttributedString(HTMLAttributeFixingCheck)
- (void)checkAttributesBeforeFixing;
- (void)checkParagraphStyleAttributeInRange:(struct _NSRange)fp12;
- (void)checkAttachmentAttributeInRange:(struct _NSRange)fp12;
@end

@interface NSCursor(HTMLCursorExtras)
+ fingerCursor;
@end

@interface NSColor(HTMLColorExtras)
+ linkColor;
+ activeLinkColor;
+ visitedLinkColor;
@end

@interface NSLayoutManager(HTMLAttachmentSupport)
+ mouseMoved:fp12 insideLink:(char)fp16 atIndex:(unsigned int)fp20 ofLayoutManager:fp24 givenOrigin:(struct _NSPoint)fp28 lastEnteredCell:(id *)fp32 pushedFinger:(char *)fp36;
- attachmentForWindowLocation:(struct _NSPoint)fp12 givenOrigin:(struct _NSPoint)fp20 frame:(struct _NSRect *)fp28;
- (char)windowLocation:(struct _NSPoint)fp12 atIndex:(unsigned int *)fp20 fraction:(float *)fp24 isInsideLink:(id *)fp28 ofItem:(id *)fp32 withRange:(struct _NSRange *)fp32 givenOrigin:(struct _NSPoint)fp36;
- (void)windowLocation:(struct _NSPoint)fp12 hitRoot:(id *)fp20 atPosition:(unsigned int *)fp24 fraction:(float *)fp28 givenOrigin:(struct _NSPoint)fp28;
- (void)drawBackgroundForGlyphRange:(struct _NSRange)fp12 atPoint:(struct _NSPoint)fp20 selectedRange:(struct _NSRange)fp28 topTextView:fp32;
- (struct _NSRange)selectionRangeForProposedRange:(struct _NSRange)fp16 granularity:(int)fp24;
- (struct _NSRect)usedRectWithLayoutForTextContainer:fp16 glyphRange:(struct _NSRange *)fp20;
@end

@interface NSColor(HTMLColorComparison)
- (float)perceptualBrightness;
- (float)distanceFromColor:fp12;
- colorDarkenedByFactor:(float)fp40;
- highContrastColor;
@end

@interface NSView(HTMLViewFinding)
- htmlView;
@end

@interface NSImage(HTMLNamedImages)
+ imageNamed:fp12 sender:fp16;
+ attributedStringForImageNamed:fp12 selectedImageNamed:fp16 withRepresentedObject:fp20 sender:fp24 makingCell:(id *)fp28;
+ attributedStringForImageNamed:fp12 withRepresentedObject:fp16 sender:fp20 makingCell:(id *)fp24;
+ imageForURL:fp12 loadIfAbsent:(char)fp16;
+ imageForURL:fp12 client:fp16;
- cachedColorForPixelImage;
@end

@interface NSMutableAttributedString(HTMLAttachmentAppending)
- (void)appendAttachment:fp12 attributes:fp16;
@end

@interface NSAttributedString(HTMLEmptyStrings)
+ emptyString;
@end

@interface NSTextTab(HTMLTabs)
+ cachedLeftTabStopForLocation:(float)fp40;
@end

@interface NSURL(HTMLAdditions)
+ URLPerformingCorrectionWithString:fp12 relativeToURL:fp16;
+ URLPerformingCorrectionWithString:fp12;
- uniqueURL;
- (char)isVisited;
- (void)setVisited;
@end

@interface NSString(HTMLUnicodeEscaping)
- unescapedUnicodeString;
- escapedUnicodeStringForEncoding:(unsigned int)fp12;
@end

@interface NSData(HTMLMIMETagMethods)
- (unsigned int)findEncodingFromCharsetTag;
- findCharsetTag;
@end

@interface NSString(HTMLMIMETagMethods)
+ mimeCharsetTagFromStringEncoding:(unsigned int)fp12;
+ (unsigned int)stringEncodingFromMimeCharsetTag:fp12;
@end

@interface NSString(HTMLSpaceHandling)
+ nonBreakingSpaceString;
- stringWithoutLeadingSpace;
- stringWithoutTrailingSpace;
- stringWithoutSpaceOnEnds;
- stringWithoutNewlinesOnEnds;
- (char)hasLeadingSpace;
- (char)hasTrailingSpace;
- (char)isWhitespaceString;
- stringByStrippingEnclosingNewlines;
@end

@interface NSString(HTMLConversion)
- htmlStringFromTextString;
@end

@interface NSString(HTMLStringComparison)
- (char)isEqualToHtmlString:fp12;
@end

@interface NSArray(HTMLFoundationExtra)
+ allRunLoopModes;
+ standardRunLoopModes;
@end

@interface HTMLFramesetController:NSResponder
{
    HTMLFramesetView *_framesetView;
    HTMLNode *_tree;
    char _pendingUpdate;
}

+ dragColor;
- initWithTree:fp12;
- _viewForItem:fp12;
- _itemForView:fp12;
- (void)_renewDisplay;
- (void)setFramesetView:fp12;
- (void)setTree:fp12;
- (void)dealloc;
- framesetView;
- htmlView;
- tree;
- document;
- (void)htmlView:fp12 selectionChangedTo:fp16;
- (void)updateRendering;
- (void)htmlDocumentDidChange:fp12;
- (char)validateMenuItem:fp12;

@end

@interface HTMLFramesetView:NSView <HTMLTargetFinding>
{
    HTMLFramesetController *_framesetCtlr;
    HTMLFrameset *_frameset;
    int _cols;
    int _rows;
    int *_colWidths;
    int *_colTypes;
    int *_rowHeights;
    int *_rowTypes;
    char _simpleWidths;
    char _simpleHeights;
    NSArray *_installedViews;
    NSArray *_installedItems;
    NSArray *_installedEmptyViews;
}

+ (void)initialize;
+ (Class)frameViewClass;
+ (void)setFrameViewClass:(Class)fp12;
+ horizontalResizeCursor;
+ verticalResizeCursor;
- framesetController;
- (void)setFramesetController:fp12;
- (void)setNextResponder:fp12;
- (void)resizeSubviewsWithOldSize:(struct _NSSize)fp12;
- (void)setFrameset:fp12;
- frameset;
- (char)isFlipped;
- (void)dealloc;
- (void)calcFrameSizes;
- (void)sizeAndInstallSubviews;
- (void)resetCursorRects;
- (void)drawRect:(struct _NSRect)fp12;
- (char)isOpaque;
- viewForItem:fp12;
- itemForView:fp12;
- findViewForTarget:fp12;
- (void)rerender;
- (void)_enteredTrackingRect;
- (void)_exitedTrackingRect;
- _mouseMoved:fp12;

@end

@interface HTMLView:NSView <HTMLTargetFinding>
{
    NSScrollView *scrollView;
    HTMLTextView *textView;
    HTMLFramesetView *framesetView;
    HTMLDocument *document;
    id _delegate;
    HTMLSelection *_selection;
    int _granularity;
    int _haveAddedTrackingRect:1;
    int _didAcceptMouseMoves:1;
    int _amInsideNow:1;
    int _pushedFinger:1;
    int _trackingRectTag;
}

+ (void)registerForServices;
+ (void)initialize;
+ (Class)textViewClass;
+ (void)setTextViewClass:(Class)fp12;
+ (Class)framesetViewClass;
+ (void)setFramesetViewClass:(Class)fp12;
+ (Class)documentClass;
+ (void)setDocumentClass:(Class)fp12;
- (struct _NSRect)_boundsForContentSubviews;
- (char)_initSubviewsForFramesetDocument;
- (char)_initSubviewsForBodyDocument;
- (char)_initSubviews;
- (void)resizeSubviewsWithOldSize:(struct _NSSize)fp12;
- (char)textViewWidthFitsContent;
- (void)reviewTextViewWidth;
- initWithFrame:(struct _NSRect)fp12;
- (void)_adjustFontBy:(int)fp12;
- document;
- (void)setDocument:fp12;
- firstDelegate;
- delegate;
- (void)setDelegate:fp12;
- defaultFirstResponder;
- scrollView;
- textView;
- textController;
- framesetView;
- framesetController;
- renderingRoot;
- parentHtmlView;
- topHtmlView;
- findViewForTarget:fp12;
- htmlViewForTarget:fp12;
- (struct _NSRect)interiorFrame;
- (void)printDocumentUsingPrintPanel:(char)fp12;
- (void)print:fp12;
- (void)printDocument:fp12;
- (int)_fontAdjustment;
- (void)makeFontBigger:fp12;
- (void)makeFontSmaller:fp12;
- (char)_processTextInSelection:fp12 forRoot:fp16 toString:fp20 checkingPoint:(struct _NSPoint *)fp24;
- attributedStringForSelection;
- (void)_setNeedsDisplayOverSelection:fp12;
- (char)_selection:fp12 containsPoint:(struct _NSPoint)fp16;
- _stripAttachmentCharactersFromAttributedString:fp12;
- stringForSelection;
- writablePasteboardTypes;
- (void)copy:fp12;
- (void)copyRuler:fp12;
- (void)copyFont:fp12;
- validRequestorForSendType:fp12 returnType:fp16;
- (char)writeSelectionToPasteboard:fp12 type:fp16 selectionString:fp20;
- (char)writeSelectionToPasteboard:fp12 types:fp16;
- htmlString;
- (void)dealloc;
- (void)promulgateSelection:fp12;
- selection;
- (void)setSelection:fp12;
- (char)scrollToFragmentUrl:fp12;
- (char)scrollToFragmentName:fp12;
- (void)followLink:fp12;
- urlForProposedLink:fp12 relativeToURL:fp16 withTarget:fp20;
- performUrlForProposedLink:fp12 relativeToURL:fp16 withTarget:fp20 resolveNow:(char)fp24;
- (void)mouseInLink:fp12 withTarget:fp16 title:fp20;
- (void)performMouseInLink:fp12 withTarget:fp16 title:fp20;
- (void)performMouseInLink:fp12;
- (void)clickedOnLink:fp12 withTarget:fp16;
- (void)_performClickOnLink:fp12;
- (void)performClickOnLink:fp12 withTarget:fp16;
- (void)performClickOnLink:fp12;
- (char)layoutManager:fp12 withOrigin:(struct _NSPoint)fp16 clickedOnLink:fp24 forItem:fp28 withRange:(struct _NSRange)fp28;
- (int)selectionGranularity;
- (void)setSelectionGranularity:(int)fp12;
- (char)dragSelectionWithEvent:fp12 offset:(struct _NSSize)fp16 slideBack:(char)fp24;
- (void)handleSelectionEvent:fp12 withRoot:fp16 position:(unsigned int)fp20 fraction:(float)fp40;
- (char)validateMenuItem:fp12;
- (void)didChange;
- (void)htmlDocumentDidChange:fp12;
- (void)_enteredTrackingRect;
- (void)_exitedTrackingRect;
- (void)_removeTrackingRect;
- (void)_setUpTrackingRect;
- (void)drawRect:(struct _NSRect)fp12;
- (void)setFrame:(struct _NSRect)fp12;
- (void)viewWillMoveToWindow:fp12;
- (void)viewDidMoveToWindow;
- (void)_windowChangedKeyState;
- (void)_mouseMoved:fp12;
- (void)mouseMoved:fp12;
- (void)mouseEntered:fp12;
- (void)mouseExited:fp12;

@end

@interface HTMLFrameView:HTMLView
{
    HTMLMarkedItem *_representedFrame;
    char _fittingToWindow;
    int _currentWidth;
    int _currentWidthType;
    int _currentHeight;
    int _currentHeightType;
}

- (char)_initSubviewsForBodyDocument;
- (char)textViewWidthFitsContent;
- (char)_superviewUsesOurURL;
- (char)_initSubviews;
- (void)resizeSubviewsWithOldSize:(struct _NSSize)fp12;
- (char)isFlipped;
- (void)dealloc;
- representedUrl;
- (char)hasSource;
- (void)URLResourceDidFinishLoading:fp12;
- (void)URLResourceDidCancelLoading:fp12;
- (void)URL:fp12 resourceDidFailLoadingWithReason:fp16;
- representedFrame;
- (void)setRepresentedFrame:fp12;
- lightBorderColor;
- darkBorderColor;
- innerBorderColor;
- contentColor;
- (void)currentWidth:(int)fp12 type:(int)fp16 height:(int)fp20 type:(int)fp24;
- (void)drawRect:(struct _NSRect)fp12;
- (char)isOpaque;
- (void)rerender;

@end

@interface HTMLFrameworkController:NSObject
{
}

+ (void)oneTimeInit;
+ (void)initialize;
+ sharedInstance;
- init;

@end

@interface NSWindow(HTMLPrivate)
- windowHtmlView;
@end

@interface HTMLSelection:NSObject
{
    HTMLTree *_selectionTree;
}

- _initWithSelectionTree:fp12;
- (char)isEqualToSelection:fp12;
- (char)isZeroLength;
- tree;

@end

@interface HTMLTextController:NSObject
{
    HTMLTextView *textView;
    HTMLNode *tree;
    unsigned int _isHTMLChange;
    char _pendingUpdate;
}

- initWithTree:fp12;
- (void)_renewDisplay;
- (void)setTextView:fp12;
- (void)setTree:fp12;
- (void)dealloc;
- textView;
- tree;
- document;
- documentBaseUrl;
- resourceBaseUrl;
- (void)textStorageWillProcessEditing:fp12;
- renderingRoot;
- (void)htmlDocumentDidChange:fp12;
- (void)updateBackground:fp12;
- (char)textView:fp12 clickedOnLink:fp16 atIndex:(unsigned int)fp20;
- (void)textView:fp12 clickedOnCell:fp16 inRect:(struct _NSRect)fp20 atIndex:(unsigned int)fp32;
- (void)textView:fp12 doubleClickedOnCell:fp16 inRect:(struct _NSRect)fp20 atIndex:(unsigned int)fp32;
- (void)textView:fp12 draggedCell:fp16 inRect:(struct _NSRect)fp20 event:fp32 atIndex:(unsigned int)fp36;
- (void)updateRendering;
- (void)checkRendering;
- (void)beginHTMLChange;
- (void)endHTMLChange;
- htmlString;

@end

@interface HTMLTextView:NSTextView
{
    HTMLTextController *textCtlr;
    HTMLView *_htmlView;
    int _viewIsTransparent:1;
    int _havePushedFingerCursor:1;
    int _havePushedIBeamCursor:1;
    id _lastEnteredCell;
}

- (void)systemColorsChanged:fp12;
- (void)completeInitWithTextController:fp12;
- initWithFrame:(struct _NSRect)fp12;
- initWithFrame:(struct _NSRect)fp12 textController:fp28;
- (void)dealloc;
- selection;
- textController;
- (void)setTextController:fp12;
- htmlView;
- (void)setHTMLView:fp12;
- (char)isEditable;
- (void)setEditable:(char)fp12;
- (char)isSelectable;
- (void)setSelectable:(char)fp12;
- (void)_drawViewBackgroundInRect:(struct _NSRect)fp12;
- backgroundColor;
- (void)setDrawsBackground:(char)fp12;
- (void)marginsChanged;
- (void)backgroundChanged;
- (void)drawRect:(struct _NSRect)fp12;
- (char)becomeFirstResponder;
- (char)resignFirstResponder;
- (void)clickedOnCell:fp12 inRect:(struct _NSRect)fp16;
- (void)doubleClickedOnCell:fp12 inRect:(struct _NSRect)fp16;
- (void)draggedCell:fp12 inRect:(struct _NSRect)fp16 event:fp32;
- (void)_enteredTrackingRect;
- (void)_exitedTrackingRect;
- _mouseMoved:fp12;
- (char)linkTrackMouseDown:fp12;
- (void)clickedOnLink:fp12 atIndex:(unsigned int)fp16;
- (void)resetCursorRects;
- _setSuperview:fp12;
- (void)mouseDown:fp12;
- menuForEvent:fp12;
- (void)htmlView:fp12 selectionChangedTo:fp16;
- defaultTextColor;
- writablePasteboardTypes;
- (char)writeSelectionToPasteboard:fp12 type:fp16;
- (char)writeSelectionToPasteboard:fp12 types:fp16;
- readablePasteboardTypes;
- (char)readSelectionFromPasteboard:fp12 type:fp16;
- (char)readSelectionFromPasteboard:fp12;
- validRequestorForSendType:fp12 returnType:fp16;
- (char)respondsToSelector:(SEL)fp12;
- (void)selectAll:fp12;
- (char)validateMenuItem:fp12;
- (void)doCommandBySelector:(SEL)fp12;

@end

@interface HTMLItem:NSObject
{
    HTMLNode *_parent;
    unsigned short _minimumWidth;
    unsigned short _maximumWidth;
    int _reservedFlags:13;
    int _hasChildrenArray:1;
    int _wasInterpolated:1;
    int _scheduledRemove:1;
    unsigned short _refCount;
}

+ (void)initialize;
- retain;
- (void)release;
- (unsigned int)retainCount;
- init;
- (void)dealloc;
- (void)awakeWithDocument:fp12;
- tree;
- parent;
- (int)depth;
- (void)removedFromTree;
- (void)removedFromTree:fp12;
- (void)setParent:fp12;
- document;
- leftSibling;
- rightSibling;
- leftNeighbor;
- rightNeighbor;
- (char)hasLeadingSpaceWithSemanticEngine:fp12;
- (char)hasTrailingSpaceWithSemanticEngine:fp12;
- (void)correctWhiteSpaceWithSemanticEngine:fp12;
- (unsigned int)removeLeadingSpaceWithSemanticEngine:fp12;
- (unsigned int)removeTrailingSpaceWithSemanticEngine:fp12;
- (char)descendsFrom:fp12;
- (void)setWasInterpolated:(char)fp12;
- (char)wasInterpolated;

@end

@interface HTMLMarkedItem:HTMLItem
{
    unsigned long _keyOrDict;
    unsigned long _valueOrMaxCapacity;
}

- init;
- initWithMarker:fp12 attributes:fp16;
- (void)dealloc;
- marker;
- itemName;
- itemId;
- attributes;
- (void)setAttributes:fp12;
- valueForAttribute:fp12;
- (void)valueOfAttribute:fp12 changedFrom:fp16 to:fp20;
- (void)setValue:fp12 forAttribute:fp16;
- (void)removeAttribute:fp12;
- (int)intValueForAttribute:fp12 withDefault:(int)fp16;
- (int)intValueForAttribute:fp12 withDefault:(int)fp16 minimum:(int)fp20;
- (char)booleanValueForAttribute:fp12;
- stringValueForAttribute:fp12;
- (char)getAttribute:fp12 intoSize:(unsigned int *)fp16 percentage:(char *)fp20;
- (int)alignmentValueForAttribute:fp12;
- (char)hasLeadingSpaceWithSemanticEngine:fp12;
- (char)hasTrailingSpaceWithSemanticEngine:fp12;

@end

@interface HTMLNode:HTMLMarkedItem
{
    id _childOrChildren;
}

- (void)awakeWithDocument:fp12;
- (void)removedFromTree;
- initWithMarker:fp12 attributes:fp16;
- (void)dealloc;
- children;
- (void)setChildren:fp12;
- (void)_convertToChildArray;
- (void)insertChild:fp12 atIndex:(unsigned int)fp16;
- (void)removeChildAtIndex:(unsigned int)fp12;
- (void)removeChild:fp12;
- (void)removeAllChildren;
- (void)insertChildren:fp12 atIndex:(unsigned int)fp16;
- (void)addChild:fp12;
- (void)addChildren:fp12;
- firstChild;
- lastChild;
- (unsigned int)indexOfChild:fp12;
- childAtIndex:(unsigned int)fp12;
- (unsigned int)numberOfChildren;
- (char)hasLeadingSpaceWithSemanticEngine:fp12;
- (char)hasTrailingSpaceWithSemanticEngine:fp12;
- (unsigned int)removeLeadingSpaceWithSemanticEngine:fp12;
- (unsigned int)removeTrailingSpaceWithSemanticEngine:fp12;
- (char)shouldAbsorbEdgeWhiteSpace;
- (void)correctWhiteSpaceWithSemanticEngine:fp12;

@end

@interface HTMLTextNode:HTMLNode
{
    NSString *_marker;
}

+ defaultBoldStyle;
+ defaultItalicStyle;
+ defaultFixedFontStyle;
+ defaultUnderlineStyle;
+ fontStyleWithSize:(unsigned int)fp12;
+ fontStyleWithColor:fp12;
- marker;
- initWithMarker:fp12 attributes:fp16;
- (void)dealloc;
- (char)shouldAbsorbEdgeWhiteSpace;

@end

@interface HTMLAnchor:HTMLTextNode
{
    HTMLAnchorMarkAttachmentCell *_anchorCell;
}

- (void)urlVisited:fp12;
- initWithMarker:fp12 attributes:fp16;
- (void)removedFromTree;
- (void)dealloc;
- name;
- href;
- target;
- title;
- hrefUrl;
- hrefUrlWithDelegateResolution:(char)fp12;
- anchorAttachmentCell;

@end

@interface HTMLAttachmentCell:NSTextAttachmentCell <HTMLMouseTrackingAttachment>
{
    NSTextContainer *_lastTextContainer;
    unsigned int _lastCharacterIndex;
    NSCursor *_cursor;
    NSString *_linkString;
    int _mouseInside:1;
    int _selected:1;
    int _allowContinuedTracking:1;
    int _alwaysSelectSelf:1;
    int _softLeftEdge:1;
    int _softRightEdge:1;
    int _showToolTip:1;
    int _sendSingleAction:1;
    int _sendDoubleAction:1;
    int _totallySafeTCAccess:1;
    int _marginFloat:2;
    int _isFloating:1;
}

+ htmlAttachmentCellWithRepresentedItem:fp12;
- (void)completeInitWithRepresentedItem:fp12;
- initWithRepresentedItem:fp12;
- initImageCell:fp12 withRepresentedItem:fp16;
- (void)dealloc;
- representedItem;
- (void)setRepresentedItem:fp12;
- (void)setMarginFloat:(int)fp12;
- (int)marginFloat;
- (char)selected;
- (void)setSelected:(char)fp12;
- lastTextContainer;
- (void)setLastTextContainer:fp12;
- (void)_textContainerDealloc;
- (unsigned int)lastCharacterIndex;
- (void)setLastCharacterIndex:(unsigned int)fp12;
- (struct _NSPoint)attachmentOrigin;
- (struct _NSRect)attachmentFrame;
- (char)allowsContinuedTracking;
- (void)setAllowsContinuedTracking:(char)fp12;
- (char)alwaysSelectsSelf;
- (void)setAlwaysSelectsSelf:(char)fp12;
- (char)softLeftEdge;
- (char)softRightEdge;
- (void)setSoftLeftEdge:(char)fp12;
- (void)setSoftRightEdge:(char)fp12;
- (char)showsToolTip;
- (void)setShowsToolTip:(char)fp12;
- (char)sendsSingleAction;
- (void)setSendSingleAction:(char)fp12;
- (char)sendsDoubleAction;
- (void)setSendDoubleAction:(char)fp12;
- (char)performSingleActionWithEvent:fp12 textView:fp16 frame:(struct _NSRect)fp20;
- (char)performDoubleActionWithEvent:fp12 textView:fp16 frame:(struct _NSRect)fp20;
- (void)drawWithFrame:(struct _NSRect)fp12 inView:fp28 characterIndex:(unsigned int)fp32 selected:(char)fp35;
- (struct _NSRect)cellFrameForProposedLineFragment:(struct _NSRect)fp16 glyphPosition:(struct _NSPoint)fp28 characterIndex:(unsigned int)fp36;
- (void)click:fp12 inFrame:(struct _NSRect)fp16 notifyingHTMLView:fp32 orTextView:fp32;
- (void)windowLocation:(struct _NSPoint)fp12 inFrame:(struct _NSRect)fp20 hitRoot:(id *)fp32 atPosition:(unsigned int *)fp36 fraction:(float *)fp40;
- textView;
- htmlTextView;
- htmlView;
- layoutManager;
- textStorage;
- (int)textContainerWidth;
- (int)textContainerHeight;
- (void)drawWithFrame:(struct _NSRect)fp12 inView:fp28 characterIndex:(unsigned int)fp32;
- (struct _NSRect)cellFrameForTextContainer:fp16 proposedLineFragment:(struct _NSRect)fp20 glyphPosition:(struct _NSPoint)fp32 characterIndex:(unsigned int)fp40;
- (struct _NSSize)cellMinimumSize;
- (struct _NSSize)cellMaximumSize;
- (char)trackMouse:fp12 inRect:(struct _NSRect)fp16 ofView:fp32 untilMouseUp:(char)fp35;
- (char)wantsToTrackMouse;
- mouseEntered;
- mouseMoved:fp12 inFrame:(struct _NSRect)fp16;
- (void)mouseExited;
- cursor;
- (void)setCursor:fp12;
- linkString;
- (void)setLinkString:fp12;
- (void)setUpContextMenuItem:fp12;
- (void)addSubclassItemsToMenu:fp12;
- (char)validateMenuItem:fp12;
- menuForEvent:fp12 inFrame:(struct _NSRect)fp16;

@end

@interface HTMLAnchorMarkAttachmentCell:HTMLAttachmentCell
{
}

- (void)drawWithFrame:(struct _NSRect)fp12 inView:fp28 characterIndex:(unsigned int)fp32 selected:(char)fp35;
- (struct _NSRect)cellFrameForProposedLineFragment:(struct _NSRect)fp16 glyphPosition:(struct _NSPoint)fp28 characterIndex:(unsigned int)fp36;

@end

@interface HTMLAnchor(HTMLRendering)
- personalizeRenderingState:fp12 copyIfChanging:(char)fp16;
- (void)appendRenderedHtmlPrologueWithState:fp12 toRendering:fp16;
@end

@interface HTMLApplet:HTMLNode
{
    NSImage *_image;
}

+ appletImage;
- marker;
- image;
- (void)setImage:fp12;
- height;
- widthString;
- (char)getWidth:(unsigned int *)fp12 percentage:(char *)fp16;
- horizontalSpace;
- verticalSpace;
- borderSize;
- appletClassName;
- (void)removedFromTree;
- (void)renderingDidChange;
- (void)dealloc;
- _imageCellWithState:fp12;
- (void)appendRenderedHtmlWithState:fp12 toRendering:fp16;
- (void)childWidthsInvalid;

@end

@interface HTMLArea:HTMLMarkedItem
{
}

- marker;
- (char)noHref;
- href;
- hrefUrl;
- target;
- (int)shape;
- coordinates;
- (char)containsLocation:(struct _NSPoint)fp12 inFrame:(struct _NSRect)fp20;
- (char)isBooleanAttribute:fp12;

@end

@interface HTMLBase:HTMLMarkedItem
{
    NSURL *_uniquedHREF;
}

- marker;
- (void)setParent:fp12;
- href;
- (void)dealloc;
- url;
- target;
- (void)valueOfAttribute:fp12 changedFrom:fp16 to:fp20;

@end

@interface HTMLBaseFont:HTMLMarkedItem
{
}

- marker;
- sizeString;
- (void)addBaseFontToState:fp12;
- (void)appendRenderedHtmlWithState:fp12 toRendering:fp16;

@end

@interface HTMLBody:HTMLNode
{
    NSString *_marker;
    NSImage *_backgroundImage;
}

+ defaultTextColor;
+ defaultBackgroundColor;
+ defaultLinkColor;
+ defaultActiveLinkColor;
+ defaultVisitedLinkColor;
- marker;
- initWithMarker:fp12 attributes:fp16;
- (void)setParent:fp12;
- (void)awakeWithDocument:fp12;
- (void)valueOfAttribute:fp12 changedFrom:fp16 to:fp20;
- backgroundImageUrl;
- backgroundImageUrlString;
- _backgroundImage;
- backgroundImage;
- (void)dealloc;
- textColor;
- backgroundColor;
- linkColor;
- activeLinkColor;
- visitedLinkColor;
- (int)leftMargin;
- (int)topMargin;

@end

@interface HTMLBody(HTMLRenderingRoots)
- (char)isRenderingRoot;
- newRenderingRootState;
- renderingRootLayoutManagerWithSize:(struct _NSSize *)fp12;
- (struct _NSPoint)renderingRootOrigin;
- (char)renderingRootContextSetUp;
@end

@interface HTMLBody(HTMLRendering)
- (void)URLResourceDidFinishLoading:fp12;
- (void)URL:fp12 resourceDidFailLoadingWithReason:fp16;
- personalizeRenderingState:fp12 copyIfChanging:(char)fp16;
- (void)drawBackgroundInRect:(struct _NSRect)fp12;
- approximateBackgroundColor;
@end

@interface HTMLInput:HTMLMarkedItem
{
    HTMLProxyAttachmentCell *_proxyCell;
}

+ instantiateWithMarker:fp12 attributes:fp16;
- initWithMarker:fp12 attributes:fp16;
- (void)dealloc;
- (void)removedFromTree;
- marker;
- name;
- form;
- (int)inputType;
- value;
- (char)checked;
- (char)isEnabled;
- (unsigned int)inputSize;
- (unsigned int)maxLength;
- source;
- drawingProxyCellForAttachmentCell:fp12;
- (void)doneWithDrawingProxyCell:fp12;
- (struct _NSRect)drawingProxyFrameForAttachmentCell:fp16;
- (char)isBooleanAttribute:fp12;
- (void)attachmentCell:fp12 singleClickEvent:fp16 inTextView:fp20 withFrame:(struct _NSRect)fp20;
- (void)attachmentCell:fp12 doubleClickEvent:fp16 inTextView:fp20 withFrame:(struct _NSRect)fp20;
- (void)cellAction:fp12;

@end

@interface HTMLCheckboxInput:HTMLInput
{
    HTMLLabel *_labelItem;
    int _userCheckedSet:1;
    int _userChecked:1;
    int _resetChecked:1;
}

- (void)awakeWithDocument:fp12;
- drawingProxyCellForAttachmentCell:fp12;
- (void)doneWithDrawingProxyCell:fp12;
- (void)cellAction:fp12;
- (void)resetFormElements;
- (void)setLabel:fp12;
- (char)isSuccessful;
- submitValue;

@end

@interface HTMLDefinition:HTMLNode
{
}

- marker;
- (char)needsLeadingBlockCharacters;
- (char)needsTrailingBlockCharacters;
- (char)hasLeadingSpaceWithSemanticEngine:fp12;
- (char)hasTrailingSpaceWithSemanticEngine:fp12;
- personalizeRenderingState:fp12 copyIfChanging:(char)fp16;
- (unsigned short)minimumWidth;
- (unsigned short)maximumWidth;
- (void)addLeadingBlockCharactersForChild:fp12 toRendering:fp16 withState:fp20;
- (void)addTrailingBlockCharactersForChild:fp12 toRendering:fp16 withState:fp20 contentLength:(int)fp24;

@end

@interface HTMLDefinitionTerm:HTMLNode
{
}

- marker;
- (char)needsLeadingBlockCharacters;
- (char)needsTrailingBlockCharacters;
- (char)hasLeadingSpaceWithSemanticEngine:fp12;
- (char)hasTrailingSpaceWithSemanticEngine:fp12;

@end

@interface HTMLDefinitionList:HTMLNode
{
}

- marker;
- (void)addLeadingBlockCharactersForChild:fp12 toRendering:fp16 withState:fp20;
- (void)addTrailingBlockCharactersForChild:fp12 toRendering:fp16 withState:fp20 contentLength:(int)fp24;
- (char)isBooleanAttribute:fp12;

@end

@interface HTMLSmall:HTMLTextNode
{
}

- personalizeRenderingState:fp12 copyIfChanging:(char)fp16;

@end

@interface HTMLBig:HTMLTextNode
{
}

- personalizeRenderingState:fp12 copyIfChanging:(char)fp16;

@end

@interface HTMLFont:HTMLTextNode
{
}

+ fontWithSize:(int)fp12;
+ fontWithSizeIncrease:(int)fp12;
+ fontWithSizeDecrease:(int)fp12;
+ fontBigger;
+ fontSmaller;
+ fontWithColor:fp12;
+ fontWithFaceString:fp12;
- (void)dealloc;
- (int)size;
- sizeString;
- color;
- colorString;
- faceString;
- personalizeRenderingState:fp12 copyIfChanging:(char)fp16;

@end

@interface HTMLForm:HTMLNode
{
}

- marker;
- action;
- actionUrl:fp12;
- (int)method;
- encodingType;
- nextFieldFromItem:fp12;
- previousFieldFromItem:fp12;
- submitButton;
- _successfulControlsWithButton:fp12;
- _encodedValuesForControls:fp12;
- (void)submitWithButton:fp12 inHTMLView:fp16;

@end

@interface HTMLFrame:HTMLMarkedItem <HTMLFrame>
{
}

- marker;
- (int)marginHeight;
- (int)marginWidth;
- (char)noResize;
- (char)frameBorder;
- (int)scrolling;
- sourceUrl;
- (char)hasSource;
- sourceUrlString;
- name;

@end

@interface HTMLFrameset:HTMLNode
{
    NSMutableArray *_subelements;
}

- marker;
- (void)setParent:fp12;
- (void)dealloc;
- rowsString;
- colsString;
- (int)columnCount;
- (int)rowCount;
- (int)_valueForIndex:(int)fp12 inString:fp16 returningSizeType:(int *)fp20;
- (int)widthForColumnAtIndex:(int)fp12 returningWidthType:(int *)fp16;
- (int)heightForRowAtIndex:(int)fp12 returningHeightType:(int *)fp16;
- (void)addSubelementsFoundUnderNode:fp12 toArray:fp16;
- subelements;
- (void)addedChild:fp12;
- (void)removedChild:fp12;
- (void)didAddChildAtIndex:(unsigned int)fp12;
- (void)didRemoveChild:fp12 atIndex:(unsigned int)fp16;
- (void)descendant:fp12 didAddChildAtIndex:(unsigned int)fp16 immediateChild:fp20;
- (void)descendant:fp12 didRemoveChild:fp16 atIndex:(unsigned int)fp20 immediateChild:fp24;

@end

@interface HTMLHead:HTMLNode
{
}

- (void)setParent:fp12;
- marker;

@end

@interface HTMLHeader:HTMLNode <HTMLTextAlignableItem>
{
    int _headerLevel;
}

- initWithMarker:fp12 attributes:fp16;
- marker;
- initWithHeaderLevel:(int)fp12;
- (int)headerLevel;
- (int)textAlignment;
- _markerForHeaderLevel:(int)fp12;
- (int)_headerLevelForMarker:fp12;

@end

@interface HTMLHeader(HTMLRendering)
- personalizeRenderingState:fp12 copyIfChanging:(char)fp16;
@end

@interface HTMLHorizontalRuleCell:HTMLAttachmentCell
{
}

+ attachmentCellWithHorizontalRule:fp12;
- initWithHorizontalRule:fp12;
- (void)drawWithFrame:(struct _NSRect)fp12 inView:fp28 characterIndex:(unsigned int)fp32 selected:(char)fp35;
- (struct _NSRect)cellFrameForProposedLineFragment:(struct _NSRect)fp16 glyphPosition:(struct _NSPoint)fp28 characterIndex:(unsigned int)fp36;

@end

@interface HTMLHorizontalRule:HTMLMarkedItem <HTMLTextAlignableItem>
{
}

- marker;
- widthString;
- (char)getWidth:(unsigned int *)fp12 percentage:(char *)fp16;
- (unsigned int)height;
- (char)showsShade;
- (int)textAlignment;
- (char)hasLeadingSpaceWithSemanticEngine:fp12;
- (char)hasTrailingSpaceWithSemanticEngine:fp12;
- (char)isBooleanAttribute:fp12;

@end

@interface HTMLHorizontalRule(HTMLRendering)
- (void)appendRenderedHtmlWithState:fp12 toRendering:fp16;
@end

@interface HTMLHTML:HTMLNode
{
}

- (void)setParent:fp12;
- marker;

@end

@interface HTMLImage:HTMLMarkedItem
{
    HTMLOutliningCell *_imageCell;
    NSImage *_scaledImage;
    NSImage *_image;
}

+ (void)setDelegate:fp12;
+ delegate;
- marker;
- (void)dealloc;
- sourceUrl;
- sourceUrlString;
- image;
- heightString;
- (char)getHeight:(unsigned int *)fp12 percentage:(char *)fp16;
- widthString;
- (char)getWidth:(unsigned int *)fp12 percentage:(char *)fp16;
- (char)serverSideImageMap;
- clientSideImageMapName;
- horizontalSpace;
- verticalSpace;
- borderSize;
- alignment;
- alternateText;
- (char)isBooleanAttribute:fp12;
- (char)_floating;
- (char)hasLeadingSpaceWithSemanticEngine:fp12;
- (char)hasTrailingSpaceWithSemanticEngine:fp12;
- (unsigned int)removeLeadingSpaceWithSemanticEngine:fp12;
- (unsigned int)removeTrailingSpaceWithSemanticEngine:fp12;

@end

@interface HTMLImage(HTMLRendering)
- (void)removedFromTree;
- (void)renderingDidChange;
- (void)_regenerateImageCell;
- (void)URLResourceDidFinishLoading:fp12;
- (void)URL:fp12 resourceDidFailLoadingWithReason:fp16;
- _imageCellWithState:fp12;
- (void)appendRenderedHtmlWithState:fp12 toRendering:fp16;
@end

@interface HTMLImageInput:HTMLInput
{
    NSImage *_renderedImage;
    NSImage *_image;
}

- sourceUrl;
- sourceUrlString;
- (char)serverSideImageMap;
- clientSideImageMapName;
- image;
- (void)dealloc;
- (void)removedFromTree;
- (void)renderingDidChange;
- (void)URLResourceDidFinishLoading:fp12;
- (void)URL:fp12 resourceDidFailLoadingWithReason:fp16;
- _renderedImage;
- drawingProxyCellForAttachmentCell:fp12;
- (void)doneWithDrawingProxyCell:fp12;
- (struct _NSRect)drawingProxyFrameForAttachmentCell:fp16;
- (void)cellAction:fp12;
- (void)performClick:fp12 withTextView:fp16;
- (void)attachmentCell:fp12 singleClickEvent:fp16 inTextView:fp20 withFrame:(struct _NSRect)fp20;
- (char)isSuccessful;

@end

@interface HTMLImageInput(HTMLRendering)
- (void)appendRenderedHtmlWithState:fp12 toRendering:fp16;
@end

@interface HTMLInlineFrame:HTMLNode <HTMLFrame>
{
    HTMLFrameView *_frameView;
}

- marker;
- (void)dealloc;
- (int)marginHeight;
- (int)marginWidth;
- (char)frameBorder;
- (int)scrolling;
- height;
- widthString;
- (char)getWidth:(unsigned int *)fp12 percentage:(char *)fp16;
- alignment;
- sourceUrl;
- (char)hasSource;
- sourceUrlString;

@end

@interface HTMLInlineFrame(HTMLRendering)
- (void)attachmentCell:fp12 doubleClickEvent:fp16 inTextView:fp20 withFrame:(struct _NSRect)fp20;
- (void)appendRenderedHtmlWithState:fp12 toRendering:fp16;
- (void)childWidthsInvalid;
@end


@interface HTMLInput(HTMLRendering)
- (void)appendRenderedHtmlWithState:fp12 toRendering:fp16;
@end

@interface HTMLLineBreak:HTMLMarkedItem
{
}

+ lineBreak;
- marker;
- (int)breakClear;
- (void)appendRenderedHtmlWithState:fp12 toRendering:fp16;
- (char)hasLeadingSpaceWithSemanticEngine:fp12;
- (char)hasTrailingSpaceWithSemanticEngine:fp12;

@end

@interface HTMLLineBreakClearAttachmentCell:HTMLAttachmentCell
{
}

+ attachmentCellForLineBreak:fp12;
- (void)drawWithFrame:(struct _NSRect)fp12 inView:fp28 characterIndex:(unsigned int)fp32 selected:(char)fp35;
- (struct _NSRect)cellFrameForProposedLineFragment:(struct _NSRect)fp16 glyphPosition:(struct _NSPoint)fp28 characterIndex:(unsigned int)fp36;

@end

@interface HTMLLink:HTMLMarkedItem
{
}

- marker;

@end

@interface HTMLList:HTMLNode
{
    NSMutableArray *_listItemCache;
    int _cachedIndent;
}

- (void)dealloc;
- (char)isBooleanAttribute:fp12;
- (void)_buildCache;
- (void)_invalidateCache;
- (void)removedFromTree;
- (void)didAddChildAtIndex:(unsigned int)fp12;
- (void)didRemoveChild:fp12 atIndex:(unsigned int)fp16;
- (void)descendant:fp12 didAddChildAtIndex:(unsigned int)fp16 immediateChild:fp20;
- (void)descendant:fp12 didRemoveChild:fp16 atIndex:(unsigned int)fp20 immediateChild:fp24;
- (void)descendantDidChange:fp12 immediateChild:fp16;
- (void)_widthsInvalid;

@end

@interface HTMLOrderedList:HTMLList
{
}

- marker;
- (int)orderingType;
- (unsigned int)startingIndex;
- (unsigned int)_indexValueForListItem:fp12;
- bulletStringForListItem:fp12;

@end

@interface HTMLUnorderedList:HTMLList
{
    NSString *_marker;
}

- marker;
- initWithMarker:fp12 attributes:fp16;
- (void)dealloc;
- bulletStringForListItem:fp12;

@end

@interface HTMLList(HTMLRendering)
- (int)indentForListItemsWithState:fp12;
- personalizeRenderingState:fp12 copyIfChanging:(char)fp16;
- (unsigned short)minimumWidth;
- (unsigned short)maximumWidth;
- (void)addLeadingBlockCharactersForChild:fp12 toRendering:fp16 withState:fp20;
- (void)addTrailingBlockCharactersForChild:fp12 toRendering:fp16 withState:fp20 contentLength:(int)fp24;
- bulletStringForListItem:fp12;
- (unsigned int)outdentForListItem:fp12 withState:fp16;
@end

@interface HTMLNode(HTMLListExtensions)
- (void)_addListItemsToArray:fp12;
@end

@interface HTMLListItem:HTMLNode
{
}

- marker;
- itemBulletString;
- (unsigned int)indexValue;
- list;
- (char)hasLeadingSpaceWithSemanticEngine:fp12;
- (char)hasTrailingSpaceWithSemanticEngine:fp12;

@end

@interface HTMLListItem(HTMLRendering)
- bulletString;
- (void)appendRenderedHtmlPrologueWithState:fp12 toRendering:fp16;
- (void)appendRenderedChildrenWithState:fp12 toString:fp16;
- (char)alignmentCouldBeEffectedByDescendant:fp12;
- (void)descendantDidChange:fp12 immediateChild:fp16;
- (void)descendant:fp12 didAddChildAtIndex:(unsigned int)fp16 immediateChild:fp20;
- (void)descendant:fp12 didRemoveChild:fp16 atIndex:(unsigned int)fp20 immediateChild:fp24;
- (void)addLeadingBlockCharactersForChild:fp12 toRendering:fp16 withState:fp20;
- (void)addTrailingBlockCharactersForChild:fp12 toRendering:fp16 withState:fp20 contentLength:(int)fp24;
- (unsigned int)numDesiredBlockReturns;
@end

@interface HTMLMap:HTMLNode
{
}

- marker;
- name;
- areaItemForLocation:(struct _NSPoint)fp12 inFrame:(struct _NSRect)fp20;

@end

@interface HTMLMeta:HTMLMarkedItem
{
}

- marker;

@end

@interface HTMLOption:HTMLNode <HTMLSelectOption>
{
    int _userSelectedSet:1;
    int _userSelected:1;
    int _resetSelected:1;
}

- (void)dealloc;
- marker;
- (char)isEnabled;
- (char)_selected;
- (void)_setSelected:(char)fp12 isOriginalValue:(char)fp16;
- (char)selected;
- value;
- label;
- childString;
- (char)isBooleanAttribute:fp12;
- form;
- select;
- optionGroup;
- (void)resetFormElements;
- (char)isSuccessful;
- submitValue;
- name;
- (void)optionSelected:fp12;
- (void)addMenuItemToPopUp:fp12;
- (void)configureBrowserCell:fp12;
- displayString;

@end

@interface HTMLParagraphNode:HTMLNode
{
    NSString *_marker;
}

- marker;
- initWithMarker:fp12 attributes:fp16;
- (void)dealloc;

@end

@interface HTMLDivision:HTMLParagraphNode <HTMLTextAlignableItem>
{
    char _isCenter;
    int _alignment;
}

- initWithMarker:fp12 attributes:fp16;
- marker;
- (void)valueOfAttribute:fp12 changedFrom:fp16 to:fp20;
- (int)textAlignment;
- personalizeRenderingState:fp12 copyIfChanging:(char)fp16;
- (unsigned int)numDesiredBlockReturns;

@end

@interface HTMLPreformatted:HTMLParagraphNode
{
}

- (void)correctWhiteSpaceWithSemanticEngine:fp12;
- (char)hasLeadingSpaceWithSemanticEngine:fp12;
- (char)hasTrailingSpaceWithSemanticEngine:fp12;
- (unsigned int)removeLeadingSpaceWithSemanticEngine:fp12;
- (unsigned int)removeTrailingSpaceWithSemanticEngine:fp12;
- personalizeRenderingState:fp12 copyIfChanging:(char)fp16;

@end

@interface HTMLBlockQuote:HTMLParagraphNode
{
}

- personalizeRenderingState:fp12 copyIfChanging:(char)fp16;
- (unsigned short)minimumWidth;
- (unsigned short)maximumWidth;

@end

@interface HTMLAddress:HTMLParagraphNode
{
}

- personalizeRenderingState:fp12 copyIfChanging:(char)fp16;

@end

@interface HTMLParagraph:HTMLParagraphNode <HTMLTextAlignableItem>
{
    int _alignment;
}

- (void)valueOfAttribute:fp12 changedFrom:fp16 to:fp20;
- (int)textAlignment;

@end

@interface HTMLParagraph(HTMLRendering)
- personalizeRenderingState:fp12 copyIfChanging:(char)fp16;
@end

@interface HTMLParam:HTMLMarkedItem
{
}

- marker;
- nameString;
- valueString;

@end

@interface HTMLRadioButtonInput:HTMLInput
{
    HTMLLabel *_labelItem;
    int _userCheckedSet:1;
    int _userChecked:1;
    int _resetChecked:1;
}

- (void)awakeWithDocument:fp12;
- drawingProxyCellForAttachmentCell:fp12;
- (void)doneWithDrawingProxyCell:fp12;
- (void)cellAction:fp12;
- (void)resetFormElements;
- (void)setLabel:fp12;
- (char)isSuccessful;
- submitValue;

@end

@interface HTMLResetButtonInput:HTMLInput
{
}

- displayString;
- drawingProxyCellForAttachmentCell:fp12;
- (void)doneWithDrawingProxyCell:fp12;
- (struct _NSRect)drawingProxyFrameForAttachmentCell:fp16;
- (void)cellAction:fp12;

@end

@interface HTMLNode(HTMLFormReset)
- (void)resetFormElements;
@end

@interface HTMLItem(HTMLFormReset)
- (void)resetFormElements;
@end

@interface HTMLScript:HTMLNode
{
}

- marker;
- scriptStringItem;
- scriptString;
- type;
- (char)browserMayDeferScript;
- (char)isBooleanAttribute:fp12;

@end

@interface HTMLScript(HTMLRendering)
- renderedScript;
- (void)appendRenderedHtmlWithState:fp12 toRendering:fp16;
@end

@interface HTMLScriptString:HTMLItem
{
    NSString *_script;
}

- initWithScript:fp12;
- (void)dealloc;
- script;
- (unsigned int)length;

@end

@interface HTMLScriptString(HTMLRendering)
- (void)appendRenderedHtmlWithState:fp12 toRendering:fp16;
@end

@interface HTMLScriptString(HTMLGeneration)
- (void)appendHTMLEquivalent:fp12;
@end

@interface HTMLSelect:HTMLNode <HTMLOptionContainer>
{
}

- (void)awakeWithDocument:fp12;
- marker;
- name;
- (char)multiple;
- (char)isEnabled;
- form;
- (int)_preferredRowsToDisplay;
- (unsigned int)numberOfVisibleItems;
- (int)widestOptionWidthForPopUp:(char)fp12;
- drawingProxyViewForAttachmentCell:fp12;
- (void)doneWithDrawingProxyView:fp12;
- (struct _NSRect)drawingProxyFrameForAttachmentCell:fp16;
- options;
- selectedOptions;
- (void)browser:fp12 createRowsForColumn:(int)fp16 inMatrix:fp20;
- (void)browserDidScroll:fp12;
- (void)attachmentCell:fp12 singleClickEvent:fp16 inTextView:fp20 withFrame:(struct _NSRect)fp20;
- (void)attachmentCell:fp12 doubleClickEvent:fp16 inTextView:fp20 withFrame:(struct _NSRect)fp20;
- (char)isBooleanAttribute:fp12;

@end

@interface HTMLSelect(HTMLRendering)
- (void)appendRenderedHtmlWithState:fp12 toRendering:fp16;
@end

@interface HTMLSGMLMarker:HTMLMarkedItem
{
    NSString *_marker;
}

- initWithMarker:fp12 attributes:fp16;
- (void)dealloc;
- marker;

@end

@interface HTMLSpan:HTMLNode
{
}

- marker;

@end

@interface HTMLSubmitButtonInput:HTMLInput
{
    int _performingClick:1;
    int _performClickHighlight:1;
}

- displayString;
- drawingProxyCellForAttachmentCell:fp12;
- (void)doneWithDrawingProxyCell:fp12;
- (struct _NSRect)drawingProxyFrameForAttachmentCell:fp16;
- (void)cellAction:fp12;
- (void)performClick:fp12 withTextView:fp16;
- (char)isSuccessful;

@end

@interface HTMLTableEnumerator:NSObject
{
    HTMLTable *_table;
    int _structureHash;
    struct _HTMLTableDimension _dims;
    int _row;
    int _col;
    int _index;
    int *_depths;
    NSArray *_rows;
    int _rowsCount;
    NSArray *_rowDatas;
    int _rowDatasCount;
}

- initWithTable:fp12;
- (void)dealloc;
- nextTableData;
- (void)reset;
- (char)spoolToTableData:fp12;
- (int)currentRow;
- (int)currentColumn;

@end

@interface HTMLTable:HTMLNode <HTMLTextAlignableItem>
{
    HTMLTableAttachmentCell *_renderCell;
    HTMLRenderingState *_measuringRenderingState;
    int _measuringRenderingStateID;
    HTMLRenderingState *_noMeasuringRenderingState;
    int _noMeasuringRenderingStateID;
    HTMLRenderingState *_maxMeasuringRenderingState;
    int _maxMeasuringRenderingStateID;
    int _structureHash;
    HTMLTableCaption *_caption;
    NSMutableArray *_rows;
    struct _HTMLTableDimension _dims;
    struct _HTMLTableDimension _effectiveDims;
    NSMutableArray *_tableDatas;
}

- (void)clearCaches;
- (void)tableStructureChanged;
- (int)_structureHash;
- initWithMarker:fp12 attributes:fp16;
- (void)removedFromTree;
- (void)dealloc;
- marker;
- (void)valueOfAttribute:fp12 changedFrom:fp16 to:fp20;
- (int)border;
- (int)cellSpacing;
- (int)cellPadding;
- (int)innerBorder;
- widthString;
- (char)getWidth:(unsigned int *)fp12 percentage:(char *)fp16;
- (int)height;
- (int)textAlignment;
- backgroundColorString;
- backgroundColor;
- (void)addRowsFoundUnderNode:fp12 toArray:fp16;
- rows;
- findCaptionUnderNode:fp12;
- caption;
- (struct _HTMLTableDimension)dimensions;
- (struct _HTMLTableDimension)effectiveDimensions;
- (struct _HTMLTableDimension)tableDecorationSize;
- (struct _HTMLTableDimension)dataDecorationSize;
- tableDatas;
- (int)numberOfTableDatas;
- tableEnumerator;

@end

@interface HTMLTableAttachmentCell:HTMLAttachmentCell <HTMLMouseTrackingAttachment>
{
    int _lastContainerWidth;
    struct _HTMLTableDimension _size;
    id _lastEnteredCell;
    int _pushedFinger:1;
    int _sizeCachesInvalid:1;
    int _imageCacheInvalid:1;
    int _noImageCache:1;
    int _captionHeight;
    int *_colWidths;
    int *_rowHeights;
    int *_colOrigins;
    int *_rowOrigins;
    NSImage *_cache;
    int _sizeBufferCheckoutCount;
    unsigned short _minimumWidth;
    unsigned short _maximumWidth;
}

- (void)clearImageCache;
- (void)clearSizeCache;
- initWithRepresentedItem:fp12;
- (void)dealloc;
- backgroundColorForCell:fp12;
- darkBorderColorForCell:fp12;
- lightBorderColorForCell:fp12;
- borderColorForCell:fp12;
- (void)fillTableDecorationPathWithFrame:(struct _NSRect)fp12 pathIsCellsWithContent:(char)fp28 inCache:(char)fp32;
- (void)drawRect:(struct _NSRect)fp12 inCache:(char)fp28;
- (char)shouldDrawUsingImageCacheForCellFrame:(struct _NSRect)fp12 controlView:fp28;
- (void)drawWithFrame:(struct _NSRect)fp12 inView:fp28 characterIndex:(unsigned int)fp32 selected:(char)fp35;
- (void)sizeSimpleCellsEnMasse;
- (struct _NSSize)cellSizeWithTextContainerWidth:(int)fp16 forLockState:(int)fp20;
- (struct _NSSize)cellSizeWithTextContainerWidth:(int)fp16;
- (struct _NSRect)cellFrameForProposedLineFragment:(struct _NSRect)fp16 glyphPosition:(struct _NSPoint)fp28 characterIndex:(unsigned int)fp36;
- (int)minimumWidth;
- (int)maximumWidth;
- (struct _NSSize)cachedCellSize;
- dataContainingPoint:(struct _NSPoint)fp12 withFrame:(struct _NSRect *)fp20 allowingPadHits:(char)fp24;
- (struct _NSRect)contentFrameForData:fp16 givenFrame:(struct _NSRect)fp20 textStorage:(id *)fp32 layoutManager:(id *)fp36;
- (void)click:fp12 inFrame:(struct _NSRect)fp16 notifyingHTMLView:fp32 orTextView:fp32;
- (void)windowLocation:(struct _NSPoint)fp12 inFrame:(struct _NSRect)fp20 hitRoot:(id *)fp32 atPosition:(unsigned int *)fp36 fraction:(float *)fp40;
- menuForEvent:fp12 inFrame:(struct _NSRect)fp16;
- mouseEntered;
- mouseMoved:fp12 inFrame:(struct _NSRect)fp16;
- (void)mouseExited;
- (int *)_checkOutColumnWidths;
- (int *)_checkOutRowHeights;
- (int *)_checkOutColumnOrigins;
- (int *)_checkOutRowOrigins;
- (void)_checkInSizeBuffer;
- (int)captionHeight;
- table;

@end

@interface HTMLTableCell:HTMLNode
{
    HTMLItem *_simpleChild;
    NSTextStorage *_cellTextStorage;
    int _hasMeasuredContents:1;
    int _simpleChildNeedsMeasure:1;
    int _haveLookedForSimpleChild:1;
    int _isSimple:1;
    int _textStorageBusyCount:4;
    int _knowsHasContent:1;
    int _hasContent:1;
    int _isHeader:1;
    int _hasRetainedBackgroundImage:1;
    unsigned char _effectiveColumnSpan;
    unsigned char _colSpan;
}

- initWithMarker:fp12 attributes:fp16;
- (void)setParent:fp12;
- (void)_disposeTextObjects;
- (void)removedFromTree;
- (void)dealloc;
- (void)tableStructureChanged;
- (void)_cellChanged;
- (void)cellChanged;
- (void)globalRenderingBasisDidChange;
- table;
- (char)hasContent;
- (int)padding;
- (char)contentsWrap;
- (char)suppressFinalBlockCharacters;
- (void)_cacheSimpleChild;
- simpleChild;
- (char)isSimple;
- (char)isSimpleAndNeedsMeasuring;
- (unsigned short)minimumWidth;
- (unsigned short)maximumWidth;
- (unsigned short)minimumHeightForWidth:(int)fp12;
- (void)childWidthsInvalid;
- (void)widthsInvalid;
- (void)subtreeWidthsInvalid;
- (int)effectiveAlignment;
- (int)effectiveVerticalAlignment;
- backgroundColor;
- effectiveBackgroundColor;
- backgroundImage;
- (void)drawBackgroundInRect:(struct _NSRect)fp12;
- approximateBackgroundColor;
- (struct _NSRect)_cellContentRectForUsedSize:(struct _NSSize)fp16 inFrame:(struct _NSRect)fp20;
- (void)drawWithOuterFrame:(struct _NSRect)fp12 contentFrame:(struct _NSRect)fp24 clipping:(struct _NSRect)fp40;
- (void)_generateTextStorage;
- (void)_measuredContents;
- textStorageWithSize:(struct _NSSize)fp12;
- (void)_shareTextStorage;
- (void)doneWithTextStorage;

@end

@interface HTMLTableCaption:HTMLTableCell <HTMLTextAlignableItem>
{
}

- marker;
- (int)padding;
- (unsigned short)minimumHeightForWidth:(int)fp12;
- (int)textAlignment;
- (int)effectiveAlignment;
- (int)effectiveVerticalAlignment;
- (int)alignment;

@end


@interface HTMLTableCell(HTMLRenderingRoots)
- (char)isRenderingRoot;
- newRenderingRootState;
- renderingRootLayoutManagerWithSize:(struct _NSSize *)fp12;
- (void)doneWithRenderingRootLayoutManager;
- (unsigned int)renderingRootIndex;
- (unsigned int)renderingRootLength;
- (struct _NSPoint)renderingRootOrigin;
- (char)renderingRootContextSetUp;
@end

@interface HTMLTableCell(HTMLRendering)
- personalizeRenderingState:fp12 copyIfChanging:(char)fp16;
- (unsigned int)numDesiredBlockReturns;
@end

@interface HTMLTableCell(HTMLTreeChangeNotifications)
- (void)didAddChildAtIndex:(unsigned int)fp12;
- (void)didRemoveChild:fp12 atIndex:(unsigned int)fp16;
- (void)renderingDidChange;
- (void)descendantRenderingDidChange:fp12 immediateChild:fp16;
- (void)descendant:fp12 didAddChildAtIndex:(unsigned int)fp16 immediateChild:fp20;
- (void)descendant:fp12 didRemoveChild:fp16 atIndex:(unsigned int)fp20 immediateChild:fp24;
@end

@interface HTMLTextView(HTMLPatching)
- (void)settingFrameDuringCellAdjustment:(char)fp12;
- (void)_centeredScrollRectToVisible:(struct _NSRect)fp12 forceCenter:(char)fp28;
@end

@interface HTMLTableData:HTMLTableCell <HTMLTextAlignableItem>
{
    unsigned short _effectiveRowSpan;
    unsigned short _rowSpan;
}

- initWithMarker:fp12 attributes:fp16;
- (void)dealloc;
- (void)tableStructureChanged;
- marker;
- (char)isHeader;
- row;
- (unsigned int)rowSpan;
- (unsigned int)columnSpan;
- (void)getRowSpan:(unsigned int *)fp12 columnSpan:(unsigned int *)fp16;
- (unsigned int)effectiveRowSpan;
- (unsigned int)effectiveColumnSpan;
- (void)setEffectiveRowSpan:(unsigned int)fp12;
- (void)setEffectiveColumnSpan:(unsigned int)fp12;
- widthString;
- (char)getWidth:(unsigned int *)fp12 percentage:(char *)fp16;
- heightString;
- (char)getHeight:(unsigned int *)fp12 percentage:(char *)fp16;
- (int)textAlignment;
- (int)cellTextAlignment;
- (int)verticalAlignment;
- backgroundColorString;
- backgroundColor;
- backgroundImageUrl;
- backgroundImageUrlString;
- (void)URLResourceDidFinishLoading:fp12;
- (void)URL:fp12 resourceDidFailLoadingWithReason:fp16;
- _backgroundImage;
- backgroundImage;
- (int)effectiveAlignment;
- (int)effectiveVerticalAlignment;
- effectiveBackgroundColor;
- (void)valueOfAttribute:fp12 changedFrom:fp16 to:fp20;
- (char)contentsWrap;
- (unsigned short)minimumHeightForWidth:(int)fp12;
- (char)isBooleanAttribute:fp12;

@end

@interface HTMLTableData(HTMLRendering)
- personalizeRenderingState:fp12 copyIfChanging:(char)fp16;
@end

@interface HTMLTableRow:HTMLNode <HTMLTextAlignableItem>
{
    NSMutableArray *_tableDatas;
    int _span;
}

- marker;
- (void)clearCaches;
- (void)tableStructureChanged;
- (void)dealloc;
- (void)addDatasFoundUnderNode:fp12 toArray:fp16;
- tableDatas;
- table;
- (int)textAlignment;
- (int)verticalAlignment;
- backgroundColorString;
- backgroundColor;
- (void)valueOfAttribute:fp12 changedFrom:fp16 to:fp20;

@end

@interface HTMLTable(HTMLRendering)
- (void)awakeWithDocument:fp12;
- (void)renderingDidChange;
- (void)didAddChildAtIndex:(unsigned int)fp12;
- (void)didRemoveChild:fp12 atIndex:(unsigned int)fp16;
- (void)reactToChangeInDescendant:fp12;
- (void)descendantRenderingDidChange:fp12 immediateChild:fp16;
- (char)structuralElementsInItem:fp12;
- (void)descendant:fp12 didAddChildAtIndex:(unsigned int)fp16 immediateChild:fp20;
- (void)descendant:fp12 didRemoveChild:fp16 atIndex:(unsigned int)fp20 immediateChild:fp24;
- attachmentCell;
- sharedAttachmentCell;
- (void)clearSizeCache;
- (void)clearImageCache;
- (void)appendRenderedHtmlWithState:fp12 toRendering:fp16;
- (char)_floating;
- (unsigned int)numDesiredBlockReturns;
- (void)clearRenderingStateCaches;
- newRenderingRootStateWithMeasuring:(int)fp12;
- lightBorderColor;
- darkBorderColor;
- tableColor;
- (struct _NSRect)frameForCell:fp16 withDecorations:(char)fp20;
- (unsigned short)minimumWidth;
- (unsigned short)maximumWidth;
- (void)childWidthsInvalid;
@end

@interface HTMLTextArea:HTMLNode
{
    NSString *_userContentString;
    HTMLProxyViewAttachmentCell *_proxyCell;
}

- (void)dealloc;
- (void)removedFromTree;
- marker;
- name;
- (char)isEnabled;
- (unsigned int)numberOfRows;
- (unsigned int)numberOfColumns;
- contentString;
- form;
- displayString;
- drawingProxyViewForAttachmentCell:fp12;
- (void)doneWithDrawingProxyView:fp12;
- (struct _NSRect)drawingProxyFrameForAttachmentCell:fp16;
- (void)attachmentCell:fp12 singleClickEvent:fp16 inTextView:fp20 withFrame:(struct _NSRect)fp20;
- (void)attachmentCell:fp12 doubleClickEvent:fp16 inTextView:fp20 withFrame:(struct _NSRect)fp20;
- (void)enterEditingInTextView:fp12;
- (char)textView:fp12 shouldChangeTextInRange:(struct _NSRange)fp16 replacementString:fp24;
- (char)textShouldEndEditing:fp12;
- (void)textDidEndEditing:fp12;
- (char)textShouldBeginEditing:fp12;
- (void)textDidBeginEditing:fp12;
- (void)textDidChange:fp12;
- (void)resetFormElements;
- (char)isSuccessful;
- submitValue;
- (char)isBooleanAttribute:fp12;

@end

@interface HTMLTextAreaTextView:NSTextView
{
}

- (void)insertTab:fp12;
- (void)insertBacktab:fp12;
- (void)resetCursorRects;
- (void)setSelectable:(char)fp12;
- _setSuperview:fp12;

@end

@interface HTMLTextArea(HTMLRendering)
- (void)appendRenderedHtmlWithState:fp12 toRendering:fp16;
@end

@interface HTMLTextFieldInput:HTMLInput
{
    NSString *_userInputString;
}

- (void)dealloc;
- displayStringForTextFieldCell:fp12;
- drawingProxyCellForAttachmentCell:fp12;
- (void)doneWithDrawingProxyCell:fp12;
- (struct _NSRect)drawingProxyFrameForAttachmentCell:fp16;
- (void)attachmentCell:fp12 singleClickEvent:fp16 inTextView:fp20 withFrame:(struct _NSRect)fp20;
- (void)attachmentCell:fp12 doubleClickEvent:fp16 inTextView:fp20 withFrame:(struct _NSRect)fp20;
- (void)enterEditingInTextView:fp12;
- (char)textView:fp12 shouldChangeTextInRange:(struct _NSRange)fp16 replacementString:fp24;
- (char)textShouldEndEditing:fp12;
- (void)textDidEndEditing:fp12;
- (char)textShouldBeginEditing:fp12;
- (void)textDidBeginEditing:fp12;
- (void)textDidChange:fp12;
- (void)resetFormElements;
- (char)isSuccessful;
- submitValue;
- (void)appendRenderedHtmlWithState:fp12 toRendering:fp16;
- (char)hasLeadingSpaceWithSemanticEngine:fp12;
- (char)hasTrailingSpaceWithSemanticEngine:fp12;
- (unsigned int)removeLeadingSpaceWithSemanticEngine:fp12;
- (unsigned int)removeTrailingSpaceWithSemanticEngine:fp12;

@end

@interface HTMLTextFieldTextView:NSTextView
{
}

- (void)resetCursorRects;
- (void)setSelectable:(char)fp12;
- _setSuperview:fp12;

@end

@interface NSText(HTMLClassTwiddling)
- (void)twiddleToHTMLTextFieldTextView;
- (void)twiddleToNSTextView;
@end

@interface NSString(HTMLTextInputExtensions)
+ stringWithRepeatedCharacter:(unsigned short)fp12 count:(int)fp16;
@end

@interface HTMLNoBreak:HTMLTextNode
{
}

- personalizeRenderingState:fp12 copyIfChanging:(char)fp16;

@end

@interface HTMLBlink:HTMLTextNode
{
}

- personalizeRenderingState:fp12 copyIfChanging:(char)fp16;

@end

@interface HTMLSuperscript:HTMLTextNode
{
}

- personalizeRenderingState:fp12 copyIfChanging:(char)fp16;

@end

@interface HTMLSubscript:HTMLTextNode
{
}

- personalizeRenderingState:fp12 copyIfChanging:(char)fp16;

@end

@interface HTMLFixedFont:HTMLTextNode
{
}

- personalizeRenderingState:fp12 copyIfChanging:(char)fp16;

@end

@interface HTMLStrikethrough:HTMLTextNode
{
}

- personalizeRenderingState:fp12 copyIfChanging:(char)fp16;

@end

@interface HTMLUnderline:HTMLTextNode
{
}

- personalizeRenderingState:fp12 copyIfChanging:(char)fp16;

@end

@interface HTMLItalics:HTMLTextNode
{
}

- personalizeRenderingState:fp12 copyIfChanging:(char)fp16;

@end

@interface HTMLBold:HTMLTextNode
{
}

- personalizeRenderingState:fp12 copyIfChanging:(char)fp16;

@end

@interface HTMLTitle:HTMLNode
{
}

- marker;
- (void)setParent:fp12;
- string;

@end

@interface HTMLNode(_HTMLPlainString)
- _plainString;
@end

@interface HTMLItem(_HTMLPlainString)
- _plainString;
@end

@interface HTMLString:HTMLItem
{
    NSString *_string;
    unsigned short _heightForMaximumWidth;
}

+ htmlStringWithString:fp12;
- (void)compactWhiteSpace;
- initWithString:fp12;
- (void)dealloc;
- string;
- (void)setString:fp12;
- (void)insertString:fp12 atLocation:(unsigned int)fp16;
- stringWithoutLeadingSpace;
- stringWithoutTrailingSpace;
- stringWithoutSpaceOnEnds;
- (char)hasLeadingSpaceWithSemanticEngine:fp12;
- (char)hasTrailingSpaceWithSemanticEngine:fp12;
- (unsigned int)removeLeadingSpaceWithSemanticEngine:fp12;
- (unsigned int)removeTrailingSpaceWithSemanticEngine:fp12;
- (unsigned int)length;

@end

@interface HTMLString(_HTMLPlainString)
- _plainString;
@end

@interface HTMLMarkedItem(HTMLInstantiationHandling)
+ instantiateWithMarker:fp12 attributes:fp16;
@end

@interface HTMLMarkedItem(HTMLTokenizing)
+ (void)loadRegistry;
+ (void)setHandler:fp12 forMarker:fp16;
+ (void)setHandler:fp12 forMarkers:fp16;
+ (Class)handlerForMarker:fp12;
+ (void)removeHandlerForMarker:fp12;
+ itemForMarker:fp12 attributes:fp16;
+ nodeForMarker:fp12 attributes:fp16;
+ itemForMarker:fp12 attributeString:fp16;
+ (void)attributePostSetIsSafe;
+ retainedItemForMarker:fp12 tokenizer:fp16;
- (void)tokenizeUsing:fp12;
@end

@interface HTMLFrameset(HTMLWhitespaceStripping)
- (int)skipWhitespace;
@end

@interface HTMLApplet(HTMLWhitespaceStripping)
- (int)skipWhitespace;
@end

@interface HTMLTitle(HTMLWhitespaceStripping)
- (int)skipWhitespace;
@end

@interface HTMLTableRow(HTMLWhitespaceStripping)
- (int)skipWhitespace;
@end

@interface HTMLTable(HTMLWhitespaceStripping)
- (int)skipWhitespace;
@end

@interface HTMLHead(HTMLWhitespaceStripping)
- (int)skipWhitespace;
@end

@interface HTMLHTML(HTMLWhitespaceStripping)
- (int)skipWhitespace;
@end

@interface HTMLPreformatted(HTMLWhitespaceStripping)
- (int)skipWhitespace;
@end

@interface HTMLTextNode(HTMLWhitespaceStripping)
- (int)skipWhitespace;
@end

@interface HTMLNode(HTMLWhitespaceStripping)
- (int)skipWhitespace;
@end

@interface HTMLTree:HTMLNode
{
    HTMLDocument *_document;
    HTMLHead *_head;
    HTMLBody *_body;
    HTMLHTML *_html;
    HTMLFrameset *_frameset;
    HTMLTitle *_title;
    HTMLBase *_base;
}

+ (void)initialize;
- initWithMarker:fp12 attributes:fp16;
- initWithDocument:fp12;
- document;
- (void)setDocument:fp12;
- (void)registerHead:fp12;
- (void)registerBody:fp12;
- (void)registerHTML:fp12;
- (void)registerFrameset:fp12;
- (void)registerTitle:fp12;
- (void)registerBase:fp12;
- documentFrameset;
- documentBase;
- (char)isFragment;
- (char)isFrameset;
- documentHead;
- documentBody;
- titleString;
- (void)appendHTMLEquivalent:fp12;
- (char)shouldAbsorbEdgeWhiteSpace;
- (char)correctWhitespaceForPasteWithPrecedingSpace:(char)fp12 followingSpace:(char)fp16;

@end

@interface HTMLTree(HTMLTokenizing)
- (char)isClosedByCloseTag:fp12;
- (char)isClosedByOpenTag:fp12;
- (char)isClosedByUnadaptableOpenTag:fp12;
@end

@interface HTMLUnknownMarkedNode:HTMLNode
{
    NSString *_marker;
}

- init;
- initWithMarker:fp12 attributes:fp16;
- (void)dealloc;
- marker;
- (void)setMarker:fp12;

@end

@interface HTMLUnknownMarkedNode(HTMLTokenizing)
- (void)tokenizeUsing:fp12;
@end

@interface HTMLNode(HTMLTokenizing)
- (char)isClosedByCloseTag:fp12;
- (char)isClosedByOpenTag:fp12;
- (char)isClosedByUnadaptableOpenTag:fp12;
- (void)tokenizeUsing:fp12;
@end

@interface HTMLTokenizer:NSObject
{
    NSString *_htmlString;
    unsigned short *_buffer;
    unsigned int _buffer_len;
    int _state;
    unsigned short *_mark;
    unsigned short *_tagmark;
    int _nextTokenType;
    NSString *_nextToken;
    struct _NSRange _nextTokenAttributesRange;
    unsigned int _nextTokenAttributeCount;
    NSString *_nextTokenAttributes;
    unsigned int _nextTokenIndex;
    unsigned int _nextTokenAttributesIndex;
    unsigned int _nextTokenEndIndex;
    char _nextTokenRetained;
    char _nextTokenAttributesMayUseBuffer;
    int _skipWhitespace;
    int _preformattedBlockCount;
}

+ (void)initialize;
+ (int)weightOfTag:fp12;
+ (char)parentMarker:fp12 mayCloseTag:fp16;
+ (char)isTag:fp12 closedByOpenTag:fp16;
+ (char)optionalCloseTag:fp12;
- initWithString:fp12;
- (void)dealloc;
- (void)setSkipWhitespace:(int)fp12;
- (int)skippingWhitespace;
- (void)enteringPreformattedBlock;
- (void)exitingPreformattedBlock;
- (void)walkOver;
- (void)_nextToken;
- (int)peekNextTokenType;
- (int)nextTokenType;
- peekNextToken;
- nextToken;
- nextTokenAttributes;
- (void)setNextTokenAttributeDictionaryForItem:fp12;
- (void)previousToken;
- (unsigned int)indexOf:fp12 options:(unsigned int)fp16;
- (unsigned int)scanUpToString:fp12 options:(unsigned int)fp16;
- (unsigned int)currentIndex;
- (void)setCurrentIndex:(unsigned int)fp12;
- (unsigned int)tokenIndex;
- (unsigned int)endTokenIndex;
- (unsigned int)attributesIndex;

@end

@interface NSString(HTMLAttributeExtensions)
+ uppercasedRetainedStringWithCharacters:(const unsigned short *)fp12 length:(unsigned int)fp16;
- newAttributeDictionary;
- uniquedMarkerString;
- (char)booleanValue;
@end

@interface NSString(HTMLEscaping)
- htmlEncodedString;
- urlEncodedString;
- _stringForHTMLEncodedStringTolerant:(char)fp12;
- newStringForHTMLEncodedString;
- newStringForHTMLEncodedAttribute;
- compactWhiteSpace;
- removeWhiteSpace;
@end

@interface NSNumber(HTMLAttributeValue)
+ objectWithAttributeStringValue:fp12;
- attributeStringValue;
@end

@interface NSString(HTMLAttributeValue)
+ objectWithAttributeStringValue:fp12;
- (char)isQuotedString;
- quotedStringIfNecessary;
- quotedString;
- unquotedString;
- attributeStringValue;
@end

@interface HTMLDisplayOnlySelection:HTMLSelection
{
    HTMLItem *_startRoot;
    HTMLItem *_endRoot;
    unsigned int _startCharacterIndex;
    unsigned int _endCharacterIndex;
}

+ selectionForStartRoot:fp12 index:(int)fp16;
+ selectionFromRootSelection:fp12 endRoot:fp16 index:(int)fp20;
- _initWithStartRoot:fp12 index:(int)fp16 endRoot:fp20 index:(int)fp24;
- (void)dealloc;
- (char)isEqualToDisplayOnlySelection:fp12;
- (char)isZeroLength;
- (struct _NSRange)selectedRangeForRoot:fp16;
- startRoot;
- endRoot;
- (unsigned int)startIndex;
- (unsigned int)endIndex;

@end

@interface HTMLDisplayOnlySelection(HTMLDebugging)
- description;
@end

@interface HTMLScriptString(HTMLDebugging)
- description;
@end

@interface HTMLString(HTMLDebugging)
- description;
@end

@interface HTMLInlineFrame(HTMLDebugging)
- indentStringForChildrenWithIndentString:fp12;
@end

@interface HTMLTable(HTMLDebugging)
- indentStringForChildrenWithIndentString:fp12;
@end

@interface HTMLNode(HTMLDebugging)
- indentStringForChildrenWithIndentString:fp12;
- deepDescriptionWithIndentString:fp12;
@end

@interface HTMLMarkedItem(HTMLDebugging)
- description;
@end

@interface HTMLItem(HTMLDebugging)
- description;
- fullDescription;
- deepDescription;
- deepDescriptionWithIndentString:fp12;
@end

@interface HTMLDocument:NSObject <NSCopying>
{
    HTMLView *_htmlView;
    HTMLTree *_tree;
    NSString *_htmlString;
    NSURL *_documentBaseUrl;
    NSString *_name;
    char _insideChangeNotification;
    short _fontAdjustment;
    HTMLSemanticEngine *_semanticEngine;
}

+ (void)initialize;
+ (Class)htmlTreeClass;
+ (void)setHTMLTreeClass:(Class)fp12;
+ emptyPageDocument;
+ emptyFramesetDocument;
+ emptyFragmentDocument;
+ documentWithHtmlData:fp12 baseUrl:fp16 useEncoding:(unsigned int)fp20 encodingUsed:(unsigned int *)fp24;
+ documentWithHtmlData:fp12 baseUrl:fp16 encodingUsed:(unsigned int *)fp20;
+ documentWithHtmlData:fp12 baseUrl:fp16;
+ documentWithContentsOfFile:fp12 useEncoding:(unsigned int)fp16 encodingUsed:(unsigned int *)fp20;
+ documentWithContentsOfFile:fp12 encodingUsed:(unsigned int *)fp16;
+ documentWithContentsOfFile:fp12;
+ documentWithContentsOfUrl:fp12 useEncoding:(unsigned int)fp16 encodingUsed:(unsigned int *)fp20;
+ documentWithContentsOfUrl:fp12 encodingUsed:(unsigned int *)fp16;
+ documentWithContentsOfUrl:fp12;
+ documentWithHtmlString:fp12 url:fp16;
+ itemWithName:fp12 sourceDocument:fp16;
+ itemWithName:fp12 ofClass:(Class)fp16 sourceDocument:fp20;
- init;
- initWithHTMLString:fp12 url:fp16;
- copyWithZone:(struct _NSZone *)fp12;
- (void)dealloc;
- semanticEngine;
- (void)_sendChangeWithUserInfo:fp12;
- (void)_setRootNode:fp12;
- (void)_loadHTMLString;
- titleString;
- (void)registerHead:fp12;
- (void)registerBody:fp12;
- (void)registerHTML:fp12;
- (void)registerFrameset:fp12;
- (void)registerTitle:fp12;
- (void)registerBase:fp12;
- documentBaseUrl;
- (void)setDocumentBaseUrl:fp12;
- resourceBaseUrl;
- baseTarget;
- urlForProposedLink:fp12;
- urlForProposedLink:fp12 relativeToURL:fp16;
- urlForProposedLink:fp12 relativeToURL:fp16 withTarget:fp20;
- urlForProposedLink:fp12 relativeToURL:fp16 withTarget:fp20 resolveNow:(char)fp24;
- (char)hasBeenSaved;
- name;
- rootNode;
- documentHead;
- documentBody;
- documentFrameset;
- (char)isFragment;
- (char)isFrameset;
- _cachedHTMLString;
- htmlString;
- (void)setHTMLString:fp12;
- htmlTree;
- (void)setHTMLTree:fp12;
- (void)globalRenderingBasisChanged:fp12;
- (void)setFontAdjustment:(int)fp12;
- (int)fontAdjustment;
- newDocumentRenderingState;
- htmlView;
- (void)setHTMLView:fp12;
- _htmlString;
- _htmlTree;

@end

@interface HTMLDocument(NSOutlineViewDelegate)
- (void)outlineView:fp12 willDisplayCell:fp16 forTableColumn:fp20 item:fp24;
@end

@interface HTMLDocument(NSOutlineViewDataSource)
- outlineView:fp12 child:(int)fp16 ofItem:fp20;
- (char)outlineView:fp12 isItemExpandable:fp16;
- (int)outlineView:fp12 numberOfChildrenOfItem:fp16;
- outlineView:fp12 objectValueForTableColumn:fp16 byItem:fp20;
@end

@interface HTMLDocument(HTMLAttributedStringSupport)
+ attributedStringWithContentsOfFile:fp12 showingEditingCharacters:(char)fp16;
+ attributedStringWithHTML:fp12 documentAttributes:(id *)fp16;
+ attributedStringWithHTML:fp12 useEncoding:(unsigned int)fp16 documentAttributes:(id *)fp20;
+ _insertNodesForAttributes:fp12 underNode:fp16;
+ documentFromAttributedString:fp12;
+ strippedHTMLStringWithData:fp12;
+ strippedHTMLStringWithData:fp12 useEncoding:(unsigned int)fp16;
@end


@interface HTMLItem(HTMLRenderingRoots)
- (char)isRenderingRoot;
- parentRenderingRoot;
- firstRenderingRoot;
- nextRenderingRoot;
- newRenderingRootState;
- allRenderingRoots;
- renderingRootLayoutManagerWithSize:(struct _NSSize *)fp12;
- (void)doneWithRenderingRootLayoutManager;
- (unsigned int)renderingRootIndex;
- (unsigned int)renderingRootLength;
- (struct _NSPoint)renderingRootOrigin;
- (char)renderingRootContextSetUp;
@end

@interface HTMLItem(HTMLRendering)
- (void)appendRenderedHtmlWithState:fp12 toRendering:fp16;
- (void)drawBackgroundInRect:(struct _NSRect)fp12;
- approximateBackgroundColor;
- (unsigned int)numDesiredBlockReturns;
- (unsigned short)minimumWidth;
- (unsigned short)maximumWidth;
- (void)_widthsInvalid;
- (void)widthsInvalid;
- (void)subtreeWidthsInvalid;
@end

@interface HTMLItem(HTMLGeneration)
- (void)appendHTMLEquivalent:fp12;
- htmlEquivalent;
@end

@interface HTMLMarkedItem(HTMLAttributeDictionaryMimicking)
- (void)_makeDictionaryWithCapacity:(unsigned int)fp12;
- (unsigned int)_attributesCount;
- _attributesObjectForKey:fp12;
- _attributesDictionary;
- _attributesKeyEnumerator;
- _attributesObjectEnumerator;
- _attributesAllKeys;
- _attributes_fastAllKeys;
- _attributesAllValues;
- (char)_attributesAllocated;
- _attributesInit;
- _attributesInitWithCapacity:(unsigned int)fp12;
- _attributesInitWithDictionary:fp12 copyItems:(char)fp16;
- (void)_attributesSetObject:fp12 forKey:fp16;
- (void)_attributesRemoveObjectForKey:fp12;
- (void)_attributesDealloc;
@end

@interface HTMLMarkedItem(HTMLRendering)
- (char)needsLeadingBlockCharacters;
- (char)needsTrailingBlockCharacters;
- (void)appendRenderedHtmlWithState:fp12 toRendering:fp16;
@end

@interface HTMLMarkedItem(HTMLGeneration)
- (char)isBooleanAttribute:fp12;
- attributeString;
- (void)appendMarkerString:fp12;
- (void)appendAttributeString:fp12;
- (void)appendHTMLEquivalent:fp12;
@end


@interface HTMLNode(HTMLRenderingRoots)
- _nextRenderingRootAfterChild:fp12 underParentRoot:fp16;
- firstRenderingRoot;
- (void)appendRenderingRootsToArray:fp12;
- allRenderingRoots;
@end

@interface HTMLNode(HTMLRendering)
- personalizeRenderingState:fp12 copyIfChanging:(char)fp16;
- (char)needsLeadingBlockCharacters;
- (char)needsTrailingBlockCharacters;
- (unsigned int)numDesiredBlockReturns;
- (void)addFormattingReturns:(unsigned int)fp12 toRendering:fp16 withState:fp20 mergeableLength:(int)fp24;
- (char)suppressFinalBlockCharacters;
- (void)addLeadingBlockCharactersForChild:fp12 toRendering:fp16 withState:fp20;
- (void)addTrailingBlockCharactersForChild:fp12 toRendering:fp16 withState:fp20 contentLength:(int)fp24;
- (void)appendRenderedChild:fp12 toRendering:fp16 withState:fp20;
- (void)appendRenderedHtmlWithState:fp12 toRendering:fp16;
- (void)appendRenderedHtmlPrologueWithState:fp12 toRendering:fp16;
- (void)appendRenderedHtmlEpilogueWithState:fp12 toRendering:fp16;
- (void)appendRenderedChildrenWithState:fp12 toString:fp16;
- (unsigned short)minimumWidth;
- (unsigned short)maximumWidth;
- (void)childWidthsInvalid;
- (void)subtreeWidthsInvalid;
@end

@interface HTMLNode(HTMLGeneration)
- (void)appendGeneratedChildren:fp12;
- (void)appendCloseMarkerString:fp12;
- (void)appendHTMLEquivalent:fp12;
@end

@interface HTMLSemanticEngine:NSObject
{
    NSDictionary *_grammarRules;
    NSDictionary *_grammarGroups;
    NSDictionary *_initialGrammarRules;
    NSDictionary *_initialGrammarGroups;
    int _lastSemanticErrorType;
    NSString *_lastSemanticErrorChildKey;
    NSString *_lastSemanticErrorParentKey;
}

+ (void)_correctGroups:fp12 inArray:fp16;
+ (void)_correctGrammarGroups:fp12 andRules:fp16;
+ (void)loadEditingGrammar;
+ (void)loadDisplayGrammar;
+ newDisplayEngine;
- initWithGrammarRules:fp12 andGroups:fp16;
- (void)dealloc;
- (void)modifyGrammarToAllow:fp12 asAChildOf:fp16;
- (void)restoreOriginalGrammar;
- stringFromGrammarKey:fp12 isPlural:(char *)fp16;
- lastSemanticError;
- (void)semanticErrorOfType:(int)fp12 withChildKey:fp16 parentKey:fp20;
- (char)isUniqueItem:fp12;
- (char)item:fp12 acceptsAncestor:fp16;
- (char)item:fp12 isLegalChildOfParent:fp16;
- (char)item:fp12 acceptsParent:fp16;
- defaultParentForItem:fp12;
- (char)isTextItem:fp12;
- (char)isBlockItem:fp12;
- (char)node:fp12 acceptsChild:fp16 withAdaptation:(char)fp20;
- node:fp12 adaptChild:fp16;
- defaultChildForNode:fp12;
- (char)isImmutableNode:fp12;

@end

@interface HTMLTextNode(HTMLGrammarTableKeys)
- _grammarTableKey;
@end

@interface HTMLParagraphNode(HTMLGrammarTableKeys)
- _grammarTableKey;
@end

@interface HTMLUnorderedList(HTMLGrammarTableKeys)
- _grammarTableKey;
@end

@interface HTMLBody(HTMLGrammarTableKeys)
- _grammarTableKey;
@end

@interface HTMLUnknownMarkedNode(HTMLGrammarTableKeys)
- _grammarTableKey;
@end

@interface HTMLUnknownMarkedItem:HTMLMarkedItem
{
    NSString *_marker;
}

- init;
- initWithMarker:fp12 attributes:fp16;
- (void)dealloc;
- marker;
- (void)_setMarker:fp12;
- (void)setMarker:fp12;

@end

@interface HTMLUnknownMarkedItem(HTMLGrammarTableKeys)
- _grammarTableKey;
@end

@interface HTMLSGMLMarker(HTMLGrammarTableKeys)
- _grammarTableKey;
@end

@interface HTMLTree(HTMLGrammarTableKeys)
- _grammarTableKey;
@end

@interface HTMLString(HTMLGrammarTableKeys)
- _grammarTableKey;
@end

@interface HTMLScriptString(HTMLGrammarTableKeys)
- _grammarTableKey;
@end

@interface HTMLMarkedItem(HTMLGrammarTableKeys)
- _grammarTableKey;
@end

@interface HTMLItem(HTMLGrammarTableKeys)
- _grammarTableKey;
@end

@interface HTMLNode(HTMLPrivateSemantics)
- (char)containsChildOfClass:(Class)fp12 besidesItem:fp16;
@end

@interface HTMLString(HTMLRendering)
- (unsigned int)_fillSizesForAttributes:fp12 withTextStorage:fp16 startingWithOffset:(unsigned int)fp20 measureMinimum:(char)fp24;
- (unsigned short)heightForMaximumWidth;
- (void)appendRenderedHtmlWithState:fp12 toRendering:fp16;
- (void)_widthsInvalid;
@end

@interface HTMLString(HTMLGeneration)
- (void)appendHTMLEquivalent:fp12;
@end

@interface HTMLTree(HTMLRenderingRoots)
- topRenderingRoot;
- (char)isRenderingRoot;
- newRenderingRootState;
- renderingRootLayoutManagerWithSize:(struct _NSSize *)fp12;
- (struct _NSPoint)renderingRootOrigin;
- (char)renderingRootContextSetUp;
@end

@interface HTMLTree(HTMLRendering)
- personalizeRenderingState:fp12 copyIfChanging:(char)fp16;
- (void)appendRenderedHtmlWithState:fp12 toRendering:fp16;
- (void)drawBackgroundInRect:(struct _NSRect)fp12;
- approximateBackgroundColor;
- (unsigned short)minimumWidth;
- (unsigned short)maximumWidth;
- (void)subtreeWidthsInvalid;
@end

@interface HTMLTree(HTMLTreeChangeNotifications)
- (void)backgroundDidChange;
- (void)didChange;
- (void)didAddChildAtIndex:(unsigned int)fp12;
- (void)didRemoveChild:fp12 atIndex:(unsigned int)fp16;
- (void)renderingDidChange;
- (void)descendantDidChange:fp12 immediateChild:fp16;
- (void)descendantRenderingDidChange:fp12 immediateChild:fp16;
- (void)descendant:fp12 didAddChildAtIndex:(unsigned int)fp16 immediateChild:fp20;
- (void)descendant:fp12 didRemoveChild:fp16 atIndex:(unsigned int)fp20 immediateChild:fp24;
@end

@interface HTMLTableData(HTMLTreeChangeNotifications)
- (void)backgroundDidChange;
@end

@interface HTMLNode(HTMLTreeChangeNotifications)
- (void)didAddChildAtIndex:(unsigned int)fp12;
- (void)didRemoveChild:fp12 atIndex:(unsigned int)fp16;
- (void)descendantDidChange:fp12 immediateChild:fp16;
- (void)descendantRenderingDidChange:fp12 immediateChild:fp16;
- (void)descendant:fp12 didAddChildAtIndex:(unsigned int)fp16 immediateChild:fp20;
- (void)descendant:fp12 didRemoveChild:fp16 atIndex:(unsigned int)fp20 immediateChild:fp24;
@end

@interface HTMLItem(HTMLTreeChangeNotifications)
- (void)didChange;
- (void)renderingDidChange;
- (void)backgroundDidChange;
- (void)globalRenderingBasisDidChange;
@end

@interface HTMLAttributeDictionary:NSMutableDictionary
{
    unsigned long _keyOrDict;
    unsigned long _valueOrMaxCapacity;
    unsigned long _refCount;
}

- retain;
- (void)release;
- (unsigned int)retainCount;
- (void)_makeDictionaryWithCapacity:(unsigned int)fp12;
- (unsigned int)count;
- objectForKey:fp12;
- copyWithZone:(struct _NSZone *)fp12;
- mutableCopyWithZone:(struct _NSZone *)fp12;
- (char)isEqualToDictionary:fp12;
- keyEnumerator;
- objectEnumerator;
- allKeys;
- _fastAllKeys;
- allValues;
- allKeysForObject:fp12;
- init;
- initWithObjects:(id *)fp12 forKeys:(id *)fp16 count:(unsigned int)fp20;
- initWithDictionary:fp12 copyItems:(char)fp16;
- initWithCapacity:(unsigned int)fp12;
- (void)setObject:fp12 forKey:fp16;
- (void)removeObjectForKey:fp12;
- (void)dealloc;

@end

@interface NSColor(HTMLColorAdditions)
+ loadColorListNamed:fp12 fromFile:fp16;
+ _colorForHexNumber:fp12;
+ _colorForName:fp12;
+ colorForHTMLAttributeValue:fp12;
+ transparentColor;
- htmlAttributeValue;
@end

@interface HTMLOutliningCell:HTMLAttachmentCell <HTMLMouseTrackingAttachment>
{
    char _outlineWhenSelected;
    short _borderWidth;
    NSColor *_borderColor;
    short _hspace;
    short _vspace;
}

- initWithRepresentedItem:fp12;
- initImageCell:fp12 withRepresentedItem:fp16;
- (void)dealloc;
- (struct _NSRect)subclassFrameForSuperclassFrame:(struct _NSRect)fp16 selected:(char)fp32;
- (struct _NSRect)superclassFrameForSubclassFrame:(struct _NSRect)fp16;
- (void)drawSelectedOutlineWithFrame:(struct _NSRect)fp12 selected:(char)fp28;
- (void)drawWithFrame:(struct _NSRect)fp12 inView:fp28 characterIndex:(unsigned int)fp32 selected:(char)fp35;
- (char)outlinesWhenSelected;
- (void)setOutlinesWhenSelected:(char)fp12;
- (short)borderWidth;
- (void)setBorderWidth:(short)fp12;
- borderColor;
- (void)setBorderColor:fp12;
- (short)horizontalSpace;
- (short)verticalSpace;
- (void)setHorizontalSpace:(short)fp12;
- (void)setVerticalSpace:(short)fp12;
- (struct _NSRect)cellFrameForProposedLineFragment:(struct _NSRect)fp16 glyphPosition:(struct _NSPoint)fp28 characterIndex:(unsigned int)fp36;
- (char)_hasImageMap;
- _clientImageMapAreaItemForLocation:(struct _NSPoint)fp12 inFrame:(struct _NSRect)fp20;
- (char)_isInsideImageMapForEvent:fp12 inFrame:(struct _NSRect)fp16;
- _urlStringForEventInImageMap:fp12 inFrame:(struct _NSRect)fp16;
- _areaItemForEventInImageMap:fp12 inFrame:(struct _NSRect)fp16;
- mouseEntered;
- mouseMoved:fp12 inFrame:(struct _NSRect)fp16;
- (void)mouseExited;
- (void)click:fp12 inFrame:(struct _NSRect)fp16 notifyingHTMLView:fp32 orTextView:fp32;

@end

@interface HTMLSizedOutliningCell:HTMLOutliningCell
{
    struct _NSSize _imageSize;
    int _percentageWidth:1;
    int _percentageHeight:1;
}

- (void)setPercentageWidth:(char)fp12;
- (char)isPercentageWidth;
- (void)setPercentageHeight:(char)fp12;
- (char)isPercentageHeight;

@end

@interface HTMLSizedImageCell:HTMLSizedOutliningCell
{
    NSImage *_scaledImage;
    struct _NSSize _scaledSize;
}

- initWithImage:fp12 representedItem:fp16 outliningWhenSelected:(char)fp20 size:(struct _NSSize)fp24;
- (void)dealloc;
- (void)drawWithFrame:(struct _NSRect)fp12 inView:fp28 characterIndex:(unsigned int)fp32 selected:(char)fp35;
- (struct _NSRect)cellFrameForProposedLineFragment:(struct _NSRect)fp16 glyphPosition:(struct _NSPoint)fp28 characterIndex:(unsigned int)fp36;

@end

@interface HTMLImageCell:HTMLOutliningCell
{
    NSImage *_selectedImage;
    int _baselineAdjust;
    char _useDarkenedImage;
}

+ darkenedImageForImage:fp12;
+ (void)uncacheDarkenedImage:fp12;
+ dualImageCellWithRepresentedItem:fp12 image:fp16 selectedImage:fp20;
+ outliningImageCellWithRepresentedItem:fp12 image:fp16;
+ imageCellWithRepresentedItem:fp12 image:fp16;
- initWithImage:fp12 selectedImage:fp16 representedItem:fp20;
- initWithImage:fp12 representedItem:fp16 outliningWhenSelected:(char)fp20;
- (int)baselineOffset;
- (void)setBaselineOffset:(int)fp12;
- (void)dealloc;
- (void)drawWithFrame:(struct _NSRect)fp12 inView:fp28 characterIndex:(unsigned int)fp32 selected:(char)fp35;
- (struct _NSRect)cellFrameForProposedLineFragment:(struct _NSRect)fp16 glyphPosition:(struct _NSPoint)fp28 characterIndex:(unsigned int)fp36;

@end

@interface HTMLDarkenedImage:NSImage
{
    int _realRefCount;
}

- (void)incrementSpecialRefCount;
- (void)decrementSpecialRefCount;

@end

@interface HTMLPixelImageCell:HTMLSizedOutliningCell
{
    NSColor *_pixelColor;
}

- initWithRepresentedItem:fp12 baseImage:fp16 size:(struct _NSSize)fp20;
- (void)dealloc;
- (void)drawWithFrame:(struct _NSRect)fp12 inView:fp28 characterIndex:(unsigned int)fp32 selected:(char)fp35;
- (struct _NSRect)cellFrameForProposedLineFragment:(struct _NSRect)fp16 glyphPosition:(struct _NSPoint)fp28 characterIndex:(unsigned int)fp36;

@end

@interface HTMLProxyAttachmentCell:HTMLAttachmentCell
{
    int _leftInset:3;
    int _rightInset:3;
    int _topInset:3;
    int _bottomInset:4;
    int _roundCornersForButton:1;
    int _roundCornersForPopUp:1;
}

- (void)drawWithFrame:(struct _NSRect)fp12 inView:fp28 characterIndex:(unsigned int)fp32 selected:(char)fp35;
- (struct _NSRect)cellFrameForProposedLineFragment:(struct _NSRect)fp16 glyphPosition:(struct _NSPoint)fp28 characterIndex:(unsigned int)fp36;
- (void)setInsetsForVisibleAreaFromLeft:(int)fp12 top:(int)fp16 right:(int)fp20 bottom:(int)fp24;
- (char)hasRoundedCornersForButton;
- (void)setHasRoundedCornersForButton:(char)fp12;
- (char)hasRoundedCornersForPopUp;
- (void)setHasRoundedCornersForPopUp:(char)fp12;
- (char)hasScrollerOnRight;
- (void)setHasScrollerOnRight:(char)fp12;
- mouseEntered;
- mouseMoved:fp12 inFrame:(struct _NSRect)fp16;
- (void)mouseExited;

@end

@interface HTMLProxyViewAttachmentCell:HTMLProxyAttachmentCell
{
}

- (void)drawWithFrame:(struct _NSRect)fp12 inView:fp28 characterIndex:(unsigned int)fp32 selected:(char)fp35;
- (struct _NSRect)cellFrameForProposedLineFragment:(struct _NSRect)fp16 glyphPosition:(struct _NSPoint)fp28 characterIndex:(unsigned int)fp36;

@end

@interface HTMLRenderingState:NSObject
{
    NSMutableDictionary *attributes;
    NSMutableDictionary *uniquedAttributes;
    HTMLRenderingState *parentState;
    HTMLRenderingState *childItalicState;
    HTMLRenderingState *childBoldState;
    HTMLRenderingState *childUnderlineState;
    HTMLRenderingState *childFixedState;
    int uniqueStateIdentifier;
    unsigned char refCount;
    int copyAttributesBeforeChanging:1;
    int isItalicCachedState:1;
    int isBoldCachedState:1;
    int isUnderlineCachedState:1;
    int isFixedCachedState:1;
    int measureRenderedText:2;
    int usingUnmodifiedBaseFontSize:1;
    char fontSizeBase;
    char fontSizeDelta;
    char fontSizeAdjustment;
}

+ defaultFontFamily;
+ (int)defaultFontSize;
+ defaultFixedFontFamily;
+ defaultFont;
+ newDefaultRenderingState;
+ (void)passState:fp12 throughChildrenOfNode:fp16 untilReachingChild:fp20;
+ stateForChild:fp12 ofItem:fp16;
+ newStateForItem:fp12;
+ (const float *)deltaSizeArrayForBaseSize:(float)fp40;
+ (int)htmlFontSizeForPointSize:(float)fp40;
+ (float)pointSizeForHTMLFontSize:(int)fp12;
+ (char)showKnownTags;
+ (char)showUnknownTags;
+ (char)showSpacesVisibly;
+ (char)showGenericBackgroundAndText;
+ (char)showImageTags;
+ (char)showInlineFrameTags;
+ (char)showAppletTags;
+ (char)showTableTags;
+ (char)showTopLevelTags;
+ (char)showComments;
+ (char)showScript;
+ (char)showIllegalFragments;
+ (char)showBreakTags;
+ (char)showNonbreakingSpaces;
+ (char)showParagraphTags;
- retain;
- (void)release;
- (unsigned int)retainCount;
- (void)_forgetDependentItalicCopy;
- (void)_forgetDependentBoldCopy;
- (void)_forgetDependentUnderlineCopy;
- (void)_forgetDependentFixedCopy;
- (void)dealloc;
- dependentItalicCopy;
- dependentBoldCopy;
- dependentUnderlineCopy;
- dependentFixedCopy;
- (void)willChange;
- uniquedAttributes;
- (int)uniqueStateIdentifier;
- attributes;
- dependentCopy;
- independentCopy;
- copy;
- attributeForKey:fp12;
- (void)setAttribute:fp12 forKey:fp16;
- (void)removeAttributeForKey:fp12;
- font;
- (void)setFont:fp12;
- (void)setFontFace:fp12;
- (void)reevaluateFontSize;
- (int)fontSizeAdjustment;
- (void)setFontSizeAdjustment:(int)fp12;
- (int)baseFontSizeLevel;
- (void)setBaseFontSizeLevel:(int)fp12;
- (int)deltaFontSizeLevel;
- (void)setDeltaFontSizeLevel:(int)fp12;
- (void)setAbsoluteFontSizeLevel:(int)fp12;
- (void)setBold;
- (void)setItalic;
- (void)setFixedFont;
- paragraphStyle;
- (void)setParagraphStyle:fp12;
- (int)alignment;
- (void)setAlignment:(int)fp12;
- (void)setUnderline;
- (void)setStrikethrough;
- (void)setBlueUnderline;
- (void)setForegroundColor:fp12;
- (void)setBackgroundColor:fp12;
- (void)setBaselineTo:(float)fp40;
- (void)offsetBaselineBy:(float)fp40;
- (void)setBaselineToCenterAttachmentOfHeight:(int)fp12;
- (void)setBaselineToCenterImage:fp12;
- (void)setBaselineToCenterImageNamed:fp12;
- (void)setBlink;
- (void)setSuperscript;
- (void)setSubscript;
- (void)removeFixedAttachmentAttributes;
- (int)measureRenderedText;
- (void)setMeasureRenderedText:(int)fp12;

@end

@interface HTMLSpecialImageCell:HTMLSizedOutliningCell
{
    NSString *_label;
    int _type;
}

+ specialImageWithType:(int)fp12;
- initWithRepresentedItem:fp12 image:fp16 label:fp20 size:(struct _NSSize)fp24;
- initWithRepresentedItem:fp12 imageType:(int)fp16 label:fp20 size:(struct _NSSize)fp24;
- (void)dealloc;
- (void)drawWithFrame:(struct _NSRect)fp12 inView:fp28 characterIndex:(unsigned int)fp32 selected:(char)fp35;
- (struct _NSRect)cellFrameForProposedLineFragment:(struct _NSRect)fp16 glyphPosition:(struct _NSPoint)fp28 characterIndex:(unsigned int)fp36;

@end

@interface HTMLTextAttachment:NSTextAttachment
{
}

- fileWrapper;

@end

@interface HTMLTextFinder:NSObject
{
    NSString *findString;
    id findTextField;
    id replaceTextField;
    id ignoreCaseButton;
    id findNextButton;
    id replaceAllScopeMatrix;
    id statusField;
    char lastFindWasSuccessful;
}

+ sharedInstance;
- init;
- (void)appDidActivate:fp12;
- (void)loadFindStringFromPasteboard;
- (void)loadFindStringToPasteboard;
- (void)loadUI;
- (void)dealloc;
- findString;
- (void)setFindString:fp12;
- (void)setFindString:fp12 writeToPasteboard:(char)fp16;
- textObjectToSearchInUsingFindTarget:(char)fp12;
- findPanel;
- (char)_searchTextInSelection:fp12 forRoot:fp16 lookingForFirst:(char)fp20 occurrenceOfString:fp24 ignoringCase:(char)fp28 foundInRoot:(id *)fp32 overRange:(struct _NSRange *)fp32;
- (char)searchSelection:fp12 lookingForFirst:(char)fp16 occurrenceOfString:fp20 ignoringCase:(char)fp24 foundInRoot:(id *)fp28 overRange:(struct _NSRange *)fp32;
- (char)find:(char)fp12;
- (void)orderFrontFindPanel:fp12;
- (void)findNextAndOrderFindPanelOut:fp12;
- (void)findNext:fp12;
- (void)findPrevious:fp12;
- (void)replace:fp12;
- (void)replaceAndFind:fp12;
- (void)replaceAll:fp12;
- (void)takeFindStringFromSelection:fp12;
- (void)jumpToSelection:fp12;

@end

@interface NSString(HTMLTextFinding)
- (struct _NSRange)_html_findString:fp16 selectedRange:(struct _NSRange)fp20 options:(unsigned int)fp28 wrap:(char)fp32;
@end

@interface HTMLViewCell:HTMLAttachmentCell
{
    id _view;
    id _theControlView;
    id _theControlViewSuperview;
    struct _NSRect _lastFrameRect;
    unsigned int _percentageWidth;
    unsigned int _percentageHeight;
}

- (void)_removeNotifications;
- (void)dealloc;
- initWithView:fp12 representedItem:fp16;
- (void)setPercentageWidth:(unsigned int)fp12;
- (unsigned int)percentageWidth;
- (void)setPercentageHeight:(unsigned int)fp12;
- (unsigned int)percentageHeight;
- (struct _NSRect)cellFrameForProposedLineFragment:(struct _NSRect)fp16 glyphPosition:(struct _NSPoint)fp28 characterIndex:(unsigned int)fp36;
- (void)drawWithFrame:(struct _NSRect)fp12 inView:fp28 characterIndex:(unsigned int)fp32 selected:(char)fp35;
- (void)clipViewChangedBounds:fp12;
- (struct _NSRange)attachmentCharacterRange;
- (void)textViewChangedFrame:fp12;
- (void)attachmentViewChangedFrame:fp12;

@end

@interface HTMLTextContainer:NSTextContainer
{
    HTMLAttachmentCell **_floatingAttachments;
    struct _NSRect *_floaterRects;
    int _floaterCount;
    int _floaterCapacity;
    char _hasBeenCleared;
    float _clearedToY;
}

- (unsigned int)_indexOfAttachment:fp12;
- (void)_setRect:(struct _NSRect)fp12 forAttachment:fp28;
- (void)_removeRectAtIndex:(unsigned int)fp12;
- (void)_removeRectForAttachment:fp12;
- (void)_clearRectsFromCharacterIndex:(unsigned int)fp12;
- (void)willDealloc;
- (void)dealloc;
- (char)containsPoint:(struct _NSPoint)fp12;
- (char)isSimpleRectangularTextContainer;
- (void)attachmentCell:fp12 willFloatToMargin:(int)fp16 withSize:(struct _NSSize)fp20 lineFragment:(struct _NSRect)fp24 characterIndex:(unsigned int)fp40;
- (void)hitLineBreakWithClear:(int)fp12 characterIndex:(unsigned int)fp16;
- (struct _NSRect)lineFragmentRectForProposedRect:(struct _NSRect)fp16 sweepDirection:(int)fp32 movementDirection:(int)fp32 remainingRect:(struct _NSRect *)fp36;
- (void)forgetFloater:fp12;
- (void)drawFloatersInRect:(struct _NSRect)fp12;
- (void)layoutManagerDidInvalidateLayout:fp12;
- (void)layoutManager:fp12 didCompleteLayoutForTextContainer:fp16 atEnd:(char)fp20;
- (struct _NSRect)addFloatersToUsedRect:(struct _NSRect)fp16;
- (struct _NSRect)frameForFloater:fp16;
- (void)substitutedCell:fp12 forCell:fp16;

@end

@interface HTMLButtonInput:HTMLInput
{
}

- displayString;
- drawingProxyCellForAttachmentCell:fp12;
- (void)doneWithDrawingProxyCell:fp12;
- (struct _NSRect)drawingProxyFrameForAttachmentCell:fp16;
- (void)cellAction:fp12;

@end

@interface HTMLNode(HTMLItemFinding)
- itemWithName:fp12;
- itemWithID:fp12;
- itemOfClass:(Class)fp12;
- itemConformingToProtocol:fp12;
- (void)addChildrenWithName:fp12 toArray:fp16;
- (void)addChildrenOfClass:(Class)fp12 toArray:fp16;
- (void)addChildrenConformingToProtocol:fp12 toArray:fp16;
- (void)addItemsWithName:fp12 toArray:fp16;
- (void)addItemsOfClass:(Class)fp12 toArray:fp16;
- (void)addItemsConformingToProtocol:fp12 toArray:fp16;
- (void)addSuccessfulControlsToArray:fp12;
- _childSatisfyingTestSelector:(SEL)fp12 withObject:fp16 beforeItem:fp20;
- _childSatisfyingTestSelector:(SEL)fp12 withObject:fp16 afterItem:fp20;
- childOfClass:(Class)fp12 beforeItem:fp16;
- childOfClass:(Class)fp12 afterItem:fp16;
- childRespondingToSelector:(SEL)fp12 beforeItem:fp16;
- childRespondingToSelector:(SEL)fp12 afterItem:fp16;
- childConformingToProtocol:fp12 beforeItem:fp16;
- childConformingToProtocol:fp12 afterItem:fp16;
@end

@interface HTMLMarkedItem(HTMLItemFinding)
- itemWithName:fp12;
- itemWithID:fp12;
- (void)addItemsWithName:fp12 toArray:fp16;
@end

@interface HTMLItem(HTMLItemFinding)
- itemWithName:fp12;
- itemWithID:fp12;
- itemOfClass:(Class)fp12;
- itemConformingToProtocol:fp12;
- (void)addItemsWithName:fp12 toArray:fp16;
- (void)addItemsOfClass:(Class)fp12 toArray:fp16;
- (void)addItemsConformingToProtocol:fp12 toArray:fp16;
- (void)addSuccessfulControlsToArray:fp12;
@end

@interface HTMLLabel:HTMLNode
{
    HTMLMarkedItem *_labelledItem;
    NSAttributedString *_labelText;
    int _labelledItemCacheValid:1;
    int _labelTextCacheValid:1;
    int _labelledItemTakesLabel:1;
}

- (void)_detachFromLabelledItem;
- (void)dealloc;
- marker;
- form;
- (void)_recacheLabelledItem;
- (void)_recacheLabelText;
- (void)labelledItemChanged;
- (void)labelTextChanged;
- (void)awakeWithDocument:fp12;
- forID;
- forItem;
- labelText;
- (void)didChange;
- (void)didAddChildAtIndex:(unsigned int)fp12;
- (void)didRemoveChild:fp12 atIndex:(unsigned int)fp16;
- (void)descendantDidChange:fp12 immediateChild:fp16;
- (void)descendant:fp12 didAddChildAtIndex:(unsigned int)fp16 immediateChild:fp20;
- (void)descendant:fp12 didRemoveChild:fp16 atIndex:(unsigned int)fp20 immediateChild:fp24;

@end

@interface HTMLLabel(HTMLRendering)
- (void)appendRenderedChildrenWithState:fp12 toString:fp16;
@end

@interface HTMLFileInput:HTMLInput
{
    NSString *_userInputFile;
    HTMLProxyAttachmentCell *_proxyCellForTextfield;
}

- (void)removedFromTree;
- (void)dealloc;
- displayStringForTextFieldCell:fp12;
- drawingProxyCellForAttachmentCell:fp12;
- (void)doneWithDrawingProxyCell:fp12;
- (struct _NSRect)drawingProxyFrameForAttachmentCell:fp16;
- (void)attachmentCell:fp12 singleClickEvent:fp16 inTextView:fp20 withFrame:(struct _NSRect)fp20;
- (void)attachmentCell:fp12 doubleClickEvent:fp16 inTextView:fp20 withFrame:(struct _NSRect)fp20;
- (void)cellAction:fp12;
- (void)resetFormElements;

@end

@interface HTMLFileInput(HTMLRendering)
- (void)appendRenderedHtmlWithState:fp12 toRendering:fp16;
@end

@interface HTMLOptionGroup:HTMLNode <HTMLSelectOption, HTMLOptionContainer>
{
}

- marker;
- (char)isEnabled;
- label;
- form;
- select;
- optionGroup;
- (void)addMenuItemToPopUp:fp12;
- (void)configureBrowserCell:fp12;
- displayString;
- options;

@end

@interface NSMenu(HTMLPopUpMenuMimicking)
- (void)addItemWithTitle:fp12;
- lastItem;
@end

@interface HTMLHTTPURLHandle:NSURLHandle
{
    NSURL *_url;
}

+ (void)initialize;
+ (void)setFetchRemoteURLs:(char)fp12;
+ (char)fetchRemoteURLs;
+ canonicalHTTPURLForURL:fp12;
+ (char)canInitWithURL:fp12;
+ cachedHandleForURL:fp12;
- initWithURL:fp12 cached:(char)fp16;
- (void)dealloc;
- (char)writeData:fp12;
- propertyForKey:fp12;
- propertyForKeyIfAvailable:fp12;
- (char)writeProperty:fp12 forKey:fp16;
- loadInForeground;
- (void)beginLoadInBackground;
- (void)endLoadInBackground;
- (void)URLHandle:fp12 resourceDataDidBecomeAvailable:fp16;
- (void)URLHandleResourceDidBeginLoading:fp12;
- (void)URLHandleResourceDidFinishLoading:fp12;
- (void)URLHandleResourceDidCancelLoading:fp12;
- (void)URLHandle:fp12 resourceDidFailLoadingWithReason:fp16;
- (int)status;

@end

@interface HTMLFontController:NSObject
{
}

+ canonicalFaceArrayFromFaceString:fp12;
+ _fontFamilyFromCanonicalFaceArray:fp12;
+ fontFamilyFromFaceString:fp12;

@end

@interface HTMLMovieView:NSMovieView <HTMLViewEmbedding>
{
    char _wasPlayingBeforeLiveResize;
}

+ (char)canInitWithItem:fp12;
- (int)_paramLoop:fp12;
- (float)_paramVolume:fp12;
- (char)_paramController:fp12;
- (char)_paramAutoplay:fp12;
- initWithFrame:(struct _NSRect)fp12 andItem:fp28;
- (void)willDetachFromItem:fp12;
- (struct _NSSize)preferredSize;
- (void)drawRect:(struct _NSRect)fp12;
- (void)viewWillStartLiveResize;
- (void)viewDidEndLiveResize;

@end

@interface HTMLObject:HTMLNode <HTMLEmbedding>
{
    NSView *_view;
}

- (void)_releaseObjects;
- (void)removedFromTree;
- (void)renderingDidChange;
- (void)dealloc;
- view;
- (void)setView:fp12;
- _createItemView:(struct _NSRect)fp12;
- (struct _NSRect)_calcItemProposedFrame;
- _viewCellWithState:fp12;
- (void)appendRenderedHtmlWithState:fp12 toRendering:fp16;
- sourceUrlString;
- sourceUrl;
- marker;
- classidString;
- paramValueString:fp12;

@end

@interface HTMLEmbed:HTMLMarkedItem <HTMLEmbedding>
{
    NSView *_view;
}

- (void)_releaseObjects;
- (void)removedFromTree;
- (void)renderingDidChange;
- (void)dealloc;
- view;
- (void)setView:fp12;
- _createItemView:(struct _NSRect)fp12;
- (struct _NSRect)_calcItemProposedFrame;
- _viewCellWithState:fp12;
- (void)appendRenderedHtmlWithState:fp12 toRendering:fp16;
- sourceUrlString;
- sourceUrl;
- marker;
- typeString;
- paramValueString:fp12;

@end

@interface HTMLDefaultEmbeddingView:NSView <HTMLViewEmbedding>
{
}

+ (char)canInitWithItem:fp12;
- initWithFrame:(struct _NSRect)fp12 andItem:fp28;
- (void)willDetachFromItem:fp12;
- (struct _NSSize)preferredSize;
- (void)drawRect:(struct _NSRect)fp12;

@end

