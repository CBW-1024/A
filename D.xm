#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <substrate.h>
#include <string.h>

// ============================================================
//  DD小丑助手  (WeChat Jailbreak Tweak, Theos/Logos 单文件)
//  在微信内自定义聊天 / 资料 / 余额等显示
//  功能：聊天文字、图片、时间、转账改写；运动步数、好友数量；余额 / 零钱通自定义
//  入口：微信 → 插件入口 → "DD小丑助手"设置页
//
//  诊断日志框架（DDLOG / DDJokerHit / 导出）为各功能共用的底座：
//    · 余额功能已稳定，静默运行、不写日志
//    · 新增功能时在自己逻辑里调用  DDJokerHit(@"标签") / DDLOG(@"...")
//      即自动进入命中统计与"导出"日志，无需额外接线
// ============================================================


#pragma mark - 微信类声明
// 本插件 hook 的微信原生类与方法签名，均锚定微信 .h 头文件 dump。


@interface WCUIAlertView : NSObject
- (id)initWithTitle:(id)a0 message:(id)a1;
- (void)showTextFieldWithMaxLen:(unsigned int)a0;
- (UITextField *)getTextField;
- (id)getTextFieldText;
- (void)setTextFieldDefaultText:(id)a0;
- (void)addBtnTitle:(id)a0 handler:(void (^)(void))a1;
- (void)addCancelBtnTitle:(id)a0 handler:(void (^)(void))a1;
- (void)show;
@end

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

@interface CMessageWrap : NSObject
@property (nonatomic, assign) unsigned int m_uiMesLocalID;
@property (nonatomic, retain) NSString *m_nsContent;
@property (nonatomic, retain) NSString *m_nsFromUsr;
@property (nonatomic, retain) NSString *m_nsToUsr;
- (BOOL)IsTextMsg;
- (BOOL)IsImgMsg;
- (BOOL)isReferMsgType;
- (NSString *)GetDisplayContent;
@end

@interface BaseMessageViewModel : NSObject
@property (nonatomic, retain) CMessageWrap *messageWrap;
- (void)resetLayoutCache;
@end

@interface CommonMessageViewModel : BaseMessageViewModel
@end

@interface BaseMessageCellView : UIView
- (void)layoutContentView;
- (void)layoutInternal;
- (void)prepareForReuse;
- (id)operationMenuItems;
@end

@interface CommonMessageCellView : BaseMessageCellView
@property (nonatomic, readonly) CommonMessageViewModel *viewModel;
- (void)setViewModel:(id)vm;
@end

@interface BaseMsgContentViewController : UIViewController
- (void)clearNodeLayoutCache;
- (void)reloadNodeWithMessageWrap:(CMessageWrap *)msgWrap;
- (void)reloadVisibleNodeWithCellView:(UIView *)cellView;
- (UITableView *)getMsgTableView;
@end

@interface TextMessageViewModel : CommonMessageViewModel
@property (readonly, nonatomic) NSString *contentText;
- (void)resetLayoutCache;
@end

@interface RichTextView : UIView
- (id)getContent;
- (void)setContent:(id)content;
- (void)calculateAndUpdateFrame;
- (void)forceDisplayInSync;
@end

@interface TextMessageCellView : CommonMessageCellView
- (id)getRichTextView;
- (id)getTextString;
- (void)layoutContentView;
- (void)setViewModel:(id)vm;

@end

@interface WCPayTransferMessageViewModel : NSObject
- (CMessageWrap *)messageWrap;
- (NSString *)titleText;
- (NSString *)descText;
@end

@interface WCPayTransferMessageCellView : CommonMessageCellView
- (void)updateTitleLabel;
- (void)updateDescLabel;
@end

@interface ImageMessageCellView : CommonMessageCellView
- (void)showImage;
- (void)OnDownloadImageOk:(id)a0;
@end

@interface ChatTimeViewModel : BaseMessageViewModel
- (NSString *)timeText;
- (void)updateLayouts;
@end

@interface ChatTimeCellView : UIView
- (id)initWithViewModel:(id)vm;
- (void)setViewModel:(id)vm;
- (void)layoutInternal;

- (UILabel *)dk_timeLabel;
- (void)dk_installTimeEditGesture;
- (void)dk_handleTimeLongPress:(UILongPressGestureRecognizer *)g;
- (void)dk_showTimeInput;
@end

@interface MMMenuItem : UIMenuItem
- (instancetype)initWithTitle:(NSString *)title icon:(UIImage *)icon target:(id)target action:(SEL)action;
@end

@interface WCDeviceStepObject : NSObject
- (unsigned int)m7StepCount;
- (unsigned int)hkStepCount;
@end

@interface ContactsDataLogic : NSObject
- (unsigned int)m_uiNormalContact;
@end
@interface ContactsViewController : UIViewController
- (void)updateCount;
@end

@interface WCPayBalanceDetailViewController : UIViewController
- (id)balanceTitleLabel;
- (void)updateBalanceTitleLabel;
- (void)refreshViewWithData:(id)arg;
@end

@interface WCPayLQTInfo : NSObject
- (unsigned long long)lqtAvailBalance;
- (unsigned long long)lqtTotalBalance;
@end

@interface WCPayLQTDetailControlLogic : NSObject
- (long long)lqtBalance;
@end

@interface WCPayBalanceInfo : NSObject
- (unsigned long long)wallet_balance;
- (unsigned long long)m_uiAvailableBalance;
- (unsigned long long)m_uiTotalBalance;
@end

@interface WCPayMainViewControllerV2 : UIViewController
@end

@interface TimeoutNumber : UIView
- (void)defaultNumber:(unsigned long long)a0;
- (void)setNoAnimationStart:(unsigned long long)a0;
- (void)updateNumber:(unsigned long long)a0;
- (void)updateNumberInternal:(unsigned long long)a0;
- (void)updateScrollNumber;
- (void)layoutSubviews;
- (id)scrollNumber;
@end

@interface ScrollNumber : NSObject

- (void)updateNumber:(unsigned long long)a0;
- (void)defaultNumber:(unsigned long long)a0;
- (void)setCurrentNumber:(unsigned long long)a0;
- (unsigned long long)currentNumber;
@end

@class WCPayTableCellViewDataView;

#pragma mark - 配置管理（接口）
// 全局开关与各功能自定义值；以 NSUserDefaults 持久化（见文件末"配置管理（实现）"）。


static NSString * const kDDFeatureTextEnabled = @"DDFeatureTextEnabled";
static NSString * const kDDFeatureTransferEnabled = @"DDFeatureTransferEnabled";
static NSString * const kDDFeatureImageEnabled = @"DDFeatureImageEnabled";
static NSString * const kDDFeatureTimeEnabled = @"DDFeatureTimeEnabled";
static NSString * const kDDFeatureBalanceEnabled = @"DDFeatureBalanceEnabled";
static NSString * const kDDFeatureStepsEnabled = @"DDFeatureStepsEnabled";
static NSString * const kDDFeatureContactsEnabled = @"DDFeatureContactsEnabled";
static NSString * const kDDFeatureDiagEnabled = @"DDFeatureDiagEnabled";

static NSString * const kDDStepsValueStringKey = @"DDStepsValueString";
static NSString * const kDDContactsCountValueKey = @"DDContactsCountValue";
static NSString * const kDDBalanceValueKey = @"DDBalanceValue";
static NSString * const kDDLingtongValueKey = @"DDLingtongValue";

@interface DDGlobalConfig : NSObject
+ (instancetype)shared;
@property (nonatomic) BOOL textEnabled;
@property (nonatomic) BOOL imageEnabled;
@property (nonatomic) BOOL timeEnabled;
@property (nonatomic) BOOL transferEnabled;
@property (nonatomic) BOOL balanceEnabled;
@property (nonatomic) BOOL stepsEnabled;
@property (nonatomic) BOOL contactsEnabled;

@property (nonatomic) BOOL diagEnabled;
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

#pragma mark - 通用诊断日志 · 采集
// DDLOG 写内存缓冲（导出用）；DDJokerHit 做 hook 命中计数与节流；清空 / 统计供设置页与导出模块调用。


static BOOL DDStringHas(const char *haystack, const char *needle) {
    if (!haystack || !needle || !*needle) return NO;
    NSString *h = [[NSString stringWithUTF8String:haystack] lowercaseString];
    NSString *n = [[NSString stringWithUTF8String:needle] lowercaseString];
    return (h && n) ? ([h rangeOfString:n].location != NSNotFound) : NO;
}

static NSDateFormatter *DDLogTimeFormatter(void) {
    static NSDateFormatter *fmt = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        fmt = [[NSDateFormatter alloc] init];
        fmt.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
        fmt.dateFormat = @"HH:mm:ss.SSS";
    });
    return fmt;
}

static NSMutableString *DDLogBuffer(void) {
    static NSMutableString *buf = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ buf = [NSMutableString string]; });
    return buf;
}

static NSMutableDictionary *DDLogHits(void) {
    static NSMutableDictionary *hits = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ hits = [NSMutableDictionary dictionary]; });
    return hits;
}

static void DDJokerLog(NSString *fmt, ...) {
    if (![DDGlobalConfig shared].diagEnabled) return;
    va_list ap;
    va_start(ap, fmt);
    NSString *msg = [[NSString alloc] initWithFormat:fmt arguments:ap];
    va_end(ap);
    NSString *line = [NSString stringWithFormat:@"%@  %@",
                      [DDLogTimeFormatter() stringFromDate:[NSDate date]], msg];
    NSLog(@"[DD小丑] %@", line);
    NSMutableString *buf = DDLogBuffer();
    @synchronized (buf) {
        [buf appendFormat:@"%@\n", line];
        if (buf.length > 300000) {
            [buf deleteCharactersInRange:NSMakeRange(0, buf.length - 200000)];
        }
    }
}

#define DDLOG(...) DDJokerLog(__VA_ARGS__)

// hook 命中计数，节流输出（前 3 次 + 每 50 次），避免刷屏。
// 插件加载时已记一次（见 %ctor），新功能里调 DDJokerHit(@"标签") 即追加命中统计。
static void DDJokerHit(NSString *tag) {
    NSMutableDictionary *hits = DDLogHits();
    NSInteger n = 0;
    @synchronized (hits) {
        n = [hits[tag] integerValue] + 1;
        hits[tag] = @(n);
    }
    if (n <= 3 || n % 50 == 0) DDLOG(@"HIT %@ 第 %ld 次", tag, (long)n);
}

static void DDJokerClearDiagLog(void) {
    NSMutableString *buf = DDLogBuffer();
    @synchronized (buf) { [buf setString:@""]; }
    NSMutableDictionary *hits = DDLogHits();
    @synchronized (hits) { [hits removeAllObjects]; }
}

static NSString *DDJokerDescribeHitStats(void) {
    NSMutableDictionary *hits = DDLogHits();
    if (!hits.count) return @"  (还没有任何 hook 被触发)\n";
    NSMutableString *s = [NSMutableString string];
    for (NSString *k in [[hits allKeys] sortedArrayUsingSelector:@selector(compare:)]) {

        [s appendFormat:@"  %@ : %@ 次\n", k, hits[k]];
    }
    return s;
}

#pragma mark - 聊天消息改写（文字 / 图片 / 转账）
// 长按消息弹出"小丑"菜单：文字改内容与引用标题、图片替换为相册所选图、转账改金额。
// 改写值按消息 m_uiMesLocalID 缓存到 plist，刷新走 cell/viewModel 重绘。


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

static NSString *JokerUnescapeXML(NSString *s) {
    if (![s isKindOfClass:[NSString class]] || !s.length) return s;
    NSDictionary *map = @{@"&lt;":@"<", @"&gt;":@">", @"&amp;":@"&",
                          @"&quot;":@"\"", @"&apos;":@"'"};
    NSMutableString *m = [s mutableCopy];
    for (NSString *key in map) {
        [m replaceOccurrencesOfString:key withString:map[key]
                               options:NSLiteralSearch range:NSMakeRange(0, m.length)];
    }
    return m;
}

static NSString *JokerReferMessageTitle(CMessageWrap *msg) {
    NSString *xml = [msg m_nsContent];
    if (![xml isKindOfClass:[NSString class]] || !xml.length) return nil;
    static NSRegularExpression *re;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        re = [NSRegularExpression regularExpressionWithPattern:@"<title\\s*>(.*?)</title\\s*>"
                                                        options:NSRegularExpressionCaseInsensitive | NSRegularExpressionDotMatchesLineSeparators
                                                          error:nil];
    });
    NSTextCheckingResult *r = [re firstMatchInString:xml options:0 range:NSMakeRange(0, xml.length)];
    if (!r || r.numberOfRanges < 2) return nil;
    NSString *t = [xml substringWithRange:[r rangeAtIndex:1]];
    t = [t stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    t = JokerUnescapeXML(t);
    return t.length ? t : nil;
}

static BOOL JokerIsTransferCell(CommonMessageCellView *cell) {
    return [cell isKindOfClass:%c(WCPayTransferMessageCellView)];
}

static BOOL JokerIsSupportedCell(CommonMessageCellView *cell) {
    if (!cell) return NO;
    if (JokerIsTransferCell(cell)) return YES;
    if ([cell isKindOfClass:%c(TextMessageCellView)]) {
        CMessageWrap *msg = JokerGetMessageWrapFromCell(cell);
        return JokerIsTextMessage(msg) || JokerIsReferMessage(msg);
    }
    return NO;
}

static BOOL JokerEnabledForCell(CommonMessageCellView *cell) {
    if (JokerIsTransferCell(cell)) return [DDGlobalConfig shared].transferEnabled;
    return [DDGlobalConfig shared].textEnabled;
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
    if (!filtered.length) return nil;

    if ([filtered rangeOfString:@"."].location == NSNotFound) {
        [filtered appendString:@".00"];
    }
    return filtered;
}

static NSString * const kDDJokerTextCacheKey = @"DDJokerTextCache";
static NSString * const kDDJokerAmountCacheKey = @"DDJokerAmountCache";
static NSString * const kDDJokerTimeCacheKey = @"DDJokerTimeCache";

static NSString * const kDDJokerTextOriginalKey = @"DDJokerTextOriginal";

static NSString *DDJokerMessageKey(CMessageWrap *msg) {
    return [NSString stringWithFormat:@"%u", msg.m_uiMesLocalID];
}

static NSString *DDJokerCacheDir(void) {
    NSString *dir = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Caches/DDJoker"];
    [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    return dir;
}
static NSString *DDJokerCacheFile(NSString *name) {
    return [DDJokerCacheDir() stringByAppendingPathComponent:[name stringByAppendingString:@".plist"]];
}
static NSMutableDictionary *DDJokerLoadCache(NSString *name) {
    NSMutableDictionary *d = [NSMutableDictionary dictionaryWithContentsOfFile:DDJokerCacheFile(name)];
    return d ?: [NSMutableDictionary dictionary];
}
static void DDJokerSaveCache(NSString *name, NSDictionary *d) {
    [d writeToFile:DDJokerCacheFile(name) atomically:YES];
}
static NSString *DDJokerImagesDir(void) {
    NSString *dir = [DDJokerCacheDir() stringByAppendingPathComponent:@"DDJokerImages"];
    [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    return dir;
}

static NSString *DDJokerCachedText(CMessageWrap *msg) {
    if (!msg) return nil;
    NSDictionary *d = DDJokerLoadCache(kDDJokerTextCacheKey);
    NSString *v = d[DDJokerMessageKey(msg)];
    return v.length ? v : nil;
}

static void DDJokerSetCachedText(CMessageWrap *msg, NSString *text) {
    if (!msg) return;
    NSMutableDictionary *d = DDJokerLoadCache(kDDJokerTextCacheKey);
    if (text.length) d[DDJokerMessageKey(msg)] = text;
    else [d removeObjectForKey:DDJokerMessageKey(msg)];
    DDJokerSaveCache(kDDJokerTextCacheKey, d);
}

static NSString *DDJokerOriginalText(CMessageWrap *msg) {
    if (!msg) return nil;
    NSDictionary *d = DDJokerLoadCache(kDDJokerTextOriginalKey);
    NSString *v = d[DDJokerMessageKey(msg)];
    return v.length ? v : nil;
}

static void DDJokerSetOriginalText(CMessageWrap *msg, NSString *text) {
    if (!msg || !text.length) return;
    if (DDJokerOriginalText(msg)) return;
    NSMutableDictionary *d = DDJokerLoadCache(kDDJokerTextOriginalKey);
    d[DDJokerMessageKey(msg)] = text;
    DDJokerSaveCache(kDDJokerTextOriginalKey, d);
}

static NSString *DDJokerCachedAmount(CMessageWrap *msg) {
    if (!msg) return nil;
    NSDictionary *d = DDJokerLoadCache(kDDJokerAmountCacheKey);
    NSString *v = d[DDJokerMessageKey(msg)];
    return v.length ? v : nil;
}

static void DDJokerSetCachedAmount(CMessageWrap *msg, NSString *amount) {
    if (!msg) return;
    NSMutableDictionary *d = DDJokerLoadCache(kDDJokerAmountCacheKey);
    if (amount.length) d[DDJokerMessageKey(msg)] = amount;
    else [d removeObjectForKey:DDJokerMessageKey(msg)];
    DDJokerSaveCache(kDDJokerAmountCacheKey, d);
}

static NSString *gDDLastTransferOverride = nil;

#pragma mark - 聊天时间 · 缓存与 ivar 读写
// 直接读写 ChatTimeViewModel 的 _showingTime ivar（double 时间戳）；缓存按消息或原始时间戳索引。


static Ivar DDShowingTimeIvarOf(id vm) {
    if (!vm) return NULL;
    Class cls = [vm class];
    Ivar iv = class_getInstanceVariable(cls, "_showingTime");
    if (iv) return iv;

    Class c = cls;
    while (c && !iv) {
        unsigned int n = 0;
        Ivar *list = class_copyIvarList(c, &n);
        for (unsigned int i = 0; i < n; i++) {
            const char *nm = ivar_getName(list[i]) ?: "";
            const char *ty = ivar_getTypeEncoding(list[i]) ?: "";
            if (strcmp(ty, "d") == 0 && DDStringHas(nm, "showingtime")) { iv = list[i]; break; }
        }
        free(list);
        c = class_getSuperclass(c);
    }
    return iv;
}

static double DDShowingTimeOf(id vm) {
    Ivar iv = DDShowingTimeIvarOf(vm);
    if (!iv) return 0.0;
    return *(double *)((uint8_t *)(__bridge void *)vm + ivar_getOffset(iv));
}

static void DDSetShowingTime(id vm, double ts) {
    Ivar iv = DDShowingTimeIvarOf(vm);
    if (!iv) return;
    *(double *)((uint8_t *)(__bridge void *)vm + ivar_getOffset(iv)) = ts;
}

static void DDRefreshTimeText(id vm) {
    [(ChatTimeViewModel *)vm updateLayouts];
}

static char kDDRawTimeKey;
static double DDRawShowingTimeOf(id vm) {
    if (!vm) return 0.0;
    NSNumber *raw = objc_getAssociatedObject(vm, &kDDRawTimeKey);
    if (!raw) {
        raw = @(DDShowingTimeOf(vm));
        objc_setAssociatedObject(vm, &kDDRawTimeKey, raw, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return [raw doubleValue];
}

static NSString *DDJokerTimeKey(id vm) {
    id wrap = [vm respondsToSelector:@selector(messageWrap)] ? [vm messageWrap] : nil;
    if ([wrap respondsToSelector:@selector(m_uiMesLocalID)] && [wrap m_uiMesLocalID] != 0) {
        return DDJokerMessageKey((CMessageWrap *)wrap);
    }
    return [NSString stringWithFormat:@"ts_%.3f", DDRawShowingTimeOf(vm)];
}

static NSNumber *DDJokerCachedTime(id vm) {
    if (!vm) return nil;
    NSDictionary *d = DDJokerLoadCache(kDDJokerTimeCacheKey);
    id v = d[DDJokerTimeKey(vm)];
    return [v isKindOfClass:[NSNumber class]] ? v : nil;
}

static void DDJokerSetCachedTime(id vm, double timestamp) {
    if (!vm) return;
    NSMutableDictionary *d = DDJokerLoadCache(kDDJokerTimeCacheKey);
    if (timestamp > 0) d[DDJokerTimeKey(vm)] = @(timestamp);
    else [d removeObjectForKey:DDJokerTimeKey(vm)];
    DDJokerSaveCache(kDDJokerTimeCacheKey, d);
}

static void DDApplyTimeOverride(id vm) {
    if (!vm || ![DDGlobalConfig shared].timeEnabled) return;
    NSNumber *cached = DDJokerCachedTime(vm);
    if (cached && DDShowingTimeOf(vm) != [cached doubleValue]) {
        DDSetShowingTime(vm, [cached doubleValue]);
    }
}

static void DDJokerClearAllMessageCache(void) {
    NSFileManager *fm = [NSFileManager defaultManager];

    [fm removeItemAtPath:DDJokerCacheFile(kDDJokerTextCacheKey) error:nil];
    [fm removeItemAtPath:DDJokerCacheFile(kDDJokerAmountCacheKey) error:nil];
    [fm removeItemAtPath:DDJokerCacheFile(kDDJokerTimeCacheKey) error:nil];

    [fm removeItemAtPath:DDJokerImagesDir() error:nil];
}

static __weak id gDDLastTimeVM = nil;

static NSString *DDTimeDesc(double ts) {
    if (ts <= 0) return @"0 (无效)";
    return [NSString stringWithFormat:@"%.3f  %@", ts, [NSDate dateWithTimeIntervalSince1970:ts]];
}

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

static void DDCollectViewsOfClass(UIView *root, Class cls, NSMutableArray *out) {
    if (!root) return;
    if ([root isKindOfClass:cls]) {
        if (![out containsObject:root]) [out addObject:root];
        return;
    }
    for (UIView *v in root.subviews) DDCollectViewsOfClass(v, cls, out);
}

static NSArray *DDVisibleCellViewsOfClass(UITableView *tv, Class cls) {
    NSMutableArray *out = [NSMutableArray array];
    if (![tv isKindOfClass:[UITableView class]] || !cls) return out;
    for (UITableViewCell *c in [tv visibleCells]) {
        DDCollectViewsOfClass(c.contentView, cls, out);
        DDCollectViewsOfClass(c, cls, out);
    }
    return out;
}

static void JokerRefreshVisibleImageCells(void) {
    for (UIViewController *vc in JokerAllChatViewControllers()) {
        UITableView *tv = [(BaseMsgContentViewController *)vc getMsgTableView];
        if (![tv isKindOfClass:[UITableView class]]) continue;
        for (ImageMessageCellView *cellView in DDVisibleCellViewsOfClass(tv, %c(ImageMessageCellView))) {
            if ([cellView respondsToSelector:@selector(showImage)]) [cellView showImage];
        }
    }
}

static NSString *DDTransferFeedescAmount(NSString *xml);
static NSString *JokerGetDisplayText(CMessageWrap *msg, BOOL isTransfer) {
    if (isTransfer) {
        NSString *cached = DDJokerCachedAmount(msg);
        if (cached.length) return cached;
        NSString *raw = DDTransferFeedescAmount([msg m_nsContent]);
        return JokerNormalizeAmount(raw) ?: @"";
    }
    NSString *cached = DDJokerCachedText(msg);
    if (cached) return cached;

    if (JokerIsReferMessage(msg)) {
        NSString *t = JokerReferMessageTitle(msg);
        if (t) return t;
    }
    return [msg GetDisplayContent] ?: @"";
}

static UITableView *JokerFindTableView(UIView *view) {
    UIView *v = view;
    while (v) {
        if ([v isKindOfClass:[UITableView class]]) return (UITableView *)v;
        v = v.superview;
    }
    return nil;
}

static void JokerApplyTextToRichView(id richView, NSString *text) {
    if (!richView || !text) return;
    [richView setContent:text];
    [richView calculateAndUpdateFrame];
    [richView forceDisplayInSync];
    [richView setNeedsDisplay];
}

static void JokerResetViewModelCache(CommonMessageCellView *cell) {
    id vm = cell.viewModel;
    [vm resetLayoutCache];
}

static void JokerRefreshCellDirectly(CommonMessageCellView *cell) {
    if (!cell) return;
    JokerResetViewModelCache(cell);
    CMessageWrap *msg = JokerGetMessageWrapFromCell(cell);

    if ([cell isKindOfClass:%c(TextMessageCellView)]) {
        NSString *cached = [DDGlobalConfig shared].textEnabled ? DDJokerCachedText(msg) : nil;

        if (!cached && (JokerIsTextMessage(msg) || JokerIsReferMessage(msg))) {
            if (JokerIsReferMessage(msg)) {
                cached = JokerReferMessageTitle(msg) ?: [msg GetDisplayContent];
            } else {
                cached = [msg GetDisplayContent];
            }
        }
        JokerApplyTextToRichView([(TextMessageCellView *)cell getRichTextView], cached);
        [(TextMessageCellView *)cell layoutContentView];
    } else if ([cell isKindOfClass:%c(WCPayTransferMessageCellView)]) {
        [(WCPayTransferMessageCellView *)cell layoutContentView];

        [(WCPayTransferMessageCellView *)cell updateTitleLabel];
        [(WCPayTransferMessageCellView *)cell updateDescLabel];
    } else if ([cell isKindOfClass:%c(ImageMessageCellView)]) {
        [(ImageMessageCellView *)cell showImage];
    }
    [cell setNeedsLayout];
}

static void JokerInvalidateAllLayout(void);

static void JokerReloadCellAfterReplace(id vc, CMessageWrap *msg, CommonMessageCellView *cell) {
    JokerRefreshCellDirectly(cell);
    UITableView *tv = cell ? JokerFindTableView((UIView *)cell) : nil;
    if (![tv isKindOfClass:[UITableView class]] && [vc isKindOfClass:%c(BaseMsgContentViewController)]) {
        tv = [(BaseMsgContentViewController *)vc getMsgTableView];
    }
    if (![tv isKindOfClass:[UITableView class]]) {

        JokerReloadAllMsgContent();
        return;
    }

    CGPoint center = [cell convertPoint:CGPointMake(CGRectGetMidX(cell.bounds), CGRectGetMidY(cell.bounds)) toView:tv];
    NSIndexPath *ip = [tv indexPathForRowAtPoint:center];
    if (ip) {
        [UIView performWithoutAnimation:^{
            [tv reloadRowsAtIndexPaths:@[ip] withRowAnimation:UITableViewRowAnimationNone];
        }];
        return;
    }
    JokerInvalidateAllLayout();
}

static void JokerPresentEditor(CommonMessageCellView *cell) {

    if (!JokerIsSupportedCell(cell)) return;
    CMessageWrap *msg = JokerGetMessageWrapFromCell(cell);
    id vc = JokerGetViewControllerFromView(cell);

    BOOL isTransfer = JokerIsTransferCell(cell);
    NSString *current = JokerGetDisplayText(msg, isTransfer);

    NSString *editorTitle = isTransfer ? @"转账修改" : @"文字修改";
    NSString *editorMessage = isTransfer ? @"请输入需要修改的金额\n留空还原" : @"请输入需要修改的文字\n留空还原";
    WCUIAlertView *alert = [(WCUIAlertView *)[%c(WCUIAlertView) alloc] initWithTitle:editorTitle message:editorMessage];
    if (!alert) return;
    [alert showTextFieldWithMaxLen:1000];
    [alert setTextFieldDefaultText:current];

    __block WCUIAlertView *blockAlert = alert;
    __block UITextField *inputField = nil;
    [alert addCancelBtnTitle:@"取消" handler:^{}];
    [alert addBtnTitle:@"确定" handler:^{
        NSString *raw = blockAlert ? [blockAlert getTextFieldText] : nil;
        if (!raw.length) raw = inputField.text;
        NSString *newText = [raw stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (newText.length) {
            if ([newText isEqualToString:current]) { blockAlert = nil; return; }
            if (isTransfer) {
                NSString *normalized = JokerNormalizeAmount(newText);
                if (normalized) { DDJokerSetCachedAmount(msg, normalized); gDDLastTransferOverride = normalized; }
            } else {
                DDJokerSetCachedText(msg, newText);
            }
            JokerReloadCellAfterReplace(vc, msg, cell);
        } else if (isTransfer ? DDJokerCachedAmount(msg) : DDJokerCachedText(msg)) {

            if (isTransfer) DDJokerSetCachedAmount(msg, nil);
            else DDJokerSetCachedText(msg, nil);
            JokerReloadCellAfterReplace(vc, msg, cell);
        }
        blockAlert = nil;
    }];
    [alert show];
    UITextField *tf = [alert getTextField];
    if (tf) {
        inputField = tf;
        if (isTransfer) tf.keyboardType = UIKeyboardTypeDecimalPad;
    }
}

static NSArray *JokerInjectMenuItem(CommonMessageCellView *cell, NSArray *original) {

    if (!JokerEnabledForCell(cell)) return original;
    if (!JokerIsSupportedCell(cell)) return original;

    UIImage *icon = [[UIImage systemImageNamed:@"face.smiling.fill"] imageWithTintColor:[UIColor whiteColor] renderingMode:UIImageRenderingModeAlwaysOriginal];
    MMMenuItem *newItem = [(MMMenuItem *)[%c(MMMenuItem) alloc] initWithTitle:@"小丑" icon:icon target:cell action:@selector(joker_handleMenuItem:)];
    NSMutableArray *newItems = [NSMutableArray arrayWithArray:original];
    [newItems insertObject:newItem atIndex:0];
    return newItems;
}

static void DDJokerApplyTextOverride(CMessageWrap *msg) {
    if (!msg) return;
    if (!JokerIsTextMessage(msg) && !JokerIsReferMessage(msg)) return;
    NSString *original = DDJokerOriginalText(msg);
    if (!original.length) {
        DDJokerSetOriginalText(msg, msg.m_nsContent);
        original = msg.m_nsContent;
    }
    NSString *cached = [DDGlobalConfig shared].textEnabled ? DDJokerCachedText(msg) : nil;
    NSString *target = cached ?: original;
    if (target.length && ![target isEqualToString:msg.m_nsContent]) {
        [msg setM_nsContent:target];
    }
}

%hook TextMessageViewModel
- (NSString *)contentText {
    DDJokerApplyTextOverride(self.messageWrap);
    NSString *origin = %orig;
    if (![DDGlobalConfig shared].textEnabled) return origin;
    CMessageWrap *msg = self.messageWrap;

    if (!JokerIsTextMessage(msg) && !JokerIsReferMessage(msg)) return origin;
    NSString *cached = DDJokerCachedText(msg);
    return cached ?: origin;
}
%end

static BOOL gJokerNeedsResetLayout = NO;

static void JokerInvalidateAllLayout(void) {
    gJokerNeedsResetLayout = YES;
    JokerReloadAllMsgContent();
    JokerRefreshVisibleImageCells();
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        gJokerNeedsResetLayout = NO;
    });
}

%hook TextMessageCellView

- (void)setViewModel:(id)vm {
    %orig;
    if (![vm respondsToSelector:@selector(resetLayoutCache)]) return;
    CMessageWrap *msg = [(CommonMessageViewModel *)vm messageWrap];
    if (!JokerIsTextMessage(msg) && !JokerIsReferMessage(msg)) return;

    if (gJokerNeedsResetLayout || DDJokerCachedText(msg) || ![DDGlobalConfig shared].textEnabled) {
        [(TextMessageViewModel *)vm resetLayoutCache];
    }
}
- (id)getTextString {
    CMessageWrap *msg = JokerGetMessageWrapFromCell(self);
    DDJokerApplyTextOverride(msg);
    id origin = %orig;
    if (![DDGlobalConfig shared].textEnabled) return origin;
    if (!JokerIsTextMessage(msg) && !JokerIsReferMessage(msg)) return origin;
    NSString *cached = DDJokerCachedText(msg);
    return cached ?: origin;
}
- (NSArray *)operationMenuItems {
    return JokerInjectMenuItem(self, %orig);
}
- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
    if (action == @selector(joker_handleMenuItem:)) {
        return JokerEnabledForCell(self) && JokerIsSupportedCell(self);
    }
    return %orig;
}
%new
- (void)joker_handleMenuItem:(id)sender {
    JokerPresentEditor(self);
}
%end

static NSString *DDTransferFeedescAmount(NSString *xml) {
    if (!xml.length) return nil;
    NSString *open = @"<feedesc><![CDATA[";
    NSString *close = @"]]></feedesc>";
    NSRange ro = [xml rangeOfString:open];
    if (ro.location == NSNotFound) return nil;
    NSUInteger start = ro.location + ro.length;
    NSRange rc = [xml rangeOfString:close options:0 range:NSMakeRange(start, xml.length - start)];
    if (rc.location == NSNotFound) return nil;
    return [xml substringWithRange:NSMakeRange(start, rc.location - start)];
}

static NSString *DDTransferReplaceAmountInText(NSString *text, NSString *override) {
    if (!text.length || !override.length) return text;
    // 转账消息金额：必带 ¥、两位小数（允许千分位逗号）。
    NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:@"¥\\d[\\d,]*\\.\\d{2}"
                                                                        options:0
                                                                          error:nil];
    if (!re) return text;
    NSString *newAmount = [@"¥" stringByAppendingString:override];
    return [re stringByReplacingMatchesInString:text
                                       options:0
                                         range:NSMakeRange(0, text.length)
                                  withTemplate:newAmount];
}

%hook WCPayTransferMessageCellView

- (NSArray *)operationMenuItems {
    return JokerInjectMenuItem(self, %orig);
}
- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {

    if (action == @selector(joker_handleMenuItem:)) {
        return [DDGlobalConfig shared].transferEnabled;
    }
    return %orig;
}
%new
- (void)joker_handleMenuItem:(id)sender {
    JokerPresentEditor(self);
}
%end

%hook WCPayTransferMessageViewModel
- (NSString *)titleText {
    NSString *origin = %orig;
    if (![DDGlobalConfig shared].transferEnabled) return origin;
    NSString *cached = DDJokerCachedAmount(self.messageWrap);
    NSString *out = cached ? DDTransferReplaceAmountInText(origin, cached) : origin;
    return out;
}
- (NSString *)descText {
    NSString *origin = %orig;
    if (![DDGlobalConfig shared].transferEnabled) return origin;
    NSString *cached = DDJokerCachedAmount(self.messageWrap);
    return cached ? DDTransferReplaceAmountInText(origin, cached) : origin;
}
%end

// 转账详情页金额改写（精确方案，零 view 树遍历）：
// 用 Flex 锁定真实金额 label 是 MMUILabel（baseClass=UILabel，frame=(0 128; 414 54)，text=¥0.01），
// 直接 hook MMUILabel 的 setText:/setAttributedText:，仅当"label 归属转账详情页 VC +
// 文本是 ¥ 金额 + 存在 override"时改写。微信每次重设金额（含状态轮询/刷新）都会被接住，不闪不还原。
// 该 label enableLongPressCopy=0，长按复制未启用，textToCopy 不参与，故不写。

// 沿 responder 链上溯判断 label 是否属于转账详情页（只走 responder 链，不遍历 view 树）。
static BOOL DDLabelOnTransferDetailVC(id v) {
    Class detailVC = %c(WCPayTransferMoneyStatusViewController);
    if (!detailVC) return NO;
    UIResponder *r = (UIResponder *)v;
    while (r) {
        if ([r isKindOfClass:detailVC]) return YES;
        r = r.nextResponder;
    }
    return NO;
}

%hook MMUILabel
- (void)setText:(NSString *)text {
    NSString *ov = gDDLastTransferOverride;
    if (ov.length && [DDGlobalConfig shared].transferEnabled && [text hasPrefix:@"¥"] && DDLabelOnTransferDetailVC(self)) {
        NSString *nt = [@"¥" stringByAppendingString:ov];
        DDLOG(@"[详情页金额] setText 改写 -> %@", nt);
        DDJokerHit(@"转账详情页金额");
        %orig(nt);
    } else {
        %orig;
    }
}
- (void)setAttributedText:(NSAttributedString *)attr {
    NSString *ov = gDDLastTransferOverride;
    if (ov.length && [DDGlobalConfig shared].transferEnabled && attr.string.length && [attr.string hasPrefix:@"¥"] && DDLabelOnTransferDetailVC(self)) {
        NSDictionary *attrs = [attr attributesAtIndex:0 effectiveRange:NULL];
        NSAttributedString *na = [[NSAttributedString alloc] initWithString:[@"¥" stringByAppendingString:ov] attributes:attrs];
        DDLOG(@"[详情页金额] setAttributedText 改写 -> %@", na.string);
        DDJokerHit(@"转账详情页金额");
        %orig(na);
    } else {
        %orig;
    }
}
%end

#pragma mark - 聊天图片改写
// hook ImageMessageCellView 各渲染入口注入替换图；相册选图回调见下一段。


@interface DDWeChatImagePickerDelegate : NSObject <UIImagePickerControllerDelegate, UINavigationControllerDelegate>
@property (nonatomic, assign) unsigned int mesLocalID;
@property (nonatomic, weak) id cellView;
@end

static NSString *DDImageReplacementPath(unsigned int mesLocalID) {
    NSString *folder = DDJokerImagesDir();
    return [folder stringByAppendingPathComponent:[NSString stringWithFormat:@"%u.png", mesLocalID]];
}

static UIImage *DDImageReplacementForMessage(CMessageWrap *msg) {
    if (!msg || ![msg IsImgMsg]) return nil;
    NSString *path = DDImageReplacementPath(msg.m_uiMesLocalID);
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) return nil;
    return [UIImage imageWithContentsOfFile:path];
}

static UIImageView *DDImageViewFromCell(UIView *cell) {
    if (!cell) return nil;
    // Flex 实测：图片 view 是 ImageMessageCellView 的 m_imageView ivar（YYAsyncImageView，UIImageView 子类）。
    // 直接取 ivar，零遍历。
    Ivar ivar = class_getInstanceVariable([cell class], "m_imageView");
    if (ivar) {
        id value = object_getIvar(cell, ivar);
        if ([value isKindOfClass:[UIImageView class]]) return (UIImageView *)value;
    }
    return nil;
}

static void DDImageApplyReplacementToCell(id cell) {
    if (![DDGlobalConfig shared].imageEnabled) return;
    CMessageWrap *msg = ((CommonMessageCellView *)cell).viewModel.messageWrap;
    UIImage *rep = DDImageReplacementForMessage(msg);
    if (rep) {
        UIImageView *iv = DDImageViewFromCell((UIView *)cell);
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
    picker.title = @"图片修改";
    DDWeChatImagePickerDelegate *delegate = [[DDWeChatImagePickerDelegate alloc] init];
    delegate.mesLocalID = msg.m_uiMesLocalID;
    delegate.cellView = self;
    picker.delegate = delegate;

    objc_setAssociatedObject(picker, "dd_picker_delegate", delegate, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [vc presentViewController:picker animated:YES completion:nil];
}
- (void)showImage {
    %orig;
    DDImageApplyReplacementToCell(self);
}
- (void)OnDownloadImageOk:(id)a0 {

    %orig;
    DDImageApplyReplacementToCell(self);
}
- (void)layoutContentView {
    %orig;
    DDImageApplyReplacementToCell(self);
}
%end

@implementation DDWeChatImagePickerDelegate

#pragma mark - 系统相册选图回调
// DDWeChatImagePickerDelegate：选图后落盘到按 mesLocalID 命名的 png，并刷新对应 cell。

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<NSString *,id> *)info {
    UIImage *image = info[UIImagePickerControllerOriginalImage];
    if (image) [self dd_saveImage:image dismissPicker:picker];
    else [picker dismissViewControllerAnimated:YES completion:nil];
}
- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:YES completion:nil];
}

- (void)dd_saveImage:(UIImage *)image dismissPicker:(UIImagePickerController *)picker {
    NSString *path = DDImageReplacementPath(self.mesLocalID);
    NSData *data = UIImagePNGRepresentation(image);
    if (!data) { [picker dismissViewControllerAnimated:YES completion:nil]; return; }
    [data writeToFile:path atomically:YES];

    id cellView = self.cellView;
    if ([cellView isKindOfClass:%c(ImageMessageCellView)]) {
        DDImageApplyReplacementToCell(cellView);
        [(UIView *)cellView setNeedsLayout];
    } else {
        JokerInvalidateAllLayout();
    }
    [picker dismissViewControllerAnimated:YES completion:nil];
}
@end

#pragma mark - 聊天时间改写
// hook ChatTimeViewModel / ChatTimeCellView：接管时间条显示，长按弹输入改时间。


static char kDDTimeVMKey;

static NSDateFormatter *DDTimeInputFormatter(void) {
    NSDateFormatter *f = [[NSDateFormatter alloc] init];
    f.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    f.dateFormat = @"yyyy-MM-dd HH:mm";
    return f;
}

static double DDTimeStampFromString(NSString *s) {
    if (!s.length) return 0;
    NSDate *d = [DDTimeInputFormatter() dateFromString:s];
    return d ? [d timeIntervalSince1970] : 0;
}

%hook ChatTimeViewModel
- (NSString *)timeText {
    gDDLastTimeVM = self;

    double raw = DDRawShowingTimeOf(self);
    NSNumber *cached = [DDGlobalConfig shared].timeEnabled ? DDJokerCachedTime(self) : nil;
    double target = cached ? [cached doubleValue] : raw;

    if (target > 0 && DDShowingTimeOf(self) != target) {
        DDSetShowingTime(self, target);
        DDRefreshTimeText(self);
    }

    NSString *o = %orig;
    if (!o && cached) {

    }
    return o;
}

- (void)updateLayouts {
    %orig;
}
%end

%hook ChatTimeCellView
- (id)initWithViewModel:(id)vm {
    id r = %orig;

    objc_setAssociatedObject(r, &kDDTimeVMKey, vm, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [(ChatTimeCellView *)r dk_installTimeEditGesture];
    return r;
}
- (void)setViewModel:(id)vm {
    %orig;
    objc_setAssociatedObject(self, &kDDTimeVMKey, vm, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [self dk_installTimeEditGesture];
}
- (void)layoutInternal {
    %orig;
}

- (void)didMoveToWindow {
    %orig;
    [self dk_installTimeEditGesture];
    if (!self.window) return;
    id vm = objc_getAssociatedObject(self, &kDDTimeVMKey);
    if (!vm) return;
    NSNumber *cached = [DDGlobalConfig shared].timeEnabled ? DDJokerCachedTime(vm) : nil;
    if (!cached) return;

    dispatch_async(dispatch_get_main_queue(), ^{
        if (!self.window) return;
        id v = objc_getAssociatedObject(self, &kDDTimeVMKey);
        if (!v) return;
        NSNumber *c = [DDGlobalConfig shared].timeEnabled ? DDJokerCachedTime(v) : nil;
        if (!c) return;
        DDApplyTimeOverride(v);
        DDRefreshTimeText(v);
        [(ChatTimeCellView *)self layoutInternal];
        [self setNeedsLayout];
    });
}
%new
- (UILabel *)dk_timeLabel {
    // Flex 实测：时间 label 即 ChatTimeCellView 的 m_timeLabel ivar（MMUILabel，文本如 "昨天 15:56"）。
    // 直接取 ivar，零遍历。
    Ivar iv = class_getInstanceVariable([self class], "m_timeLabel");
    if (iv) {
        id v = object_getIvar(self, iv);
        if ([v isKindOfClass:[UILabel class]]) return (UILabel *)v;
    }
    return nil;
}
%new
- (void)dk_installTimeEditGesture {
    if (![DDGlobalConfig shared].timeEnabled) return;
    UILabel *label = [self dk_timeLabel];
    if (!label) return;
    for (UIGestureRecognizer *g in label.gestureRecognizers) {
        if ([g isKindOfClass:[UILongPressGestureRecognizer class]]) return;
    }
    label.userInteractionEnabled = YES;
    UILongPressGestureRecognizer *lp = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(dk_handleTimeLongPress:)];
    lp.minimumPressDuration = 0.5;
    lp.allowableMovement = 24;
    lp.cancelsTouchesInView = NO;
    [label addGestureRecognizer:lp];
}
%new
- (void)dk_handleTimeLongPress:(UILongPressGestureRecognizer *)g {
    if (g.state != UIGestureRecognizerStateBegan) return;
    [self dk_showTimeInput];
}
%new
- (void)dk_showTimeInput {
    if (![DDGlobalConfig shared].timeEnabled) return;
    id vm = objc_getAssociatedObject(self, &kDDTimeVMKey);
    if (!vm || !%c(WCUIAlertView)) return;

    NSNumber *cached = DDJokerCachedTime(vm);
    double base = cached ? [cached doubleValue]
                         : DDShowingTimeOf(vm);
    NSString *defaultText = base > 0 ? [DDTimeInputFormatter() stringFromDate:[NSDate dateWithTimeIntervalSince1970:base]] : @"";

    WCUIAlertView *alert = [(WCUIAlertView *)[%c(WCUIAlertView) alloc] initWithTitle:@"时间修改"
                                                                           message:@"输入格式如下\n2024-08-01 22:30\n留空还原"];
    [alert showTextFieldWithMaxLen:100];
    [alert setTextFieldDefaultText:defaultText];

    __block WCUIAlertView *blockAlert = alert;
    __block UITextField *inputField = nil;
    [alert addCancelBtnTitle:@"取消" handler:^{ blockAlert = nil; }];
    [alert addBtnTitle:@"确定" handler:^{
        NSString *raw = blockAlert ? [blockAlert getTextFieldText] : nil;
        if (!raw.length) raw = inputField.text;
        NSString *t = [raw stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        double ts = DDTimeStampFromString(t);
        if (ts > 0) {

            DDJokerSetCachedTime(vm, ts);
            DDSetShowingTime(vm, ts);
            DDRefreshTimeText(vm);
            [self layoutInternal];
            [self setNeedsLayout];
        } else if (DDJokerCachedTime(vm)) {

            DDJokerSetCachedTime(vm, 0);
            double rawTime = DDRawShowingTimeOf(vm);
            if (rawTime > 0) DDSetShowingTime(vm, rawTime);
            DDRefreshTimeText(vm);
            [self layoutInternal];
            [self setNeedsLayout];
        }
        blockAlert = nil;
    }];
    [alert show];
    UITextField *tf = [alert getTextField];
    if (tf) inputField = tf;
    objc_setAssociatedObject(self, &kDDTimeVMKey, vm, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
%end

#pragma mark - 运动步数改写
// hook WCDeviceStepObject 的 m7StepCount / hkStepCount getter，返回自定义步数。


%hook WCDeviceStepObject
- (unsigned int)m7StepCount {
    DDGlobalConfig *cfg = [DDGlobalConfig shared];
    if (cfg.stepsEnabled && [cfg hasStepsValue]) {
        NSInteger v = [cfg stepsIntegerValue];
        if (v > 0) return (unsigned int)MIN(v, 99999);
    }
    return %orig;
}

- (unsigned int)hkStepCount {
    DDGlobalConfig *cfg = [DDGlobalConfig shared];
    if (cfg.stepsEnabled && [cfg hasStepsValue]) {
        NSInteger v = [cfg stepsIntegerValue];
        if (v > 0) return (unsigned int)MIN(v, 99999);
    }
    return %orig;
}
%end

#pragma mark - 好友数量改写
// hook ContactsDataLogic 数量 getter 与通讯录页标题。


%hook ContactsDataLogic
- (unsigned int)m_uiNormalContact {
    DDGlobalConfig *cfg = [DDGlobalConfig shared];
    if (cfg.contactsEnabled && [cfg hasContactsValue]) {
        NSInteger v = [cfg.contactsValue integerValue];
        if (v > 0) return (unsigned int)v;
    }
    return %orig;
}
%end

%hook ContactsViewController
- (void)viewWillAppear:(BOOL)animated {
    %orig;
    DDGlobalConfig *cfg = [DDGlobalConfig shared];
    if (cfg.contactsEnabled && [cfg hasContactsValue]) {
        self.title = [NSString stringWithFormat:@"通讯录(%@)", cfg.contactsValue];
    }

    if ([self respondsToSelector:@selector(updateCount)]) [self updateCount];
}
%end

#pragma mark - 余额 / 零钱通改写（工具）
// 元→分换算、页面类型判定（余额 / 零钱通 / 无关）、金额文本正则改写。


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

typedef NS_ENUM(NSInteger, DDBalancePageKind) {
    DDBalancePageNone = 0,
    DDBalancePageBalance,
    DDBalancePageLQT
};

static const void *kDDBalanceKindKey = &kDDBalanceKindKey;

// 页面判定：沿响应链找最近 VC，按 description 页标识区分余额/零钱通。
//   余额：balanceEntryUIPage / WCPayMainViewControllerV2；零钱通：lqtDetailUIPage
static DDBalancePageKind DDBalancePageKindOf(id sn) {
    @try {
        if (![sn isKindOfClass:[UIView class]]) return DDBalancePageNone;
        UIResponder *r = (UIResponder *)sn;
        for (int depth = 0; depth < 24 && r; depth++) {
            if ([r isKindOfClass:[UIViewController class]]) {
                NSString *cls = NSStringFromClass([r class]) ?: @"";
                NSString *all = [NSString stringWithFormat:@"%@ %@", cls, [r description] ?: @""];
                if ([all rangeOfString:@"lqtDetailUIPage"].location != NSNotFound)
                    return DDBalancePageLQT;
                if ([all rangeOfString:@"balanceEntryUIPage"].location != NSNotFound ||
                    [cls rangeOfString:@"WCPayMainViewControllerV2"].location != NSNotFound)
                    return DDBalancePageBalance;
            }
            r = r.nextResponder;
        }
    } @catch (NSException *e) {}
    return DDBalancePageNone;
}

static unsigned long long DDClampFen(unsigned long long fen) {
    const unsigned long long kMaxFen = 99999999999ULL;
    return fen > kMaxFen ? kMaxFen : fen;
}

static NSString *DDBalanceRewriteMoneyText(NSString *text, unsigned long long fen) {
    if (!text.length) return text;
    // 金额由 ScrollNumber 以两位小数渲染，¥ 为独立 label，故匹配可选 ¥ + 两位小数数字。
    NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:@"[¥￥]?\\s*\\d[\\d,]*\\.\\d{2}" options:0 error:nil];
    NSTextCheckingResult *m = [re firstMatchInString:text options:0 range:NSMakeRange(0, text.length)];
    if (!m || m.range.location == NSNotFound) return text;
    NSRange r = m.range;
    NSString *num = [text substringWithRange:r];
    BOOL sym = ([num hasPrefix:@"¥"] || [num hasPrefix:@"￥"]);
    NSString *core = sym ? [num substringFromIndex:1] : num;
    core = [core stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    BOOL comma = ([core rangeOfString:@","].location != NSNotFound);
    NSInteger dec = 0;
    NSRange dot = [core rangeOfString:@"."];
    if (dot.location != NSNotFound) dec = (NSInteger)core.length - (NSInteger)dot.location - 1;
    unsigned long long scaled = fen;
    if (dec > 2) { for (int i = 0; i < dec - 2; i++) scaled *= 10; }
    else { for (int i = 0; i < 2 - dec; i++) scaled /= 10; }
    unsigned long long ip = scaled / (unsigned long long)pow(10, dec);
    unsigned long long fp = scaled % (unsigned long long)pow(10, dec);
    NSMutableString *ipStr = [NSMutableString stringWithFormat:@"%llu", ip];
    if (comma) {
        NSMutableString *tmp = [NSMutableString string];
        NSInteger c = 0;
        for (NSInteger i = (NSInteger)ipStr.length - 1; i >= 0; i--) {
            [tmp insertString:[ipStr substringWithRange:NSMakeRange(i, 1)] atIndex:0];
            if (++c % 3 == 0 && c < (NSInteger)ipStr.length) [tmp insertString:@"," atIndex:0];
        }
        ipStr = tmp;
    }
    NSString *newNum = dec > 0 ? [NSString stringWithFormat:@"%@.%0*llu", ipStr, (int)dec, fp] : [ipStr copy];
    if (sym) newNum = [@"¥" stringByAppendingString:newNum];
    NSMutableString *out = [text mutableCopy];
    [out replaceCharactersInRange:r withString:newNum];
    return out;
}

static void DDBalancePatchTitleLabel(id vc, unsigned long long fen, NSString *hit) {
    @try {
        if (![vc respondsToSelector:@selector(balanceTitleLabel)]) return;
        id lb = [vc balanceTitleLabel];
        if (![lb isKindOfClass:[UILabel class]]) return;
        NSString *t = ((UILabel *)lb).text;
        if (!t.length) return;
        NSString *nt = DDBalanceRewriteMoneyText(t, fen);
        if (![nt isEqualToString:t]) { ((UILabel *)lb).text = nt; }
    } @catch (NSException *e) {}
}

#pragma mark - 余额 / 零钱通改写（接管 ScrollNumber 渲染）
// 接管 ScrollNumber 渲染链路与详情页 UILabel，写入自定义余额 / 零钱通值。


// 读路径静默替换：首判后把页面类型缓存到实例关联对象（O(1)）；
// 三个写入口在刷新时清缓存重判，避免首帧闪烁。
%hook ScrollNumber
- (unsigned long long)currentNumber {
    unsigned long long orig = %orig;
    @try {
        DDGlobalConfig *cfg = [DDGlobalConfig shared];
        if (!cfg.balanceEnabled) return orig;

        NSNumber *cached = objc_getAssociatedObject(self, kDDBalanceKindKey);
        DDBalancePageKind kind = cached ? (DDBalancePageKind)cached.integerValue : DDBalancePageNone;
        if (!cached) {
            kind = DDBalancePageKindOf(self);
            objc_setAssociatedObject(self, kDDBalanceKindKey, @(kind), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        if (kind == DDBalancePageLQT && [cfg hasLingtongValue]) return DDClampFen(DDLingtongFenValue());
        if (kind == DDBalancePageBalance && [cfg hasBalanceValue]) return DDClampFen(DDBalanceFenValue());
    } @catch (NSException *e) {}
    return orig;
}

- (void)updateNumber:(unsigned long long)original {
    @try {
        DDGlobalConfig *cfg = [DDGlobalConfig shared];
        if (cfg.balanceEnabled) {
            objc_setAssociatedObject(self, kDDBalanceKindKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            DDBalancePageKind kind = DDBalancePageKindOf(self);
            if (kind == DDBalancePageLQT && [cfg hasLingtongValue]) { %orig(DDClampFen(DDLingtongFenValue())); return; }
            if (kind == DDBalancePageBalance && [cfg hasBalanceValue]) { %orig(DDClampFen(DDBalanceFenValue())); return; }
        }
    } @catch (NSException *e) {}
    %orig(original);
}
- (void)defaultNumber:(unsigned long long)original {
    @try {
        DDGlobalConfig *cfg = [DDGlobalConfig shared];
        if (cfg.balanceEnabled) {
            objc_setAssociatedObject(self, kDDBalanceKindKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            DDBalancePageKind kind = DDBalancePageKindOf(self);
            if (kind == DDBalancePageLQT && [cfg hasLingtongValue]) { %orig(DDClampFen(DDLingtongFenValue())); return; }
            if (kind == DDBalancePageBalance && [cfg hasBalanceValue]) { %orig(DDClampFen(DDBalanceFenValue())); return; }
        }
    } @catch (NSException *e) {}
    %orig(original);
}
- (void)setCurrentNumber:(unsigned long long)original {
    @try {
        DDGlobalConfig *cfg = [DDGlobalConfig shared];
        if (cfg.balanceEnabled) {
            objc_setAssociatedObject(self, kDDBalanceKindKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            DDBalancePageKind kind = DDBalancePageKindOf(self);
            if (kind == DDBalancePageLQT && [cfg hasLingtongValue]) { %orig(DDClampFen(DDLingtongFenValue())); return; }
            if (kind == DDBalancePageBalance && [cfg hasBalanceValue]) { %orig(DDClampFen(DDBalanceFenValue())); return; }
        }
    } @catch (NSException *e) {}
    %orig(original);
}
%end

%hook TimeoutNumber
- (void)layoutSubviews {
    %orig;
    @try {

        if ([self respondsToSelector:@selector(updateScrollNumber)])
            [self updateScrollNumber];
    } @catch (NSException *e) {}
}
%end

%hook WCPayBalanceDetailViewController
- (void)refreshViewWithData:(id)arg {
    %orig;
    DDGlobalConfig *cfg = [DDGlobalConfig shared];
    if (cfg.balanceEnabled && [cfg hasBalanceValue])
        DDBalancePatchTitleLabel(self, DDClampFen(DDBalanceFenValue()), @"余额.详情UILabel.余额");
}
- (void)updateBalanceTitleLabel {
    %orig;
    DDGlobalConfig *cfg = [DDGlobalConfig shared];
    if (cfg.balanceEnabled && [cfg hasBalanceValue])
        DDBalancePatchTitleLabel(self, DDClampFen(DDBalanceFenValue()), @"余额.详情UILabel.余额");
}
- (void)viewWillAppear:(BOOL)animated {
    %orig;
    DDGlobalConfig *cfg = [DDGlobalConfig shared];
    if (cfg.balanceEnabled && [cfg hasBalanceValue])
        DDBalancePatchTitleLabel(self, DDClampFen(DDBalanceFenValue()), @"余额.详情UILabel.余额");
}
%end

#pragma mark - 通用诊断日志 · 快照与导出
// 拼装导出文本（命中统计 / 缓存盘点 / 时间条结构 / 日志正文），写微信 Documents/DDJokerDiag.log。


static NSString *DDJokerDescribeClassIvars(Class cls) {
    NSMutableString *s = [NSMutableString string];
    if (!cls) return @"  (类不存在：dump 里的类名在当前微信版本变了)\n";
    [s appendFormat:@"  类名    : %s\n", class_getName(cls)];

    NSMutableArray *chain = [NSMutableArray array];
    Class sup = class_getSuperclass(cls);
    while (sup) { [chain addObject:[NSString stringWithUTF8String:class_getName(sup)]]; sup = class_getSuperclass(sup); }
    [s appendFormat:@"  父类链  : %@\n", chain.count ? [chain componentsJoinedByString:@" → "] : @"(无)"];

    unsigned int n = 0;
    Ivar *list = class_copyIvarList(cls, &n);
    [s appendFormat:@"  ivar 数 : %u\n", n];
    for (unsigned int i = 0; i < n; i++) {
        Ivar iv = list[i];
        const char *nm = ivar_getName(iv) ?: "";
        [s appendFormat:@"    [%02u] %-32s type=%-8s offset=%td%s\n",
         i, nm, ivar_getTypeEncoding(iv) ?: "", ivar_getOffset(iv),
         (DDStringHas(nm, "time") || DDStringHas(nm, "date")) ? "  <<<" : ""];
    }
    free(list);

    unsigned int m = 0;
    Method *ms = class_copyMethodList(cls, &m);
    [s appendFormat:@"  方法数  : %u（只列名字含 time/date 的）\n", m];
    for (unsigned int i = 0; i < m; i++) {
        SEL sel = method_getName(ms[i]);
        const char *nm = sel_getName(sel) ?: "";
        if (DDStringHas(nm, "time") || DDStringHas(nm, "date")) {
            [s appendFormat:@"    - %-34s %s\n", nm, method_getTypeEncoding(ms[i]) ?: ""];
        }
    }
    free(ms);
    return s;
}

static NSString *DDJokerDescribeTimeVM(id vm) {
    if (!vm) return @"  (还没触发过 ChatTimeViewModel.timeText：先打开一个聊天页滚动几下再导出)\n";
    NSMutableString *s = [NSMutableString string];
    [s appendFormat:@"  vm=%p  类=%s\n", vm, class_getName([vm class])];
    [s appendFormat:@"  showingTime 当前值 : %@\n", DDTimeDesc(DDShowingTimeOf(vm))];
    [s appendFormat:@"  原始 showingTime   : %@\n", DDTimeDesc(DDRawShowingTimeOf(vm))];
    [s appendFormat:@"  时间 key           : %@\n", DDJokerTimeKey(vm)];
    NSNumber *cached = DDJokerCachedTime(vm);
    [s appendFormat:@"  缓存命中           : %@\n", cached ? DDTimeDesc([cached doubleValue]) : @"无"];
    return s;
}

static NSString *DDJokerDescribeCaches(void) {
    NSMutableString *s = [NSMutableString string];
    NSDictionary *time = DDJokerLoadCache(kDDJokerTimeCacheKey);
    NSDictionary *text = DDJokerLoadCache(kDDJokerTextCacheKey);
    NSDictionary *amount = DDJokerLoadCache(kDDJokerAmountCacheKey);
    NSDictionary *origin = DDJokerLoadCache(kDDJokerTextOriginalKey);
    [s appendFormat:@"  时间缓存 %lu 条 : %@\n", (unsigned long)time.count, time ?: @{}];
    [s appendFormat:@"  文字缓存 %lu 条\n", (unsigned long)text.count];
    [s appendFormat:@"  金额缓存 %lu 条\n", (unsigned long)amount.count];
    [s appendFormat:@"  原文备份 %lu 条（清理缓存时刻意保留，用于文字还原）\n", (unsigned long)origin.count];
    NSString *folder = DDJokerImagesDir();
    NSArray *imgs = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:folder error:nil];
    [s appendFormat:@"  替换图片目录 %@ : %lu 个文件\n", folder, (unsigned long)imgs.count];
    return s;
}

static NSString *DDJokerExportLogText(void) {
    NSMutableString *out = [NSMutableString string];
    [out appendString:@"===== DD小丑助手 诊断日志 =====\n"];

    NSDateFormatter *f = [[NSDateFormatter alloc] init];
    f.locale = [NSLocale localeWithLocaleIdentifier:@"zh_CN"];
    f.dateFormat = @"yyyy-MM-dd HH:mm:ss";
    [out appendFormat:@"导出时间 : %@\n", [f stringFromDate:[NSDate date]]];
    [out appendFormat:@"系统版本 : %@ %@\n", [UIDevice currentDevice].systemName, [UIDevice currentDevice].systemVersion];
    NSDictionary *info = [[NSBundle mainBundle] infoDictionary];
    [out appendFormat:@"微信版本 : %@ (%@)\n", info[@"CFBundleShortVersionString"], info[@"CFBundleVersion"]];

    DDGlobalConfig *c = [DDGlobalConfig shared];
    [out appendFormat:@"开关状态 : 文字=%d 图片=%d 时间=%d 转账=%d 诊断=%d 余额=%d 余额值=%@ 零钱通值=%@\n",
     c.textEnabled, c.imageEnabled, c.timeEnabled, c.transferEnabled, c.diagEnabled,
     c.balanceEnabled, ([c hasBalanceValue] ? c.balanceValue : @"-"), ([c hasLingtongValue] ? c.lingtongValue : @"-")];
    [out appendString:@"复现步骤 : 清空日志 → 复现问题（改时间/文字/金额/图片/步数…）→ 回本页导出，把日志发出去即可定位\n"];

    [out appendString:@"\n----- hook 命中统计 -----\n"];
    [out appendString:DDJokerDescribeHitStats()];

    [out appendString:@"\n----- 缓存盘点 -----\n"];
    [out appendString:DDJokerDescribeCaches()];

    [out appendString:@"\n----- 最近一条时间条 -----\n"];
    [out appendString:DDJokerDescribeTimeVM(gDDLastTimeVM)];

    [out appendString:@"\n----- 该类运行时结构 -----\n"];
    [out appendString:DDJokerDescribeClassIvars([gDDLastTimeVM class] ?: NSClassFromString(@"ChatTimeViewModel"))];

    [out appendString:@"\n----- 日志正文 -----\n"];
    NSMutableString *buf = DDLogBuffer();
    NSString *body = @"";
    @synchronized (buf) { body = [buf copy]; }
    [out appendString:body.length ? body : @"(空：诊断开关没开，或还没触发过相关 hook)\n"];
    return out;
}

static NSString *DDJokerWriteDiagLog(void) {
    NSString *text = DDJokerExportLogText();
    NSString *dir = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    if (!dir.length) return nil;
    NSString *path = [dir stringByAppendingPathComponent:@"DDJokerDiag.log"];
    NSError *err = nil;
    [text writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:&err];
    if (err) { NSLog(@"[DD小丑] 写诊断日志失败: %@", err); return nil; }
    [[UIPasteboard generalPasteboard] setString:path];
    return path;
}

#pragma mark - 设置界面
// 各功能开关、自定义值输入、诊断日志清空 / 导出；表视图委托转发给微信原生 manager。


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

- (UIButton *)dd_actionButton:(NSString *)title action:(SEL)action x:(CGFloat)x {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    btn.frame = CGRectMake(x, 0, 52, 34);
    [btn setTitle:title forState:UIControlStateNormal];
    [btn setTitleColor:[UIColor labelColor] forState:UIControlStateNormal];
    btn.backgroundColor = [UIColor systemGray5Color];
    btn.layer.cornerRadius = 6.0;
    btn.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightRegular];
    [btn addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return btn;
}

- (void)buildTable {
    [_tableViewManager clearAllSection];

    DDGlobalConfig *cfg = [DDGlobalConfig shared];
    Class cellCls = %c(WCTableViewCellManager);

    WCTableViewSectionManager *chatSection = [%c(WCTableViewSectionManager) sectionWithHeader:@"聊天设置"];
    chatSection.attributedFooterTitle = [self dd_centeredFooterString:@"聊天文字 / 图片 / 时间 / 转账修改 为独立开关：长按消息弹窗菜单小丑按钮，文字改内容与引用标题、图片替换为相册所选图、时间改显示、转账改金额"];
    [chatSection addCell:[cellCls switchCellForSel:@selector(textSwitchChanged:) target:self title:@"聊天文字修改" on:cfg.textEnabled]];
    [chatSection addCell:[cellCls switchCellForSel:@selector(imageSwitchChanged:) target:self title:@"聊天图片修改" on:cfg.imageEnabled]];
    [chatSection addCell:[cellCls switchCellForSel:@selector(timeSwitchChanged:) target:self title:@"聊天时间修改" on:cfg.timeEnabled]];
    [chatSection addCell:[cellCls switchCellForSel:@selector(transferSwitchChanged:) target:self title:@"聊天转账修改" on:cfg.transferEnabled]];
    UIButton *clearBtn = [self dd_actionButton:@"清理" action:@selector(clearChatCacheTapped:) x:0];
    UIView *clearRight = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 52, 34)];
    [clearRight addSubview:clearBtn];
    [chatSection addCell:[cellCls normalCellForSel:nil target:nil title:@"清除修改缓存" rightView:clearRight]];
    [_tableViewManager addSection:chatSection];

    WCTableViewSectionManager *profileSection = [%c(WCTableViewSectionManager) sectionWithHeader:@"资料设置"];
    profileSection.attributedFooterTitle = [self dd_centeredFooterString:@"零钱余额修改开启后可自定义余额与零钱通金额。步数与好友数量修改后返回对应页面即生效（重新进入微信运动或通讯录、或下拉刷新），无需重启微信"];
    [profileSection addCell:[cellCls switchCellForSel:@selector(balanceSwitchChanged:) target:self title:@"零钱余额修改" on:cfg.balanceEnabled]];
    if (cfg.balanceEnabled) {
        self.balanceField = [[UITextField alloc] init];
        [self.balanceField addTarget:self action:@selector(balanceChanged:) forControlEvents:UIControlEventEditingChanged];
        NSString *currentBalance = [cfg hasBalanceValue] ? cfg.balanceValue : @"";
        UIView *balanceRight = [self inputRowWithField:self.balanceField
                                                action:@selector(balanceConfirm:)
                                           placeholder:@"例如：888.88"
                                                  text:currentBalance];
        self.balanceField.keyboardType = UIKeyboardTypeDecimalPad;
        WCTableViewCellManager *balanceSubCell = [cellCls normalCellForSel:nil target:nil title:@"↳余额自定义" rightView:balanceRight];
        balanceSubCell.userInfo = @"SubCell";
        [profileSection addCell:balanceSubCell];

        self.lingtongField = [[UITextField alloc] init];
        [self.lingtongField addTarget:self action:@selector(lingtongChanged:) forControlEvents:UIControlEventEditingChanged];
        NSString *currentLingtong = [cfg hasLingtongValue] ? cfg.lingtongValue : @"";
        UIView *lingtongRight = [self inputRowWithField:self.lingtongField
                                                 action:@selector(lingtongConfirm:)
                                            placeholder:@"例如：888.88"
                                                   text:currentLingtong];
        self.lingtongField.keyboardType = UIKeyboardTypeDecimalPad;
        WCTableViewCellManager *lingtongSubCell = [cellCls normalCellForSel:nil target:nil title:@"↳零钱通自定义" rightView:lingtongRight];
        lingtongSubCell.userInfo = @"SubCell";
        [profileSection addCell:lingtongSubCell];
    }

    [profileSection addCell:[cellCls switchCellForSel:@selector(stepsSwitchChanged:) target:self title:@"运动步数修改" on:cfg.stepsEnabled]];
    if (cfg.stepsEnabled) {
        self.stepsField = [[UITextField alloc] init];
        [self.stepsField addTarget:self action:@selector(stepsChanged:) forControlEvents:UIControlEventEditingChanged];
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
        [self.contactsField addTarget:self action:@selector(contactsChanged:) forControlEvents:UIControlEventEditingChanged];
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

    WCTableViewSectionManager *diagSection = [%c(WCTableViewSectionManager) sectionWithHeader:@"诊断日志"];
    diagSection.attributedFooterTitle = [self dd_centeredFooterString:@"所有功能（文字/图片/时间/转账/步数/好友/余额）的运行时日志都记在这一处。排查问题：清空 → 复现 → 导出，日志含各 hook 命中次数、缓存盘点与运行时类结构"];
    [diagSection addCell:[cellCls switchCellForSel:@selector(diagSwitchChanged:) target:self title:@"记录运行日志" on:cfg.diagEnabled]];
    UIButton *exportBtn = [self dd_actionButton:@"导出" action:@selector(exportDiagLogTapped:) x:0];
    UIButton *logClearBtn = [self dd_actionButton:@"清空" action:@selector(clearDiagLogTapped:) x:60];
    UIView *logRight = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 112, 34)];
    [logRight addSubview:exportBtn];
    [logRight addSubview:logClearBtn];
    [diagSection addCell:[cellCls normalCellForSel:nil target:nil title:@"导出日志" rightView:logRight]];
    [_tableViewManager addSection:diagSection];

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
    JokerInvalidateAllLayout();
    [self buildTable];
}

- (void)imageSwitchChanged:(UISwitch *)sender {
    [DDGlobalConfig shared].imageEnabled = sender.isOn;
    JokerInvalidateAllLayout();
    [self buildTable];
}

- (void)timeSwitchChanged:(UISwitch *)sender {
    [DDGlobalConfig shared].timeEnabled = sender.isOn;
    JokerInvalidateAllLayout();
    [self buildTable];
}

- (void)transferSwitchChanged:(UISwitch *)sender {
    [DDGlobalConfig shared].transferEnabled = sender.isOn;

    JokerInvalidateAllLayout();
    [self buildTable];
}

- (void)clearChatCacheTapped:(id)sender {
    DDJokerClearAllMessageCache();
    JokerInvalidateAllLayout();
    [self buildTable];
    [self dd_showDoneToast:@"已清理"];
}

- (void)diagSwitchChanged:(UISwitch *)sender {
    [DDGlobalConfig shared].diagEnabled = sender.isOn;
    [self buildTable];
}

- (void)clearDiagLogTapped:(id)sender {
    DDJokerClearDiagLog();
    [self dd_showDoneToast:@"日志已清空"];
}

- (void)exportDiagLogTapped:(id)sender {
    NSString *path = DDJokerWriteDiagLog();
    if (!path.length) { [self dd_showDoneToast:@"导出失败"]; return; }
    NSURL *url = [NSURL fileURLWithPath:path];
    UIActivityViewController *av = [[UIActivityViewController alloc] initWithActivityItems:@[url] applicationActivities:nil];
    if (av.popoverPresentationController) {
        UIView *anchor = [sender isKindOfClass:[UIView class]] ? (UIView *)sender : self.view;
        av.popoverPresentationController.sourceView = anchor;
        av.popoverPresentationController.sourceRect = anchor.bounds;
    }
    __weak DDJokerSettingsViewController *weakSelf = self;
    av.completionWithItemsHandler = ^(UIActivityType type, BOOL completed, NSArray *items, NSError *error) {
        [weakSelf dd_showDoneToast:completed ? @"日志已导出" : @"已取消"];
    };
    [self presentViewController:av animated:YES completion:nil];
}

- (void)dd_showDoneToast:(NSString *)text {
    if (!text.length) return;

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

- (void)balanceChanged:(id)sender {
    [self saveBalanceInput:self.balanceField.text];
}

- (void)lingtongChanged:(id)sender {
    [self saveLingtongInput:self.lingtongField.text];
}

- (void)stepsChanged:(id)sender {
    [self saveStepsInput:self.stepsField.text];
}

- (void)contactsChanged:(id)sender {
    [self saveContactsInput:self.contactsField.text];
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
// DDGlobalConfig 单例：属性 setter 同步 NSUserDefaults。


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
        _timeEnabled = [def boolForKey:kDDFeatureTimeEnabled];
        _transferEnabled = [def boolForKey:kDDFeatureTransferEnabled];
        _balanceEnabled = [def boolForKey:kDDFeatureBalanceEnabled];
        _stepsEnabled = [def boolForKey:kDDFeatureStepsEnabled];
        _contactsEnabled = [def boolForKey:kDDFeatureContactsEnabled];

        _diagEnabled = [def objectForKey:kDDFeatureDiagEnabled] ? [def boolForKey:kDDFeatureDiagEnabled] : YES;
        _stepsValueString = [def stringForKey:kDDStepsValueStringKey];
        _contactsValue = [def stringForKey:kDDContactsCountValueKey];
        _balanceValue = [def stringForKey:kDDBalanceValueKey];
        _lingtongValue = [def stringForKey:kDDLingtongValueKey];
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

- (void)setTimeEnabled:(BOOL)enabled {
    _timeEnabled = enabled;
    [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:kDDFeatureTimeEnabled];
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

- (void)setDiagEnabled:(BOOL)enabled {
    _diagEnabled = enabled;
    [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:kDDFeatureDiagEnabled];
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
// %ctor 把设置页注册到微信插件入口。


%ctor {
    @autoreleasepool {
        DDLOG(@"=== 插件加载 ===");
        DDJokerHit(@"插件加载");
        WCPluginsMgr *mgr = [%c(WCPluginsMgr) sharedInstance];
        [mgr registerControllerWithTitle:@"DD小丑助手"
                                 version:@"1.0.0"
                              controller:@"DDJokerSettingsViewController"];
    }
}

