/*
*	HLX:CE Inforank			     v. 0.2
*	by serfreeman1337	    http://1337.uz/
*/

#include <amxmodx>
#include <nvault>
#include <sqlx>
#include <hamsandwich>

#if AMXX_VERSION_NUM < 183
	#include <colorchat>
	
	#define print_team_default DontChange
	#define print_team_grey Grey
	#define print_team_red Red
	#define print_team_blue Blue
#endif

enum _:cvars 
{
	CVAR_HOST,
	CVAR_USER,
	CVAR_PASS,
	CVAR_DB,
	CVAR_PREFIX,
	CVAR_GAME,
	CVAR_TRACK,
	CVAR_ADVERT
}

new cvar[cvars]

public plugin_init() {
	register_plugin("HLX:CE Inforank","0.2","serfreeman1337")
	
	/*
	* Хост БД
	*/
	cvar[CVAR_HOST] = register_cvar("ir_host", "localhost", FCVAR_PROTECTED)
	
	/*
	* Пользователь БД
	*/
	cvar[CVAR_USER] = register_cvar("ir_user", "root", FCVAR_PROTECTED)
	
	/*
	* Пароль пользователя БД
	*/
	cvar[CVAR_PASS] = register_cvar("ir_pass", "", FCVAR_PROTECTED|FCVAR_UNLOGGED)
	
	/*
	* Название БД HLstatsX
	*/
	cvar[CVAR_DB] = register_cvar("ir_db", "hlxce", FCVAR_PROTECTED|FCVAR_UNLOGGED)
	
	/*
	* Префикс таблиц HLstatsX
	*/
	cvar[CVAR_PREFIX] = register_cvar("ir_prefix", "hlstats_", FCVAR_PROTECTED|FCVAR_UNLOGGED)
	
	/*
	* Код игры сервера
	* Посмотреть можно на странице настройек: hlstats.php?mode=admin&task=games
	*/
	cvar[CVAR_GAME] = register_cvar("ir_game","valve",FCVAR_PROTECTED|FCVAR_UNLOGGED)
	
	/*
	* Как ведется учет игроков
	* 	1 - по нику
	* 	2 - по ip
	* 	3 - по steamid
	*/
	cvar[CVAR_TRACK] = register_cvar("ir_track", "3",FCVAR_PROTECTED|FCVAR_UNLOGGED)
	
	/*
	* Оповещение о текущем ранге игрока
	*	0.0 - через 5 секунд после первого спавна
	*	больше 0.0 - через указанное кол-во секунд после первого спавна
	*/
	cvar[CVAR_ADVERT] = register_cvar("ir_advert","0.0")
	
	RegisterHam(Ham_Spawn,"player","HamHook_PlayerSpawn",true)
	
	register_dictionary("inforank_hlxce.txt")
}

/*
* Спавн игрока
*/
public HamHook_PlayerSpawn(id)
{
	if(!is_user_alive(id))
	{
		return HAM_IGNORED
	}
	
	new Float:adv_time = get_pcvar_float(cvar[CVAR_ADVERT])
	
	if(adv_time == 0.0) // отображаем сообщение один раз через 5 секунд после спавна
	{
		set_task(5.0,"info_rank",id)
	}
	else if(adv_time > 0.0 && !task_exists(id)) // отображаем соощение каждые n секунд после спавна
	{
		set_task(adv_time,"info_rank",id,.flags = "b")
	}
	
	return HAM_IGNORED
}

/*
* Строим запрос на отображение сообщения о позици игрока в статистике
*/
public info_rank(id){
	if(!is_user_connected(id))
	{
		remove_task(id)
		
		return PLUGIN_HANDLED
	}
	
	new uid[32],len
	
	switch(get_pcvar_num(cvar[CVAR_TRACK])){
		case 1: get_user_name(id,uid,charsmax(uid))
		case 2: get_user_ip(id,uid,charsmax(uid),true)
		case 3: {
			get_user_authid(id,uid,charsmax(uid))
			replace(uid,charsmax(uid), "STEAM_0:", "")
		}
	}
	
	new query[512]
	static prefix[20],mod[20],Handle:sql
	
	if(sql == Empty_Handle)
	{
		get_pcvar_string(cvar[CVAR_GAME],mod,charsmax(mod))
		get_pcvar_string(cvar[CVAR_PREFIX],prefix,charsmax(prefix))
		
		new host[64],user[64],pass[64],db[64]
		
		get_pcvar_string(cvar[CVAR_HOST],host,charsmax(host))
		get_pcvar_string(cvar[CVAR_USER],user,charsmax(user))
		get_pcvar_string(cvar[CVAR_PASS],pass,charsmax(pass))
		get_pcvar_string(cvar[CVAR_DB],db,charsmax(db))
		
		sql = SQL_MakeDbTuple(host,user,pass,db,5)
	}
	
	len = formatex(query[len],charsmax(query)-len, 
		"SELECT `a`.`skill` AS `lol`,\
		(SELECT playerId FROM %sPlayerUniqueIds WHERE uniqueId = '%s') AS `smId`,\
		(SELECT COUNT(*) FROM %sPlayers WHERE skill >= lol AND hideranking = 0 AND game = '%s' AND kills > 0) AS `rank`,\
		",prefix,uid,prefix,mod)
		
	len += formatex(query[len],charsmax(query)-len,
		"(SELECT COUNT(*) FROM %sPlayers WHERE game = '%s') AS `snum`\
		FROM %sPlayers AS `a`,%sPlayerUniqueIds AS `b` \
		WHERE `b`.`uniqueId` = '%s' \
		AND `b`.`playerId` = `a`.`playerId` \
		AND `b`.`game` = '%s'",prefix,mod,prefix,prefix,uid,mod)
		
	new data[1]
	data[0] = id
	
	SQL_ThreadQuery(sql,"show_info",query,data,sizeof data)
	
	return PLUGIN_CONTINUE
}


/*
* Вывод сообщения
*/
public show_info(fail,Handle:query,err[],errnum,data[],datasize){
	if(fail){
		new error[1024]
		SQL_QueryError(query,error,1023)
		log_amx("MySQL Query Failed [%s] [%d]",err,errnum)
		log_amx("%s",error)
	}else{
		new id = data[0]

		// игрока еще нету в статистике или он уже отключился от сервера
		if(!SQL_NumResults(query) || !is_user_connected(id))
		{
			return PLUGIN_HANDLED
		}
		
		// смотрим предедущею позицию в nvault
		new vault,uid[32],temp[32]
		vault = nvault_open("info_rank")
		
		switch(get_pcvar_num(cvar[CVAR_TRACK])){
			case 1: get_user_name(id,uid,charsmax(uid))
			case 2: get_user_ip(id,uid,charsmax(uid),1)
			case 3: {
				get_user_authid(id,uid,31)
				replace(uid,31, "STEAM_0:", "")
			}
		}
		
		new skill = SQL_ReadResult(query,0)
		new rank = SQL_ReadResult(query,2)
		
		nvault_get(vault,uid,temp,charsmax(temp))
		new prerank = str_to_num(temp)
		
		new maxrank = SQL_ReadResult(query,3)
		
		new diff=prerank-rank
		
		if(diff>0)
		{
			client_print_color(id,print_team_blue,"%L",id,"IR_GOOD",diff)
		}
		else if(diff < 0)
		{
			client_print_color(id,print_team_red,"%L",id,"IR_BAD",abs(diff))
		}
			
		client_print_color(id,print_team_default,"%L",id,"IR_RANK",rank,maxrank,skill)
		
		// запоминаем посл. позицию в nvault
		num_to_str(rank,temp,31)
		nvault_set(vault,uid,temp)
		
		new prune_time=(get_systime()-(28*86400))
		nvault_prune(vault,0,prune_time)
		
		nvault_close(vault)
	}
	
	return PLUGIN_HANDLED
}
