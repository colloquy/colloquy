@interface JVViewCell : NSCell {
    @private
    NSView *_view;
}
- (void) setView:(NSView *) view;
- (NSView *) view;
@end
