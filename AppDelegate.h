//
//  AppDelegate.h
//  VKVideoLegacy
//
//  Делегат приложения. Отвечает за запуск UIApplication,
//  создание главного окна и корневого контроллера.
//

#import <UIKit/UIKit.h>

@class ViewController;

@interface AppDelegate : UIResponder <UIApplicationDelegate>
{
    // Окно приложения (в iOS 6 UIWindow наследуется от UIView, без scenes).
    UIWindow *_window;

    // Корневой контроллер (экран поиска и списка видео).
    ViewController *_viewController;
}

// Свойство окна обязательно по протоколу UIApplicationDelegate.
@property (nonatomic, retain) UIWindow *window;

// Корневой контроллер.
@property (nonatomic, retain) ViewController *viewController;

@end
