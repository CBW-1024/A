#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <substrate.h>

static NSString *const kDDWxidEnabledKey   = @"DDProfileWxidEnabled";
static NSString *const kDDWxidValueKey     = @"DDProfileWxidValue";
static NSString *const kDDAvatarEnabledKey = @"DDProfileAvatarEnabled";

@interface DDProfileConfig : NSObject
+ (instancetype)shared;
@property (nonatomic) BOOL wxidEnabled;
@property (nonatomic, copy) NSString *wxidValue;
@property (nonatomic) BOOL avatarEnabled;
@end

#pragma mark - 微信类声明

@interface WeToast : NSObject
+ (id)toast;
- (void)showDoneToastWithText:(id)a0;
@end

static void DDShowDoneToast(NSString *text) {
    if (!text.length) return;
    WeToast *toast = [%c(WeToast) toast];
    if (toast) [toast showDoneToastWithText:text];
}

@interface WCPluginsMgr : NSObject
+ (instancetype)sharedInstance;
- (void)registerControllerWithTitle:(NSString *)title version:(NSString *)version controller:(NSString *)controller;
@end

@interface WCTableViewCellManager : NSObject
+ (id)switchCellForSel:(SEL)sel target:(id)target title:(id)title on:(BOOL)on;
+ (id)normalCellForSel:(SEL)sel target:(id)target title:(id)title rightView:(id)rightView;
@property (nonatomic, retain) id userInfo;
@end

@interface WCTableViewSectionManager : NSObject
+ (id)sectionWithHeader:(NSString *)header;
+ (id)defaultSection;
@property (nonatomic, copy) NSString *footerTitle;
- (void)addCell:(id)arg1;
- (unsigned long long)getCellCount;
- (id)getCellAt:(unsigned long long)a0;
@end

@interface WCTableViewManager : NSObject
- (id)initWithFrame:(CGRect)frame style:(NSInteger)style;
@property (nonatomic, readonly) UITableView *tableView;
@property (nonatomic, weak) id delegate;
- (void)clearAllSection;
- (void)addSection:(id)arg1;
- (id)cellInfoAtIndexPath:(NSIndexPath *)indexPath;
- (void)reloadTableView;
- (id)getTableView;
- (id)getAllSections;
- (void)insertSection:(id)arg1 At:(unsigned int)a1;
@end

@interface CBaseContact : NSObject
@property (retain, nonatomic) NSString *m_nsUsrName;
@property (retain, nonatomic) NSString *m_nsAliasName;
- (BOOL)isSelf;
@end

@interface CContact : CBaseContact
@end

@interface CSetting : NSObject
- (id)m_nsAliasName;
@end

@interface MMHeadImageView : UIView
@property (readonly, nonatomic) NSString *nsUsrName;
- (void)setHeadImageByName:(id)usrName;
- (void)doUpdateHeadImg:(BOOL)force;
- (void)updateUsrName:(id)usrName withHeadImgUrl:(id)headImgUrl;
- (void)updateHeadImage:(id)image;
- (void)ImageDidLoad:(id)image Url:(id)url;
- (void)didMoveToWindow;
@end

@interface ImageScrollView : UIView
- (void)updateImage:(id)image;
@end
@interface MMHDHeadImageView : UIView
@property (retain, nonatomic) CBaseContact *m_contact;
- (void)updateHead;
- (void)updateHDHead;
- (void)dd_applyCustomHDHead;
@end

@interface AddContactToChatRoomViewController : UIViewController
@property (retain, nonatomic) CContact *m_contact;
- (void)ddAvatarSwitchChanged:(UISwitch *)sender;
- (void)dd_injectAvatarCell;
@end

#pragma mark - 配置

static void DDRefreshAvatarViewsForUser(NSString *usrName);

#pragma mark - 头像文件管理

static NSString *DDAvatarDir(void) {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *doc = paths.firstObject;
    if (doc.length == 0) doc = @"/var/mobile/Documents";
    NSString *dir = [doc stringByAppendingPathComponent:@"DDAvatar"];
    BOOL isDir = NO;
    if (![[NSFileManager defaultManager] fileExistsAtPath:dir isDirectory:&isDir]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:dir
                                 withIntermediateDirectories:YES
                                                  attributes:nil
                                                       error:nil];
    }
    return dir;
}

static NSString *DDAvatarPathForUser(NSString *usrName) {
    if (usrName.length == 0) return nil;
    NSCharacterSet *keep = [NSCharacterSet alphanumericCharacterSet];
    NSMutableString *safe = [NSMutableString string];
    for (NSUInteger i = 0; i < usrName.length; i++) {
        unichar c = [usrName characterAtIndex:i];
        if ([keep characterIsMember:c]) {
            [safe appendFormat:@"%C", c];
        } else {
            [safe appendString:@"_"];
        }
    }
    return [DDAvatarDir() stringByAppendingPathComponent:[safe stringByAppendingPathExtension:@"png"]];
}

static NSCache *DDAvatarCache(void) {
    static NSCache *cache = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        cache = [[NSCache alloc] init];
        cache.countLimit = 64;
    });
    return cache;
}

static void DDAvatarCacheInvalidate(NSString *usrName) {
    if (usrName.length) [DDAvatarCache() removeObjectForKey:usrName];
    else [DDAvatarCache() removeAllObjects];
}

static UIImage *DDAvatarImageForUser(NSString *usrName) {
    if (![DDProfileConfig shared].avatarEnabled) return nil;
    if (usrName.length == 0) return nil;
    NSCache *cache = DDAvatarCache();
    id cached = [cache objectForKey:usrName];
    if (cached) return (cached == [NSNull null]) ? nil : (UIImage *)cached;

    UIImage *img = [UIImage imageWithContentsOfFile:DDAvatarPathForUser(usrName)];
    if (!(img && img.size.width > 0 && img.size.height > 0)) img = nil;
    [cache setObject:(img ?: (UIImage *)[NSNull null]) forKey:usrName];
    return img;
}

static UIImage *DDScaledImage(UIImage *image, CGFloat maxSide) {
    if (!image || maxSide <= 0) return image;
    CGSize size = image.size;
    CGFloat longest = MAX(size.width, size.height);
    if (longest <= maxSide) return image;
    CGFloat ratio = maxSide / longest;
    CGSize target = CGSizeMake(round(size.width * ratio), round(size.height * ratio));
    UIGraphicsBeginImageContextWithOptions(target, NO, 0.0);
    [image drawInRect:CGRectMake(0, 0, target.width, target.height)];
    UIImage *scaled = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return scaled ?: image;
}

static BOOL DDAvatarSaveImage(UIImage *image, NSString *usrName) {
    NSString *path = DDAvatarPathForUser(usrName);
    if (!image || !path) return NO;
    NSData *data = UIImagePNGRepresentation(DDScaledImage(image, 400.0));
    if (data.length == 0) return NO;
    BOOL ok = [data writeToFile:path atomically:YES];
    if (ok) {
        DDAvatarCacheInvalidate(usrName);
        DDRefreshAvatarViewsForUser(usrName);
    }
    return ok;
}

static BOOL DDAvatarRemoveForUser(NSString *usrName) {
    NSString *path = DDAvatarPathForUser(usrName);
    if (!path) return NO;
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) return NO;
    BOOL ok = [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
    DDAvatarCacheInvalidate(usrName);
    if (ok) DDRefreshAvatarViewsForUser(usrName);
    return ok;
}

static NSInteger DDAvatarRemoveAll(void) {
    NSString *dir = DDAvatarDir();
    NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:dir error:nil];
    NSInteger n = 0;
    for (NSString *f in files) {
        if (![f.pathExtension isEqualToString:@"png"]) continue;
        if ([[NSFileManager defaultManager] removeItemAtPath:[dir stringByAppendingPathComponent:f] error:nil]) n++;
    }
    if (n > 0) {
        DDAvatarCacheInvalidate(nil);
        DDRefreshAvatarViewsForUser(nil);
    }
    return n;
}

#pragma mark - 选图（系统 UIImagePickerController）

typedef void (^DDAvatarPickCompletion)(UIImage *image);

@interface DDAvatarPicker : NSObject <UIImagePickerControllerDelegate, UINavigationControllerDelegate>
@property (nonatomic, copy) DDAvatarPickCompletion completion;
+ (void)presentFromViewController:(UIViewController *)vc completion:(DDAvatarPickCompletion)completion;
@end

@implementation DDAvatarPicker

static char kDDAvatarPickerDelegateKey;

static UIViewController *DDTopPresentedViewController(UIViewController *vc) {
    UIViewController *top = vc;
    NSInteger guard = 0;
    while (top.presentedViewController && !top.presentedViewController.isBeingDismissed && guard++ < 8) {
        top = top.presentedViewController;
    }
    return top;
}

+ (void)presentFromViewController:(UIViewController *)vc completion:(DDAvatarPickCompletion)completion {
    if (!vc) {
        if (completion) completion(nil);
        return;
    }
    if (![UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary]) {
        if (completion) completion(nil);
        return;
    }

    UIViewController *presenter = DDTopPresentedViewController(vc);

    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    picker.allowsEditing = YES;
    picker.title = @"头像修改";

    DDAvatarPicker *proxy = [[DDAvatarPicker alloc] init];
    proxy.completion = completion;
    picker.delegate = proxy;
    objc_setAssociatedObject(picker, &kDDAvatarPickerDelegateKey, proxy, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    dispatch_async(dispatch_get_main_queue(), ^{
        if (!presenter.view.window || presenter.isBeingDismissed || presenter.presentedViewController) {
            if (completion) completion(nil);
            return;
        }
        [presenter presentViewController:picker animated:YES completion:^{
        }];
    });
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<NSString *,id> *)info {
    UIImage *image = info[UIImagePickerControllerEditedImage] ?: info[UIImagePickerControllerOriginalImage];
    DDAvatarPickCompletion cb = self.completion;
    [picker dismissViewControllerAnimated:YES completion:^{
        if (cb) cb(image);
    }];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    DDAvatarPickCompletion cb = self.completion;
    [picker dismissViewControllerAnimated:YES completion:^{
        if (cb) cb(nil);
    }];
}

@end

#pragma mark - 自定义微信号（只改自己）

static NSString *DDCustomWxid(void) {
    DDProfileConfig *cfg = [DDProfileConfig shared];
    if (!cfg.wxidEnabled) return nil;
    NSString *value = cfg.wxidValue;
    if (value.length == 0) return nil;
    return value;
}

%hook CSetting

- (id)m_nsAliasName {
    NSString *custom = DDCustomWxid();
    if (custom) {
        return custom;
    }
    return %orig;
}

%end

%hook CBaseContact

- (id)m_nsAliasName {
    NSString *custom = DDCustomWxid();
    if (custom && [self isSelf]) {
        return custom;
    }
    return %orig;
}

%end

#pragma mark - 头像替换（显示侧）

static NSHashTable *DDAvatarViews(void) {
    static NSHashTable *t = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ t = [NSHashTable weakObjectsHashTable]; });
    return t;
}

static void DDRefreshAvatarViewsForUser(NSString *usrName) {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{ DDRefreshAvatarViewsForUser(usrName); });
        return;
    }
    for (MMHeadImageView *v in DDAvatarViews()) {
        NSString *name = v.nsUsrName;
        if (name.length == 0) continue;
        if (usrName.length && ![name isEqualToString:usrName]) continue;
        [v setHeadImageByName:name];
    }
}

static BOOL DDTryApplyCustomAvatar(MMHeadImageView *view, NSString *usrName) {
    NSString *name = usrName.length ? usrName : view.nsUsrName;
    UIImage *custom = DDAvatarImageForUser(name);
    if (!custom) return NO;
    [view updateHeadImage:custom];
    return YES;
}

%hook MMHeadImageView

- (void)updateHeadImage:(id)image {
    UIImage *custom = DDAvatarImageForUser([self nsUsrName]);
    %orig(custom ?: image);
}

- (void)updateUsrName:(id)usrName withHeadImgUrl:(id)headImgUrl {
    %orig(usrName, headImgUrl);
    UIImage *custom = DDAvatarImageForUser(usrName ?: [self nsUsrName]);
    if (custom) {
        [self updateHeadImage:custom];
    }
}

- (void)ImageDidLoad:(id)image Url:(id)url {
    %orig(image, url);
    UIImage *custom = DDAvatarImageForUser([self nsUsrName]);
    if (custom) {
        [self updateHeadImage:custom];
    }
}

- (void)setHeadImageByName:(id)usrName {
    %orig(usrName);
    DDTryApplyCustomAvatar(self, usrName);
}

- (void)doUpdateHeadImg:(BOOL)force {
    %orig(force);
    DDTryApplyCustomAvatar(self, nil);
}

- (void)didMoveToWindow {
    %orig;
    if (!self.window) return;
    [DDAvatarViews() addObject:self];
    DDTryApplyCustomAvatar(self, nil);
}

%end

#pragma mark - 头像替换 · 高清大图（点开资料页头像后）

static UIView *DDFindImageScrollViewIn(UIView *root) {
    if (!root) return nil;
    Class cls = %c(ImageScrollView);
    if (!cls) return nil;
    for (UIView *v in root.subviews) {
        if ([v isKindOfClass:cls]) return v;
        UIView *found = DDFindImageScrollViewIn(v);
        if (found) return found;
    }
    return nil;
}

%hook MMHDHeadImageView

%new
- (void)dd_applyCustomHDHead {
    UIImage *custom = DDAvatarImageForUser([self.m_contact m_nsUsrName]);
    if (!custom) return;
    ImageScrollView *sv = (ImageScrollView *)DDFindImageScrollViewIn(self);
    if (!sv) return;
    [sv updateImage:custom];
}

- (void)updateHead {
    %orig;
    [self dd_applyCustomHDHead];
}

- (void)updateHDHead {
    %orig;
    [self dd_applyCustomHDHead];
}

%end

#pragma mark - 头像修改入口（单聊「聊天信息」页）

#define kDDAvatarChangedNotification @"DDProfileAvatarChanged"

static const void *kDDAvatarCellMarker = &kDDAvatarCellMarker;

static BOOL DDSectionHasAvatarCell(id section) {
    @try {
        unsigned long long n = [section getCellCount];
        for (unsigned long long i = 0; i < n; i++) {
            id c = [section getCellAt:i];
            if (objc_getAssociatedObject(c, kDDAvatarCellMarker) != nil) return YES;
        }
    } @catch (NSException *e) {}
    return NO;
}

static __weak AddContactToChatRoomViewController *s_currentProfileVC = nil;

static AddContactToChatRoomViewController *DDCurrentProfileVCForTable(id tableViewInfo) {
    AddContactToChatRoomViewController *vc = s_currentProfileVC;
    if (!vc || !tableViewInfo) return nil;
    id tv = nil;
    @try { tv = [vc valueForKey:@"m_tableViewInfo"]; } @catch (NSException *e) { tv = nil; }
    if (tv != tableViewInfo) return nil;
    return vc;
}

static void DDInjectAvatarSwitchIntoTable(AddContactToChatRoomViewController *vc, BOOL reloadNow) {
    if (![DDProfileConfig shared].avatarEnabled) return;
    if (![vc m_contact]) return;
    id tableViewInfo = [vc valueForKey:@"m_tableViewInfo"];
    if (!tableViewInfo) return;
    NSArray *sections = [tableViewInfo getAllSections];
    if (sections.count == 0) return;
    for (id s in sections) {
        if (DDSectionHasAvatarCell(s)) return;
    }
    NSString *usrName = [[vc m_contact] m_nsUsrName];
    BOOL hasCustom = DDAvatarImageForUser(usrName) != nil;
    id cell = [%c(WCTableViewCellManager) switchCellForSel:@selector(ddAvatarSwitchChanged:)
                                                   target:vc
                                                    title:@"自定义头像"
                                                       on:hasCustom];
    if (!cell) return;
    objc_setAssociatedObject(cell, kDDAvatarCellMarker, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    id section = [%c(WCTableViewSectionManager) defaultSection];
    [section addCell:cell];
    [tableViewInfo insertSection:section At:1];
    if (reloadNow) [[tableViewInfo getTableView] reloadData];
}

%hook WCTableViewManager

// 主力路径：微信重建表格走 clearAllSection → addSection ×N。
// 首个 addSection 回调时资料卡已加回，此刻同步插到 At:1，
// 与重建在同一 runloop 内完成，微信随后的一次 reloadData 即带出该行，不产生第二帧。
- (void)addSection:(id)a0 {
    %orig;
    if (!a0) return;
    AddContactToChatRoomViewController *vc = DDCurrentProfileVCForTable(self);
    if (!vc || ![vc m_contact]) return;
    DDInjectAvatarSwitchIntoTable(vc, NO);
}

%end

%hook AddContactToChatRoomViewController

// s_currentProfileVC 必须在 %orig 之前赋值：
// 微信在 super viewDidLoad 内部就完成表格装配（addSection ×7），
// 若等到 %orig 之后再赋值，装配期的 addSection 钩子会被判为"不是我的表"而全部跳过，
// 只能退到 viewDidAppear 才补插——这就是开关"过一下才出现"的原因。
- (void)viewDidLoad {
    s_currentProfileVC = self;
    %orig;
    s_currentProfileVC = self;
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(reloadTableData)
                                                 name:kDDAvatarChangedNotification
                                               object:nil];
    [self dd_injectAvatarCell];   // 表格已装配完、页面尚未显示，首帧即带开关
}

// 转场动画开始前再确认一次：若微信在 %orig 里又重建了一次表格，此处补回；
// 正常情况下已被 addSection 插好，这里被去重挡住。
- (void)viewWillAppear:(BOOL)animated {
    s_currentProfileVC = self;
    %orig;
    s_currentProfileVC = self;
    [self dd_injectAvatarCell];
}

- (void)dealloc {
    if (s_currentProfileVC == self) s_currentProfileVC = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kDDAvatarChangedNotification object:nil];
    %orig;
}

%new
- (void)dd_injectAvatarCell {
    DDInjectAvatarSwitchIntoTable(self, YES);
}

%new
- (void)ddAvatarSwitchChanged:(UISwitch *)sender {
    CContact *contact = [self m_contact];
    NSString *usrName = [contact m_nsUsrName];
    if (usrName.length == 0) {
        return;
    }

    if (DDAvatarImageForUser(usrName)) {
        (void)DDAvatarRemoveForUser(usrName);
        [[NSNotificationCenter defaultCenter] postNotificationName:kDDAvatarChangedNotification object:nil];
    } else {
        __weak typeof(self) weakSelf = self;
        __weak UISwitch *weakSw = sender;
        [DDAvatarPicker presentFromViewController:self completion:^(UIImage *image) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            if (!image) {
                [weakSw setOn:NO animated:YES];
                return;
            }
            if (!DDAvatarSaveImage(image, usrName)) {
                [weakSw setOn:NO animated:YES];
            } else {
                [[NSNotificationCenter defaultCenter] postNotificationName:kDDAvatarChangedNotification object:nil];
            }
        }];
    }
}

%end

#pragma mark - 设置页

@interface DDProfileSettingsViewController : UIViewController <UITableViewDelegate>
@property (nonatomic, strong) WCTableViewManager *tableViewManager;
- (void)buildTable;
- (UIView *)inputRowWithField:(UITextField *)field
                       action:(SEL)action
                         text:(NSString *)text
                     keyboard:(UIKeyboardType)keyboard;
- (UIButton *)dd_actionButton:(NSString *)title action:(SEL)action x:(CGFloat)x;
- (void)wxidSwitchChanged:(id)sender;
- (void)wxidConfirm:(id)sender;
- (void)avatarSwitchChanged:(id)sender;
- (void)clearAllAvatarTapped:(id)sender;
@end

@implementation DDProfileSettingsViewController {
    id<UITableViewDelegate> _originalDelegate;
    UITextField *_wxidField;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"小丑资料设置";

    UINavigationBarAppearance *appearance = [[UINavigationBarAppearance alloc] init];
    [appearance configureWithDefaultBackground];
    appearance.shadowColor = nil;
    self.navigationItem.standardAppearance = appearance;
    self.navigationItem.scrollEdgeAppearance = appearance;
    self.navigationItem.compactAppearance = appearance;

    _tableViewManager = [(WCTableViewManager *)[%c(WCTableViewManager) alloc] initWithFrame:[[UIScreen mainScreen] bounds]
                                                                                     style:UITableViewStyleInsetGrouped];
    _tableViewManager.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _tableViewManager.tableView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentAutomatic;
    [self.view addSubview:_tableViewManager.tableView];

    _originalDelegate = _tableViewManager.delegate;
    _tableViewManager.delegate = self;

    [self buildTable];
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (_originalDelegate && [_originalDelegate respondsToSelector:@selector(tableView:willDisplayCell:forRowAtIndexPath:)]) {
        [_originalDelegate tableView:tableView willDisplayCell:cell forRowAtIndexPath:indexPath];
    }
    WCTableViewCellManager *cellInfo = [_tableViewManager cellInfoAtIndexPath:indexPath];
    if ([cellInfo.userInfo isEqual:@"SubCell"]) {
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

- (UIView *)inputRowWithField:(UITextField *)field
                       action:(SEL)action
                         text:(NSString *)text
                     keyboard:(UIKeyboardType)keyboard {
    UIView *container = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 220, 34)];
    container.backgroundColor = [UIColor clearColor];

    field.frame = CGRectMake(0, 0, 160, 34);
    field.borderStyle = UITextBorderStyleNone;
    field.text = text;
    field.textAlignment = NSTextAlignmentRight;
    field.keyboardType = keyboard;
    field.autocorrectionType = UITextAutocorrectionTypeNo;
    field.autocapitalizationType = UITextAutocapitalizationTypeNone;
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

    DDProfileConfig *cfg = [DDProfileConfig shared];
    Class cellCls = %c(WCTableViewCellManager);

    WCTableViewSectionManager *profileSection = [%c(WCTableViewSectionManager) sectionWithHeader:@"资料自定义"];
    profileSection.footerTitle = @"微信号仅改本地显示，不修改服务器数据；头像开启后可在单聊「聊天信息」页替换联系人头像";

    [profileSection addCell:[cellCls switchCellForSel:@selector(wxidSwitchChanged:)
                                               target:self
                                                title:@"自定义微信号"
                                                   on:cfg.wxidEnabled]];
    if (cfg.wxidEnabled) {
        _wxidField = [[UITextField alloc] init];
        UIView *right = [self inputRowWithField:_wxidField
                                        action:@selector(wxidConfirm:)
                                           text:cfg.wxidValue ?: @""
                                       keyboard:UIKeyboardTypeASCIICapable];
        WCTableViewCellManager *wxidSubCell = [cellCls normalCellForSel:nil
                                                              target:nil
                                                               title:@"↳目标微信号"
                                                           rightView:right];
        wxidSubCell.userInfo = @"SubCell";
        [profileSection addCell:wxidSubCell];
    }

    [profileSection addCell:[cellCls switchCellForSel:@selector(avatarSwitchChanged:)
                                               target:self
                                                title:@"备注用户头像"
                                                   on:cfg.avatarEnabled]];
    UIButton *clearBtn = [self dd_actionButton:@"清理" action:@selector(clearAllAvatarTapped:) x:0];
    UIView *clearRight = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 52, 34)];
    [clearRight addSubview:clearBtn];
    [profileSection addCell:[cellCls normalCellForSel:nil
                                              target:nil
                                               title:@"清理全部头像"
                                           rightView:clearRight]];
    [_tableViewManager addSection:profileSection];

    [_tableViewManager reloadTableView];
}

- (void)wxidSwitchChanged:(id)sender {
    UISwitch *sw = (UISwitch *)sender;
    [DDProfileConfig shared].wxidEnabled = sw.on;
    [self buildTable];
}

- (void)wxidConfirm:(id)sender {
    NSString *text = [_wxidField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    [DDProfileConfig shared].wxidValue = text;
    [_wxidField resignFirstResponder];
    [self buildTable];
}

- (void)avatarSwitchChanged:(id)sender {
    UISwitch *sw = (UISwitch *)sender;
    [DDProfileConfig shared].avatarEnabled = sw.on;
    if (!sw.on) DDRefreshAvatarViewsForUser(nil);
    [self buildTable];
}

- (void)clearAllAvatarTapped:(id)sender {
    (void)DDAvatarRemoveAll();
    DDShowDoneToast(@"头像已清理");
}

@end

#pragma mark - 配置实现

@implementation DDProfileConfig

+ (instancetype)shared {
    static DDProfileConfig *config = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ config = [DDProfileConfig new]; });
    return config;
}

- (instancetype)init {
    if (self = [super init]) {
        NSUserDefaults *def = [NSUserDefaults standardUserDefaults];
        _wxidEnabled = [def boolForKey:kDDWxidEnabledKey];
        _wxidValue = [def stringForKey:kDDWxidValueKey] ?: @"";
        _avatarEnabled = [def boolForKey:kDDAvatarEnabledKey];
    }
    return self;
}

- (void)setWxidEnabled:(BOOL)wxidEnabled {
    _wxidEnabled = wxidEnabled;
    NSUserDefaults *def = [NSUserDefaults standardUserDefaults];
    [def setBool:wxidEnabled forKey:kDDWxidEnabledKey];
    [def synchronize];
}

- (void)setWxidValue:(NSString *)wxidValue {
    _wxidValue = wxidValue ?: @"";
    NSUserDefaults *def = [NSUserDefaults standardUserDefaults];
    [def setObject:_wxidValue forKey:kDDWxidValueKey];
    [def synchronize];
}

- (void)setAvatarEnabled:(BOOL)avatarEnabled {
    _avatarEnabled = avatarEnabled;
    NSUserDefaults *def = [NSUserDefaults standardUserDefaults];
    [def setBool:avatarEnabled forKey:kDDAvatarEnabledKey];
    [def synchronize];
}

@end

#pragma mark - 插件注册

%ctor {
    @autoreleasepool {
        WCPluginsMgr *mgr = [%c(WCPluginsMgr) sharedInstance];
        [mgr registerControllerWithTitle:@"DD小丑资料"
                                 version:@"1.0.0"
                              controller:@"DDProfileSettingsViewController"];
    }
}
