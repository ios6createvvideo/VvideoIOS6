//
//  main.m
//  VKVideoLegacy
//
//  Точка входа в приложение.
//  Совместимо с iOS 6.1.3 SDK (Xcode) и Theos.
//
//  Здесь создается UIApplication/AppDelegate и запускается
//  главный цикл событий (run loop) приложения.
//

#import <UIKit/UIKit.h>
#import "AppDelegate.h"

int main(int argc, char *argv[])
{
    // Оборачиваем весь запуск в autorelease pool.
    // В iOS 6 с ARC этот код не обязателен, но сохранён
    // для совместимости со сборкой без ARC (MRC) в Theos.
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    int retVal = UIApplicationMain(argc, argv,
                                   nil,               // класс UIApplication (nil = стандартный)
                                   NSStringFromClass([AppDelegate class])); // класс делегата

    [pool drain];
    return retVal;
}
