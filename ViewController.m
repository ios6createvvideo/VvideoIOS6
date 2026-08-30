//
//  ViewController.m
//  VKVideoLegacy
//
//  Полная реализация главного экрана.
//
//  Функции:
//   1. Нативный UISearchBar для ввода запроса.
//   2. Отправка HTTP GET запроса к прокси VKVideoBridge:
//        http://<host>:8080/api/search?q=<query>
//   3. Парсинг JSON-ответа (массив объектов) в массив VideoItem.
//   4. Отображение UITableView со льняным/градиентным фоном iOS 6.
//   5. Глянцевые ячейки с превью (загрузка асинхронно) и заголовком.
//   6. Воспроизведение нативно через MPMoviePlayerViewController.
//
//  Совместимость iOS 6.1.3: используем MRC (manual retain/release),
//  так как многие сборки Theos работают без ARC. Все объекты
//  освобождаются вручную и в dealloc.
//

#import "ViewController.h"
#import <MediaPlayer/MediaPlayer.h>
#import <QuartzCore/QuartzCore.h>

// ----------------------------------------------------------------
//  Реализация модели VideoItem
// ----------------------------------------------------------------
@implementation VideoItem

@synthesize title, duration, photo, url;

- (void)dealloc
{
    [title release];
    [duration release];
    [photo release];
    [url release];
    [super dealloc];
}

@end

// ----------------------------------------------------------------
//  Реализация главного контроллера
// ----------------------------------------------------------------
@implementation ViewController

@synthesize serverBaseURL;

// Статический кэш превью-картинок по URL (защита от повторной загрузки).
+ (NSCache *)thumbnailCache
{
    static NSCache *cache = nil;
    if (cache == nil) {
        cache = [[NSCache alloc] init];
    }
    return cache;
}

- (id)init
{
    self = [super init];
    if (self) {
        // По умолчанию прокси на localhost:8080.
        // ВАЖНО: замените на реальный IP вашего сервера в локальной сети.
        self.serverBaseURL = @"http://127.0.0.1:8080";

        _items = [[NSMutableArray alloc] init];
        _receivedData = [[NSMutableData alloc] init];
    }
    return self;
}

- (void)dealloc
{
    [_connection cancel];
    [_connection release];
    [_receivedData release];
    [_items release];
    [_spinner release];
    [serverBaseURL release];
    [super dealloc];
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    // --- Заголовок навигационной панели ---
    // Стандартный нативный заголовок iOS 6 (тиснёный, глянцевый).
    self.title = @"ВК Видео";

    // --- Фон: общий серый льняной паттерн (скевоморфизм iOS 6) ---
    // Создаём серый градиент как фон главного представления.
    // Паттерн «лён» не входит в SDK, поэтому рисуем собственный градиент
    // через CAGradientLayer — это даёт аккуратный серый перелив как на iOS 6.
    CAGradientLayer *gradient = [CAGradientLayer layer];
    gradient.frame = self.view.bounds;
    gradient.colors = [NSArray arrayWithObjects:
        (id)[UIColor colorWithWhite:0.55f alpha:1.0f].CGColor,
        (id)[UIColor colorWithWhite:0.38f alpha:1.0f].CGColor,
        nil];
    // Добавляем слой позади всего.
    [self.view.layer insertSublayer:gradient atIndex:0];
    // (отпускаем локальную переменную, она retain'ится слоем)
    // Чтобы градиент пересчитывался при повороте — в layoutSubviews не нужно,
    // т.к. окно фиксировано в полный экран. Это допустимо для демо.

    // --- Поисковая строка (нативная, в стиле iOS 6) ---
    _searchBar = [[UISearchBar alloc] initWithFrame:
        CGRectMake(0, 0, self.view.bounds.size.width, 44)];
    _searchBar.placeholder = @"Поиск видео";
    _searchBar.delegate = self;
    // Стандартный стиль панели поиска iOS 6.
    _searchBar.barStyle = UIBarStyleBlackTranslucent;
    _searchBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;

    // Создаём подложку для поисковой строки, чтобы она была над таблицей.
    // Используем простой подход: ставим searchBar как headerView таблицы.

    // --- Таблица результатов ---
    _tableView = [[UITableView alloc] initWithFrame:
        CGRectMake(0, 44, self.view.bounds.size.width,
                   self.view.bounds.size.height - 44)
        style:UITableViewStylePlain];
    _tableView.delegate = self;
    _tableView.dataSource = self;
    // Прозрачный фон — виден градиент под таблицей.
    _tableView.backgroundColor = [UIColor clearColor];
    _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    _tableView.autoresizingMask =
        UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

    // Ставим searchBar как "плавающую" шапку таблицы.
    // (searchBar будет прокручиваться вместе с таблицей — привычно для iOS 6.)
    UIView *searchContainer = [[UIView alloc] initWithFrame:
        CGRectMake(0, 0, self.view.bounds.size.width, 44)];
    searchContainer.backgroundColor = [UIColor clearColor];
    [searchContainer addSubview:_searchBar];
    _tableView.tableHeaderView = searchContainer;
    [searchContainer release];

    // Добавляем таблицу в главное представление.
    [self.view addSubview:_tableView];

    // --- Индикатор загрузки (в центре, убирается после ответа) ---
    _spinner = [[UIActivityIndicatorView alloc]
        initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    _spinner.center = CGPointMake(self.view.bounds.size.width/2,
                                  self.view.bounds.size.height/2);
    [_spinner setHidesWhenStopped:YES];
    [self.view addSubview:_spinner];
}

// Освобождаем элементы при выгрузке.
- (void)viewDidUnload
{
    [super viewDidUnload];
    [_searchBar release];  _searchBar = nil;
    [_tableView release];  _tableView = nil;
    [_spinner release];    _spinner = nil;
}

// ----------------------------------------------------------------
//  Отправка запроса к прокси (VKVideoBridge)
// ----------------------------------------------------------------
- (void)performSearchWithQuery:(NSString *)query
{
    // Отменяем предыдущее незавершённое соединение.
    [_connection cancel];
    [_connection release];
    _connection = nil;
    [_receivedData setLength:0];

    // Формируем URL: http://<host>:8080/api/search?q=<query>
    // Кодируем строку запроса для URL (проценто-кодирование).
    NSString *encodedQuery = (NSString *)
        CFURLCreateStringByAddingPercentEscapes(
            NULL,
            (CFStringRef)query,
            NULL,
            (CFStringRef)@"!*'();:@&=+$,/?%#[]",
            kCFStringEncodingUTF8);
    NSString *urlString = [NSString stringWithFormat:@"%@/api/search?q=%@",
                           self.serverBaseURL, encodedQuery];
    [encodedQuery release]; // CFRelease — освобождаем

    NSURL *url = [NSURL URLWithString:urlString];

    // Собираем запрос.
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setTimeoutInterval:15.0];
    [request setCachePolicy:NSURLRequestReloadIgnoringLocalCacheData];

    // Показываем индикатор.
    [_spinner startAnimating];

    // Начинаем асинхронную загрузку.
    _connection = [[NSURLConnection alloc] initWithRequest:request
                                                  delegate:self
                                          startImmediately:YES];
}

// ----------------------------------------------------------------
//  NSURLConnectionDataDelegate — приём данных JSON
// ----------------------------------------------------------------
- (void)connection:(NSURLConnection *)connection
    didReceiveResponse:(NSURLResponse *)response
{
    // Новый ответ — сбрасываем буфер.
    [_receivedData setLength:0];
}

- (void)connection:(NSURLConnection *)connection
    didReceiveData:(NSData *)data
{
    // Дописываем полученные байты в буфер.
    [_receivedData appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    // Загрузка завершена. Скрываем индикатор.
    [_spinner stopAnimating];

    // Освобождаем соединение.
    [_connection release];
    _connection = nil;

    // Парсим JSON.
    NSError *error = nil;
    id json = [NSJSONSerialization JSONObjectWithData:_receivedData
                                              options:0
                                                error:&error];

    // Обновляем массив данных.
    [_items removeAllObjects];

    if (json && [json isKindOfClass:[NSArray class]]) {
        // Ответ — массив объектов.
        for (NSDictionary *dict in (NSArray *)json) {
            if (![dict isKindOfClass:[NSDictionary class]]) continue;

            VideoItem *item = [[VideoItem alloc] init];
            item.title    = [dict objectForKey:@"title"];
            item.duration = [dict objectForKey:@"duration"];
            item.photo    = [dict objectForKey:@"photo"];
            item.url      = [dict objectForKey:@"url"];

            // Защита: не добавляем пустые элементы без ссылки.
            if (item.url && [item.url length] > 0) {
                [_items addObject:item];
            }
            [item release];
        }
    }

    // Обновляем таблицу.
    [_tableView reloadData];
}

- (void)connection:(NSURLConnection *)connection
    didFailWithError:(NSError *)error
{
    // Ошибка сети.
    [_spinner stopAnimating];
    [_connection release];
    _connection = nil;

    // Показываем системный алерт об ошибке.
    UIAlertView *alert = [[UIAlertView alloc]
        initWithTitle:@"Ошибка"
              message:@"Не удалось выполнить запрос. Проверьте, что прокси-сервер запущен."
             delegate:nil
    cancelButtonTitle:@"OK"
    otherButtonTitles:nil];
    [alert show];
    [alert release];
}

// ----------------------------------------------------------------
//  UITableViewDataSource
// ----------------------------------------------------------------
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView
    numberOfRowsInSection:(NSInteger)section
{
    return [_items count];
}

// Высота ячейки.
- (CGFloat)tableView:(UITableView *)tableView
    heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 80.0f;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
    cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"VideoCell";

    // Переиспользуем ячейки.
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc]
            initWithStyle:UITableViewCellStyleSubtitle
          reuseIdentifier:CellIdentifier] autorelease];

        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;

        // Глянцевая скругленная подложка контента.
        // Цвет фона подложки делаем почти белым с лёгкой прозрачностью.
        cell.contentView.backgroundColor = [UIColor clearColor];
        cell.backgroundColor = [UIColor clearColor];

        // Общая подсветка при выборе — классическая голубая iOS.
        cell.selectionStyle = UITableViewCellSelectionStyleBlue;
    }

    VideoItem *item = [_items objectAtIndex:indexPath.row];

    // --- Настройка текста ---
    cell.textLabel.text = item.title;
    cell.textLabel.numberOfLines = 2;               // до 2 строк
    cell.textLabel.lineBreakMode = UILineBreakModeTailTruncation;
    cell.textLabel.font = [UIFont boldSystemFontOfSize:14.0f];
    cell.textLabel.textColor = [UIColor whiteColor]; // читаемо на тёмном фоне

    // --- Длительность (серым мелким шрифтом) ---
    cell.detailTextLabel.text = item.duration;
    cell.detailTextLabel.font = [UIFont systemFontOfSize:12.0f];
    cell.detailTextLabel.textColor = [UIColor colorWithWhite:0.85f alpha:1.0f];

    // --- Превью-картинка (квадрат слева) ---
    cell.imageView.contentMode = UIViewContentModeScaleAspectFill;
    [self loadThumbnailForCell:cell item:item];

    return cell;
}

// ----------------------------------------------------------------
//  Асинхронная загрузка превью-картинки
// ----------------------------------------------------------------
- (void)loadThumbnailForCell:(UITableViewCell *)cell item:(VideoItem *)item
{
    if (!item.photo || [item.photo length] == 0) {
        return;
    }

    // --- Проверяем кэш ---
    UIImage *cached = [[ViewController thumbnailCache] objectForKey:item.photo];
    if (cached) {
        cell.imageView.image = cached;
        return;
    }

    // Ставим «заглушку» пока картинка грузится.
    // Рисуем серый прямоугольник программно (без внешних ресурсов).
    static UIImage *placeholder = nil;
    if (placeholder == nil) {
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(60, 60), NO, 0);
        CGContextRef ctx = UIGraphicsGetCurrentContext();
        CGContextSetFillColorWithColor(ctx,
            [UIColor colorWithWhite:0.35f alpha:1.0f].CGColor);
        CGContextFillRect(ctx, CGRectMake(0, 0, 60, 60));
        placeholder = [UIGraphicsGetImageFromCurrentImageContext() retain];
        UIGraphicsEndImageContext();
    }
    cell.imageView.image = placeholder;

    // --- Асинхронная загрузка по URL на фоновом потоке (GCD) ---
    NSString *photoURL = item.photo;
    dispatch_queue_t bgQueue = dispatch_get_global_queue(
        DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(bgQueue, ^{
        NSData *data = [NSData dataWithContentsOfURL:
            [NSURL URLWithString:photoURL]];
        if (data) {
            UIImage *img = [UIImage imageWithData:data];
            if (img) {
                // Сохраняем в кэш.
                [[ViewController thumbnailCache] setObject:img
                                                    forKey:photoURL];
                // Возвращаемся на главный поток, чтобы обновить UI.
                dispatch_async(dispatch_get_main_queue(), ^{
                    cell.imageView.image = img;
                });
            }
        }
    });
}

// ----------------------------------------------------------------
//  UITableViewDelegate — обработка нажатия → воспроизведение
// ----------------------------------------------------------------
- (void)tableView:(UITableView *)tableView
    didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    VideoItem *item = [_items objectAtIndex:indexPath.row];

    // --- Берём прямую ссылку на видео из поля url ---
    NSString *mediaURL = item.url;
    if (!mediaURL || [mediaURL length] == 0) {
        return;
    }

    // Резолвим возможный роут прокси:
    // Если url начинается с "/stream?url=..." то делаем полный URL прокси.
    if ([mediaURL hasPrefix:@"/"]) {
        mediaURL = [NSString stringWithFormat:@"%@%@", self.serverBaseURL, mediaURL];
    }

    NSURL *url = [NSURL URLWithString:mediaURL];

    // --- Создаём нативный плеер iOS 6 ---
    // MPMoviePlayerViewController — полноэкранный системный плеер
    // со встроенными контроллерами перемотки, громкости и кнопкой «Готово».
    MPMoviePlayerViewController *movieVC =
        [[MPMoviePlayerViewController alloc] initWithContentURL:url];

    // --- Подписка на уведомление о завершении ---
    // Наблюдатель убирается в обработчике.
    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(moviePlayerDidExit:)
               name:MPMoviePlayerDidExitFullscreenNotification
             object:movieVC.moviePlayer];

    // --- Разворачиваем на весь экран ---
    [self presentViewController:movieVC animated:YES completion:NULL];

    // Запуск воспроизведения.
    [movieVC.moviePlayer play];
    [movieVC release];
}

// Обработчик выхода из полноэкранного режима плеера.
- (void)moviePlayerDidExit:(NSNotification *)notification
{
    // Снимаем наблюдателя, чтобы не было утечки.
    [[NSNotificationCenter defaultCenter]
        removeObserver:self
                  name:MPMoviePlayerDidExitFullscreenNotification
                object:[notification object]];
}

// ----------------------------------------------------------------
//  UISearchBarDelegate
// ----------------------------------------------------------------
// Нажатие кнопки «Поиск» на клавиатуре.
- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar
{
    [searchBar resignFirstResponder]; // убираем клавиатуру
    [self performSearchWithQuery:searchBar.text];
}

// Поддержка поворота экрана (iOS 6: все ориентации).
- (BOOL)shouldAutorotate
{
    return YES;
}

- (NSUInteger)supportedInterfaceOrientations
{
    // В iOS 6 используется битовая маска UIInterfaceOrientationMask.
    // Для совместимости возвращаем все ориентации кроме перевёрнутой.
    return UIInterfaceOrientationMaskAllButUpsideDown;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
    // Метод из iOS 5, оставлен для совместимости (не помешает в iOS 6).
    return YES;
}

@end
