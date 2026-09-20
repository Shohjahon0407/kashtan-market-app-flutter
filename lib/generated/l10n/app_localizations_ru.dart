// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get addressLocationUnavailable =>
      'Не удалось определить местоположение. Проверьте GPS или выберите точку на карте.';

  @override
  String get appName => 'Besh Kashtan';

  @override
  String get commonRetry => 'Повторить';

  @override
  String get commonFieldRequired => 'Заполните это поле';

  @override
  String get commonCancel => 'Отмена';

  @override
  String get commonSave => 'Сохранить';

  @override
  String get commonContinue => 'Продолжить';

  @override
  String get commonClose => 'Закрыть';

  @override
  String get commonSearch => 'Поиск';

  @override
  String get commonAll => 'Все';

  @override
  String get commonLoading => 'Загрузка...';

  @override
  String get commonEmpty => 'Пока пусто';

  @override
  String get commonYes => 'Да';

  @override
  String get commonNo => 'Нет';

  @override
  String get offlineBanner => 'Офлайн режим';

  @override
  String get connectionServerUnavailable => 'Не удалось подключиться к серверу';

  @override
  String get offlineStaleData => 'устаревшие данные';

  @override
  String get errorNetwork =>
      'Нет подключения к интернету. Проверьте соединение.';

  @override
  String get errorServer => 'Ошибка сервера. Попробуйте позже.';

  @override
  String get errorUnknown => 'Произошла непредвиденная ошибка.';

  @override
  String get errorSessionExpired => 'Сессия истекла. Войдите заново.';

  @override
  String get errorThrottled => 'Слишком много попыток. Подождите немного.';

  @override
  String get errorNotFound => 'Не найдено.';

  @override
  String get errorForbidden => 'Нет доступа к этому действию.';

  @override
  String get authPhoneTitle => 'Ваш номер телефона';

  @override
  String get authPhoneSubtitle => 'Введите номер для входа';

  @override
  String get authRequiredTitle => 'Сначала войдите в приложение';

  @override
  String get authRequiredSubtitle => 'Введите номер телефона, чтобы продолжить';

  @override
  String get authPhoneHint => '90 123 45 67';

  @override
  String get authSendCode => 'Получить код';

  @override
  String get authOtpTitle => 'Код подтверждения';

  @override
  String authOtpSubtitle(String phone) {
    return 'Введите 6-значный код, отправленный на $phone';
  }

  @override
  String get authOtpResend => 'Отправить код повторно';

  @override
  String authOtpResendIn(int seconds) {
    return 'Повторная отправка через $seconds сек.';
  }

  @override
  String authOtpExpiresIn(int seconds) {
    return 'Код истечёт через $seconds сек.';
  }

  @override
  String get authConsentPrefix => 'Продолжая, вы соглашаетесь с ';

  @override
  String get authConsentTerms => 'Условиями использования';

  @override
  String get authConsentAnd => ' и ';

  @override
  String get authConsentPrivacy => 'Политикой конфиденциальности';

  @override
  String get authConsentSuffix => '.';

  @override
  String get authLogout => 'Выйти';

  @override
  String get authErrorOtpCooldown =>
      'Подождите немного перед повторной отправкой.';

  @override
  String get authErrorOtpHourLimit => 'Не более 5 кодов в час.';

  @override
  String get authErrorOtpInvalid => 'Неверный код. Проверьте ещё раз.';

  @override
  String get authErrorOtpExpired =>
      'Срок действия кода истёк. Запросите новый.';

  @override
  String get authErrorOtpAttempts => 'Попытки исчерпаны. Запросите новый код.';

  @override
  String get authErrorSmsFailed => 'SMS не отправлено. Попробуйте позже.';

  @override
  String get authErrorInvalidPhone => 'Неверный номер телефона.';

  @override
  String get onboardingNameTitle => 'Ваше имя';

  @override
  String get onboardingNameSubtitle => 'Будет показано в заказах';

  @override
  String get onboardingLocationTitle => 'Ваш адрес';

  @override
  String get onboardingLocationSubtitle =>
      'Нужен для расчёта стоимости доставки';

  @override
  String get storeGrocery => 'Продукты';

  @override
  String get storeHousehold => 'Товары для дома';

  @override
  String get storeRestaurant => 'Ресторан';

  @override
  String get storeShashlik => 'Шашлык';

  @override
  String get storeMeat => 'Мясные продукты';

  @override
  String get cartTitle => 'Корзина';

  @override
  String get cartEmpty => 'Корзина пуста';

  @override
  String get cartEmptyStore => 'корзина пуста';

  @override
  String get cartMainSubtitle =>
      'Каждый магазин доставляет и оформляет заказ отдельно';

  @override
  String cartItemsCount(int count) {
    return '$count шт.';
  }

  @override
  String get cartCheckout => 'Оформить заказ';

  @override
  String get cartTotal => 'Итого';

  @override
  String get cartSubtotal => 'Товары';

  @override
  String get cartDeliveryFee => 'Доставка';

  @override
  String get ordersTitle => 'Заказы';

  @override
  String get ordersEmpty => 'Пока нет заказов';

  @override
  String get profileTitle => 'Профиль';

  @override
  String get profilePrivacyPolicy => 'Политика конфиденциальности';

  @override
  String profileAppVersion(String version) {
    return 'Версия $version';
  }

  @override
  String get profileDeleteAccount => 'Удалить аккаунт';

  @override
  String get profileDeleteAccountTitle => 'Полное удаление аккаунта';

  @override
  String get profileDeleteAccountWarning =>
      'Ваше имя, номер телефона, адреса, корзина, избранное и отзывы будут удалены. Это действие необратимо. Для подтверждения мы отправим SMS-код.';

  @override
  String get profileDeleteAccountSendCode => 'Отправить код';

  @override
  String get profileDeleteAccountCodeHint =>
      'Введите код, отправленный на ваш телефон. После подтверждения аккаунт будет удалён немедленно.';

  @override
  String get profileDeleteAccountConfirm => 'Удалить навсегда';

  @override
  String get profileLanguage => 'Язык';

  @override
  String get profileAddresses => 'Адреса';

  @override
  String get profileNotifications => 'Уведомления';

  @override
  String get profileSupport => 'Помощь';

  @override
  String get languageUz => 'O\'zbekcha';

  @override
  String get languageUzCyrl => 'Ўзбекча';

  @override
  String get languageRu => 'Русский';

  @override
  String get devPlaygroundTitle => 'Проверка API';

  @override
  String get devPlaygroundSubtitle => 'Ответ GET /home/ и переключение языка';

  @override
  String get devFetch => 'Отправить запрос';

  @override
  String get devApiLang => 'Отправлено на сервер lang';

  @override
  String get devScript => 'Письменность';

  @override
  String get devResponseSize => 'Размер ответа';

  @override
  String devItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count элементов',
      few: '$count элемента',
      one: '1 элемент',
      zero: 'Нет элементов',
    );
    return '$_temp0';
  }

  @override
  String errorThrottledSeconds(int seconds) {
    return 'Слишком много попыток. Повторите через $seconds сек.';
  }

  @override
  String get authChangeNumber => 'Изменить номер';

  @override
  String get authOtpHint => '6-значный код из SMS';

  @override
  String get authOtpExpired => 'Срок действия кода истёк';

  @override
  String get authPhoneInvalidOperator => 'Такого кода оператора не существует.';

  @override
  String get homeGreeting => 'Добро пожаловать!';

  @override
  String get homePlaceholder =>
      'Главная страница будет построена на следующем этапе.';

  @override
  String get homeDeliverTitle => 'Доставим к вам домой';

  @override
  String get homeAddressNotSelected => 'Адрес не выбран';

  @override
  String get homeStoresTitle => 'Магазины';

  @override
  String get homeRequestText => 'Текст';

  @override
  String get homeRequestImage => 'Фото';

  @override
  String get homeRequestVoice => 'Голос';

  @override
  String get searchHint => 'Найти товар';

  @override
  String get searchStartTyping => 'Начните вводить запрос';

  @override
  String get searchEmpty => 'Ничего не найдено';

  @override
  String searchResultsCount(int count) {
    return 'Результаты $count';
  }

  @override
  String get searchMissingTitle => 'Не нашли нужный товар?';

  @override
  String get searchMissingSubtitle =>
      'Оставьте заявку текстом, фотографией или голосом';

  @override
  String get storeComingSoon => 'Этот раздел будет построен на следующем этапе';

  @override
  String get profileSheetTitle => 'Профиль';

  @override
  String get profileUnnamed => 'Пользователь';

  @override
  String get profileChooseStore => 'Выберите магазин';

  @override
  String get notificationsComingSoon => 'Уведомления скоро появятся';

  @override
  String get commonDelete => 'Удалить';

  @override
  String get commonEdit => 'Изменить';

  @override
  String get commonDone => 'Готово';

  @override
  String get commonAdd => 'Добавить';

  @override
  String get navHome => 'Главная';

  @override
  String get navVideos => 'Видео';

  @override
  String get navProducts => 'Товары';

  @override
  String get navFavorites => 'Избранное';

  @override
  String get navCart => 'Корзина';

  @override
  String get navOrders => 'Заказы';

  @override
  String get catalogTitle => 'Товары';

  @override
  String catalogProductVarietyCount(int count) {
    return '$count товаров';
  }

  @override
  String get catalogAllProducts => 'Все товары';

  @override
  String get catalogEmpty => 'В этом магазине пока нет товаров';

  @override
  String get catalogSearchHint => 'Поиск в этом магазине';

  @override
  String get catalogCategoryFilter => 'Категории';

  @override
  String get householdSectionHomeTools => 'Дом, ремонт и инструменты';

  @override
  String get householdSectionTechTransport => 'Техника и транспорт';

  @override
  String get householdSectionKitchenLiving => 'Кухня и хозяйство';

  @override
  String get householdSectionClothingCare => 'Одежда и уход';

  @override
  String get householdSectionKidsHobbyOther => 'Дети, хобби и другое';

  @override
  String get catalogFeatured => 'Рекомендуем';

  @override
  String get catalogDiscounted => 'Скидки';

  @override
  String get catalogPopular => 'Популярное';

  @override
  String get catalogNew => 'Новинки';

  @override
  String get favoritesTitle => 'Избранное';

  @override
  String get favoritesEmpty => 'В этом магазине нет избранных товаров';

  @override
  String get productUnavailable => 'Сейчас недоступно для покупки';

  @override
  String get productSoldOut => 'Закончилось';

  @override
  String get productSoldOutDetail => 'Это блюдо сейчас закончилось.';

  @override
  String get paymePayButton => 'Оплатить через Payme';

  @override
  String get paymeCheckPayment => 'Проверить оплату';

  @override
  String get paymeUnavailable => 'Оплата через Payme временно недоступна';

  @override
  String get paymePaymentPaid => 'Оплата выполнена';

  @override
  String get paymePaymentPending =>
      'Оплата ещё не подтверждена. Проверьте чуть позже';

  @override
  String get paymePaymentFailed => 'Оплата не прошла. Попробуйте ещё раз';

  @override
  String get paymePaymentCancelled => 'Оплата отменена';

  @override
  String get paymeLinkOpenFailed => 'Не удалось открыть страницу оплаты';

  @override
  String get productInReview => 'На проверке';

  @override
  String get productInReviewDetail =>
      'Этот товар на проверке. Пока недоступен для покупки.';

  @override
  String get reportProductButton => 'Неверный товар';

  @override
  String get reportProductConfirmTitle => 'Отправить администратору?';

  @override
  String get reportProductConfirmBody =>
      'Товар с неверным фото или категорией будет отправлен на проверку и временно снят с продажи до исправления.';

  @override
  String get reportProductConfirmAction => 'Отправить';

  @override
  String get reportProductSuccess => 'Отправлено. Товар взят на проверку.';

  @override
  String get productChooseOptions => 'Выбрать';

  @override
  String get productAddToCart => 'Добавить в корзину';

  @override
  String get productBuy => 'Купить';

  @override
  String get productAddShort => 'В корзину';

  @override
  String get productGoToCart => 'Перейти в корзину';

  @override
  String get productAdded => 'Товар добавлен в корзину';

  @override
  String productImageCount(int count) {
    return 'Изображений: $count';
  }

  @override
  String get productDescription => 'Описание';

  @override
  String get productRelated => 'Похожие товары';

  @override
  String get productVariant => 'Выберите вариант';

  @override
  String get productAddons => 'Дополнения';

  @override
  String get productRequired => 'Обязательно';

  @override
  String get productChooseMin => 'Выберите не меньше указанного количества';

  @override
  String get productChooseMax => 'Достигнут предел выбора';

  @override
  String get productNote => 'Комментарий';

  @override
  String get productNoteHint => 'Например, без лука';

  @override
  String get cartClear => 'Очистить корзину';

  @override
  String get cartClearConfirm => 'Удалить все товары из корзины?';

  @override
  String get cartEmptyHint => 'Добавьте товары из каталога';

  @override
  String get cartVariant => 'Вариант';

  @override
  String get cartAddons => 'Дополнения';

  @override
  String get checkoutTitle => 'Оформление заказа';

  @override
  String get checkoutFulfillment => 'Способ получения';

  @override
  String get checkoutDelivery => 'Доставка';

  @override
  String get checkoutPickup => 'Самовывоз';

  @override
  String get checkoutAddress => 'Адрес доставки';

  @override
  String get checkoutSelectAddress => 'Выберите адрес';

  @override
  String get checkoutAddAddress => 'Новый адрес';

  @override
  String get checkoutLocationPromptTitle => 'Выберите место доставки';

  @override
  String get checkoutLocationPromptHint =>
      'Для каждого заказа добавьте новое местоположение или заново выберите сохранённый адрес.';

  @override
  String get checkoutAddNewLocation => 'Добавить новое местоположение';

  @override
  String get checkoutSavedLocations => 'Сохранённые адреса';

  @override
  String get checkoutChooseOrChangeAddress => 'Выбрать или изменить адрес';

  @override
  String get checkoutBranch => 'Филиал самовывоза';

  @override
  String get checkoutSelectBranch => 'Выберите филиал';

  @override
  String get checkoutMixedStorePickup =>
      'Товары в корзине из разных физических магазинов. Самовывоз недоступен; выберите доставку или разделите корзину.';

  @override
  String get checkoutEstimateUnavailable =>
      'Доставка по этому адресу недоступна';

  @override
  String get checkoutDistance => 'Расстояние';

  @override
  String get checkoutPaymentMethod => 'Способ оплаты';

  @override
  String get checkoutPayPayme => 'Payme';

  @override
  String get checkoutPayCashCourier => 'Наличными курьеру';

  @override
  String get checkoutPayCashStore => 'Наличными в магазине';

  @override
  String get checkoutNote => 'Комментарий к заказу';

  @override
  String get checkoutSubmit => 'Подтвердить заказ';

  @override
  String get checkoutEmptyCart => 'Корзина пуста';

  @override
  String get addressTitle => 'Название адреса';

  @override
  String get addressTitleOptional => 'Название адреса (необязательно)';

  @override
  String get addressUnnamed => 'Точка на карте';

  @override
  String get addressDistrict => 'Район';

  @override
  String get addressNeighborhood => 'Махалля';

  @override
  String get addressStreet => 'Улица';

  @override
  String get addressHouse => 'Дом';

  @override
  String get addressApartment => 'Квартира';

  @override
  String get addressLandmark => 'Ориентир';

  @override
  String get addressSetDefault => 'Сделать основным';

  @override
  String get addressChooseOnMap => 'Выберите точку на карте';

  @override
  String get addressCurrentLocation => 'Определить моё местоположение';

  @override
  String get mapZoomIn => 'Увеличить карту';

  @override
  String get mapZoomOut => 'Уменьшить карту';

  @override
  String get addressLocationDenied =>
      'Доступ к геолокации не предоставлен. Выберите точку на карте вручную.';

  @override
  String get addressLocationRequired => 'Выберите точку на карте';

  @override
  String get addressesEmpty => 'Адреса пока не добавлены';

  @override
  String get addressDefaultLabel => 'Основной';

  @override
  String get ordersToday => 'Сегодня';

  @override
  String get ordersHistory => 'История';

  @override
  String get ordersTodayEmpty => 'Сегодня заказов нет';

  @override
  String get ordersHistoryEmpty => 'История заказов пуста';

  @override
  String ordersMoreProducts(Object count) {
    return '+$count товаров';
  }

  @override
  String get ordersLoadMore => 'Показать ещё';

  @override
  String get orderItems => 'Товары';

  @override
  String get orderAddress => 'Адрес';

  @override
  String get orderPickupBranch => 'Филиал самовывоза';

  @override
  String get orderCourier => 'Курьер';

  @override
  String get orderCancel => 'Отменить заказ';

  @override
  String get orderCancelConfirm => 'Отменить заказ?';

  @override
  String get unsupportedStoreTitle => 'Неизвестный магазин';

  @override
  String get unsupportedStoreMessage =>
      'Этот тип магазина не поддерживается приложением.';

  @override
  String get unsupportedStoreBack => 'Вернуться на главную';

  @override
  String get routeNotFoundTitle => 'Страница не найдена';

  @override
  String get routeNotFoundMessage =>
      'Ссылка устарела или требует новую версию приложения.';

  @override
  String get supportCenterTitle => 'Помощь и обращения';

  @override
  String get supportFormIntro =>
      'Не нашли нужный товар, есть предложение или вопрос? Отправьте текст, изображение или голосовое сообщение.';

  @override
  String get supportMissingProductTitle => 'Заказать отсутствующий товар';

  @override
  String get supportMissingProductSubtitle =>
      'Сообщите нам о товаре, которого нет в приложении';

  @override
  String get supportMissingProductHint => 'Подробно опишите нужный товар';

  @override
  String get supportSuggestionTitle => 'Отправить предложение';

  @override
  String get supportSuggestionHint => 'Напишите, как можно улучшить приложение';

  @override
  String get supportHelpTitle => 'Получить помощь';

  @override
  String get supportHelpHint => 'Опишите проблему или вопрос';

  @override
  String get supportStoreLabel => 'Магазин';

  @override
  String get supportMessageLabel => 'Сообщение';

  @override
  String get supportAddImage => 'Добавить фото';

  @override
  String get supportTakePhoto => 'Сделать фото';

  @override
  String get supportChooseGallery => 'Выбрать из галереи';

  @override
  String get supportRecordVoice => 'Записать голос';

  @override
  String get supportStopRecording => 'Остановить';

  @override
  String get supportRecording => 'Идёт запись';

  @override
  String get supportMicrophoneDenied =>
      'Нет доступа к микрофону. Можно отправить текст или изображение.';

  @override
  String get supportRecordingFailed =>
      'Не удалось записать голос. Попробуйте ещё раз.';

  @override
  String get supportMediaReadFailed => 'Не удалось прочитать файл.';

  @override
  String get supportImageTooLarge =>
      'Размер изображения не должен превышать 8 МБ.';

  @override
  String get supportVoiceTooLarge =>
      'Размер голосового сообщения не должен превышать 10 МБ.';

  @override
  String get supportAtLeastOne =>
      'Отправьте хотя бы текст, изображение или голосовое сообщение.';

  @override
  String get supportSelectStore =>
      'Выберите магазин для отсутствующего товара.';

  @override
  String get supportSend => 'Отправить';

  @override
  String get supportSending => 'Отправка...';

  @override
  String get supportSent => 'Обращение отправлено';

  @override
  String get supportHistory => 'История обращений';

  @override
  String get supportHistoryEmpty => 'Вы ещё не отправляли обращения';

  @override
  String get supportStatusOpen => 'Новое';

  @override
  String get supportStatusInProgress => 'На рассмотрении';

  @override
  String get supportStatusClosed => 'Завершено';

  @override
  String get supportContactMissing => 'Имя и фамилия не указаны';

  @override
  String get supportContactNeededTitle => 'Контактные данные';

  @override
  String get supportContactNeededSubtitle =>
      'Укажите имя и фамилию, чтобы администратор мог с вами связаться.';

  @override
  String get supportFirstName => 'Имя';

  @override
  String get supportLastName => 'Фамилия';

  @override
  String get supportRequestProductAction => 'Заказать этот товар';

  @override
  String get supportRemoveAttachment => 'Удалить вложение';

  @override
  String get supportImageAttached => 'Изображение прикреплено';

  @override
  String get supportVoiceAttached => 'Голосовое сообщение прикреплено';

  @override
  String get supportOneAttachment => '1 файл';

  @override
  String get supportChooseStoreQuestion => 'Из какого магазина?';

  @override
  String get supportResponseHint => 'Оператор рассмотрит ваше обращение';

  @override
  String get videoFeedTitle => 'Видеолента';

  @override
  String get videoProductView => 'Посмотреть товар';

  @override
  String get videoCommentsTitle => 'Комментарии';

  @override
  String get videoCommentHint => 'Напишите комментарий...';

  @override
  String get videoCommentSend => 'Отправить';

  @override
  String get videoCommentsEmpty => 'Комментариев пока нет';

  @override
  String get videoLoadError => 'Не удалось загрузить видео.';

  @override
  String get videoLike => 'Нравится';

  @override
  String get videoUnmute => 'Включить звук';

  @override
  String get videoMute => 'Выключить звук';

  @override
  String get videoGoToStore => 'Перейти в магазин';

  @override
  String get videoProductsTitle => 'Товары для вас';

  @override
  String get videoSeeAllProducts => 'Посмотреть все';

  @override
  String get videoProductsLoadError => 'Не удалось загрузить товары.';

  @override
  String get videoYou => 'Вы';

  @override
  String get orderSearchingCourier => 'Ищем курьера';

  @override
  String get orderSearchingSubtitle =>
      'Ищем ближайшего курьера для доставки вашего заказа';

  @override
  String orderWaitingElapsed(Object elapsed) {
    return 'Ожидание: $elapsed';
  }

  @override
  String get orderCourierAccepted => 'Курьер принял заказ';

  @override
  String get orderCourierAcceptedSubtitle => 'Ваш заказ готовится к доставке';

  @override
  String get orderCourierOnWay => 'Курьер в пути';

  @override
  String get orderCourierOnWaySubtitle =>
      'Ваш заказ направляется к вашему адресу';

  @override
  String get orderStatusAccepted => 'Принят';

  @override
  String get orderStatusDelivering => 'Доставляется';

  @override
  String get orderStatusDelivered => 'Доставлен';

  @override
  String get orderStatusCancelled => 'Отменён';

  @override
  String get orderStatusProcessing => 'В обработке';

  @override
  String get orderDeliveredSubtitle => 'Ваш заказ успешно доставлен';

  @override
  String get orderEstimatedArrival => 'Ожидаемое прибытие';

  @override
  String orderArrivesInMinutes(Object minutes) {
    return 'В течение $minutes мин.';
  }

  @override
  String get orderCourierNote => 'Комментарий курьера';

  @override
  String get orderCallCourier => 'Позвонить';

  @override
  String get orderCopyPhone => 'Скопировать номер';

  @override
  String get orderPhoneCopied => 'Номер телефона скопирован';

  @override
  String get orderLiveTracking => 'Отслеживание';

  @override
  String orderLocationUpdated(Object seconds) {
    return 'Геопозиция обновлена $seconds сек. назад';
  }

  @override
  String get orderLocationDelayed => 'Обновление геопозиции задерживается';

  @override
  String get orderLocationUnavailable =>
      'Геопозиция курьера временно недоступна';

  @override
  String get orderRouteUnavailable =>
      'Маршрут недоступен. Показана текущая позиция курьера.';

  @override
  String orderMapEta(Object minutes) {
    return 'По карте: $minutes мин.';
  }

  @override
  String get orderVehicle => 'Транспорт';

  @override
  String get notificationsTitle => 'Уведомления';

  @override
  String get notificationsEmpty => 'Уведомлений пока нет';

  @override
  String get notificationsReadAll => 'Прочитать все';

  @override
  String get notificationOpen => 'Открыть';

  @override
  String get productReviewsTitle => 'Оценки и отзывы';

  @override
  String get productReviewsEmpty => 'Отзывов пока нет';

  @override
  String get productReviewWrite => 'Оценить и написать отзыв';

  @override
  String get productReviewPurchasedOnly =>
      'Отзыв можно оставить после доставки товара';

  @override
  String get productReviewAlreadyWritten =>
      'Вы уже оставили отзыв на этот товар';

  @override
  String get productReviewCommentHint => 'Ваше мнение о товаре';

  @override
  String get productReviewSubmit => 'Отправить';

  @override
  String get productReviewSuccess => 'Ваша оценка и отзыв отправлены';

  @override
  String get orderDeliveryWithinOneDay => 'Доставка в течение 1 дня';

  @override
  String get orderDeliveryWithinTwoDays => 'Доставка в течение 2 дней';

  @override
  String get ugcPolicyTitle => 'Правила сообщества';

  @override
  String get ugcPolicySummary =>
      'Перед публикацией примите условия использования и правила сообщества. Оскорбления, спам и неприемлемый контент запрещены.';

  @override
  String get ugcPolicyConsent =>
      'Я прочитал(а) и принимаю условия использования и правила сообщества';

  @override
  String get ugcAccept => 'Принять';

  @override
  String get ugcTerms => 'Условия использования';

  @override
  String get ugcCommunityGuidelines => 'Правила сообщества';

  @override
  String get ugcContentActions => 'Действия с контентом';

  @override
  String get ugcReport => 'Пожаловаться';

  @override
  String get ugcReportTitle => 'Выберите причину жалобы';

  @override
  String get ugcReportSubmit => 'Отправить жалобу';

  @override
  String get ugcReportSent => 'Жалоба отправлена';

  @override
  String get ugcReportDetails => 'Дополнительная информация (необязательно)';

  @override
  String get ugcReasonSpam => 'Спам';

  @override
  String get ugcReasonAbuse => 'Оскорбление или травля';

  @override
  String get ugcReasonInappropriate => 'Неприемлемый контент';

  @override
  String get ugcReasonOther => 'Другая причина';

  @override
  String get ugcBlockUser => 'Заблокировать пользователя';

  @override
  String get ugcBlock => 'Заблокировать';

  @override
  String get ugcUnblock => 'Разблокировать';

  @override
  String get ugcUserBlocked =>
      'Пользователь заблокирован. Его комментарии больше не отображаются.';

  @override
  String get ugcBlockedUsers => 'Заблокированные пользователи';

  @override
  String get ugcBlockedUsersEmpty => 'Заблокированных пользователей нет';

  @override
  String ugcBlockConfirmation(String name) {
    return 'Заблокировать пользователя $name? Его публичные комментарии и отзывы больше не будут вам видны.';
  }
}
