#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <substrate.h>

static NSString * const kAFKey = @"hidePluginEntryEnable";
static char kAFGestureKey;

@interface WCTableViewCellBaseConfig : NSObject
@end

@interface WCTableViewCellLeftConfig : NSObject
@property (copy, nonatomic) NSString *title;
@end

@interface WCTableViewCellNormalConfig : WCTableViewCellBaseConfig
@property (retain, nonatomic) WCTableViewCellLeftConfig *leftConfig;
@end

@interface WCTableViewCellManager : NSObject
@property (retain, nonatomic) WCTableViewCellBaseConfig *cellConfig;
@end

@interface WCTableViewSectionManager : NSObject
@property (retain, nonatomic) NSMutableArray<WCTableViewCellManager *> *cells;
@end

@interface WCTableViewManager : NSObject
@property (retain, nonatomic) NSMutableArray<WCTableViewSectionManager *> *sections;
- (void)reloadTableView;
@end

@interface MoreViewController : UIViewController
- (void)reloadMoreView;
@end

@interface MMTabBarController : UITabBarController
- (NSArray *)getTabBarBtnViews;
@end

%hook MoreViewController

- (void)reloadMoreView {
    %orig;
    if (![[NSUserDefaults standardUserDefaults] boolForKey:kAFKey]) return;
    WCTableViewManager *mgr = (WCTableViewManager *)[self valueForKey:@"m_tableViewMgr"];
    for (WCTableViewSectionManager *section in mgr.sections) {
        NSMutableArray<WCTableViewCellManager *> *cells = section.cells;
        for (NSInteger i = (NSInteger)cells.count - 1; i >= 0; i--) {
            WCTableViewCellNormalConfig *cfg = (WCTableViewCellNormalConfig *)cells[i].cellConfig;
            if ([cfg.leftConfig.title isEqualToString:@"插件"])
                [cells removeObjectAtIndex:i];
        }
    }
    [mgr reloadTableView];
}

%end

%hook MMTabBarController

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    UIView *me = (UIView *)[self getTabBarBtnViews].lastObject;
    if (!me || objc_getAssociatedObject(me, &kAFGestureKey)) return;
    UILongPressGestureRecognizer *lp = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(af_toggle:)];
    lp.minimumPressDuration = 2.0;
    lp.cancelsTouchesInView = NO;
    [me addGestureRecognizer:lp];
    objc_setAssociatedObject(me, &kAFGestureKey, lp, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

%new
- (void)af_toggle:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan) return;
    BOOL on = ![[NSUserDefaults standardUserDefaults] boolForKey:kAFKey];
    [[NSUserDefaults standardUserDefaults] setBool:on forKey:kAFKey];
    UIViewController *vc = self.selectedViewController;
    if ([vc isKindOfClass:UINavigationController.class]) vc = [(UINavigationController *)vc topViewController];
    [(MoreViewController *)vc reloadMoreView];
}

%end
