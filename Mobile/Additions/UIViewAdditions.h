extern BOOL cq_shouldAnimate(BOOL wantsToAnimate);

@interface UIView (Additions)
- (void) cq_addMatchingConstraintsToView:(UIView *) destination;
@end
