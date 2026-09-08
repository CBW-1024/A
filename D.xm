#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <substrate.h>

#pragma mark - 微信类声明

// 微信原生带输入框 alert（头文件证据：WeChat/WCUIAlertView.h）
@interface WCUIAlertView : NSObject
- (id)initWithTitle:(id)a0 message:(id)a1;
- (void)showTextFieldWithMaxLen:(unsigned int)a0;
- (UITextField *)getTextField;
- (id)getTextFieldText;
- (void)setTextFieldPlaceHolder:(id)a0;
- (void)setTextFieldDefaultText:(id)a0;
- (void)addBtnTitle:(id)a0 handler:(void (^)(void))a1;
- (void)addCancelBtnTitle:(id)a0 handler:(void (^)(void))a1;
- (void)show;
@end

// 微信原生 toast（头文件证据：WeChat/WeToast.h）
@interface WeToast : NSObject
+ (id)toast;
- (void)showDoneToastWithText:(id)a0;
- (void)showErrorToastWithText:(id)a0;
@end

@interface WCPluginsMgr : NSObject
+ (instancetype)sharedInstance;
- (void)registerControllerWithTitle:(NSString *)title version:(NSString *)version controller:(NSString *)controller;
@end

@interface WCTableViewCellManager : NSObject
+ (id)switchCellForSel:(SEL)sel target:(id)target title:(id)title on:(BOOL)on;
+ (id)normalCellForSel:(SEL)sel target:(id)target title:(id)title rightValue:(id)rightValue;
+ (id)normalCellForSel:(SEL)sel target:(id)target title:(id)title rightView:(id)rightView;
@property (nonatomic, retain) id userInfo;
@end

@interface WCTableViewSectionManager : NSObject
+ (id)sectionWithHeader:(NSString *)header;
+ (id)sectionWithFooter:(NSString *)footer;
+ (id)sectionWithHeader:(NSString *)header Footer:(NSString *)footer;
@property (nonatomic, copy) NSAttributedString *attributedFooterTitle;
- (void)addCell:(id)arg1;
@end

@interface WCTableViewManager : NSObject
- (id)initWithFrame:(CGRect)frame style:(NSInteger)style;
@property (nonatomic, readonly) UITableView *tableView;
@property (nonatomic, weak) id delegate;
- (void)clearAllSection;
- (void)addSection:(id)arg1;
- (id)cellInfoAtIndexPath:(NSIndexPath *)indexPath;
- (void)reloadTableView;
@end

@interface WCPayInfoItem : NSObject
@property (nonatomic, retain) NSString *m_nsFeeDesc;
@property (nonatomic, retain) NSString *m_receiverDesc;
@property (nonatomic, retain) NSString *m_senderDesc;
@property (nonatomic, assign) unsigned int m_uiPaySubType;
@property (nonatomic, retain) NSString *m_nsTransferID;
@end

@interface CMessageWrap : NSObject
@property (nonatomic, assign) unsigned int m_uiMesLocalID;
@property (nonatomic, retain) NSString *m_nsContent;
@property (nonatomic, retain) NSString *m_nsTitle;
@property (nonatomic, retain) NSString *m_nsFromUsr;
@property (nonatomic, retain) NSString *m_nsToUsr;
@property (nonatomic, retain) WCPayInfoItem *m_oWCPayInfoItem;
- (BOOL)IsTextMsg;
- (BOOL)IsImgMsg;
- (BOOL)isReferMsgType;
- (NSString *)GetDisplayContent;
- (void)parseWCPayInfoItemIfNeed;
@end

@interface CommonMessageViewModel : NSObject
@property (nonatomic, readonly) CMessageWrap *messageWrap;
@end

@interface CommonMessageCellView : UIView
@property (nonatomic, readonly) CommonMessageViewModel *viewModel;
@end

@interface BaseMsgContentViewController : UIViewController
- (void)clearNodeLayoutCache;
- (void)reloadNodeWithMessageWrap:(CMessageWrap *)msgWrap;
- (void)reloadVisibleNodeWithCellView:(UIView *)cellView;
- (UITableView *)getMsgTableView;
@end

// 文本消息：真正决定显示文本的是 viewModel 的 contentText（爱锋 hook 点，头文件 TextMessageViewModel.h:23/67）
@interface TextMessageViewModel : CommonMessageViewModel
@property (readonly, nonatomic) NSString *contentText;
- (void)resetLayoutCache;
@end

@interface TextMessageCellView : CommonMessageCellView
- (id)getTextString;   // TextMessageCellView.h:164
- (void)layoutInternal;
@end

// 转账/收付款：金额由 viewModel 的 titleText / descText 渲染（WCPayBaseMessageViewModel.h:6/7）
@interface WCPayBaseMessageViewModel : CommonMessageViewModel
@property (readonly, nonatomic) NSString *titleText;
@property (readonly, nonatomic) NSString *descText;
@end

@interface WCPayTransferMessageViewModel : WCPayBaseMessageViewModel @end
@interface WCPayTransferMessageCellView : CommonMessageCellView
- (void)layoutContentView;
@end

@interface AppMessageCellView : CommonMessageCellView @end
@interface ImageMessageCellView : CommonMessageCellView
- (void)showImage;           // ImageMessageCellView.h，微信自身的图片加载/显示入口
@end

@interface MMMenuItem : UIMenuItem
- (instancetype)initWithTitle:(NSString *)title icon:(UIImage *)icon target:(id)target action:(SEL)action;
@end

@interface WCDeviceStepObject : NSObject
- (unsigned int)m7StepCount;
- (unsigned int)hkStepCount;
@end

@interface WCDataItem : NSObject
- (unsigned int)stepCount;
@end

@interface MMUILabel : UILabel @end

@interface ScrollNumber : UIView
- (BOOL)isLQT;
- (void)updateNumber:(unsigned long long)a0;
@end

#pragma mark - 配置管理（接口声明）

static NSString * const kDDFeatureTextEnabled = @"DDFeatureTextEnabled";
static NSString * const kDDFeatureTransferEnabled = @"DDFeatureTransferEnabled";
static NSString * const kDDFeatureImageEnabled = @"DDFeatureImageEnabled";
static NSString * const kDDFeatureBalanceEnabled = @"DDFeatureBalanceEnabled";
static NSString * const kDDFeatureStepsEnabled = @"DDFeatureStepsEnabled";
static NSString * const kDDFeatureContactsEnabled = @"DDFeatureContactsEnabled";

static NSString * const kDDStepsValueStringKey = @"DDStepsValueString";
static NSString * const kDDContactsCountValueKey = @"DDContactsCountValue";
static NSString * const kDDBalanceValueKey = @"DDBalanceValue";
static NSString * const kDDLingtongValueKey = @"DDLingtongValue";
static NSString * const kDDLastStepsUpdateDateKey = @"DDLastStepsUpdateDate";

@interface DDGlobalConfig : NSObject
+ (instancetype)shared;
@property (nonatomic) BOOL textEnabled;
@property (nonatomic) BOOL imageEnabled;
@property (nonatomic) BOOL transferEnabled;
@property (nonatomic) BOOL balanceEnabled;
@property (nonatomic) BOOL stepsEnabled;
@property (nonatomic) BOOL contactsEnabled;
@property (nonatomic, copy) NSString *stepsValueString;
@property (nonatomic, copy) NSString *contactsValue;
@property (nonatomic, copy) NSString *balanceValue;
@property (nonatomic, copy) NSString *lingtongValue;
- (NSInteger)stepsIntegerValue;
- (BOOL)hasStepsValue;
- (BOOL)hasContactsValue;
- (BOOL)hasBalanceValue;
- (BOOL)hasLingtongValue;
- (void)saveSteps;
- (void)saveContacts;
@end

#pragma mark - ① 聊天文字/图片/转账修改

static CMessageWrap *JokerGetMessageWrapFromCell(CommonMessageCellView *cell) {
    return cell.viewModel.messageWrap;
}

static id JokerGetViewControllerFromView(UIView *view) {
    UIResponder *responder = view;
    while (responder) {
        if ([responder isKindOfClass:[UIViewController class]]) {
            return responder;
        }
        responder = [responder nextResponder];
    }
    return nil;
}

static BOOL JokerIsTextMessage(CMessageWrap *msg) {
    return [msg IsTextMsg];
}

static BOOL JokerIsReferMessage(CMessageWrap *msg) {
    return [msg isReferMsgType];
}

static BOOL JokerIsTransferMessage(CMessageWrap *msg) {
    if (!msg) return NO;
    [msg parseWCPayInfoItemIfNeed];
    WCPayInfoItem *payInfo = msg.m_oWCPayInfoItem;
    if (!payInfo) return NO;
    return (payInfo.m_uiPaySubType == 3 || payInfo.m_uiPaySubType == 4 || payInfo.m_nsTransferID.length > 0);
}

static BOOL JokerIsSupportedMessage(CMessageWrap *msg) {
    return JokerIsTextMessage(msg) || JokerIsReferMessage(msg) || JokerIsTransferMessage(msg);
}

static BOOL JokerEnabledForMessage(CMessageWrap *msg) {
    if (JokerIsTransferMessage(msg)) return [DDGlobalConfig shared].transferEnabled;
    return [DDGlobalConfig shared].textEnabled;
}

static NSString *JokerGetTransferAmount(CMessageWrap *msg) {
    if (!JokerIsTransferMessage(msg)) return nil;
    [msg parseWCPayInfoItemIfNeed];
    NSString *amount = msg.m_oWCPayInfoItem.m_nsFeeDesc ?: @"";
    if ([amount hasPrefix:@"¥"]) {
        amount = [amount substringFromIndex:1];
    }
    return amount;
}

static NSString *JokerNormalizeAmount(NSString *amount) {
    NSString *trimmed = [amount stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!trimmed.length) return nil;
    NSMutableString *filtered = [NSMutableString string];
    for (NSUInteger i = 0; i < trimmed.length; i++) {
        unichar c = [trimmed characterAtIndex:i];
        if ((c >= '0' && c <= '9') || c == '.') {
            [filtered appendFormat:@"%C", c];
        }
    }
    return filtered.length ? filtered : nil;
}

static NSString * const kDDJokerTextCacheKey = @"DDJokerTextCache";
static NSString * const kDDJokerAmountCacheKey = @"DDJokerAmountCache";

static NSString *DDJokerMessageKey(CMessageWrap *msg) {
    return [NSString stringWithFormat:@"%u", msg.m_uiMesLocalID];
}

// 原值快照：只有「不得不直接改写 CMessageWrap 属性」的场景（引用消息标题）才用，
// 清理缓存时靠它把被改写过的对象还原回原始内容
static NSString * const kDDJokerOriginalSnapshotKey = @"DDJokerOriginalSnapshot";

static void DDJokerSaveOriginal(CMessageWrap *msg, NSString *original) {
    if (!msg || !original.length) return;
    NSUserDefaults *def = [NSUserDefaults standardUserDefaults];
    NSMutableDictionary *d = [NSMutableDictionary dictionaryWithDictionary:[def dictionaryForKey:kDDJokerOriginalSnapshotKey] ?: @{}];
    NSString *k = DDJokerMessageKey(msg);
    if (d[k]) return;
    d[k] = original;
    [def setObject:d forKey:kDDJokerOriginalSnapshotKey];
}

static NSString *DDJokerOriginal(CMessageWrap *msg) {
    if (!msg) return nil;
    return [[NSUserDefaults standardUserDefaults] dictionaryForKey:kDDJokerOriginalSnapshotKey][DDJokerMessageKey(msg)];
}

// 只替换文本里的第一段数字，用于转账金额（保留 ¥ 等前后缀）
static NSString *JokerReplaceFirstNumber(NSString *text, NSString *number) {
    if (!text.length || !number.length) return text;
    NSRange first = [text rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"0123456789"]];
    if (first.location == NSNotFound) return text;
    NSUInteger end = first.location;
    while (end < text.length) {
        unichar c = [text characterAtIndex:end];
        if ((c >= '0' && c <= '9') || c == '.') end++;
        else break;
    }
    return [text stringByReplacingCharactersInRange:NSMakeRange(first.location, end - first.location) withString:number];
}

static NSString *DDJokerCachedText(CMessageWrap *msg) {
    if (!msg) return nil;
    NSDictionary *d = [[NSUserDefaults standardUserDefaults] dictionaryForKey:kDDJokerTextCacheKey];
    NSString *v = d[DDJokerMessageKey(msg)];
    return v.length ? v : nil;
}

static void DDJokerSetCachedText(CMessageWrap *msg, NSString *text) {
    if (!msg) return;
    NSUserDefaults *def = [NSUserDefaults standardUserDefaults];
    NSMutableDictionary *d = [NSMutableDictionary dictionaryWithDictionary:[def dictionaryForKey:kDDJokerTextCacheKey] ?: @{}];
    if (text.length) d[DDJokerMessageKey(msg)] = text;
    else [d removeObjectForKey:DDJokerMessageKey(msg)];
    [def setObject:d forKey:kDDJokerTextCacheKey];
    [def synchronize];
}

static NSString *DDJokerCachedAmount(CMessageWrap *msg) {
    if (!msg) return nil;
    NSDictionary *d = [[NSUserDefaults standardUserDefaults] dictionaryForKey:kDDJokerAmountCacheKey];
    NSString *v = d[DDJokerMessageKey(msg)];
    return v.length ? v : nil;
}

static void DDJokerSetCachedAmount(CMessageWrap *msg, NSString *amount) {
    if (!msg) return;
    NSUserDefaults *def = [NSUserDefaults standardUserDefaults];
    NSMutableDictionary *d = [NSMutableDictionary dictionaryWithDictionary:[def dictionaryForKey:kDDJokerAmountCacheKey] ?: @{}];
    if (amount.length) d[DDJokerMessageKey(msg)] = amount;
    else [d removeObjectForKey:DDJokerMessageKey(msg)];
    [def setObject:d forKey:kDDJokerAmountCacheKey];
    [def synchronize];
}

static void DDJokerClearAllMessageCache(void) {
    NSUserDefaults *def = [NSUserDefaults standardUserDefaults];
    [def removeObjectForKey:kDDJokerTextCacheKey];
    [def removeObjectForKey:kDDJokerAmountCacheKey];
    [def synchronize];
    NSString *dir = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
    NSString *folder = [dir stringByAppendingPathComponent:@"DDJokerImages"];
    [[NSFileManager defaultManager] removeItemAtPath:folder error:nil];
}

// iOS 15+ 起 UIApplication.windows 已废弃，改用 UIWindowScene.windows（按 iOS 18 编译，不做低版本判断）
static void JokerCollectViewControllers(UIViewController *root, NSMutableArray *out) {
    if (!root || [out containsObject:root]) return;
    [out addObject:root];
    if (root.presentedViewController) JokerCollectViewControllers(root.presentedViewController, out);
    for (UIViewController *c in root.childViewControllers) JokerCollectViewControllers(c, out);
    if ([root isKindOfClass:[UINavigationController class]]) {
        for (UIViewController *c in ((UINavigationController *)root).viewControllers) JokerCollectViewControllers(c, out);
    }
    if ([root isKindOfClass:[UITabBarController class]]) {
        for (UIViewController *c in ((UITabBarController *)root).viewControllers) JokerCollectViewControllers(c, out);
    }
}

// 遍历所有 window 的整棵 VC 树：聊天页与插件设置页处在不同导航栈，
// 只查 keyWindow 的 nav.viewControllers 是找不到 BaseMsgContentViewController 的
static NSArray *JokerAllChatViewControllers(void) {
    NSMutableArray *all = [NSMutableArray array];
    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) continue;
        for (UIWindow *w in ((UIWindowScene *)scene).windows) {
            JokerCollectViewControllers(w.rootViewController, all);
        }
    }
    NSMutableArray *chats = [NSMutableArray array];
    for (UIViewController *vc in all) {
        if ([vc isKindOfClass:%c(BaseMsgContentViewController)]) [chats addObject:vc];
    }
    return chats;
}

static void JokerReloadAllMsgContent(void) {
    for (UIViewController *vc in JokerAllChatViewControllers()) {
        UITableView *tv = [(BaseMsgContentViewController *)vc getMsgTableView];
        if ([tv isKindOfClass:[UITableView class]]) [tv reloadData];
    }
}

// 图片：reloadData 后主动触发微信自己的加载流程，确保替换图被还原
static void JokerRefreshVisibleImageCells(void) {
    for (UIViewController *vc in JokerAllChatViewControllers()) {
        UITableView *tv = [(BaseMsgContentViewController *)vc getMsgTableView];
        if (![tv isKindOfClass:[UITableView class]]) continue;
        for (UITableViewCell *c in [tv visibleCells]) {
            if ([c isKindOfClass:%c(ImageMessageCellView)]) {
                [(ImageMessageCellView *)c showImage];
            }
        }
    }
}

// 输入框回填要显示"当前正在显示的内容"，所以优先取缓存值
static NSString *JokerGetDisplayText(CMessageWrap *msg) {
    if (JokerIsTextMessage(msg)) return DDJokerCachedText(msg) ?: [msg GetDisplayContent];
    if (JokerIsReferMessage(msg)) return DDJokerCachedText(msg) ?: (msg.m_nsTitle ?: @"");
    if (JokerIsTransferMessage(msg)) return DDJokerCachedAmount(msg) ?: JokerGetTransferAmount(msg);
    return nil;
}

static UITableView *JokerFindTableView(UIView *view) {
    UIView *v = view;
    while (v) {
        if ([v isKindOfClass:[UITableView class]]) return (UITableView *)v;
        v = v.superview;
    }
    return nil;
}

static void JokerReloadCellAfterReplace(id vc, CMessageWrap *msg, CommonMessageCellView *cell) {
    UITableView *tv = cell ? JokerFindTableView((UIView *)cell) : nil;
    if (![tv isKindOfClass:[UITableView class]] && [vc isKindOfClass:%c(BaseMsgContentViewController)]) {
        tv = [(BaseMsgContentViewController *)vc getMsgTableView];
    }
    if (![tv isKindOfClass:[UITableView class]]) {
        // 拿不到 tableView 就退化为全局刷新，避免"改了没反应、要重进才生效"
        JokerReloadAllMsgContent();
        return;
    }
    NSIndexPath *ip = [tv indexPathForCell:(UITableViewCell *)cell];
    if (ip) {
        [UIView performWithoutAnimation:^{
            [tv reloadRowsAtIndexPaths:@[ip] withRowAnimation:UITableViewRowAnimationNone];
        }];
        return;
    }
    JokerReloadAllMsgContent();
}

static void JokerPresentEditor(CommonMessageCellView *cell) {
    CMessageWrap *msg = JokerGetMessageWrapFromCell(cell);
    if (!JokerIsSupportedMessage(msg)) return;
    id vc = JokerGetViewControllerFromView(cell);   // 取不到也不影响弹窗，只影响兜底刷新

    NSString *current = JokerGetDisplayText(msg) ?: @"";
    BOOL isTransfer = JokerIsTransferMessage(msg);

    // 微信原生带输入框 alert：WCUIAlertView（声明见文件顶部）
    WCUIAlertView *alert = [(WCUIAlertView *)[%c(WCUIAlertView) alloc] initWithTitle:@"小丑" message:nil];
    if (!alert) return;
    [alert showTextFieldWithMaxLen:1000];
    [alert setTextFieldDefaultText:current];
    // 强引用输入框：回调里直接读 text，不依赖 alert 此刻是否还活着
    //（之前用 __weak 引用 alert，点确定时 alert 可能已释放，回调直接 return，导致修改完全无效）
    UITextField *inputField = [alert getTextField];
    if (isTransfer) {
        [alert setTextFieldPlaceHolder:@"例如：888.88"];
        if (inputField) inputField.keyboardType = UIKeyboardTypeDecimalPad;
    }
    if (!inputField) return;

    [alert addCancelBtnTitle:@"取消" handler:^{}];
    [alert addBtnTitle:@"确定" handler:^{
        NSString *newText = [inputField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (!newText.length || [newText isEqualToString:current]) return;
        if (isTransfer) {
            newText = JokerNormalizeAmount(newText);
            if (!newText) return;
            DDJokerSetCachedAmount(msg, newText);
        } else {
            DDJokerSetCachedText(msg, newText);
        }
        JokerReloadCellAfterReplace(vc, msg, cell);
    }];
    [alert show];
}

static NSArray *JokerInjectMenuItem(CommonMessageCellView *cell, NSArray *original) {
    CMessageWrap *msg = JokerGetMessageWrapFromCell(cell);
    if (!JokerEnabledForMessage(msg)) return original;
    if (!JokerIsSupportedMessage(msg)) return original;

    if (!%c(MMMenuItem)) return original;

    UIImage *icon = [[UIImage systemImageNamed:@"face.smiling.fill"] imageWithTintColor:[UIColor whiteColor] renderingMode:UIImageRenderingModeAlwaysOriginal];
    MMMenuItem *newItem = [(MMMenuItem *)[%c(MMMenuItem) alloc] initWithTitle:@"小丑" icon:icon target:cell action:@selector(joker_handleMenuItem:)];
    NSMutableArray *newItems = [NSMutableArray arrayWithArray:original];
    [newItems insertObject:newItem atIndex:0];
    return newItems;
}

// 真正决定文本显示的是 viewModel 的 contentText（TextMessageViewModel.h:23），
// 只在 setViewModel: 里改 m_nsContent 不生效，且会污染 CMessageWrap 导致清理后无法还原
%hook TextMessageViewModel
- (NSString *)contentText {
    NSString *origin = %orig;
    if (![DDGlobalConfig shared].textEnabled) return origin;
    CMessageWrap *msg = self.messageWrap;
    if (!JokerIsTextMessage(msg)) return origin;
    NSString *cached = DDJokerCachedText(msg);
    return cached ?: origin;
}
%end

// 清理缓存后需要强制清掉 viewModel 里已算好的 contentText 布局缓存，否则仍显示旧文本
static BOOL gJokerNeedsResetLayout = NO;

%hook TextMessageCellView
- (void)setViewModel:(id)vm {
    CMessageWrap *msg = [(CommonMessageViewModel *)vm messageWrap];
    NSString *cached = ([DDGlobalConfig shared].textEnabled && JokerIsTextMessage(msg)) ? DDJokerCachedText(msg) : nil;
    NSString *original = msg.m_nsContent;
    // 临时替换：让 viewModel 按新文本计算 contentText 和气泡尺寸，避免只改显示导致截断
    if (cached) msg.m_nsContent = cached;
    %orig;
    // 立即还原：不污染 CMessageWrap 对象，关闭开关/清理缓存后自动恢复原始内容
    if (cached) msg.m_nsContent = original;

    if (gJokerNeedsResetLayout && [vm isKindOfClass:%c(TextMessageViewModel)]) {
        [(TextMessageViewModel *)vm resetLayoutCache];
    }
}
- (id)getTextString {
    id origin = %orig;
    if (![DDGlobalConfig shared].textEnabled) return origin;
    CMessageWrap *msg = JokerGetMessageWrapFromCell(self);
    if (!JokerIsTextMessage(msg)) return origin;
    NSString *cached = DDJokerCachedText(msg);
    return cached ?: origin;
}
- (NSArray *)operationMenuItems {
    return JokerInjectMenuItem(self, %orig);
}
- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
    if (action == @selector(joker_handleMenuItem:)) {
        return JokerEnabledForMessage(JokerGetMessageWrapFromCell(self)) && JokerIsSupportedMessage(JokerGetMessageWrapFromCell(self));
    }
    return %orig;
}
%new
- (void)joker_handleMenuItem:(id)sender {
    JokerPresentEditor(self);
}
%end

%hook AppMessageCellView
// 引用消息没有可拦截的渲染方法，只能改 m_nsTitle；
// 因此要先存原值快照，缓存被清理（或开关关闭）时用它还原
- (void)setViewModel:(id)vm {
    CMessageWrap *msg = [(CommonMessageViewModel *)vm messageWrap];
    if ([msg isReferMsgType]) {
        NSString *cached = [DDGlobalConfig shared].textEnabled ? DDJokerCachedText(msg) : nil;
        if (cached) {
            DDJokerSaveOriginal(msg, msg.m_nsTitle);
            msg.m_nsTitle = cached;
        } else {
            NSString *original = DDJokerOriginal(msg);
            if (original) msg.m_nsTitle = original;
        }
    }
    %orig;
}
- (NSArray *)operationMenuItems {
    return JokerInjectMenuItem(self, %orig);
}
- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
    if (action == @selector(joker_handleMenuItem:)) {
        return JokerEnabledForMessage(JokerGetMessageWrapFromCell(self)) && JokerIsSupportedMessage(JokerGetMessageWrapFromCell(self));
    }
    return %orig;
}
%new
- (void)joker_handleMenuItem:(id)sender {
    JokerPresentEditor(self);
}
%end

// 金额由 WCPayBaseMessageViewModel 的 descText / titleText 渲染（WCPayBaseMessageViewModel.h:6/7），
// 之前直接改 WCPayInfoItem.m_nsFeeDesc 会污染 CMessageWrap，导致清理缓存后金额还原不回去
%hook WCPayBaseMessageViewModel
- (NSString *)descText {
    NSString *origin = %orig;
    if (![DDGlobalConfig shared].transferEnabled) return origin;
    CMessageWrap *msg = self.messageWrap;
    if (!JokerIsTransferMessage(msg)) return origin;
    NSString *cached = DDJokerCachedAmount(msg);
    return cached ? JokerReplaceFirstNumber(origin, cached) : origin;
}
- (NSString *)titleText {
    NSString *origin = %orig;
    if (![DDGlobalConfig shared].transferEnabled) return origin;
    CMessageWrap *msg = self.messageWrap;
    if (!JokerIsTransferMessage(msg)) return origin;
    NSString *cached = DDJokerCachedAmount(msg);
    return cached ? JokerReplaceFirstNumber(origin, cached) : origin;
}
%end

%hook WCPayTransferMessageCellView
- (NSArray *)operationMenuItems {
    return JokerInjectMenuItem(self, %orig);
}
- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
    if (action == @selector(joker_handleMenuItem:)) {
        return JokerEnabledForMessage(JokerGetMessageWrapFromCell(self)) && JokerIsSupportedMessage(JokerGetMessageWrapFromCell(self));
    }
    return %orig;
}
%new
- (void)joker_handleMenuItem:(id)sender {
    JokerPresentEditor(self);
}
%end

#pragma mark - ①b 聊天图片修改

@interface DDImagePickerDelegate : NSObject <UIImagePickerControllerDelegate, UINavigationControllerDelegate>
@property (nonatomic, assign) unsigned int mesLocalID;
@property (nonatomic, weak) id viewController;
- (void)dd_saveImage:(UIImage *)image dismissPicker:(UIImagePickerController *)picker;
@end

static NSString *DDImageReplacementPath(unsigned int mesLocalID) {
    NSString *dir = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
    NSString *folder = [dir stringByAppendingPathComponent:@"DDJokerImages"];
    [[NSFileManager defaultManager] createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:nil];
    return [folder stringByAppendingPathComponent:[NSString stringWithFormat:@"%u.png", mesLocalID]];
}

static UIImage *DDImageReplacementForMessage(CMessageWrap *msg) {
    if (!msg || ![msg IsImgMsg]) return nil;
    NSString *path = DDImageReplacementPath(msg.m_uiMesLocalID);
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) return nil;
    return [UIImage imageWithContentsOfFile:path];
}

static void DDImageApplyReplacementToCell(id cell) {
    if (![DDGlobalConfig shared].imageEnabled) return;
    CMessageWrap *msg = ((CommonMessageCellView *)cell).viewModel.messageWrap;
    UIImage *rep = DDImageReplacementForMessage(msg);
    if (rep) {
        // m_imageView 在头文件里是纯 ivar（ImageMessageCellView.h:4 -> YYAsyncImageView *m_imageView;）
        // 没有 getter 方法，只能靠 KVC 的 ivar 回退取值；这是全文件唯一保留的 KVC
        UIImageView *iv = (UIImageView *)[(ImageMessageCellView *)cell valueForKey:@"m_imageView"];
        [iv setImage:rep];
    }
}

%hook ImageMessageCellView
- (void)setViewModel:(id)vm {
    %orig;
    DDImageApplyReplacementToCell(self);
}
- (NSArray *)operationMenuItems {
    NSArray *original = %orig;
    DDGlobalConfig *cfg = [DDGlobalConfig shared];
    if (!cfg.imageEnabled) return original;
    CMessageWrap *msg = self.viewModel.messageWrap;
    if (![msg IsImgMsg]) return original;
    if (!%c(MMMenuItem)) return original;
    UIImage *icon = [[UIImage systemImageNamed:@"face.smiling.fill"] imageWithTintColor:[UIColor whiteColor] renderingMode:UIImageRenderingModeAlwaysOriginal];
    MMMenuItem *newItem = [(MMMenuItem *)[%c(MMMenuItem) alloc] initWithTitle:@"小丑" icon:icon target:self action:@selector(dk_changeChatImage)];
    NSMutableArray *newItems = [NSMutableArray arrayWithArray:original];
    [newItems insertObject:newItem atIndex:0];
    return newItems;
}
- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
    if (action == @selector(dk_changeChatImage)) {
        DDGlobalConfig *cfg = [DDGlobalConfig shared];
        if (!cfg.imageEnabled) return NO;
        CMessageWrap *msg = self.viewModel.messageWrap;
        return [msg IsImgMsg];
    }
    return %orig;
}
%new
- (void)dk_changeChatImage {
    CMessageWrap *msg = self.viewModel.messageWrap;
    if (![msg IsImgMsg]) return;
    id vc = JokerGetViewControllerFromView((UIView *)(id)self);
    if (!vc) return;
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    picker.allowsEditing = NO;
    DDImagePickerDelegate *delegate = [[DDImagePickerDelegate alloc] init];
    delegate.mesLocalID = msg.m_uiMesLocalID;
    delegate.viewController = vc;
    picker.delegate = delegate;
    objc_setAssociatedObject(picker, "dd_picker_delegate", delegate, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [vc presentViewController:picker animated:YES completion:nil];
}
- (void)showImage {
    %orig;
    DDImageApplyReplacementToCell(self);
}
- (void)layoutContentView {
    %orig;
    DDImageApplyReplacementToCell(self);
}
%end

@implementation DDImagePickerDelegate
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<NSString *,id> *)info {
    UIImage *image = info[UIImagePickerControllerOriginalImage];
    if (image) {
        [self dd_saveImage:image dismissPicker:picker];
    } else {
        [picker dismissViewControllerAnimated:YES completion:nil];
    }
}
- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:YES completion:nil];
}
- (void)dd_saveImage:(UIImage *)image dismissPicker:(UIImagePickerController *)picker {
    NSString *path = DDImageReplacementPath(self.mesLocalID);
    NSData *data = UIImagePNGRepresentation(image);
    if (data) [data writeToFile:path atomically:YES];
    [picker dismissViewControllerAnimated:YES completion:^{
        // 之前这里要求 viewController 必须是 BaseMsgContentViewController，否则直接 return，
        // 刷新根本没执行 —— 这就是"改完图要退出重进才生效"的原因
        dispatch_async(dispatch_get_main_queue(), ^{
            id vc = self.viewController;
            UITableView *tv = nil;
            if ([vc isKindOfClass:%c(BaseMsgContentViewController)]) {
                tv = [(BaseMsgContentViewController *)vc getMsgTableView];
            }
            if ([tv isKindOfClass:[UITableView class]]) [tv reloadData];
            else JokerReloadAllMsgContent();
        });
    }];
}
@end

#pragma mark - ② 运动步数修改

static BOOL isToday(NSDate *date) {
    if (!date) return NO;
    NSCalendar *cal = [NSCalendar currentCalendar];
    NSDateComponents *dc1 = [cal components:NSCalendarUnitYear|NSCalendarUnitMonth|NSCalendarUnitDay fromDate:date];
    NSDateComponents *dc2 = [cal components:NSCalendarUnitYear|NSCalendarUnitMonth|NSCalendarUnitDay fromDate:[NSDate date]];
    return dc1.year == dc2.year && dc1.month == dc2.month && dc1.day == dc2.day;
}

%hook WCDeviceStepObject
- (unsigned int)m7StepCount {
    DDGlobalConfig *cfg = [DDGlobalConfig shared];
    if (cfg.stepsEnabled && [cfg hasStepsValue]) {
        NSDate *last = [[NSUserDefaults standardUserDefaults] objectForKey:kDDLastStepsUpdateDateKey];
        if (!last || !isToday(last)) {
            [[NSUserDefaults standardUserDefaults] setObject:[NSDate date] forKey:kDDLastStepsUpdateDateKey];
        }
        return (unsigned int)[cfg stepsIntegerValue];
    }
    return %orig;
}

- (unsigned int)hkStepCount {
    DDGlobalConfig *cfg = [DDGlobalConfig shared];
    if (cfg.stepsEnabled && [cfg hasStepsValue]) {
        NSDate *last = [[NSUserDefaults standardUserDefaults] objectForKey:kDDLastStepsUpdateDateKey];
        if (!last || !isToday(last)) {
            [[NSUserDefaults standardUserDefaults] setObject:[NSDate date] forKey:kDDLastStepsUpdateDateKey];
        }
        return (unsigned int)[cfg stepsIntegerValue];
    }
    return %orig;
}
%end

%hook WCDataItem
- (unsigned int)stepCount {
    DDGlobalConfig *cfg = [DDGlobalConfig shared];
    if (cfg.stepsEnabled && [cfg hasStepsValue]) {
        return (unsigned int)[cfg stepsIntegerValue];
    }
    return %orig;
}
%end

#pragma mark - ③ 好友数量修改

%hook MMUILabel
- (void)setText:(NSString *)text {
    if (!text) {
        %orig;
        return;
    }
    DDGlobalConfig *cfg = [DDGlobalConfig shared];
    if (cfg.contactsEnabled && [cfg hasContactsValue]) {
        if ([text hasSuffix:@"个朋友"] && [[text substringToIndex:text.length-3] rangeOfCharacterFromSet:[[NSCharacterSet decimalDigitCharacterSet] invertedSet]].location == NSNotFound) {
            %orig([NSString stringWithFormat:@"%@个朋友", cfg.contactsValue]);
            return;
        }
    }
    %orig;
}
%end

#pragma mark - ④ 余额显示修改

static unsigned long long DDBalanceFenValue(void) {
    DDGlobalConfig *cfg = [DDGlobalConfig shared];
    if (![cfg hasBalanceValue]) return 0;
    double v = [cfg.balanceValue doubleValue];
    if (v < 0) v = 0;
    return (unsigned long long)(v * 100.0 + 0.5);
}

static unsigned long long DDLingtongFenValue(void) {
    DDGlobalConfig *cfg = [DDGlobalConfig shared];
    if (![cfg hasLingtongValue]) return 0;
    double v = [cfg.lingtongValue doubleValue];
    if (v < 0) v = 0;
    return (unsigned long long)(v * 100.0 + 0.5);
}

%hook ScrollNumber
- (void)updateNumber:(unsigned long long)original {
    DDGlobalConfig *cfg = [DDGlobalConfig shared];
    if (!cfg.balanceEnabled) {
        %orig(original);
        return;
    }
    if ([self isLQT]) {
        if ([cfg hasLingtongValue]) {
            %orig(DDLingtongFenValue());
        } else {
            %orig(original);
        }
    } else {
        if ([cfg hasBalanceValue]) {
            %orig(DDBalanceFenValue());
        } else {
            %orig(original);
        }
    }
}
%end

#pragma mark - 设置界面

@interface DDJokerSettingsViewController : UIViewController <UITableViewDelegate>
@property (nonatomic, strong) WCTableViewManager *tableViewManager;
@property (nonatomic, strong) UITextField *stepsField;
@property (nonatomic, strong) UITextField *contactsField;
@property (nonatomic, strong) UITextField *balanceField;
@property (nonatomic, strong) UITextField *lingtongField;
@end

@implementation DDJokerSettingsViewController {
    id<UITableViewDelegate> _originalDelegate;
}

- (NSAttributedString *)dd_centeredFooterString:(NSString *)text {
    NSMutableParagraphStyle *ps = [[NSMutableParagraphStyle alloc] init];
    ps.alignment = NSTextAlignmentCenter;
    ps.lineBreakMode = NSLineBreakByWordWrapping;
    NSMutableAttributedString *attr = [[NSMutableAttributedString alloc] initWithString:text];
    [attr addAttribute:NSParagraphStyleAttributeName value:ps range:NSMakeRange(0, text.length)];
    return attr;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"小丑助手设置";

    UINavigationBarAppearance *appearance = [[UINavigationBarAppearance alloc] init];
    [appearance configureWithDefaultBackground];
    appearance.shadowColor = nil;
    self.navigationItem.standardAppearance = appearance;
    self.navigationItem.scrollEdgeAppearance = appearance;
    self.navigationItem.compactAppearance = appearance;

    _tableViewManager = [(WCTableViewManager *)[%c(WCTableViewManager) alloc] initWithFrame:self.view.bounds style:UITableViewStyleInsetGrouped];
    _tableViewManager.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _tableViewManager.tableView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentAutomatic;
    [self.view addSubview:_tableViewManager.tableView];

    _originalDelegate = _tableViewManager.delegate;
    _tableViewManager.delegate = self;

    [self buildTable];
}

- (UIView *)inputRowWithField:(UITextField *)field action:(SEL)action placeholder:(NSString *)placeholder text:(NSString *)text {
    UIView *container = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 220, 34)];
    container.backgroundColor = [UIColor clearColor];

    field.frame = CGRectMake(0, 0, 160, 34);
    field.borderStyle = UITextBorderStyleNone;
    field.placeholder = placeholder;
    field.text = text;
    field.textAlignment = NSTextAlignmentRight;
    field.keyboardType = UIKeyboardTypeNumberPad;
    field.backgroundColor = [UIColor systemGray5Color];
    field.layer.cornerRadius = 6.0;
    field.layer.masksToBounds = YES;
    field.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 34)];
    field.leftViewMode = UITextFieldViewModeAlways;
    field.rightView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 34)];
    field.rightViewMode = UITextFieldViewModeAlways;
    [container addSubview:field];

    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    btn.frame = CGRectMake(168, 0, 52, 34);
    [btn setTitle:@"确认" forState:UIControlStateNormal];
    [btn setTitleColor:[UIColor labelColor] forState:UIControlStateNormal];
    btn.backgroundColor = [UIColor systemGray5Color];
    btn.layer.cornerRadius = 6.0;
    btn.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightRegular];
    [btn addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [container addSubview:btn];

    return container;
}

- (void)buildTable {
    [_tableViewManager clearAllSection];

    DDGlobalConfig *cfg = [DDGlobalConfig shared];
    Class cellCls = %c(WCTableViewCellManager);

    WCTableViewSectionManager *chatSection = [%c(WCTableViewSectionManager) sectionWithHeader:@"聊天设置"];
    chatSection.attributedFooterTitle = [self dd_centeredFooterString:@"聊天文字修改 / 聊天图片修改 / 聊天转账修改 为独立开关：长按消息弹窗菜单小丑按钮，文字消息改内容与引用标题、图片消息替换为相册所选图、转账消息改金额"];
    [chatSection addCell:[cellCls switchCellForSel:@selector(textSwitchChanged:) target:self title:@"聊天文字修改" on:cfg.textEnabled]];
    [chatSection addCell:[cellCls switchCellForSel:@selector(imageSwitchChanged:) target:self title:@"聊天图片修改" on:cfg.imageEnabled]];
    [chatSection addCell:[cellCls switchCellForSel:@selector(transferSwitchChanged:) target:self title:@"聊天转账修改" on:cfg.transferEnabled]];
    UIButton *clearBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    clearBtn.frame = CGRectMake(0, 0, 52, 34);
    [clearBtn setTitle:@"清理" forState:UIControlStateNormal];
    [clearBtn setTitleColor:[UIColor labelColor] forState:UIControlStateNormal];
    clearBtn.backgroundColor = [UIColor systemGray5Color];
    clearBtn.layer.cornerRadius = 6.0;
    clearBtn.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightRegular];
    [clearBtn addTarget:self action:@selector(clearChatCacheTapped:) forControlEvents:UIControlEventTouchUpInside];
    UIView *clearRight = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 52, 34)];
    [clearRight addSubview:clearBtn];
    [chatSection addCell:[cellCls normalCellForSel:nil target:nil title:@"清除修改缓存" rightView:clearRight]];
    [_tableViewManager addSection:chatSection];

    WCTableViewSectionManager *profileSection = [%c(WCTableViewSectionManager) sectionWithHeader:@"资料设置"];
    profileSection.attributedFooterTitle = [self dd_centeredFooterString:@"零钱余额修改开启后可自定义余额与零钱通金额。步数和好友数量修改后需重启微信生效"];
    [profileSection addCell:[cellCls switchCellForSel:@selector(balanceSwitchChanged:) target:self title:@"零钱余额修改" on:cfg.balanceEnabled]];
    if (cfg.balanceEnabled) {
        self.balanceField = [[UITextField alloc] init];
        NSString *currentBalance = [cfg hasBalanceValue] ? cfg.balanceValue : @"";
        UIView *balanceRight = [self inputRowWithField:self.balanceField
                                                action:@selector(balanceConfirm:)
                                           placeholder:@"例如：888.88"
                                                  text:currentBalance];
        WCTableViewCellManager *balanceSubCell = [cellCls normalCellForSel:nil target:nil title:@"↳余额自定义" rightView:balanceRight];
        balanceSubCell.userInfo = @"SubCell";
        [profileSection addCell:balanceSubCell];

        self.lingtongField = [[UITextField alloc] init];
        NSString *currentLingtong = [cfg hasLingtongValue] ? cfg.lingtongValue : @"";
        UIView *lingtongRight = [self inputRowWithField:self.lingtongField
                                                 action:@selector(lingtongConfirm:)
                                            placeholder:@"例如：888.88"
                                                   text:currentLingtong];
        WCTableViewCellManager *lingtongSubCell = [cellCls normalCellForSel:nil target:nil title:@"↳零钱通自定义" rightView:lingtongRight];
        lingtongSubCell.userInfo = @"SubCell";
        [profileSection addCell:lingtongSubCell];
    }

    [profileSection addCell:[cellCls switchCellForSel:@selector(stepsSwitchChanged:) target:self title:@"运动步数修改" on:cfg.stepsEnabled]];
    if (cfg.stepsEnabled) {
        self.stepsField = [[UITextField alloc] init];
        NSString *currentSteps = [cfg hasStepsValue] ? cfg.stepsValueString : @"";
        UIView *rightView = [self inputRowWithField:self.stepsField
                                             action:@selector(stepsConfirm:)
                                        placeholder:@"例如：88888"
                                               text:currentSteps];
        WCTableViewCellManager *stepsSubCell = [cellCls normalCellForSel:nil target:nil title:@"↳步数自定义" rightView:rightView];
        stepsSubCell.userInfo = @"SubCell";
        [profileSection addCell:stepsSubCell];
    }

    [profileSection addCell:[cellCls switchCellForSel:@selector(contactsSwitchChanged:) target:self title:@"好友数量修改" on:cfg.contactsEnabled]];
    if (cfg.contactsEnabled) {
        self.contactsField = [[UITextField alloc] init];
        NSString *currentContacts = [cfg hasContactsValue] ? cfg.contactsValue : @"";
        UIView *rightView = [self inputRowWithField:self.contactsField
                                             action:@selector(contactsConfirm:)
                                        placeholder:@"例如：5200"
                                               text:currentContacts];
        WCTableViewCellManager *contactsSubCell = [cellCls normalCellForSel:nil target:nil title:@"↳数量自定义" rightView:rightView];
        contactsSubCell.userInfo = @"SubCell";
        [profileSection addCell:contactsSubCell];
    }
    [_tableViewManager addSection:profileSection];

    [_tableViewManager reloadTableView];
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (_originalDelegate && [_originalDelegate respondsToSelector:@selector(tableView:willDisplayCell:forRowAtIndexPath:)]) {
        [_originalDelegate tableView:tableView willDisplayCell:cell forRowAtIndexPath:indexPath];
    }
    WCTableViewCellManager *cellInfo = [self.tableViewManager cellInfoAtIndexPath:indexPath];
    if ([cellInfo.userInfo isEqualToString:@"SubCell"]) {
        cell.indentationLevel = 1;
        cell.indentationWidth = 16.0;
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (_originalDelegate && [_originalDelegate respondsToSelector:@selector(tableView:didSelectRowAtIndexPath:)]) {
        [_originalDelegate tableView:tableView didSelectRowAtIndexPath:indexPath];
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (_originalDelegate && [_originalDelegate respondsToSelector:@selector(tableView:heightForRowAtIndexPath:)]) {
        return [_originalDelegate tableView:tableView heightForRowAtIndexPath:indexPath];
    }
    return UITableViewAutomaticDimension;
}

- (void)textSwitchChanged:(UISwitch *)sender {
    [DDGlobalConfig shared].textEnabled = sender.isOn;
    JokerReloadAllMsgContent();   // 关闭立即恢复原文，开启立即套用已保存的修改
    [self buildTable];
}

- (void)imageSwitchChanged:(UISwitch *)sender {
    [DDGlobalConfig shared].imageEnabled = sender.isOn;
    JokerReloadAllMsgContent();
    JokerRefreshVisibleImageCells();
    [self buildTable];
}

- (void)transferSwitchChanged:(UISwitch *)sender {
    [DDGlobalConfig shared].transferEnabled = sender.isOn;
    JokerReloadAllMsgContent();
    [self buildTable];
}

- (void)clearChatCacheTapped:(id)sender {
    gJokerNeedsResetLayout = YES;     // 让聊天页在重建时清掉已缓存的 contentText
    DDJokerClearAllMessageCache();    // 清文本/金额缓存字典 + 替换图目录
    JokerReloadAllMsgContent();       // 全量重绘所有聊天页（遍历全部 window 的 VC 树，不再只查单个导航栈）
    JokerRefreshVisibleImageCells();  // 图片走的是 setImage，需触发微信重新加载原图
    [self buildTable];
    [self dd_showDoneToast:@"已清理"];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        gJokerNeedsResetLayout = NO;
    });
    // 注意：kDDJokerOriginalSnapshotKey 不能在这里清 —— 引用消息的标题是直接改写
    // CMessageWrap 的，要靠快照在下次 setViewModel: 时还原；聊天页不在内存时尤其需要
}

- (void)dd_showDoneToast:(NSString *)text {
    if (!text.length) return;
    // 微信原生带勾 success toast：WeToast - showDoneToastWithText:（声明见文件顶部）
    WeToast *toast = [%c(WeToast) toast];
    if (toast) [toast showDoneToastWithText:text];
}

- (void)balanceSwitchChanged:(UISwitch *)sender {
    [DDGlobalConfig shared].balanceEnabled = sender.isOn;
    [self buildTable];
}

- (void)stepsSwitchChanged:(UISwitch *)sender {
    [DDGlobalConfig shared].stepsEnabled = sender.isOn;
    [self buildTable];
}

- (void)contactsSwitchChanged:(UISwitch *)sender {
    [DDGlobalConfig shared].contactsEnabled = sender.isOn;
    [self buildTable];
}

- (void)stepsConfirm:(id)sender {
    NSString *input = self.stepsField.text;
    [self saveStepsInput:input];
    [self buildTable];
}

- (void)contactsConfirm:(id)sender {
    NSString *input = self.contactsField.text;
    [self saveContactsInput:input];
    [self buildTable];
}

- (void)balanceConfirm:(id)sender {
    NSString *input = self.balanceField.text;
    [self saveBalanceInput:input];
    [self buildTable];
}

- (void)lingtongConfirm:(id)sender {
    NSString *input = self.lingtongField.text;
    [self saveLingtongInput:input];
    [self buildTable];
}

- (void)saveStepsInput:(NSString *)input {
    DDGlobalConfig *cfg = [DDGlobalConfig shared];
    NSString *trimmed = [input stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (trimmed.length == 0) {
        cfg.stepsValueString = nil;
    } else {
        NSInteger val = [trimmed integerValue];
        if (val < 0) val = 0;
        if (val > 100000) val = 100000;
        cfg.stepsValueString = [NSString stringWithFormat:@"%ld", (long)val];
    }
}

- (void)saveContactsInput:(NSString *)input {
    DDGlobalConfig *cfg = [DDGlobalConfig shared];
    NSString *trimmed = [input stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (trimmed.length == 0) {
        cfg.contactsValue = nil;
    } else {
        NSCharacterSet *nonDigits = [[NSCharacterSet decimalDigitCharacterSet] invertedSet];
        if ([trimmed rangeOfCharacterFromSet:nonDigits].location == NSNotFound) {
            cfg.contactsValue = trimmed;
        }
    }
}

- (void)saveBalanceInput:(NSString *)input {
    DDGlobalConfig *cfg = [DDGlobalConfig shared];
    NSString *trimmed = [input stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (trimmed.length == 0) {
        cfg.balanceValue = nil;
        return;
    }
    NSMutableString *filtered = [NSMutableString string];
    BOOL hasDot = NO;
    for (NSUInteger i = 0; i < trimmed.length; i++) {
        unichar c = [trimmed characterAtIndex:i];
        if (c >= '0' && c <= '9') {
            [filtered appendFormat:@"%C", c];
        } else if (c == '.' && !hasDot) {
            [filtered appendFormat:@"%C", c];
            hasDot = YES;
        }
    }
    cfg.balanceValue = filtered.length ? filtered : nil;
}

- (void)saveLingtongInput:(NSString *)input {
    DDGlobalConfig *cfg = [DDGlobalConfig shared];
    NSString *trimmed = [input stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (trimmed.length == 0) {
        cfg.lingtongValue = nil;
        return;
    }
    NSMutableString *filtered = [NSMutableString string];
    BOOL hasDot = NO;
    for (NSUInteger i = 0; i < trimmed.length; i++) {
        unichar c = [trimmed characterAtIndex:i];
        if (c >= '0' && c <= '9') {
            [filtered appendFormat:@"%C", c];
        } else if (c == '.' && !hasDot) {
            [filtered appendFormat:@"%C", c];
            hasDot = YES;
        }
    }
    cfg.lingtongValue = filtered.length ? filtered : nil;
}

@end

#pragma mark - 配置管理（实现）

@implementation DDGlobalConfig

+ (instancetype)shared {
    static DDGlobalConfig *config = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ config = [DDGlobalConfig new]; });
    return config;
}

- (instancetype)init {
    if (self = [super init]) {
        NSUserDefaults *def = [NSUserDefaults standardUserDefaults];
        _textEnabled = [def boolForKey:kDDFeatureTextEnabled];
        _imageEnabled = [def boolForKey:kDDFeatureImageEnabled];
        _transferEnabled = [def boolForKey:kDDFeatureTransferEnabled];
        _balanceEnabled = [def boolForKey:kDDFeatureBalanceEnabled];
        _stepsEnabled = [def boolForKey:kDDFeatureStepsEnabled];
        _contactsEnabled = [def boolForKey:kDDFeatureContactsEnabled];
        _stepsValueString = [def stringForKey:kDDStepsValueStringKey];
        _contactsValue = [def stringForKey:kDDContactsCountValueKey];
        _balanceValue = [def stringForKey:kDDBalanceValueKey];
        _lingtongValue = [def stringForKey:kDDLingtongValueKey];
        if (![def objectForKey:kDDLastStepsUpdateDateKey]) {
            [def setObject:[NSDate date] forKey:kDDLastStepsUpdateDateKey];
            [def synchronize];
        }
    }
    return self;
}

- (void)setTextEnabled:(BOOL)enabled {
    _textEnabled = enabled;
    [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:kDDFeatureTextEnabled];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)setTransferEnabled:(BOOL)enabled {
    _transferEnabled = enabled;
    [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:kDDFeatureTransferEnabled];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)setImageEnabled:(BOOL)enabled {
    _imageEnabled = enabled;
    [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:kDDFeatureImageEnabled];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)setBalanceEnabled:(BOOL)enabled {
    _balanceEnabled = enabled;
    [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:kDDFeatureBalanceEnabled];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)setStepsEnabled:(BOOL)enabled {
    _stepsEnabled = enabled;
    [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:kDDFeatureStepsEnabled];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)setContactsEnabled:(BOOL)enabled {
    _contactsEnabled = enabled;
    [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:kDDFeatureContactsEnabled];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)setStepsValueString:(NSString *)stepsValueString {
    _stepsValueString = [stepsValueString copy];
    [self saveSteps];
}

- (void)setContactsValue:(NSString *)contactsValue {
    _contactsValue = [contactsValue copy];
    [self saveContacts];
}

- (void)setBalanceValue:(NSString *)balanceValue {
    _balanceValue = [balanceValue copy];
    NSUserDefaults *def = [NSUserDefaults standardUserDefaults];
    if (_balanceValue.length) {
        [def setObject:_balanceValue forKey:kDDBalanceValueKey];
    } else {
        [def removeObjectForKey:kDDBalanceValueKey];
    }
    [def synchronize];
}

- (void)setLingtongValue:(NSString *)lingtongValue {
    _lingtongValue = [lingtongValue copy];
    NSUserDefaults *def = [NSUserDefaults standardUserDefaults];
    if (_lingtongValue.length) {
        [def setObject:_lingtongValue forKey:kDDLingtongValueKey];
    } else {
        [def removeObjectForKey:kDDLingtongValueKey];
    }
    [def synchronize];
}

- (NSInteger)stepsIntegerValue {
    if (![self hasStepsValue]) return 0;
    return [_stepsValueString integerValue];
}

- (BOOL)hasStepsValue {
    return _stepsValueString.length > 0;
}

- (BOOL)hasContactsValue {
    return _contactsValue.length > 0;
}

- (BOOL)hasBalanceValue {
    return _balanceValue.length > 0;
}

- (BOOL)hasLingtongValue {
    return _lingtongValue.length > 0;
}

- (void)saveSteps {
    NSUserDefaults *def = [NSUserDefaults standardUserDefaults];
    if (_stepsValueString.length) {
        [def setObject:_stepsValueString forKey:kDDStepsValueStringKey];
    } else {
        [def removeObjectForKey:kDDStepsValueStringKey];
    }
    [def setObject:[NSDate date] forKey:kDDLastStepsUpdateDateKey];
    [def synchronize];
}

- (void)saveContacts {
    NSUserDefaults *def = [NSUserDefaults standardUserDefaults];
    if (_contactsValue.length) {
        [def setObject:_contactsValue forKey:kDDContactsCountValueKey];
    } else {
        [def removeObjectForKey:kDDContactsCountValueKey];
    }
    [def synchronize];
}

@end

#pragma mark - 插件注册

%ctor {
    @autoreleasepool {
        WCPluginsMgr *mgr = [%c(WCPluginsMgr) sharedInstance];
        [mgr registerControllerWithTitle:@"DD小丑助手"
                                 version:@"1.0.0"
                              controller:@"DDJokerSettingsViewController"];
    }
}