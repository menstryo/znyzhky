// Великі міста: id (наш), назва, слаг GoToShop, місто в Zakaz.ua (якщо там є магазини).
export const CITIES = [
  { id: "kyiv",      name: "Київ",              gts: "kiev",            zakaz: "kiev" },
  { id: "kharkiv",   name: "Харків",            gts: "kharkov",         zakaz: "kharkiv" },
  { id: "odesa",     name: "Одеса",             gts: "odessa",          zakaz: "odesa" },
  { id: "dnipro",    name: "Дніпро",            gts: "dnepr",           zakaz: "dnipro" },
  { id: "lviv",      name: "Львів",             gts: "lvov",            zakaz: "lviv" },
  { id: "zaporizh",  name: "Запоріжжя",         gts: "zaporozhye",      zakaz: null },
  { id: "kryvyirih", name: "Кривий Ріг",        gts: "krivoy-rog",      zakaz: "kryvyyrig" },
  { id: "vinnytsia", name: "Вінниця",           gts: "vinnitsa",        zakaz: "vinnytsia" },
  { id: "poltava",   name: "Полтава",           gts: "poltava",         zakaz: "poltava" },
  { id: "mykolaiv",  name: "Миколаїв",          gts: "nikolaev",        zakaz: null },
  { id: "chernihiv", name: "Чернігів",          gts: "chernigov",       zakaz: null },
  { id: "cherkasy",  name: "Черкаси",           gts: "cherkasy",        zakaz: null },
  { id: "sumy",      name: "Суми",              gts: "sumy",            zakaz: null },
  { id: "zhytomyr",  name: "Житомир",           gts: "zhitomir",        zakaz: "zhytomyr" },
  { id: "khmeln",    name: "Хмельницький",      gts: "khmelnitsky",     zakaz: null },
  { id: "chernivtsi",name: "Чернівці",          gts: "chernovtsy",      zakaz: "chernivtsi" },
  { id: "rivne",     name: "Рівне",             gts: "rovno",           zakaz: "rivne" },
  { id: "ifrank",    name: "Івано-Франківськ",  gts: "ivano-frankovsk", zakaz: "ivanofrankivsk" },
  { id: "ternopil",  name: "Тернопіль",         gts: "ternopol",        zakaz: null },
  { id: "lutsk",     name: "Луцьк",             gts: "lutsk",           zakaz: null },
  { id: "kropyv",    name: "Кропивницький",     gts: "kirovograd",      zakaz: null },
  { id: "uzhhorod",  name: "Ужгород",           gts: "uzhgorod",        zakaz: null },
];

// Мережі з Zakaz.ua (товари з назвами → основна сітка)
export const ZAKAZ_CHAINS = [
  { chain: "novus",     name: "Novus" },
  { chain: "ekomarket", name: "ЕКО маркет" },
  { chain: "metro",     name: "Metro" },
];

// Мережі з газетками на GoToShop (окремий розділ «Газетки»). Форта — з власного сайту (leaflets.mjs).
export const LEAFLET_CHAINS = [
  { slug: "sim-23", id: "sim23",  name: "Сім23" },
  { slug: "salyut", id: "salyut", name: "Салют" },
  { slug: "fora",   id: "fora",   name: "Фора" },
];
