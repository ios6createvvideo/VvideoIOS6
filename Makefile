#
#  Makefile
#  VKVideoLegacy
#
#  Сборка через Theos (поддерживает Windows/Linux/iOS).
#  Для сборки на Xcode (macOS) используется VKVideoLegacy.xcodeproj.
#
#  Требуемые установки:
#    - Theos (https://theos.dev) с Theos SDK (Objective-C, e.g. iOS 6.1 SDK)
#    - Переменная окружения THEOS должна указывать на каталог theos.
#
#  Без подписи кода на Windows/Linux: Theos по умолчанию не подписывает
#  (на устройствах нужен fakesign / JIT). Можно явно отключить:
#
#    export CODE_SIGNING_ALLOWED=NO
#    make package FINALPACKAGE=1
#

# ---------------------------------------------------------------
#  Имя твика/приложения
# ---------------------------------------------------------------
TARGET := iphone:clang:6.1:6.1
ARCHS := armv7

# Пакет — обычное приложение (не твик).
ADDITIONAL_OBJCFLAGS = -fobjc-arc
INSTALL_TARGET_PROCESSES = VKVideoLegacy

include $(THEOS)/makefiles/common.mk

# ---------------------------------------------------------------
#  Приложение
# ---------------------------------------------------------------
APPLICATION_NAME = VKVideoLegacy

# Исходные файлы приложения.
VKVideoLegacy_FILES = main.m AppDelegate.m ViewController.m

# Фреймворки и библиотеки.
VKVideoLegacy_FRAMEWORKS = UIKit Foundation MediaPlayer QuartzCore CoreGraphics

# Настройка Info.plist (любые ключи — дисплейное имя и пр.).
VKVideoLegacy_PLIST = VKVideoLegacy-Info.plist

# Функции для iOS 6 прошивки.
VKVideoLegacy_CFLAGS = -fobjc-arc

# ---------------------------------------------------------------
#  Сборка
# ---------------------------------------------------------------
include $(THEOS_MAKE_PATH)/application.mk

# ---------------------------------------------------------------
#  Необязательное отключение подписи кода при сборке через Theos.
#  Раскомментируйте при сборке без сертификата:
# ---------------------------------------------------------------
# CODE_SIGNING_ALLOWED = NO

# Также можно принудительно не подписывать:
# TARGET_CODESIGN = NO
