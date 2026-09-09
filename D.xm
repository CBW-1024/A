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

// 已在最新 dump 逐条核对：CMessageWrap 只有 IsTextMsg / IsImgMsg / isReferMsgType /
// GetDisplayContent / m_uiMesLocalID / m_nsContent / m_nsFromUsr / m_nsToUsr，
// **没有** m_nsTitle，**没有** m_oWCPayInfoItem（只有 parseWCPayInfoItemIfNeed 这个方法）。
// 因此：引用消息不再改写 m_nsTitle（写了会 unrecognized selector 崩溃）；
// 转账一律用 cell/viewModel 类判断，不再碰任何支付字段。
//（WCPayInfoItem 的声明已整体移除，避免后人误用这些拿不到的属性。）
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

// 重要：这份 dump 把继承链抹成了 NSObject，只列出"本类自己实现"的方法，
// 父类方法不会重复出现在子类里。所以不能在子类头文件里搜不到就判定方法不存在 ——
// messageWrap / resetLayoutCache 实际定义在 BaseMessageViewModel
// （BaseMessageViewModel.h:57 -(id)messageWrap; :78 -(void)resetLayoutCache;），
// CommonMessageViewModel / TextMessageViewModel 靠继承拿到，运行时是能响应的。
@interface BaseMessageViewModel : NSObject
@property (nonatomic, retain) CMessageWrap *messageWrap;
- (void)resetLayoutCache;
@end

@interface CommonMessageViewModel : BaseMessageViewModel
@end

// BaseMessageCellView.h:94 -(void)layoutContentView; :96 -(void)layoutInternal;
//                    :126 -(void)prepareForReuse; :65 -(id)operationMenuItems;
// CommonMessageCellView.h:120 -(void)setViewModel:
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

// 文本消息：真正决定显示文本的是 viewModel 的 contentText（爱锋 hook 点，头文件 TextMessageViewModel.h:23/67）
@interface TextMessageViewModel : CommonMessageViewModel
@property (readonly, nonatomic) NSString *contentText;
- (void)resetLayoutCache;
@end

// 文本最终画在 RichTextView 上，而它是**异步绘制**的（RichTextView.h:120 newAsyncDisplayTask），
// 所以只改 viewModel 数据不会立刻重绘 —— 这正是"改完要退出重进才生效"的根因。
// 必须显式 setContent: + forceDisplayInSync 强制同步重绘，才能改完马上变。
// RichTextView.h:205 -(void)setContent:(id); :156 -(void)calculateAndUpdateFrame;
//              :171 -(void)forceDisplayInSync; :100 -(id)getContent;
@interface RichTextView : UIView
- (id)getContent;
- (void)setContent:(id)content;
- (void)calculateAndUpdateFrame;
- (void)forceDisplayInSync;
@end

@interface TextMessageCellView : CommonMessageCellView
- (id)getRichTextView;     // TextMessageCellView.h:36
- (id)getTextString;       // TextMessageCellView.h:40
- (void)layoutContentView; // TextMessageCellView.h:67
- (void)setViewModel:(id)vm; // TextMessageCellView.h:139
// layoutInternal 由父类提供（CommonMessageCellView.h:78），爱锋就是 hook 它
@end

// 转账：金额走 viewModel 的 titleText/descText（WCPayTransferMessageViewModel.h:29 / :20），
// 改完要主动触发 cell 的 updateTitleLabel/updateDescLabel 才会重画
@interface WCPayTransferMessageViewModel : NSObject
- (CMessageWrap *)messageWrap;   // 继承自 BaseMessageViewModel（BaseMessageViewModel.h -(id) messageWrap;）
- (NSString *)titleText;         // WCPayTransferMessageViewModel.h:29
- (NSString *)descText;          // WCPayTransferMessageViewModel.h:20
@end

@interface WCPayTransferMessageCellView : CommonMessageCellView
- (void)updateTitleLabel;        // WCPayTransferMessageCellView.h:25
- (void)updateDescLabel;         // WCPayTransferMessageCellView.h:23
@end

@interface ImageMessageCellView : CommonMessageCellView
- (void)showImage;                  // ImageMessageCellView.h，微信自身的图片加载/显示入口
- (void)OnDownloadImageOk:(id)a0;   // 异步下载完成后会再次 setImage，必须在这里补一次替换
@end

// 注意：头文件 dump 里没有 AppMessageCellView（只有 AppUrlMessageCellView 等），
// 引用消息（isReferMsgType）实际由 TextMessageCellView 渲染，统一走文本这条链路

// 聊天时间条（对应爱锋"时间小丑"）
// ChatTimeViewModel.h:14 -(id)timeText; :10 -(double)showingTime; :19 -(void)setShowingTime:(double);
//                    :20 -(void)updateLayouts;
// ChatTimeCellView.h:5 -(id)initWithViewModel:; :9 -(void)layoutInternal; :13 -(void)setViewModel:
@interface ChatTimeViewModel : BaseMessageViewModel
@property (nonatomic) double showingTime;
- (NSString *)timeText;
- (void)updateLayouts;   // ChatTimeViewModel.h:20，改时间后让 viewModel 重算布局
@end

@interface ChatTimeCellView : UIView
- (id)initWithViewModel:(id)vm;
- (void)setViewModel:(id)vm;
- (void)layoutInternal;
// 下面几个是本插件 %new 出来的，先声明以便相互调用（-Werror 下不能有未声明选择器）
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

// 好友数量小丑：对齐爱锋 —— 不 hook MMUILabel（全局 UILabel 复用会误伤/崩溃），
// 而是在数据层 ContactsDataLogic.m_uiNormalContact（unsigned int，ContactsDataLogic.h:58 确认）直接返回自定义值，
// 并可选地同步导航标题。爱锋 hooks_final.json：ContactsDataLogic.m_uiNormalContact @0xc5ae8 /
// ContactsViewController.viewWillAppear: @0xc5d74（真实实现里 updateCustomCountLabel 是死代码，
// 真正驱动"X个朋友"的是 m_uiNormalContact 的返回值，微信自行拼后缀）。
@interface ContactsDataLogic : NSObject
- (unsigned int)m_uiNormalContact;
@end
@interface ContactsViewController : UIViewController
@end

// ScrollNumber.h 确认存在：-(void)updateNumber:(unsigned long long); -(void)defaultNumber:(unsigned long long);
//                          -(unsigned long long)currentNumber; -(unsigned long long)getNumber;
// 注意 isLQT：爱锋 hooks_final.json 里它标记为 "new"，说明那本来就不是微信的 API，
// 而是爱锋自己 %new 出来的判定方法 —— 所以 dump 里搜不到是正常的，我们也自己实现一个。
// 真实父类无法从 dump 确认（继承被抹成 NSObject），可能是 UIView 也可能不是，
// 因此下面凡是走响应链的访问都必须先做 UIResponder 类型检查，否则 nextResponder 会崩。
@interface ScrollNumber : NSObject
- (BOOL)isLQT;                                 // 本插件 %new 实现，见下方 hook
- (void)updateNumber:(unsigned long long)a0;
- (void)defaultNumber:(unsigned long long)a0;
- (unsigned long long)currentNumber;
@end

#pragma mark - 配置管理（接口声明）

static NSString * const kDDFeatureTextEnabled = @"DDFeatureTextEnabled";
static NSString * const kDDFeatureTransferEnabled = @"DDFeatureTransferEnabled";
static NSString * const kDDFeatureImageEnabled = @"DDFeatureImageEnabled";
static NSString * const kDDFeatureTimeEnabled = @"DDFeatureTimeEnabled";
static NSString * const kDDFeatureBalanceEnabled = @"DDFeatureBalanceEnabled";
static NSString * const kDDFeatureStepsEnabled = @"DDFeatureStepsEnabled";
static NSString * const kDDFeatureContactsEnabled = @"DDFeatureContactsEnabled";

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

// 引用消息（type 57 appmsg）的 GetDisplayContent 返回的是原始 XML 碎片
// （<msg><appmsg><title>...</title><refermsg>...），直接回填输入框会全是 < > " 这类像正则的字符。
// 真正显示在气泡里的回复正文其实是 <appmsg><title>，这里把它解析出来作为预填/还原文本。
// 还原 XML/HTML 实体（引用标题里偶尔会被编码，例如回复正文含 < > & 等字符）
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

// 引用消息（type 57 appmsg）的 GetDisplayContent 返回原始 XML 碎片，回填输入框会一团乱；
// 真正显示在气泡里的回复正文就是 <appmsg><title>。引用消息 XML 里 <title> 只此一处
// （被引用内容在 <refermsg> 里用的是 <content>/<msgtitle>，不是 <title>，见上传样本），
// 所以用一条正则一次性精确捕获 <title ...>内容</title ...>，无需一堆 if 兜底。
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

// 已删除 JokerIsTransferMessage(msg)：CMessageWrap.h 里没有 m_oWCPayInfoItem
// （只有 :572 parseWCPayInfoItemIfNeed），那个判定在真机上恒为 NO，
// 用它会导致"金额改了没反应"和"点小丑不弹窗"。转账一律按下面的类判定。

// 判断转账的唯一可靠依据：cell 的类（不依赖任何支付字段）
static BOOL JokerIsTransferCell(CommonMessageCellView *cell) {
    return [cell isKindOfClass:%c(WCPayTransferMessageCellView)];
}

// 注意：必须用 cell 判定，不能用 msg 判定 —— 转账消息在 CMessageWrap 上没有任何可用标记
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
    // 转账金额：不带小数点的纯数字，自动补 .00（如 666 -> 666.00）；
    // 含小数点（666.5 / 666.）的保持原样，由微信按原始精度渲染
    if ([filtered rangeOfString:@"."].location == NSNotFound) {
        [filtered appendString:@".00"];
    }
    return filtered;
}

static NSString * const kDDJokerTextCacheKey = @"DDJokerTextCache";
static NSString * const kDDJokerAmountCacheKey = @"DDJokerAmountCache";
static NSString * const kDDJokerTimeCacheKey = @"DDJokerTimeCache";
// 文本/引用消息的原始 m_nsContent 备份（对齐爱锋 entry 里的 originalText，@0xccbb8）。
// 改文字会写回 CMessageWrap，没有这份备份就还原不回去 —— 清理缓存时它必须保留。
static NSString * const kDDJokerTextOriginalKey = @"DDJokerTextOriginal";

static NSString *DDJokerMessageKey(CMessageWrap *msg) {
    return [NSString stringWithFormat:@"%u", msg.m_uiMesLocalID];
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

// 原始文案备份：只在第一次见到这条消息时记录（那时 m_nsContent 还没被改写）
static NSString *DDJokerOriginalText(CMessageWrap *msg) {
    if (!msg) return nil;
    NSDictionary *d = [[NSUserDefaults standardUserDefaults] dictionaryForKey:kDDJokerTextOriginalKey];
    NSString *v = d[DDJokerMessageKey(msg)];
    return v.length ? v : nil;
}

static void DDJokerSetOriginalText(CMessageWrap *msg, NSString *text) {
    if (!msg || !text.length) return;
    if (DDJokerOriginalText(msg)) return;   // 已备份过就不再更新，否则会把改后的内容当成原始
    NSUserDefaults *def = [NSUserDefaults standardUserDefaults];
    NSMutableDictionary *d = [NSMutableDictionary dictionaryWithDictionary:[def dictionaryForKey:kDDJokerTextOriginalKey] ?: @{}];
    d[DDJokerMessageKey(msg)] = text;
    [def setObject:d forKey:kDDJokerTextOriginalKey];
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

#pragma mark - ①c 聊天时间修改缓存

// 时间条（ChatTimeViewModel）可能绑定消息，也可能只是个纯时间分隔条。
// 爱锋同样是优先用消息 ID（wechatku.dylib @0xcb650）：
//   m_n64MesSvrID != 0 → "message_server_%lld"，否则 "message_local_%u_%u_%@_%@"，
//   拿不到消息才退回 "time_timestamp_%.3f"（showingTime）。
// 这里沿用同样的优先级，但复用插件统一的消息 key，方便"清除修改缓存"一次清干净。
static NSString *DDJokerTimeKey(id vm) {
    id wrap = [vm respondsToSelector:@selector(messageWrap)] ? [vm messageWrap] : nil;
    if ([wrap respondsToSelector:@selector(m_uiMesLocalID)] && [wrap m_uiMesLocalID] != 0) {
        return DDJokerMessageKey((CMessageWrap *)wrap);
    }
    double t = [vm respondsToSelector:@selector(showingTime)] ? [vm showingTime] : 0.0;
    return [NSString stringWithFormat:@"ts_%.3f", t];
}

static NSNumber *DDJokerCachedTime(id vm) {
    if (!vm) return nil;
    NSDictionary *d = [[NSUserDefaults standardUserDefaults] dictionaryForKey:kDDJokerTimeCacheKey];
    id v = d[DDJokerTimeKey(vm)];
    return [v isKindOfClass:[NSNumber class]] ? v : nil;
}

static void DDJokerSetCachedTime(id vm, double timestamp) {
    if (!vm) return;
    NSUserDefaults *def = [NSUserDefaults standardUserDefaults];
    NSMutableDictionary *d = [NSMutableDictionary dictionaryWithDictionary:[def dictionaryForKey:kDDJokerTimeCacheKey] ?: @{}];
    if (timestamp > 0) d[DDJokerTimeKey(vm)] = @(timestamp);
    else [d removeObjectForKey:DDJokerTimeKey(vm)];
    [def setObject:d forKey:kDDJokerTimeCacheKey];
    [def synchronize];
}

static void DDJokerClearAllMessageCache(void) {
    NSUserDefaults *def = [NSUserDefaults standardUserDefaults];
    [def removeObjectForKey:kDDJokerTextCacheKey];
    [def removeObjectForKey:kDDJokerAmountCacheKey];
    [def removeObjectForKey:kDDJokerTimeCacheKey];
    // kDDJokerTextOriginalKey 故意保留：文字走数据层后 m_nsContent 已被改写，
    // 清掉覆盖值后要靠这份原始备份才能写回还原（爱锋的 originalText 同样是持久化的）。
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

// 关键：微信聊天页里 [tableView visibleCells] 返回的是 UITableViewCell，
// 而 ImageMessageCellView / TextMessageCellView 是挂在 cell.contentView 上的 UIView，
// 直接对 visibleCells 判 isKindOfClass 永远匹配不到 —— 必须递归往子里找。
static void DDCollectViewsOfClass(UIView *root, Class cls, NSMutableArray *out) {
    if (!root) return;
    if ([root isKindOfClass:cls]) {
        if (![out containsObject:root]) [out addObject:root];
        return;   // 命中即停，避免把子层同名 view 也收进来
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

// 图片：重走微信自己的加载流程，替换图才会落到 imageView 上
static void JokerRefreshVisibleImageCells(void) {
    for (UIViewController *vc in JokerAllChatViewControllers()) {
        UITableView *tv = [(BaseMsgContentViewController *)vc getMsgTableView];
        if (![tv isKindOfClass:[UITableView class]]) continue;
        for (ImageMessageCellView *cellView in DDVisibleCellViewsOfClass(tv, %c(ImageMessageCellView))) {
            if ([cellView respondsToSelector:@selector(showImage)]) [cellView showImage];
        }
    }
}

// 输入框回填要显示"当前正在显示的内容"，所以优先取缓存值。
// 转账金额不再从 WCPayInfoItem 读（新版本拿不到），直接用缓存值回填
static NSString *DDTransferFeedescAmount(NSString *xml);  // 前向声明：从 m_nsContent 解析原始转账金额
static NSString *JokerGetDisplayText(CMessageWrap *msg, BOOL isTransfer) {
    if (isTransfer) {
        NSString *cached = DDJokerCachedAmount(msg);
        if (cached.length) return cached;                            // 已修改 → 显示修改后的金额
        NSString *raw = DDTransferFeedescAmount([msg m_nsContent]);  // 未修改 → 真实金额
        return JokerNormalizeAmount(raw) ?: @"";                     // 去掉 ¥，与缓存格式统一
    }
    NSString *cached = DDJokerCachedText(msg);
    if (cached) return cached;
    // 引用消息的 GetDisplayContent 是原始 XML 碎片（像正则），回填输入框会一团乱，
    // 改成取 <title>（即气泡里真正显示的回复正文），与 %orig 的 contentText 显示一致
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

// 富文本是异步绘制的（RichTextView.h:120 newAsyncDisplayTask），改完数据不会自动重绘 ——
// 必须显式 setContent: + forceDisplayInSync，否则要等 cell 复用/重进页面才看得到变化。
static void JokerApplyTextToRichView(id richView, NSString *text) {
    if (!richView || !text) return;
    [richView setContent:text];
    [richView calculateAndUpdateFrame];
    [richView forceDisplayInSync];
    [richView setNeedsDisplay];
}

// TextMessageViewModel 把 contentText 懒加载缓存进 ivar，不清就一直返回旧值，
// 这正是"改完要退出重进才生效"的根因（resetLayoutCache 见 BaseMessageViewModel.h:78）
static void JokerResetViewModelCache(CommonMessageCellView *cell) {
    id vm = cell.viewModel;
    [vm resetLayoutCache];
}

// 与爱锋一致：不依赖 tableView reload，而是直接触发 cell 自身的显示/布局流程
static void JokerRefreshCellDirectly(CommonMessageCellView *cell) {
    if (!cell) return;
    JokerResetViewModelCache(cell);
    CMessageWrap *msg = JokerGetMessageWrapFromCell(cell);

    if ([cell isKindOfClass:%c(TextMessageCellView)]) {
        NSString *cached = [DDGlobalConfig shared].textEnabled ? DDJokerCachedText(msg) : nil;
        // 没有缓存（关开关 / 清过缓存）就还原成原文，否则关掉修改后文字变不回去
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
        // 金额是在这两个方法里落到 label 上的，只 layout 不够
        [(WCPayTransferMessageCellView *)cell updateTitleLabel];
        [(WCPayTransferMessageCellView *)cell updateDescLabel];
    } else if ([cell isKindOfClass:%c(ImageMessageCellView)]) {
        [(ImageMessageCellView *)cell showImage];
    }
    [cell setNeedsLayout];
}

// 提前声明：JokerInvalidateAllLayout 的定义在下方（依赖 gJokerNeedsResetLayout），
// 但本函数及多处开关回调在定义之前就会调用它，static 函数必须先声明后使用
static void JokerInvalidateAllLayout(void);

static void JokerReloadCellAfterReplace(id vc, CMessageWrap *msg, CommonMessageCellView *cell) {
    JokerRefreshCellDirectly(cell);
    UITableView *tv = cell ? JokerFindTableView((UIView *)cell) : nil;
    if (![tv isKindOfClass:[UITableView class]] && [vc isKindOfClass:%c(BaseMsgContentViewController)]) {
        tv = [(BaseMsgContentViewController *)vc getMsgTableView];
    }
    if (![tv isKindOfClass:[UITableView class]]) {
        // 拿不到 tableView 就退化为全局刷新，避免"改了没反应、要重进才生效"
        JokerReloadAllMsgContent();
        return;
    }
    // cell 是挂在 UITableViewCell.contentView 上的 UIView，直接传给 indexPathForCell:
    // 永远返回 nil（类型都不对），只能靠全局刷新兜底 —— 改成按中心点换算 indexPath
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
    // 用 cell 判定，不能用 msg 判定：转账消息在 CMessageWrap 上没有任何可用标记，
    // 用 JokerIsSupportedMessage(msg) 会把转账直接拦掉 —— 表现为"点小丑没弹窗"
    if (!JokerIsSupportedCell(cell)) return;
    CMessageWrap *msg = JokerGetMessageWrapFromCell(cell);
    id vc = JokerGetViewControllerFromView(cell);   // 取不到也不影响弹窗，只影响兜底刷新

    // 转账用 cell 类型判断，不依赖 CMessageWrap 的支付字段（新 dump 已无 m_oWCPayInfoItem）
    BOOL isTransfer = JokerIsTransferCell(cell);
    NSString *current = JokerGetDisplayText(msg, isTransfer);

    // 微信原生带输入框 alert：WCUIAlertView（声明见文件顶部）。标题按类型区分，
    // 副标题给出输入指引（金额/文字），输入框本身不放 placeholder —— 默认文本已经是当前值
    NSString *editorTitle = isTransfer ? @"转账修改" : @"文字修改";
    NSString *editorMessage = isTransfer ? @"请输入需要修改的金额" : @"请输入需要修改的文字";
    WCUIAlertView *alert = [(WCUIAlertView *)[%c(WCUIAlertView) alloc] initWithTitle:editorTitle message:editorMessage];
    if (!alert) return;
    [alert showTextFieldWithMaxLen:1000];
    [alert setTextFieldDefaultText:current];

    // 注意两点（都踩过坑）：
    // 1) 不能用 __weak 引用 alert —— 回调触发时它可能已释放，nil 会让修改静默失效；
    // 2) 不能在 show 之前判断 getTextField 为空就 return —— 那会让弹窗根本不显示。
    // 所以：alert 与输入框都强引用，取文本时两条路径都试。
    __block WCUIAlertView *blockAlert = alert;
    __block UITextField *inputField = nil;
    [alert addCancelBtnTitle:@"取消" handler:^{}];
    [alert addBtnTitle:@"确定" handler:^{
        NSString *raw = blockAlert ? [blockAlert getTextFieldText] : nil;
        if (!raw.length) raw = inputField.text;
        NSString *newText = [raw stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (newText.length && ![newText isEqualToString:current]) {
            if (isTransfer) {
                NSString *normalized = JokerNormalizeAmount(newText);
                if (normalized) DDJokerSetCachedAmount(msg, normalized);
            } else {
                DDJokerSetCachedText(msg, newText);
            }
            JokerReloadCellAfterReplace(vc, msg, cell);
        }
        blockAlert = nil;   // 打破 alert -> handler -> alert 的保留环
    }];
    [alert show];
    UITextField *tf = [alert getTextField];   // show 之后输入框一定已创建
    if (tf) {
        inputField = tf;
        if (isTransfer) tf.keyboardType = UIKeyboardTypeDecimalPad;
    }
}

static NSArray *JokerInjectMenuItem(CommonMessageCellView *cell, NSArray *original) {
    // 一律用 cell 判定：CMessageWrap 上没有任何可用的转账标记，
    // 用 msg 判定会让转账消息既拿不到菜单、也弹不出修改框
    if (!JokerEnabledForCell(cell)) return original;
    if (!JokerIsSupportedCell(cell)) return original;

    UIImage *icon = [[UIImage systemImageNamed:@"face.smiling.fill"] imageWithTintColor:[UIColor whiteColor] renderingMode:UIImageRenderingModeAlwaysOriginal];
    MMMenuItem *newItem = [(MMMenuItem *)[%c(MMMenuItem) alloc] initWithTitle:@"小丑" icon:icon target:cell action:@selector(joker_handleMenuItem:)];
    NSMutableArray *newItems = [NSMutableArray arrayWithArray:original];
    [newItems insertObject:newItem atIndex:0];
    return newItems;
}

// 真正决定文本显示的是 viewModel 的 contentText（TextMessageViewModel.h:23）。
// 现在按爱锋 DKApplyTextOverrideToModel @0xccb08 的做法叠加数据层：
//   ① 在 contentText 取值那一刻改 m_nsContent（@0xccbfc setM_nsContent:），再让微信按新值自己算；
//   ② 缓存里有值就直接返回（爱锋 @0xba1b4~0xba1f0 读 entry[@"text"] 后直接返回），气泡显示不依赖 XML；
//   ③ 没覆盖值（关开关 / 清过缓存）就用 originalText 备份写回（@0xccbb8），保证还原得回去。
// 与爱锋一致不区分消息类型：引用消息的 m_nsContent 是 XML，也会被整段换成纯文本。
// 注意时序——只在 getter 里改才生效；之前在 cell 的 setViewModel: 里改，文本早算完了，白改还污染 model。
static void DDJokerApplyTextOverride(CMessageWrap *msg) {
    if (!msg) return;
    if (!JokerIsTextMessage(msg) && !JokerIsReferMessage(msg)) return;
    NSString *original = DDJokerOriginalText(msg);
    if (!original.length) {
        DDJokerSetOriginalText(msg, msg.m_nsContent);   // 首次见到：此时还没被改写，存下来当原始
        original = msg.m_nsContent;
    }
    NSString *cached = [DDGlobalConfig shared].textEnabled ? DDJokerCachedText(msg) : nil;
    NSString *target = cached ?: original;
    if (target.length && ![target isEqualToString:msg.m_nsContent]) [msg setM_nsContent:target];
}

%hook TextMessageViewModel
- (NSString *)contentText {
    DDJokerApplyTextOverride(self.messageWrap);   // 爱锋 @0xba15c：先改 model 再取 %orig
    NSString *origin = %orig;
    if (![DDGlobalConfig shared].textEnabled) return origin;
    CMessageWrap *msg = self.messageWrap;
    // 引用消息（isReferMsgType）同样由 TextMessageCellView 渲染，走同一条替换链路
    if (!JokerIsTextMessage(msg) && !JokerIsReferMessage(msg)) return origin;
    NSString *cached = DDJokerCachedText(msg);
    return cached ?: origin;
}
%end

// 清理缓存/切换开关后需要强制清掉 viewModel 里已算好的 contentText 布局缓存，否则仍显示旧文本
static BOOL gJokerNeedsResetLayout = NO;

// 开关切换、清理缓存都走这里：置位 → 全量重绘 → 稍后复位。
// 置位期间 TextMessageCellView 的 setViewModel: 才主动清懒加载缓存，文字才还原得回去。
static void JokerInvalidateAllLayout(void) {
    gJokerNeedsResetLayout = YES;
    JokerReloadAllMsgContent();
    JokerRefreshVisibleImageCells();   // 图片走的是 setImage，需触发微信重新加载
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        gJokerNeedsResetLayout = NO;
    });
}

%hook TextMessageCellView
// 之前这里在 %orig 前临时改 m_nsContent、%orig 后又立刻还原，而真正的文本计算发生在
// 之后的 layoutContentView，所以那段改写完全无效，还白白污染了一次 CMessageWrap。
// 正确做法：%orig 之后清掉 viewModel 的懒加载缓存，等布局重新取 contentText 时就会拿到替换值。
- (void)setViewModel:(id)vm {
    %orig;
    if (![vm respondsToSelector:@selector(resetLayoutCache)]) return;
    CMessageWrap *msg = [(CommonMessageViewModel *)vm messageWrap];
    if (!JokerIsTextMessage(msg) && !JokerIsReferMessage(msg)) return;
    // 开启且有缓存 → 清缓存让替换值生效；关闭 → 也清一次让原文还原回去
    if (gJokerNeedsResetLayout || DDJokerCachedText(msg) || ![DDGlobalConfig shared].textEnabled) {
        [(TextMessageViewModel *)vm resetLayoutCache];
    }
}
- (id)getTextString {
    CMessageWrap *msg = JokerGetMessageWrapFromCell(self);
    DDJokerApplyTextOverride(msg);   // 爱锋 @0xbcb80：getTextString 里同样先改 model，复制/转发取到的是改后文本
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

// 转账金额走显示层覆盖：只改 viewModel 吐给 label 的文本，绝不回写 m_nsContent。
// 之前的数据层方案（把覆盖金额写回 CMessageWrap.m_nsContent，CMessageWrap.h:676 setM_nsContent:）
// 会被微信持久化进消息 DB，表现为"清理缓存后重启微信，金额仍是修改后的、还原不回去"。
// 与文字修改同一套路：hook WCPayTransferMessageViewModel 的 titleText/descText（头文件 :29 / :20），
// 只在文本里精准替换金额那一段，CMessageWrap 保持原样 —— 清理缓存后重算即还原真实金额。
// 从转账 m_nsContent 的 <feedesc><![CDATA[金额]]></feedesc> 里解析出真实金额（如 ¥888.88），
// 仅用于弹窗预填（未修改时显示真实金额），不参与渲染。
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
// 金额在标题/描述文本里就是一段"¥数字"（可能带小数），正则一次命中整段替换，其余字符原样保留。
// 缓存里的金额已由 JokerNormalizeAmount 归一为纯数字（补 .00、去 ¥），这里统一补回 ¥ 前缀。
static NSString *DDTransferReplaceAmountInText(NSString *text, NSString *override) {
    if (!text.length || !override.length) return text;
    NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:@"¥?\\d+(?:\\.\\d+)?"
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
// 渲染时不需要在这里做任何事：金额由 WCPayTransferMessageViewModel 的 titleText/descText 覆盖，
// 这里只负责把"小丑"菜单注入转账气泡。
- (NSArray *)operationMenuItems {
    return JokerInjectMenuItem(self, %orig);
}
- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
    // 本 hook 就挂在 WCPayTransferMessageCellView 上，天然是转账 cell，直接用开关判定
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

// 转账金额显示层覆盖（对齐文字修改的 contentText hook 套路）：
// titleText 是气泡上的金额大字（WCPayTransferMessageViewModel.h:29），
// descText 是"已收款/已退款"等说明（同文件 :20，退款类文案同样带金额）。
// vm 继承自 BaseMessageViewModel，messageWrap 可用（BaseMessageViewModel.h 的 -(id) messageWrap;）——
// 现有 JokerGetMessageWrapFromCell 在转账 cell 上已实测拿到 msg，即 runtime 证据。
// 命中的是金额正则段，文本里没有金额时原样返回。
%hook WCPayTransferMessageViewModel
- (NSString *)titleText {
    NSString *origin = %orig;
    if (![DDGlobalConfig shared].transferEnabled) return origin;
    NSString *cached = DDJokerCachedAmount(self.messageWrap);
    return cached ? DDTransferReplaceAmountInText(origin, cached) : origin;
}
- (NSString *)descText {
    NSString *origin = %orig;
    if (![DDGlobalConfig shared].transferEnabled) return origin;
    NSString *cached = DDJokerCachedAmount(self.messageWrap);
    return cached ? DDTransferReplaceAmountInText(origin, cached) : origin;
}
%end

#pragma mark - ①b 聊天图片修改

// 聊天图片替换用 Apple UIImagePickerController：
// 爱锋 DKChatImagePickerDelegate 反汇编（@0xa59cc）证实聊天图片替换走
// imagePickerController:didFinishPickingMediaWithInfo: + UIImagePickerControllerOriginalImage，
// 与下方实现一致，故回退到这条被证实可用的路径（原生 MMImagePickerController 直接 present 会闪退）。
@interface DDWeChatImagePickerDelegate : NSObject <UIImagePickerControllerDelegate, UINavigationControllerDelegate>
@property (nonatomic, assign) unsigned int mesLocalID;
@property (nonatomic, weak) id cellView;   // 对齐爱锋：[self cell] 直接持有要替换的 ImageMessageCellView
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

// 最新 dump 不含 ivar 信息，无法确认 m_imageView 是否还在。
// 直接 valueForKey: 一旦 key 不存在会抛 NSUnknownKeyException 让微信崩溃，
// 所以先用 class_getInstanceVariable 探测，取不到再退化为按面积找最大的 UIImageView
static UIImageView *DDImageViewFromCell(UIView *cell) {
    if (!cell) return nil;
    Ivar ivar = class_getInstanceVariable([cell class], "m_imageView");
    if (ivar) {
        id value = object_getIvar(cell, ivar);
        if ([value isKindOfClass:[UIImageView class]]) return (UIImageView *)value;
    }
    UIImageView *best = nil;
    CGFloat bestArea = 0;
    for (UIView *v in cell.subviews) {
        if (![v isKindOfClass:[UIImageView class]]) continue;
        CGFloat area = v.bounds.size.width * v.bounds.size.height;
        if (area > bestArea) { bestArea = area; best = (UIImageView *)v; }
    }
    return best;
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
    delegate.cellView = self;   // 对齐爱锋：delegate 直接持有 cell，dismiss 后无需递归查找
    picker.delegate = delegate;
    // 强引用 delegate：picker 不持有外部 delegate，避免回调时已被释放
    objc_setAssociatedObject(picker, "dd_picker_delegate", delegate, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [vc presentViewController:picker animated:YES completion:nil];
}
- (void)showImage {
    %orig;
    DDImageApplyReplacementToCell(self);
}
- (void)OnDownloadImageOk:(id)a0 {
    // 微信异步下载完成后会再次 setImage 覆盖掉替换图，必须在这里补一次
    %orig;
    DDImageApplyReplacementToCell(self);
}
- (void)layoutContentView {
    %orig;
    DDImageApplyReplacementToCell(self);
}
%end

@implementation DDWeChatImagePickerDelegate

#pragma mark - Apple 系统相册（爱锋聊天图片替换同款）
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

    // 对齐爱锋 DKChatImagePickerDelegate（@0xa59cc）：delegate 直接持有 cell（[self cell]），
    // 在 dismiss 之前【同步】刷新，dismiss 的 completion 为 nil，不屏蔽交互、不调 showImage
    // （showImage 的 %orig 会打开微信图片预览——之前"选完图预览被打开"正是这里触发；
    //  爱锋用 updateLayouts+setNeedsLayout 刷新，从不调 showImage）。
    // DD 的替换图应用集中在 DDImageApplyReplacementToCell（直接 setImage 到内部 imageView），
    // 等价于爱锋 updateLayouts 做的事；setNeedsLayout 对齐爱锋的 cell 级刷新。
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

#pragma mark - ①c 聊天时间修改

static char kDDTimeVMKey;

// 爱锋 timeText @0xba2d0 直接用覆盖时间（DKHelperConfig 字典里的字符串）自己格式化显示，
// 根本不依赖微信原始 timeText 文本选格式。DD 之前用微信 origin（可能是"昨天"/"刚刚"相对时间）
// 选格式串，会把用户改的具体日期格式成"昨天 HH:mm"丢失绝对日期 —— 这是时间修改失效的根因。
// 改为：基于用户指定的 ts 相对今天推算格式（今天/昨天/前天/今年含星期/跨年），与微信原生一致。
static NSString *DDTimeFormatForTimestamp(double ts) {
    NSCalendar *cal = [NSCalendar currentCalendar];
    NSDate *d = [NSDate dateWithTimeIntervalSince1970:ts];
    NSDate *now = [NSDate date];
    if ([cal isDateInToday:d]) return @"今天 HH:mm";
    if ([cal isDateInYesterday:d]) return @"昨天 HH:mm";
    NSDateComponents *dc = [cal components:NSCalendarUnitDay fromDate:d toDate:now options:0];
    if (dc.day == 2) return @"前天 HH:mm";
    NSInteger y = [cal component:NSCalendarUnitYear fromDate:d];
    NSInteger ny = [cal component:NSCalendarUnitYear fromDate:now];
    if (y == ny) return @"M月d日 EEEE HH:mm";
    return @"yyyy年M月d日 EEEE HH:mm";
}

// 输入/解析统一用 en_US_POSIX + @"yyyy-MM-dd HH:mm"（爱锋 timestampFromDateString: @0xbaf30 同款）。
// 必须用 en_US_POSIX，否则用户改了 12/24 小时制或地区后会解析出 nil。
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

static NSString *DDTimeStringForDisplay(double ts) {
    NSDateFormatter *f = [[NSDateFormatter alloc] init];
    f.locale = [NSLocale localeWithLocaleIdentifier:@"zh_CN"];
    f.timeZone = [NSTimeZone localTimeZone];
    f.dateFormat = DDTimeFormatForTimestamp(ts);
    return [f stringFromDate:[NSDate dateWithTimeIntervalSince1970:ts]];
}

// 时间条显示的就是 viewModel 的 timeText（ChatTimeViewModel.h:14）。覆盖时间直接用用户指定的 ts 格式化，
// 不再读微信 origin（避免相对时间 origin 让绝对日期丢失），与爱锋 timeText @0xba2d0 思路一致。
%hook ChatTimeViewModel
- (NSString *)timeText {
    if (![DDGlobalConfig shared].timeEnabled) return %orig;
    NSNumber *ts = DDJokerCachedTime(self);
    if (!ts) return %orig;
    NSString *s = DDTimeStringForDisplay([ts doubleValue]);
    return s.length ? s : %orig;
}
%end

%hook ChatTimeCellView
- (id)initWithViewModel:(id)vm {
    id r = %orig;
    // vm 先存起来：弹窗时要用它读 showingTime 和写缓存
    objc_setAssociatedObject(r, &kDDTimeVMKey, vm, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [(ChatTimeCellView *)r dk_installTimeEditGesture];
    return r;
}
- (void)setViewModel:(id)vm {
    %orig;
    objc_setAssociatedObject(self, &kDDTimeVMKey, vm, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [self dk_installTimeEditGesture];
}
// 长按手势装在 label 上，而 label 可能晚于 init 才创建，cell 复用时也会换，
// 所以 didMoveToWindow 里再补一次（爱锋同样 hook 了它，且实现是幂等的）
- (void)didMoveToWindow {
    %orig;
    [self dk_installTimeEditGesture];
}
%new
- (UILabel *)dk_timeLabel {
    // 爱锋 @0xbac08 也是先试 ivar m_timeLabel，取不到再退化为遍历
    Ivar iv = class_getInstanceVariable([self class], "m_timeLabel");
    if (iv) {
        id v = object_getIvar(self, iv);
        if ([v isKindOfClass:[UILabel class]]) return (UILabel *)v;
    }
    NSMutableArray *q = [NSMutableArray arrayWithObject:self];
    for (NSUInteger i = 0; i < q.count && i < 40; i++) {
        UIView *v = q[i];
        if (v != (UIView *)self && [v isKindOfClass:[UILabel class]] && ((UILabel *)v).text.length) {
            return (UILabel *)v;
        }
        for (UIView *s in v.subviews) [q addObject:s];
    }
    return nil;
}
%new
- (void)dk_installTimeEditGesture {
    if (![DDGlobalConfig shared].timeEnabled) return;
    UILabel *label = [self dk_timeLabel];
    if (!label) return;
    for (UIGestureRecognizer *g in label.gestureRecognizers) {
        if ([g isKindOfClass:[UILongPressGestureRecognizer class]]) return;   // 幂等，不重复装
    }
    label.userInteractionEnabled = YES;
    UILongPressGestureRecognizer *lp = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(dk_handleTimeLongPress:)];
    lp.minimumPressDuration = 0.5;      // 爱锋 @0xbada4 同为 0.5 秒
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
                         : [vm showingTime];
    NSString *defaultText = base > 0 ? [DDTimeInputFormatter() stringFromDate:[NSDate dateWithTimeIntervalSince1970:base]] : @"";

    // 与爱锋一致：微信原生 WCUIAlertView，标题/提示文案都沿用它的（@0xbb174 / @0x6287e8 / @0x628828）
    WCUIAlertView *alert = [(WCUIAlertView *)[%c(WCUIAlertView) alloc] initWithTitle:@"时间修改"
                                                                           message:@"输入格式如下\n2024-08-01 22:30"];
    [alert showTextFieldWithMaxLen:100];
    [alert setTextFieldDefaultText:defaultText];
    // alert 通过 handler: 强引用这两个 block，若 block 再强引用 alert 会形成保留环（-Werror 直接报错），
    // 故用 __weak：弹窗显示期间 alert 由微信内部持有仍存活，点击时 weakAlert 仍有效
    __weak WCUIAlertView *weakAlert = alert;
    [alert addCancelBtnTitle:@"取消" handler:^{ }];
    [alert addBtnTitle:@"确定" handler:^{
        WCUIAlertView *a = weakAlert;
        NSString *raw = a ? [a getTextFieldText] : nil;
        NSString *t = [raw stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        double ts = DDTimeStampFromString(t);
        if (ts > 0) {
            // 爱锋 changeTime @0xbb284 的收尾三步（反汇编实证）：
            //   写覆盖 → [vm updateLayouts] (@0xbb500，让 vm 重算 timeText)
            //   → [cell layoutInternal] (@0xbb590) → setNeedsLayout (@0xbb598)。
            // 之前少了 updateLayouts，vm 里已算好的 timeText 不会重算，cell 重画又把它写回 label，
            // 于是改完立刻弹回真实时间 —— 这就是"时间修改不生效"的根因。
            DDJokerSetCachedTime(vm, ts);
            [vm updateLayouts];          // ChatTimeViewModel.h:20
            [self layoutInternal];       // ChatTimeCellView.h:9，用重算后的 timeText 重画
            [self setNeedsLayout];
        }
    }];
    [alert show];
    objc_setAssociatedObject(self, &kDDTimeVMKey, vm, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
%end

#pragma mark - ② 运动步数修改
// 对齐爱锋：WCDeviceStepObject.m7StepCount / hkStepCount 直接返回自定义步数
// （爱锋 hooks_final.json 0xb313c / 0xb318c）。这两个 getter 是微信运动排行榜刷新的热路径，
// 爱锋实现里除读开关 + 自定义值外不做任何磁盘 IO（反汇编确认：调 [DKHelperConfig changeSteps]/
// [DKHelperConfig changedSteps] 后 csel 返回，无 NSUserDefaults 写）。因此这里绝不写磁盘，值上限 99999
// （爱锋弹窗建议 ≤60000，showTextFieldWithMaxLen:5）。

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

#pragma mark - ③ 好友数量修改
// 对齐爱锋：不 hook MMUILabel（全局 UILabel 复用会误伤/崩溃），而是在数据层
// ContactsDataLogic.m_uiNormalContact（unsigned int，ContactsDataLogic.h:58 确认）直接返回自定义好友数，
// 并可选地同步导航标题。爱锋 hooks_final.json：ContactsDataLogic.m_uiNormalContact @0xc5ae8 /
// ContactsViewController.viewWillAppear: @0xc5d74。爱锋真实实现里 updateCustomCountLabel 是死代码，
// 真正驱动"X个朋友"的是 m_uiNormalContact 的返回值（微信自行拼后缀）。

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

typedef NS_ENUM(NSInteger, DDBalancePageKind) {
    DDBalancePageNone = 0,     // 非钱包页 —— 必须原样返回，不能插手
    DDBalancePageBalance,      // 零钱/余额：WCPayBalanceDetailViewController
    DDBalancePageLQT           // 零钱通：WCPayLQTDetailViewController / WCPayLQTMoneyViewController
};

// 安全版响应链查找。ScrollNumber 的真实父类无法从 dump 确认（继承被抹成 NSObject），
// 它可能压根不是 UIResponder —— 那种情况下直接 nextResponder 就是 unrecognized selector 崩溃。
// 另外一个更关键的问题：ScrollNumber 是通用滚动数字控件，倒计时（TimeoutNumber）、
// 红包金额等都在用，无条件改所有实例会把无关控件的数值也改掉，严重时就是"进页面闪退"。
// 所以这里除了做类型检查，还要求响应链上的 VC 必须是余额/零钱通页，否则一律不插手。
static UIViewController *DDViewControllerOfView(id view) {
    if (!view || ![view isKindOfClass:[UIResponder class]]) return nil;
    UIResponder *r = (UIResponder *)view;
    NSInteger guard = 0;
    while (r && guard++ < 128) {          // 上限防御响应链成环
        if ([r isKindOfClass:[UIViewController class]]) return (UIViewController *)r;
        r = [r nextResponder];
    }
    return nil;
}

// 反汇编爱锋 isLQT（wechatku.dylib @0xbe820）得到的真实判定：
//   vc = [DKHelper currentViewController]
//   [vc isKindOfClass:KindaViewController] && [[vc title] isEqualToString:@"钱包"]
//   → 取 self.superview.superview.superview.subviews[0].subviews[1]（一个 UILabel）
//   → [label.text hasPrefix:@"零钱通"]  →  YES 表示这个 ScrollNumber 是零钱通
// 两点结论：①爱锋同样只在钱包页生效，不是全局改；②区分零钱/零钱通靠的是旁边的文字。
// 这里不照抄它硬编码的下标（层级一变就数组越界），改成在附近 view 树里搜"零钱通"字样。
static BOOL DDIsWalletBalancePage(UIViewController *vc) {
    if (!vc) return NO;
    NSString *cls = NSStringFromClass([vc class]);
    NSString *title = [vc respondsToSelector:@selector(title)] ? [vc title] : nil;
    // 钱包主页：KindaViewController + 标题"钱包"（零钱与零钱通并排显示）
    if ([cls isEqualToString:@"KindaViewController"] && [title isEqualToString:@"钱包"]) return YES;
    // 余额详情页 / 零钱通详情页
    if ([cls rangeOfString:@"WCPayBalanceDetail"].location != NSNotFound) return YES;
    if ([cls rangeOfString:@"WCPayLQT"].location != NSNotFound) return YES;
    return NO;
}

static BOOL DDHasTextNearView(id view, NSString *want, NSInteger depth) {
    if (!view || depth > 5 || ![view isKindOfClass:[UIView class]]) return NO;
    if ([view isKindOfClass:[UILabel class]]) {
        NSString *t = ((UILabel *)view).text;
        if (t.length && [t rangeOfString:want].location != NSNotFound) return YES;
    }
    NSInteger n = 0;
    for (UIView *sub in ((UIView *)view).subviews) {
        if (++n > 24) break;              // 限制遍历规模，别在一次刷新里扫穿整棵树
        if (DDHasTextNearView(sub, want, depth + 1)) return YES;
    }
    return NO;
}

static BOOL DDHasLQTBeside(id scrollNumber) {
    id v = scrollNumber;
    for (int i = 0; i < 5 && v; i++) {
        if (DDHasTextNearView(v, @"零钱通", 0)) return YES;
        if (![v respondsToSelector:@selector(superview)]) break;
        v = [v superview];
    }
    return NO;
}

static DDBalancePageKind DDBalancePageKindOf(id obj) {
    // 不在钱包页就一律不插手：ScrollNumber 是通用滚动数字控件（倒计时 TimeoutNumber 等都在用），
    // 全局改会把无关控件的数值也改掉，这正是"开启余额小丑后闪退"的根因
    if (!DDIsWalletBalancePage(DDViewControllerOfView(obj))) return DDBalancePageNone;
    return DDHasLQTBeside(obj) ? DDBalancePageLQT : DDBalancePageBalance;
}

// ScrollNumber 会为每一位数字建一整列滚动 view，位数极端时内存暴涨会被系统杀掉（也是闪退），
// 所以给金额封顶 11 位（约 9999 万元），足够用且不会把控件撑爆
static unsigned long long DDClampFen(unsigned long long fen) {
    const unsigned long long kMaxFen = 99999999999ULL;
    return fen > kMaxFen ? kMaxFen : fen;
}

%hook ScrollNumber
// 与爱锋一致：isLQT 是自己加的判定方法（爱锋 hooks 里同样标记 "new"），
// 结果用 associatedObject 缓存，避免每次刷新都遍历一遍响应链
%new
- (BOOL)isLQT {
    id cached = objc_getAssociatedObject(self, @selector(isLQT));
    if (cached) return [cached boolValue];
    // 只在已经能定论时才缓存：VC 还没挂上就缓存 NO，会把结果永久锁死成"余额"
    DDBalancePageKind kind = DDBalancePageKindOf(self);
    if (kind == DDBalancePageNone) return NO;
    BOOL v = (kind == DDBalancePageLQT);
    objc_setAssociatedObject(self, @selector(isLQT), @(v), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return v;
}

// 微信初始化时走 defaultNumber:，只 hook updateNumber: 会让刚进页面先闪一下真值
- (void)defaultNumber:(unsigned long long)original {
    @try {
        DDGlobalConfig *cfg = [DDGlobalConfig shared];
        DDBalancePageKind kind = cfg.balanceEnabled ? DDBalancePageKindOf(self) : DDBalancePageNone;
        if (kind == DDBalancePageNone) { %orig(original); return; }   // 非钱包页，不插手
        if (kind == DDBalancePageLQT) {
            %orig([cfg hasLingtongValue] ? DDClampFen(DDLingtongFenValue()) : original);
        } else {
            %orig([cfg hasBalanceValue] ? DDClampFen(DDBalanceFenValue()) : original);
        }
    } @catch (NSException *exception) {
        %orig(original);   // 任何异常都退回原值，绝不让微信崩
    }
}

- (void)updateNumber:(unsigned long long)original {
    @try {
        DDGlobalConfig *cfg = [DDGlobalConfig shared];
        DDBalancePageKind kind = cfg.balanceEnabled ? DDBalancePageKindOf(self) : DDBalancePageNone;
        if (kind == DDBalancePageNone) { %orig(original); return; }   // 非钱包页，不插手
        if (kind == DDBalancePageLQT) {
            %orig([cfg hasLingtongValue] ? DDClampFen(DDLingtongFenValue()) : original);
        } else {
            %orig([cfg hasBalanceValue] ? DDClampFen(DDBalanceFenValue()) : original);
        }
    } @catch (NSException *exception) {
        %orig(original);
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
    chatSection.attributedFooterTitle = [self dd_centeredFooterString:@"聊天文字 / 图片 / 时间 / 转账修改 为独立开关：长按消息弹窗菜单小丑按钮，文字改内容与引用标题、图片替换为相册所选图、时间改显示、转账改金额"];
    [chatSection addCell:[cellCls switchCellForSel:@selector(textSwitchChanged:) target:self title:@"聊天文字修改" on:cfg.textEnabled]];
    [chatSection addCell:[cellCls switchCellForSel:@selector(imageSwitchChanged:) target:self title:@"聊天图片修改" on:cfg.imageEnabled]];
    [chatSection addCell:[cellCls switchCellForSel:@selector(timeSwitchChanged:) target:self title:@"聊天时间修改" on:cfg.timeEnabled]];
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
    JokerInvalidateAllLayout();   // 关闭立即恢复原文，开启立即套用已保存的修改
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
    // 关开关时也必须走全量重绘：vm 里已算好的 titleText 是懒加载缓存，不清就一直显示旧金额
    JokerInvalidateAllLayout();
    [self buildTable];
}

- (void)clearChatCacheTapped:(id)sender {
    DDJokerClearAllMessageCache();    // 清文本/金额缓存字典 + 替换图目录
    JokerInvalidateAllLayout();       // 全量重绘所有聊天页（遍历全部 window 的 VC 树，不再只查单个导航栈）
    [self buildTable];
    [self dd_showDoneToast:@"已清理"];
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

// 实时回调：边打边存，不重建 table（重建会销毁正在编辑的 textField、丢焦点并让键盘抖动）。
// 键盘回收仍交给"确认"按钮的 buildTable 完成。
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

%ctor {
    @autoreleasepool {
        WCPluginsMgr *mgr = [%c(WCPluginsMgr) sharedInstance];
        [mgr registerControllerWithTitle:@"DD小丑助手"
                                 version:@"1.0.0"
                              controller:@"DDJokerSettingsViewController"];
    }
}