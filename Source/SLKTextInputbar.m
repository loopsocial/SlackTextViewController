//
//  SlackTextViewController
//  https://github.com/slackhq/SlackTextViewController
//
//  Copyright 2014-2016 Slack Technologies, Inc.
//  Licence: MIT-Licence
//

#import "SLKTextInputbar.h"
#import "SLKTextView.h"
#import "SLKInputAccessoryView.h"

#import "SLKTextView+SLKAdditions.h"
#import "UIView+SLKAdditions.h"

#import "SLKUIConstants.h"

NSString * const SLKTextInputbarDidMoveNotification =   @"SLKTextInputbarDidMoveNotification";

@interface SLKTextInputbar ()

@property (nonatomic, strong) NSLayoutConstraint *textViewBottomMarginC;
@property (nonatomic, strong) NSLayoutConstraint *leftMarginWC;
@property (nonatomic, strong) NSLayoutConstraint *rightButtonWC;
@property (nonatomic, strong) NSLayoutConstraint *rightMarginWC;
@property (nonatomic, strong) NSArray *charCountLabelVCs;

@property (nonatomic, strong) UILabel *charCountLabel;

@property (nonatomic) CGPoint previousOrigin;

@property (nonatomic, strong) Class textViewClass;

@property (nonatomic, getter=isHidden) BOOL hidden; // Required override

@end

@implementation SLKTextInputbar
@synthesize textView = _textView;
@synthesize inputAccessoryView = _inputAccessoryView;
@synthesize hidden = _hidden;

#pragma mark - Initialization

- (instancetype)initWithTextViewClass:(Class)textViewClass
{
    if (self = [super init]) {
        self.textViewClass = textViewClass;
        [self slk_commonInit];
    }
    return self;
}

- (id)init
{
    if (self = [super init]) {
        [self slk_commonInit];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if (self = [super initWithCoder:coder]) {
        [self slk_commonInit];
    }
    return self;
}

- (void)slk_commonInit
{
    self.charCountLabelNormalColor = [UIColor lightGrayColor];
    self.charCountLabelWarningColor = [UIColor redColor];
    
    self.autoHideRightButton = YES;
    self.contentInset = UIEdgeInsetsMake(5.0, 8.0, 54.0, 8.0);
    
    [self addSubview:self.rightButton];
    [self addSubview:self.textView];
    [self addSubview:self.charCountLabel];
    [self addSubview:self.bottomButtonsStackView];
    
    [self slk_setupViewConstraints];
    [self slk_updateConstraintConstants];
    
    self.counterStyle = SLKCounterStyleNone;
    self.counterPosition = SLKCounterPositionTop;
    
    [self slk_registerNotifications];
    
    [self slk_registerTo:self.layer forSelector:@selector(position)];
    [self slk_registerTo:self.rightButton.titleLabel forSelector:@selector(font)];
}


#pragma mark - UIView Overrides

- (void)layoutIfNeeded
{
    if (self.constraints.count == 0 || !self.window) {
        return;
    }
    
    [self slk_updateConstraintConstants];
    [super layoutIfNeeded];
}

- (CGSize)intrinsicContentSize
{
    return CGSizeMake(UIViewNoIntrinsicMetric, [self minimumInputbarHeight]);
}

+ (BOOL)requiresConstraintBasedLayout
{
    return YES;
}


#pragma mark - Getters

- (SLKTextView *)textView
{
    if (!_textView) {
        Class class = self.textViewClass ? : [SLKTextView class];
        
        _textView = [[class alloc] init];
        _textView.translatesAutoresizingMaskIntoConstraints = NO;
        _textView.font = [UIFont systemFontOfSize:15.0];
        _textView.maxNumberOfLines = [self slk_defaultNumberOfLines];
        
        _textView.keyboardType = UIKeyboardTypeDefault;
        _textView.returnKeyType = UIReturnKeyDefault;
        _textView.enablesReturnKeyAutomatically = YES;
        _textView.scrollIndicatorInsets = UIEdgeInsetsMake(0.0, -1.0, 0.0, 1.0);
        _textView.textContainerInset = UIEdgeInsetsMake(8.0, 4.0, 8.0, 0.0);
    }
    return _textView;
}

- (SLKInputAccessoryView *)inputAccessoryView
{
    if (!_inputAccessoryView) {
        _inputAccessoryView = [[SLKInputAccessoryView alloc] initWithFrame:CGRectZero];
        _inputAccessoryView.backgroundColor = [UIColor clearColor];
        _inputAccessoryView.userInteractionEnabled = NO;
    }
    
    return _inputAccessoryView;
}

- (UIButton *)rightButton
{
    if (!_rightButton) {
        _rightButton = [UIButton buttonWithType:UIButtonTypeCustom];
        _rightButton.translatesAutoresizingMaskIntoConstraints = NO;
        _rightButton.titleLabel.font = [UIFont boldSystemFontOfSize:15.0];
        _rightButton.enabled = NO;
        
        NSString *title = NSLocalizedString(@"Send", nil);
        
        [_rightButton setTitle:title forState:UIControlStateNormal];
    }
    return _rightButton;
}

- (UIStackView *)bottomButtonsStackView {
    if (!_bottomButtonsStackView) {
        _bottomButtonsStackView = [[UIStackView alloc] init];
        _bottomButtonsStackView.translatesAutoresizingMaskIntoConstraints = NO;
    }
    return _bottomButtonsStackView;
}

- (UILabel *)charCountLabel
{
    if (!_charCountLabel) {
        _charCountLabel = [UILabel new];
        _charCountLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _charCountLabel.backgroundColor = [UIColor clearColor];
        _charCountLabel.textAlignment = NSTextAlignmentRight;
        _charCountLabel.font = [UIFont systemFontOfSize:11.0];
        
        _charCountLabel.hidden = NO;
    }
    return _charCountLabel;
}

- (BOOL)isHidden
{
    return _hidden;
}

- (CGFloat)minimumInputbarHeight
{
    CGFloat minimumHeight = self.textView.intrinsicContentSize.height;
    minimumHeight += self.contentInset.top;
    minimumHeight += self.slk_bottomMargin;
    
    return minimumHeight;
}

- (CGFloat)appropriateHeight
{
    CGFloat height = 0.0;
    CGFloat minimumHeight = [self minimumInputbarHeight];
    
    if (self.textView.numberOfLines == 1) {
        height = minimumHeight;
    }
    else if (self.textView.numberOfLines < self.textView.maxNumberOfLines) {
        height = [self slk_inputBarHeightForLines:self.textView.numberOfLines];
    }
    else {
        height = [self slk_inputBarHeightForLines:self.textView.maxNumberOfLines];
    }
    
    if (height < minimumHeight) {
        height = minimumHeight;
    }
    
    return roundf(height);
}

- (BOOL)limitExceeded
{
    NSString *text = [self.textView.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    if (self.maxCharCount > 0 && text.length > self.maxCharCount) {
        return YES;
    }
    return NO;
}

- (CGFloat)slk_inputBarHeightForLines:(NSUInteger)numberOfLines
{
    CGFloat height = self.textView.intrinsicContentSize.height;
    height -= self.textView.font.lineHeight;
    height += roundf(self.textView.font.lineHeight*numberOfLines);
    height += self.contentInset.top;
    height += self.slk_bottomMargin;
    
    return height;
}

- (CGFloat)slk_bottomMargin
{
    CGFloat margin = self.contentInset.bottom;
    
    return margin;
}

- (CGFloat)slk_appropriateRightButtonWidth
{
    if (self.autoHideRightButton) {
        if (self.textView.text.length == 0) {
            return 0.0;
        }
    }

    return 64;
}

- (CGFloat)slk_appropriateRightButtonMargin
{
    return 0;
}

- (NSUInteger)slk_defaultNumberOfLines
{
    if (SLK_IS_IPAD) {
        return 8;
    }
    else if (SLK_IS_IPHONE4) {
        return 4;
    }
    else {
        return 6;
    }
}


#pragma mark - Setters

- (void)setAutoHideRightButton:(BOOL)hide
{
    if (self.autoHideRightButton == hide) {
        return;
    }
    
    _autoHideRightButton = hide;
    
    self.rightButtonWC.constant = [self slk_appropriateRightButtonWidth];
    self.rightMarginWC.constant = [self slk_appropriateRightButtonMargin];

    [self layoutIfNeeded];
}

- (void)setContentInset:(UIEdgeInsets)insets
{
    if (UIEdgeInsetsEqualToEdgeInsets(self.contentInset, insets)) {
        return;
    }
    
    if (UIEdgeInsetsEqualToEdgeInsets(self.contentInset, UIEdgeInsetsZero)) {
        _contentInset = insets;
        return;
    }
    
    _contentInset = insets;
    
    // Add new constraints
    [self removeConstraints:self.constraints];
    [self slk_setupViewConstraints];
    
    // Add constant values and refresh layout
    [self slk_updateConstraintConstants];
    
    [super layoutIfNeeded];
}

- (void)setHidden:(BOOL)hidden
{
    // We don't call super here, since we want to avoid to visually hide the view.
    // The hidden render state is handled by the view controller.
    
    _hidden = hidden;
}

- (void)setCounterPosition:(SLKCounterPosition)counterPosition
{
    if (self.counterPosition == counterPosition && self.charCountLabelVCs) {
        return;
    }
    
    // Clears the previous constraints
    if (_charCountLabelVCs.count > 0) {
        [self removeConstraints:_charCountLabelVCs];
        _charCountLabelVCs = nil;
    }
    
    _counterPosition = counterPosition;
    
    NSDictionary *views = @{@"rightButton": self.rightButton,
                            @"charCountLabel": self.charCountLabel
                            };
    
    NSDictionary *metrics = @{@"top" : @(self.contentInset.top),
                              @"bottom" : @(-self.slk_bottomMargin/2.0)
                              };
    
    // Constraints are different depending of the counter's position type
    if (counterPosition == SLKCounterPositionBottom) {
        _charCountLabelVCs = [NSLayoutConstraint constraintsWithVisualFormat:@"V:[charCountLabel]-(bottom)-[rightButton]" options:0 metrics:metrics views:views];
    }
    else {
        _charCountLabelVCs = [NSLayoutConstraint constraintsWithVisualFormat:@"V:|-(top@750)-[charCountLabel]-(>=0)-|" options:0 metrics:metrics views:views];
    }
    
    [self addConstraints:self.charCountLabelVCs];
}

- (void)addBottomStackviewSubview:(UIView*)subview {
    [self.bottomButtonsStackView addArrangedSubview:subview];
    [self slk_updateConstraintConstants];
}


#pragma mark - Character Counter

- (void)slk_updateCounter
{
    NSString *text = [self.textView.text stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    NSString *counter = nil;
    
    if (self.counterStyle == SLKCounterStyleNone) {
        counter = [NSString stringWithFormat:@"%lu", (unsigned long)text.length];
    }
    if (self.counterStyle == SLKCounterStyleSplit) {
        counter = [NSString stringWithFormat:@"%lu/%lu", (unsigned long)text.length, (unsigned long)self.maxCharCount];
    }
    if (self.counterStyle == SLKCounterStyleCountdown) {
        counter = [NSString stringWithFormat:@"%ld", (long)(text.length - self.maxCharCount)];
    }
    if (self.counterStyle == SLKCounterStyleCountdownReversed)
    {
        counter = [NSString stringWithFormat:@"%ld", (long)(self.maxCharCount - text.length)];
    }
    
    self.charCountLabel.text = counter;
    self.charCountLabel.textColor = [self limitExceeded] ? self.charCountLabelWarningColor : self.charCountLabelNormalColor;
}


#pragma mark - Notification Events

- (void)slk_didChangeTextViewText:(NSNotification *)notification
{
    SLKTextView *textView = (SLKTextView *)notification.object;
    
    // Skips this it's not the expected textView.
    if (![textView isEqual:self.textView]) {
        return;
    }
    
    // Updates the char counter label
    if (self.maxCharCount > 0) {
        [self slk_updateCounter];
    }
    
    if (self.autoHideRightButton)
    {
        CGFloat rightButtonNewWidth = [self slk_appropriateRightButtonWidth];
        
        // Only updates if the width did change
        if (self.rightButtonWC.constant == rightButtonNewWidth) {
            return;
        }
        
        self.rightButtonWC.constant = rightButtonNewWidth;
        self.rightMarginWC.constant = [self slk_appropriateRightButtonMargin];
        [self.rightButton layoutIfNeeded]; // Avoids the right button to stretch when animating the constraint changes
        
        BOOL bounces = self.bounces && [self.textView isFirstResponder];
        
        if (self.window) {
            [self slk_animateLayoutIfNeededWithBounce:bounces
                                              options:UIViewAnimationOptionCurveEaseInOut|UIViewAnimationOptionBeginFromCurrentState|UIViewAnimationOptionAllowUserInteraction
                                           animations:NULL];
        }
        else {
            [self layoutIfNeeded];
        }
    }
}

- (void)slk_didChangeTextViewContentSize:(NSNotification *)notification
{
    if (self.maxCharCount > 0) {
        BOOL shouldHide = (self.textView.numberOfLines == 1);
        self.charCountLabel.hidden = shouldHide;
    }
}

- (void)slk_didChangeContentSizeCategory:(NSNotification *)notification
{
    if (!self.textView.isDynamicTypeEnabled) {
        return;
    }
    
    [self layoutIfNeeded];
}


#pragma mark - View Auto-Layout

- (void)slk_setupViewConstraints
{
    NSDictionary *views = @{@"textView": self.textView,
                            @"rightButton": self.rightButton,
                            @"charCountLabel": self.charCountLabel,
                            @"stackView": self.bottomButtonsStackView
                            };
    
    NSDictionary *metrics = @{@"top" : @(self.contentInset.top),
                              @"left" : @(self.contentInset.left),
                              @"right" : @(self.contentInset.right),
                              };
    
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-[textView]-(right)-|" options:0 metrics:metrics views:views]];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:[rightButton(0)]-(0)-|" options:0 metrics:metrics views:views]];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[rightButton(44)]-(0)-|" options:0 metrics:metrics views:views]];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-(left@250)-[charCountLabel(<=50@1000)]-(right@750)-|" options:0 metrics:metrics views:views]];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-[textView(0@999)]-(0)-|" options:0 metrics:metrics views:views]];
    [[self.bottomButtonsStackView.leftAnchor constraintEqualToAnchor:self.textView.leftAnchor] setActive: YES];
    [[self.bottomButtonsStackView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor] setActive:YES];
    
    self.textViewBottomMarginC = [self slk_constraintForAttribute:NSLayoutAttributeBottom firstItem:self secondItem:self.textView];

    self.leftMarginWC = [[self slk_constraintsForAttribute:NSLayoutAttributeLeading] firstObject];
    
    self.rightButtonWC = [self slk_constraintForAttribute:NSLayoutAttributeWidth firstItem:self.rightButton secondItem:nil];
    self.rightMarginWC = [[self slk_constraintsForAttribute:NSLayoutAttributeTrailing] firstObject];
}

- (void)slk_updateConstraintConstants
{
    CGFloat zero = 0.0;
    
    self.textViewBottomMarginC.constant = self.slk_bottomMargin;

    self.leftMarginWC.constant = zero;
    
    self.rightButtonWC.constant = [self slk_appropriateRightButtonWidth];
    self.rightMarginWC.constant = [self slk_appropriateRightButtonMargin];
}


#pragma mark - Observers

- (void)slk_registerTo:(id)object forSelector:(SEL)selector
{
    if (object) {
        [object addObserver:self forKeyPath:NSStringFromSelector(selector) options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:NULL];
    }
}

- (void)slk_unregisterFrom:(id)object forSelector:(SEL)selector
{
    if (object) {
        [object removeObserver:self forKeyPath:NSStringFromSelector(selector)];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([object isEqual:self.layer] && [keyPath isEqualToString:NSStringFromSelector(@selector(position))]) {
        
        if (!CGPointEqualToPoint(self.previousOrigin, self.frame.origin)) {
            self.previousOrigin = self.frame.origin;
            [[NSNotificationCenter defaultCenter] postNotificationName:SLKTextInputbarDidMoveNotification object:self userInfo:@{@"origin": [NSValue valueWithCGPoint:self.previousOrigin]}];
        }
    }
    else if ([object isEqual:self.rightButton.titleLabel] && [keyPath isEqualToString:NSStringFromSelector(@selector(font))]) {
        
        [self slk_updateConstraintConstants];
    }
    else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}


#pragma mark - NSNotificationCenter registration

- (void)slk_registerNotifications
{
    [self slk_unregisterNotifications];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(slk_didChangeTextViewText:) name:UITextViewTextDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(slk_didChangeTextViewContentSize:) name:SLKTextViewContentSizeDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(slk_didChangeContentSizeCategory:) name:UIContentSizeCategoryDidChangeNotification object:nil];
}

- (void)slk_unregisterNotifications
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UITextViewTextDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:SLKTextViewContentSizeDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIContentSizeCategoryDidChangeNotification object:nil];
}


#pragma mark - Lifeterm

- (void)dealloc
{
    [self slk_unregisterNotifications];
    
    [self slk_unregisterFrom:self.layer forSelector:@selector(position)];
    [self slk_unregisterFrom:self.rightButton.titleLabel forSelector:@selector(font)];
}

@end
