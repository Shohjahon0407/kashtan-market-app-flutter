// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get shashlikCartUpdated => 'Корзина обновлена';

  @override
  String get shashlikSaveQuantity => 'Сохранить количество';

  @override
  String get shashlikChooseQuantity => 'Выбрать количество';

  @override
  String get shashlikPieceUnit => 'шт.';

  @override
  String get shashlikKilogramUnit => 'кг';

  @override
  String cartItemsInCartTitle(int count) {
    return '$count товар(ов) в корзине';
  }

  @override
  String get cartCheckoutAction => 'Оформить';

  @override
  String get cartOrderSummaryTitle => 'Ваш заказ';

  @override
  String cartItemsLine(int count) {
    return '$count товар(ов)';
  }

  @override
  String get cartDiscount => 'Скидка';

  @override
  String cartPerUnit(String price) {
    return '$price/шт';
  }

  @override
  String get deliveryEstimateTitle => 'Ориентировочный срок доставки';

  @override
  String get deliveryEstimateAvailabilityHint =>
      'Уточняется с учётом наличия товаров';

  @override
  String cartMinimumHint(String amount) {
    return 'Минимальный заказ для доставки — ещё $amount';
  }

  @override
  String get checkoutReceiveMethod => 'Способ получения';

  @override
  String get checkoutCourier => 'Курьер';

  @override
  String get checkoutPickupFree => 'бесплатно';

  @override
  String get checkoutChooseAddressHint => 'выберите адрес';

  @override
  String get checkoutChangeOther => 'Выбрать другой';

  @override
  String get checkoutChooseAddressAction => 'Выбрать адрес';

  @override
  String get checkoutDeliveryAddressLabel => 'Адрес доставки';

  @override
  String get checkoutPickupStoreLabel => 'Самовывоз из магазина';

  @override
  String get checkoutQuoteCalculating => 'Рассчитываем стоимость доставки…';

  @override
  String get checkoutRecipient => 'Получатель';

  @override
  String get checkoutRecipientName => 'Имя';

  @override
  String get checkoutRecipientPhone => 'Номер телефона';

  @override
  String get checkoutRecipientSave => 'Сохранить';

  @override
  String get checkoutRecipientReset => 'Мне';

  @override
  String get checkoutRecipientPhoneInvalid => 'Введите корректный номер';

  @override
  String get checkoutPickupReadyHint => 'Сообщим, когда заказ будет готов';

  @override
  String get checkoutPaymentType => 'Способ оплаты';

  @override
  String get checkoutOrderSummary => 'Ваш заказ';

  @override
  String get checkoutPayOnReceive => 'Оплата при получении';

  @override
  String get checkoutPayOnReceiveCaption => 'Наличными курьеру или в магазине';

  @override
  String get checkoutPayOnlineCaption =>
      'Payme — UZCARD, HUMO, Visa, Mastercard';

  @override
  String get checkoutPayWithPayme => 'Оплатить через Payme';

  @override
  String get checkoutDeliveryFree => 'Бесплатно';

  @override
  String get checkoutTotal => 'Итого';

  @override
  String get checkoutMinimumTitle => 'Не набрана минимальная сумма заказа';

  @override
  String get cartContinueOrder => 'Продолжить оформление';

  @override
  String get cartSelectDeliveryAddress => 'Выбрать адрес доставки';

  @override
  String get cartMinimumRecommendations => 'Дополните заказ до минимума';

  @override
  String get cartAllProducts => 'Все товары';

  @override
  String get cartUpdating => 'Обновляем расчёт…';

  @override
  String get cartDeliveryUnknown =>
      'Стоимость доставки рассчитаем после выбора адреса';

  @override
  String get cartEdit => 'Редактировать корзину';

  @override
  String get cartChoosePickup => 'Выберите филиал для самовывоза';

  @override
  String get cartOrderChanged =>
      'Условия заказа изменились. Проверьте корзину.';

  @override
  String get cartProductsTitle => 'Товары';

  @override
  String get cartDeliveryNotAvailable => 'Доставка по этому адресу недоступна';

  @override
  String get cartRefreshError =>
      'Не удалось обновить корзину. Попробуйте ещё раз.';

  @override
  String get checkoutReviewTitle => 'Проверьте заказ';

  @override
  String checkoutProductsSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count товара',
      many: '$count товаров',
      few: '$count товара',
      one: '1 товар',
    );
    return '$_temp0';
  }

  @override
  String get checkoutEditCart => 'Редактировать корзину';

  @override
  String get checkoutCartChanged =>
      'Корзина изменилась. Проверьте состав и сумму и подтвердите снова.';

  @override
  String get checkoutReceiptOpen => 'Посмотреть товары';

  @override
  String get deliveryAddressTitle => 'Адрес доставки';

  @override
  String get deliveryAddressSubtitle => 'Куда доставить заказ?';

  @override
  String get deliveryAddressSavedHint =>
      'Выберите сохранённый адрес для заказа.';

  @override
  String get deliveryAddressConfirm => 'Доставить по выбранному адресу';

  @override
  String get deliveryAddressAdd => 'Добавить новый адрес';

  @override
  String get deliveryAddressAddOnMap => 'Добавить адрес на карте';

  @override
  String get deliveryAddressEmpty =>
      'Добавьте адрес доставки для этого заказа.';

  @override
  String get deliveryAddressSave => 'Сохранить адрес';

  @override
  String get deliveryAddressChange => 'Выбрать другой адрес';

  @override
  String get deliveryAddressCalculating => 'Рассчитываем стоимость доставки…';

  @override
  String get deliveryAddressGpsHint =>
      'Вы можете выбрать сохранённый адрес даже без GPS.';

  @override
  String get checkoutMinimumIncludesDelivery =>
      'Учитывается сумма товаров и стоимость доставки.';

  @override
  String get checkoutMinimumNeedsAddress =>
      'Выберите адрес, чтобы рассчитать доставку.';

  @override
  String get addressCoverageLoading => 'Загружаем данные карты…';

  @override
  String get addressRadiusLimit =>
      'Выберите точку внутри зелёного круга. Адрес за пределами зоны подтвердить нельзя.';

  @override
  String get addressAddTitle => 'Добавить новый адрес';

  @override
  String get addressEditTitle => 'Изменить адрес';

  @override
  String get addressSelectPoint => 'Укажите точку доставки';

  @override
  String get addressMapHelp => 'Как выбрать адрес?';

  @override
  String get addressMapHelpBody =>
      'Нажмите GPS или передвиньте карту, чтобы выбрать любую точку. Выберите дом или работу и оставьте курьеру ориентир или код домофона. Адрес сохранится только после подтверждения. Возможность и стоимость доставки проверяются при оформлении заказа.';

  @override
  String get addressTypeHome => 'Дом';

  @override
  String get addressTypeWork => 'Работа';

  @override
  String get addressTypeOther => 'Другое';

  @override
  String get addressTypeLabel => 'ТИП АДРЕСА';

  @override
  String get addressCourierNote =>
      'Ориентир или комментарий курьеру (необязательно)';

  @override
  String get addressCourierNoteHint =>
      'Например: ворота за магазином, код домофона 124';

  @override
  String get addressConfirmPoint => 'Подтвердить этот адрес';

  @override
  String get addressMapRetry => 'Карта не загрузилась. Повторить';

  @override
  String get categoryAdDetails => 'Подробнее';

  @override
  String get categorySearchHint => 'Поиск товаров в этой категории…';

  @override
  String get categoryRecommendationsTitle => 'Рекомендуем вам';

  @override
  String get categoryProductsTitle => 'Товары категории';

  @override
  String get categorySearchFallback =>
      'В этой категории не найдено. Результаты из других категорий Xozmak:';

  @override
  String get appUpdateTitle => 'Доступно обновление';

  @override
  String appUpdateBody(String version) {
    return 'Вышла версия $version. Обновите приложение, чтобы воспользоваться новыми возможностями и улучшениями.';
  }

  @override
  String get appUpdateDownload => 'Скачать';

  @override
  String get appUpdateLater => 'Позже';

  @override
  String get appUpdateOpenFailed =>
      'Не удалось открыть магазин приложений. Попробуйте ещё раз или обновите приложение позже.';

  @override
  String get checkoutAddressActionHint => 'Выберите, куда доставить заказ';

  @override
  String get checkoutReceiptTitle => 'Состав заказа';

  @override
  String checkoutCartCount(int count) {
    return 'Товары: $count';
  }

  @override
  String get checkoutOptional => 'Необязательно';

  @override
  String get checkoutPaymentHint => 'Выберите удобный способ';

  @override
  String get checkoutPayOnline => 'Оплата онлайн';

  @override
  String get checkoutPayOnReceipt => 'При получении';

  @override
  String get checkoutPayOnPickup => 'При самовывозе';

  @override
  String get checkoutNotePlaceholder =>
      'Например, код двери или пожелания по доставке...';

  @override
  String get checkoutNoteNoBell => 'Не звоните в дверной звонок';

  @override
  String get checkoutNoteCall => 'Позвоните по прибытии';

  @override
  String get checkoutNoteNoOnion => 'Без лука';

  @override
  String get checkoutCostBreakdown => 'Стоимость заказа';

  @override
  String get checkoutGrandTotal => 'Итого к оплате';

  @override
  String get checkoutSelectedAddress => 'Выбран';

  @override
  String get checkoutReviewHint =>
      'Проверьте адрес и заказ перед подтверждением';

  @override
  String get checkoutHelpTitle => 'Об оформлении заказа';

  @override
  String get checkoutHelpBody =>
      'Выберите адрес и способ оплаты. Зона доставки показана на карте. Заказ можно подтвердить после проверки адреса и стоимости доставки. Для самовывоза выберите подходящий филиал.';

  @override
  String get catalogImagelessPull =>
      'Потяните вверх ещё раз, чтобы увидеть товары без фото';

  @override
  String get catalogImagelessRelease => 'Отпустите';

  @override
  String get catalogImagelessShow => 'Показать товары без фото';

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
  String get offlineBanner => 'Нет интернета';

  @override
  String get connectionServerUnavailable => 'Пока не удалось подключиться';

  @override
  String get offlineStaleData => 'Сохранённые данные';

  @override
  String offlineMenuSaving(int done, int total) {
    return 'Сохраняем меню: $done/$total';
  }

  @override
  String get offlineMenuReady =>
      'Меню сохранено на телефоне · Доступно без интернета';

  @override
  String get offlineMenuPartial =>
      'Меню сохранено не полностью. Загрузка продолжится при подключении к интернету.';

  @override
  String get offlineMenuWaiting =>
      'Меню сохранится на телефоне при подключении к интернету.';

  @override
  String get errorNetwork =>
      'Не удалось подключиться к интернету. Проверьте соединение и попробуйте ещё раз.';

  @override
  String get errorNetworkSlow =>
      'Загрузка заняла слишком много времени. Проверьте интернет и попробуйте ещё раз.';

  @override
  String get errorServer =>
      'Пока не удалось выполнить действие. Попробуйте ещё раз немного позже.';

  @override
  String get errorUnknown =>
      'Не удалось выполнить действие. Попробуйте ещё раз.';

  @override
  String get errorSessionExpired =>
      'Чтобы продолжить, войдите в приложение снова.';

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
  String get meatProductLamb => 'Баранина';

  @override
  String get meatProductBeef => 'Говядина';

  @override
  String get meatProductHorse => 'Конина';

  @override
  String get meatProductQazi => 'Казы';

  @override
  String get meatProductBeefLiver => 'Говяжья печень';

  @override
  String get meatProductLambLiver => 'Баранья печень';

  @override
  String get shashlikSectionKebabs => 'Шашлыки';

  @override
  String get shashlikSectionCharcoal => 'Уголь';

  @override
  String get shashlikSectionOther => 'Другое';

  @override
  String get shashlikFamilyBeefJazz => 'Говяжий шашлык';

  @override
  String get shashlikFamilyLambJazz => 'Бараний шашлык';

  @override
  String get shashlikFamilyChicken => 'Куриные крылышки';

  @override
  String get shashlikFamilyLiver => 'Печень';

  @override
  String get shashlikFamilyMince => 'Фарш';

  @override
  String get shashlikOptionSkewered => 'На шампуре';

  @override
  String get shashlikOptionByKilo => 'На вес';

  @override
  String get shashlikOptionMince => 'Фарш';

  @override
  String get shashlikOptionBreadMince => 'Фарш с хлебом';

  @override
  String get shashlikOptionKiloMince => 'Фарш на вес';

  @override
  String get shashlikChooseProduct => 'Выберите вид продукта и количество';

  @override
  String get shashlikQuantity => 'Количество';

  @override
  String get shashlikQuantityHint =>
      'Прокрутите для выбора или нажмите число для ввода';

  @override
  String get shashlikQuantityInvalid => 'Введите целое число от 1 до 999 999';

  @override
  String get shashlikAddToCart => 'Добавить в корзину';

  @override
  String shashlikPriceFrom(String price) {
    return 'от $price';
  }

  @override
  String shashlikKilogramPrice(String price) {
    return 'За килограмм $price';
  }

  @override
  String shashlikPieceQuantity(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count штуки',
      many: '$count штук',
      few: '$count штуки',
      one: '1 штука',
    );
    return '$_temp0';
  }

  @override
  String shashlikKilogramQuantity(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count килограмма',
      many: '$count килограммов',
      few: '$count килограмма',
      one: '1 килограмм',
    );
    return '$_temp0';
  }

  @override
  String shashlikInCart(int count) {
    return 'В корзине: $count';
  }

  @override
  String get cartTitle => 'Корзина';

  @override
  String get cartEmpty => 'Корзина пуста';

  @override
  String get cartEmptyNow => 'Ваша корзина пока пуста';

  @override
  String get cartRecommendationsTitle => 'Может пригодиться';

  @override
  String get mapAttributionTitle => 'Источники карты';

  @override
  String checkoutDeliveryMinimum(String amount) {
    return 'Минимальная сумма для доставки: $amount';
  }

  @override
  String checkoutMinimumRemaining(String amount) {
    return 'До минимального заказа ещё $amount';
  }

  @override
  String get checkoutMinimumReached => 'Минимальная сумма заказа набрана';

  @override
  String get checkoutAddProducts => 'Добавить товары';

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
  String get householdSearchHint => 'Поиск в Xozmak';

  @override
  String get householdCategorySearchHint => 'Поиск категории';

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
  String get restaurantSectionTraditional => 'Традиционные блюда';

  @override
  String get restaurantSectionGrillTandoor => 'Гриль и тандыр';

  @override
  String get restaurantSectionSaladsTable => 'Салаты и дополнения';

  @override
  String get restaurantSectionDessertsDrinks => 'Десерты и напитки';

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
  String get paymeAwaitingPayment => 'Ожидаем оплату';

  @override
  String get paymePaymentRefundPending =>
      'Заказ отменён. Ожидается возврат денег.';

  @override
  String get paymePaymentRefunded => 'Деньги возвращены';

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
  String get homeForYou => 'Для вас';

  @override
  String get homeForYouSubtitle => 'Подобрали по вашим интересам';

  @override
  String catalogSimilarTo(String name) {
    return 'Похожие на «$name»';
  }

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
  String get cartIncreaseQuantity => 'Увеличить количество';

  @override
  String get cartDecreaseQuantity => 'Уменьшить количество';

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
  String get ordersRecommendedTitle => 'Вам может понравиться';

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
  String get orderCancelCallCourier =>
      'Курьер забрал заказ и уже в пути. Для отмены позвоните курьеру.';

  @override
  String get orderCancelCallAction => 'Позвонить курьеру';

  @override
  String get orderCourierPhoneUnavailable =>
      'Номер телефона курьера пока недоступен.';

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
  String orderWaitingElapsed(Object elapsed) {
    return 'Ожидание: $elapsed';
  }

  @override
  String get orderStatusDelivering => 'Курьер в пути';

  @override
  String get orderStageAwaiting => 'Ожидаем подтверждения заказа';

  @override
  String get orderStageAwaitingHint => 'Курьер рассматривает ваш заказ';

  @override
  String get orderStagePreparing => 'Ваш заказ готовится';

  @override
  String get orderStagePreparingHint => 'Курьер едет в магазин';

  @override
  String get orderStageOnWay => 'Курьер выехал к вам';

  @override
  String get orderStageOnWayHint => 'Ваш заказ направляется к вашему адресу';

  @override
  String get orderStageDelivered => 'Заказ доставлен';

  @override
  String get orderStageDeliveredHint => 'Спасибо за покупку!';

  @override
  String get orderDeliveryWindowTitle => 'Доставим в';

  @override
  String get orderDeliveryWindowPending =>
      'Уточним после подтверждения курьером';

  @override
  String orderDeliveredAt(String time) {
    return 'Доставлен · $time';
  }

  @override
  String get orderSummaryTitle => 'Детали заказа';

  @override
  String orderSummaryProducts(int count) {
    return '$count товар(ов)';
  }

  @override
  String get orderDeliveryDetails => 'Детали доставки';

  @override
  String get orderRecipientPhone => 'Номер получателя';

  @override
  String get orderPaymentMethodLabel => 'Способ оплаты';

  @override
  String get orderPaymentCash => 'Наличными курьеру';

  @override
  String get orderPaymentPayme => 'Payme';

  @override
  String get orderDeliveryFree => 'Бесплатно';

  @override
  String get orderBackToOrder => 'Вернуться к заказу';

  @override
  String get orderHelp => 'Помощь';

  @override
  String get orderOpenMap => 'Развернуть карту';

  @override
  String get orderStatusAwaiting => 'Ждёт подтверждения';

  @override
  String get orderStatusPreparing => 'Готовится';

  @override
  String get orderCourierRole => 'Курьер';

  @override
  String get orderVehicleFoot => 'Пешком';

  @override
  String get orderVehicleBicycle => 'Велосипед';

  @override
  String get orderVehicleMotorcycle => 'Мотоцикл';

  @override
  String get orderVehicleCar => 'Автомобиль';

  @override
  String get orderStatusDelivered => 'Доставлен';

  @override
  String get orderStatusCancelled => 'Отменён';

  @override
  String get orderStatusProcessing => 'В обработке';

  @override
  String orderArrivesInMinutes(Object minutes) {
    return 'В течение $minutes мин.';
  }

  @override
  String get orderCallCourier => 'Позвонить';

  @override
  String get orderCopyPhone => 'Скопировать номер';

  @override
  String get orderPhoneCopied => 'Номер телефона скопирован';

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

  @override
  String get checkoutDeliveryMapTitle => 'Карта доставки';

  @override
  String get checkoutMapStore => 'Магазин';

  @override
  String get checkoutMapAddress => 'Адрес доставки';

  @override
  String get checkoutMapYou => 'Вы здесь';

  @override
  String get checkoutMapFit => 'Показать всё';

  @override
  String get checkoutMapExpand => 'Развернуть';

  @override
  String get checkoutMapLocating => 'Определяем местоположение';

  @override
  String get checkoutMapGpsUnavailable =>
      'Не удалось определить местоположение телефона. Можно выбрать адрес вручную.';

  @override
  String get checkoutGpsDenied =>
      'Доступ к геолокации не разрешён. Адрес доставки можно выбрать вручную.';

  @override
  String get checkoutGpsDeniedForever =>
      'Разрешите геолокацию в настройках телефона или выберите адрес вручную.';

  @override
  String get checkoutGpsDisabled =>
      'GPS выключен. Включите его или выберите адрес вручную.';

  @override
  String get checkoutGpsTimeout =>
      'GPS не ответил вовремя. Повторите попытку или выберите адрес вручную.';

  @override
  String get checkoutGpsStale =>
      'Данные GPS устарели. Обновите местоположение или выберите адрес вручную.';

  @override
  String get checkoutGpsApproximate =>
      'Местоположение приблизительное. Включите точную геолокацию или обновите GPS.';

  @override
  String get checkoutGpsSettings => 'Открыть настройки';

  @override
  String get checkoutMapTilesUnavailable =>
      'Не загрузились изображения карты. Метки адресов работают.';

  @override
  String get checkoutMapCoverageUnavailable =>
      'Не удалось показать филиал на карте. Вы можете выбрать сохранённый адрес.';

  @override
  String checkoutCoverageRadius(String radius) {
    return 'Радиус доставки: $radius км';
  }

  @override
  String checkoutOutsideRadius(String radius) {
    return 'Адрес вне радиуса доставки $radius км. Выберите другой адрес или самовывоз.';
  }

  @override
  String get checkoutTariffUnavailable =>
      'Пока не удалось определить стоимость доставки по этому адресу.';

  @override
  String get checkoutMapPreviewHint =>
      'Это предварительный просмотр зоны филиала. Выберите адрес доставки для заказа.';

  @override
  String get cartUnavailable =>
      'Этот товар сейчас недоступен для заказа. Удалите его из корзины.';

  @override
  String get cartVariantUnavailable =>
      'Выбранный вариант недоступен. Выберите товар заново.';

  @override
  String get cartAddonsUnavailable =>
      'Выбранные дополнения недоступны. Выберите товар заново.';

  @override
  String get orderCancellationUnavailable =>
      'Этот заказ уже нельзя отменить. Обновите статус заказа.';

  @override
  String get errorValidation => 'Проверьте данные и попробуйте снова.';

  @override
  String get checkoutResumePending =>
      'Нужно проверить результат предыдущего заказа. Продолжите.';

  @override
  String get catalogSwipeProducts => 'Листайте вбок';

  @override
  String get storeSwitchTitle => 'Сменить магазин';

  @override
  String get storeSwitchKeepsCart =>
      'Корзина и выбранные параметры каждого магазина сохранятся.';
}
