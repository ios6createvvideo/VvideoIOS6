//
//  AppDelegate.m
//  VKVideoLegacy
//
//  Реализация делегата приложения.
//  Создаёт UIWindow и корневой ViewController, оборачивая его
//  в UINavigationController для навигационной панели iOS 6.
//

#import "AppDelegate.h"
#import "ViewController.h"

@implementation AppDelegate

@synthesize window   = _window;
@synthesize viewController = _viewController;

// Сообщаем компилятору, что _window/_viewController освобождаются в dealloc.
// Это нужно при сборке с MRC (без ARC) в Theos.
- (void)dealloc
{
    [_viewController release];
    [_window release];
    [super dealloc];
}

// Главная точка входа после запуска приложения.
- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // --- Размер экрана устройства ---
    // Используем bounds главного экрана. В iOS 6 нет safe area,
    // поэтому используем полные размеры (для iPhone 4/4s это 320x480 pt).
    CGRect screenBounds = [[UIScreen mainScreen] bounds];

    // --- Создание окна ---
    self.window = [[[UIWindow alloc] initWithFrame:screenBounds] autorelease];

    // --- Создание главного экрана (поиск и список видео) ---
    ViewController *vc = [[ViewController alloc] init];
    self.viewController = vc;
    [vc release]; // удерживается свойством

    // Стандартный тёмно-синий цвет навигации iOS 6 (аналог VK).
    // Глянцевый эффект обеспечивает нативный UINavigationBar iOS 6.
    [[UINavigationBar appearance] setTintColor:
        [UIColor colorWithRed:0.22f green:0.34f blue:0.58f alpha:1.0f]];

    // --- Оборачиваем в NavigationController ---
    // Это добавляет глянцевую синюю панель навигации с заголовком.
    UINavigationController *navController =
        [[UINavigationController alloc] initWithRootViewController:vc];

    // --- Устанавливаем корневой контроллер →
    // должен быть вложен в окно через navigation controller.
    [self.window setRootViewController:navController];
    [navController release];

    // --- Делаем окно видимым ---
    [self.window makeKeyAndVisible];

    // Настраиваем стиль строки состояния и общий стиль.
    [[UIApplication sharedApplication]
        setStatusBarStyle:UIStatusBarStyleBlackOpaque animated:NO];

    return YES;
}

// Обработчики событий жизненного цикла (обязательные, но пустые в этом приложении).
- (void)applicationWillResignActive:(UIApplication *)application {}
- (void)applicationDidEnterBackground:(UIApplication *)application {}
- (void)applicationWillEnterForeground:(UIApplication *)application {}
- (void)applicationDidBecomeActive:(UIApplication *)application {}
- (void)applicationWillTerminate:(UIApplication *)application {}

@end
