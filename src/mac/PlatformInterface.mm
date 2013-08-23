#include "PlatformInterface.h"

#include "Utils.h"
#include "Config.h"
#include "ZulipApplication.h"
#include "ZulipWindow.h"

#include <QDir>
#include <QTimer>

#import <Foundation/Foundation.h>
#import <Sparkle/SUUpdater.h>
#import <Growl/GrowlApplicationBridge.h>

#if defined(LION) || defined(MOUNTAIN_LION)
#define SET_LION_FULLSCREEN NSWindowCollectionBehaviorFullScreenPrimary
#define LION_FULLSCREEN_ENTER_NOTIFICATION_VALUE NSWindowWillEnterFullScreenNotification
#define LION_FULLSCREEN_EXIT_NOTIFICATION_VALUE NSWindowDidExitFullScreenNotification
#else
#define SET_LION_FULLSCREEN (NSUInteger)(1 << 7) // Defined as NSWindowCollectionBehaviorFullScreenPrimary in lion's NSWindow.h
#define LION_FULLSCREEN_ENTER_NOTIFICATION_VALUE @"NSWindowWillEnterFullScreenNotification"
#define LION_FULLSCREEN_EXIT_NOTIFICATION_VALUE @"NSWindowDidExitFullScreenNotification"
#endif

@interface ZGrowlDelegate : NSObject <GrowlApplicationBridgeDelegate>
- (void) growlNotificationWasClicked:(id)clickContext;
@end

@implementation ZGrowlDelegate
- (void) growlNotificationWasClicked:(id)clickContext {
    APP->mainWindow()->trayClicked();
}
@end

class PlatformInterfacePrivate : public QObject {
    Q_OBJECT
public:
    PlatformInterfacePrivate(PlatformInterface *qq) : q(qq) {
        QDir binDir(QApplication::applicationDirPath());
        binDir.cdUp();
        binDir.cd("Resources");

        const QString file = binDir.absoluteFilePath("zulip.wav");
        sound = [[NSSound alloc] initWithContentsOfFile:fromQString(file)
                                            byReference:NO];

        if (APP->debugMode()) {
            [[NSUserDefaults standardUserDefaults] registerDefaults:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES]
                                                                                                forKey:@"WebKitDeveloperExtras"]];
        }

        QTimer::singleShot(0, this, SLOT(enableFullscreen()));
    }

    ~PlatformInterfacePrivate() {
        [sound release];
    }

public slots:
    void enableFullscreen() {
        // We don't support anything below leopard, so if it's not [snow] leopard it must be lion
        // Can't check for lion as Qt 4.7 doesn't have the enum val, not checking for Unknown as it will be lion
        // on 4.8
        if ( QSysInfo::MacintoshVersion != QSysInfo::MV_SNOWLEOPARD &&
             QSysInfo::MacintoshVersion != QSysInfo::MV_LEOPARD   )
        {
            ZulipWindow *w = APP->mainWindow();

            if (!w)
                return;

            NSView *nsview = (NSView *)w->winId();
            NSWindow *nswindow = [nsview window];
            [nswindow setCollectionBehavior:SET_LION_FULLSCREEN];
        }
    }

public:

    NSSound *sound;
    PlatformInterface *q;
};

PlatformInterface::PlatformInterface(QObject *parent)
    : QObject(parent)
    , m_d(new PlatformInterfacePrivate(this))
{
    // Initialize Sparkle
    [[SUUpdater sharedUpdater] setDelegate: NSApp];
    [[SUUpdater sharedUpdater] setUpdateCheckInterval:21600]; // 6 hour interval
    [[SUUpdater sharedUpdater] setAutomaticallyDownloadsUpdates:YES];

    [GrowlApplicationBridge setGrowlDelegate:[[ZGrowlDelegate alloc] init]];
}

PlatformInterface::~PlatformInterface() {
    delete m_d;
}

void PlatformInterface::checkForUpdates() {
    [[SUUpdater sharedUpdater] checkForUpdates: NSApp];
}

void PlatformInterface::desktopNotification(const QString &titleQ, const QString &contentQ) {
    // Bounce dock icon
    [NSApp requestUserAttention:NSCriticalRequest];

    // Show desktop notification
    NSString *title = fromQString(titleQ);
    NSString *content = fromQString(contentQ);

    [GrowlApplicationBridge notifyWithTitle:title description:content
                           notificationName:@"Message Notification"
                                   iconData:nil
                                   priority:0
                                   isSticky:NO
                               clickContext:nil];
}

void PlatformInterface::unreadCountUpdated(int, int) {

}

void PlatformInterface::playSound() {
    [m_d->sound play];
}

#include "PlatformInterface.moc"
