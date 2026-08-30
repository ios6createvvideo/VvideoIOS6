//
//  ViewController.h
//  VKVideoLegacy
//
//  Основной экран: поисковая строка (UISearchBar) +
//  UITableView со списком видеороликов.
//
//  Работает полностью БЕЗ авторизации. Отправляет HTTP-запросы
//  к локальному прокси (VKVideoBridge): http://host:8080/api/search?q=...
//

#import <UIKit/UIKit.h>
#import <MediaPlayer/MediaPlayer.h>

// Модель одного видеоролика (данные JSON ответа сервера).
@interface VideoItem : NSObject

@property (nonatomic, retain) NSString *title;     // Заголовок видео
@property (nonatomic, retain) NSString *duration;  // Длительность (строка или число)
@property (nonatomic, retain) NSString *photo;     // URL превью-картинки
@property (nonatomic, retain) NSString *url;       // Прямая MP4/HLS-ссылка или /stream?url=...

@end

// Главный контроллер экрана.
@interface ViewController : UIViewController
    <UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate,
     NSURLConnectionDelegate, NSURLConnectionDataDelegate>
{
    // Поле ввода поиска, закреплённое над таблицей.
    UISearchBar *_searchBar;

    // Таблица со списком результатов.
    UITableView *_tableView;

    // Массив объектов VideoItem (результаты поиска).
    NSMutableArray *_items;

    // Данные ответа сервера (асинхронная загрузка).
    NSMutableData *_receivedData;

    // Текущее активное соединение (для отмены).
    NSURLConnection *_connection;

    // Индикатор загрузки в шапке.
    UIActivityIndicatorView *_spinner;
}

// URL прокси-сервера (VKVideoBridge). Укажите IP/хост вашего сервера.
// Формат: http://<IP_ИЛИ_ХОСТ>:8080
@property (nonatomic, retain) NSString *serverBaseURL;

// Выполнить поиск по строке запроса.
- (void)performSearchWithQuery:(NSString *)query;

// Загрузить превью-картинку асинхронно в ячейку (кэш по адресу).
- (void)loadThumbnailForCell:(UITableViewCell *)cell item:(VideoItem *)item;

@end
