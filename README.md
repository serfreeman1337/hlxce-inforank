# HLStatsX:CE InfoRank
Отображение изменений позиции игрока в статистике HLStatsX:CE

## Квары
* **ir_host** "localhost" - хост бд
* **ir_user** "root" - пользователь бд
* **ir_pass** "" - пароль бд
* **ir_db** "hlxce" - название бд hlstatsx
* **ir_prefix** "hlstats_" - префикс таблиц hlstatsx
* **ir_game** "valve" - код игры сервера
* **ir_track** "3" - тип учета игроков в hlstatsx
	* 1 - по нику
	* 2 - по ip
	* 3 - по steamid
* **ir_advert** "0.0" - сообщение об изменении позиции игрока
	* 0.0 - показывать через 5 секунд после первого спавна
	* больше 0.0 - показывать каждые указанное кол-во секунд после первого спавна

## Информация
* colorchat.inc можно скачать на странице компилятора AGHL.ru (http://aghl.ru/webcompiler/include/colorchat.inc)